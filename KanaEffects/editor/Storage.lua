-- Stable native envelope; profile.schemaVersion is validated separately.
-- Source signatures, corruption policy and load phase: docs/storage-reference.md.
local Storage={}; Storage.__index=Storage; KanaEffects.Storage=Storage
local function diagnostic(code,path,message) return {code=code,path=path,message=message} end
local function finite(n) return type(n)=='number' and n==n and math.abs(n)<math.huge end
local function copy(value,active,issues,path)
    local kind=type(value); path=path or 'data'; active=active or {}; issues=issues or {}
    if kind=='table' then
        if active[value] or getmetatable(value) then
            issues[#issues+1]=diagnostic('nonserializable',path,'Runtime table omitted from recovery')
            return {recoveryOmitted=active[value] and 'cycle' or 'metatable'}
        end
        active[value]=true; local out={}
        for key,item in pairs(value) do
            if type(key)=='string' or (type(key)=='number' and finite(key)) then out[key]=copy(item,active,issues,path..'['..tostring(key)..']')
            else issues[#issues+1]=diagnostic('nonserializable',path,'Runtime key omitted from recovery') end
        end
        active[value]=nil; return out
    elseif kind=='function' or kind=='userdata' or kind=='thread' or (kind=='number' and not finite(value)) then
        issues[#issues+1]=diagnostic('nonserializable',path,'Runtime value omitted from recovery')
        return {recoveryOmitted=kind}
    end
    return value
end
local function append(a,b) for _,v in ipairs(b) do a[#a+1]=v end end
local function equal(a,b)
    if type(a)~=type(b) then return false end; if type(a)~='table' then return a==b end
    for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end; return true
end
local function validate(profile)
    local ok,diag=KanaEffects.Schema.Validate(profile); if not ok then return false,diag end
    local compiled; compiled,diag=KanaEffects.Rules.Compile(profile.sets,profile.longThreshold,profile.widgets); if not compiled then return false,diag end
    return #diag==0,diag
end
local function normalizedProfile(profile)
    local valid,diag=KanaEffects.Schema.Validate(profile)
    if not valid then return nil,diag end
    local candidate=KanaEffects.Schema.CopyProfile(profile)
    KanaEffects.Rules.NormalizePanelFunctions(candidate)
    local ok,issues=validate(candidate)
    if not ok then return nil,issues end
    return candidate,issues
end
local function dense(value)
    if type(value)~='table' then return false end
    local n,max=0,0; for k in pairs(value) do
        if type(k)~='number' or not finite(k) or k<1 or k%1~=0 then return false end
        n=n+1; max=math.max(k,max)
    end
    return n==max
end
local function recordValid(row)
    if type(row)~='table' or row.synthetic~=false or
        type(row.unitTag)~='string' or row.unitTag=='' or not finite(row.lastSeen) or type(row.catalog)~='table' then return false end
    local clock=row.lastSeenClock
    if clock~=nil and clock~='session-frame-seconds' and clock~='legacy-frame-seconds' and clock~='native-timestamp-seconds' then return false end
    if clock=='native-timestamp-seconds' and (row.lastSeen<0 or row.lastSeen%1~=0) then return false end
    local c=row.catalog
    local id=row.artificialEffectId or row.abilityId
    if not finite(id) or id<(row.artificialEffectId~=nil and 0 or 1) or id%1~=0 then return false end
    if row.artificialEffectId~=nil then
        if row.abilityId~=nil or c.abilityId~=nil or c.artificialEffectId~=row.artificialEffectId then return false end
    elseif c.abilityId~=row.abilityId or c.artificialEffectId~=nil then return false end
    if type(c.name)~='string' or type(c.icon)~='string' or not dense(c.aliases) or type(c.categories)~='table' or
        (c.origin~='skill' and c.origin~='set' and c.origin~='enchant' and c.origin~='unknown') or
        not finite(c.apiVersion) or type(c.provenance)~='string' or type(c.verified)~='boolean' or
        (c.familyId~=nil and (type(c.familyId)~='string' or c.familyId=='')) or
        (c.level~=nil and c.level~='minor' and c.level~='major') or (c.rank~=nil and not finite(c.rank)) or
        (row.provenance~=nil and type(row.provenance)~='string') then return false end
    for _,alias in ipairs(c.aliases) do if type(alias)~='string' then return false end end
    for key,v in pairs(c.categories) do if type(key)~='string' or v~=true then return false end end
    return true
end
local function historyData(data,importing)
    local issues={}; local safe=copy(data,nil,issues,'history'); local out={}; local diag={}
    if #issues>0 then return {},issues end
    if not dense(safe) then return {},{diagnostic('invalid_history','history','Expected a dense history list')} end
    for i,row in ipairs(safe) do
        if recordValid(row) then
            if row.lastSeenClock==nil or (importing and row.lastSeenClock=='session-frame-seconds') then row.lastSeenClock='legacy-frame-seconds' end
            out[#out+1]=row
        else diag[#diag+1]=diagnostic('invalid_history','history['..i..']','Malformed or synthetic history record') end
    end
    while #out>1000 do table.remove(out,1) end
    if #safe>1000 then diag[#diag+1]=diagnostic('history_capacity','history','Only the newest 1000 real records may load') end
    return out,diag
end
function Storage.New(api,defaultsProvider)
    assert(type(defaultsProvider)=='function','Storage requires defaultsProvider')
    return setmetatable({api=api,defaultsProvider=defaultsProvider,diagnostics={},quarantined={}},Storage)
end
function Storage:_Preserve(container,path,value,diagnostics)
    local issues={}; local original=copy(value,nil,issues,path)
    if self.quarantined[path] and equal(self.quarantined[path],original) then return end
    local recovery=rawget(container,'recovery')
    local previousRecovery
    if not dense(recovery) or getmetatable(recovery) then
        if recovery~=nil then previousRecovery=copy(recovery,nil,issues,path..'.recovery') end
        recovery={}; rawset(container,'recovery',recovery)
    end
    -- Repeated Load/reloads of unchanged corrupt data must not grow recovery.
    for _,row in ipairs(recovery) do
        if type(row)=='table' and not getmetatable(row) and rawget(row,'path')==path and
            equal(copy(rawget(row,'original')),original) then
            self.quarantined[path]=copy(original); append(self.diagnostics,issues); return
        end
    end
    recovery[#recovery+1]={path=path,original=original,diagnostics=copy(diagnostics),lossy=#issues>0,previousRecovery=previousRecovery}
    self.quarantined[path]=copy(original)
    append(self.diagnostics,issues)
end
function Storage:_Open()
    if self.opened then return end; self.opened=true
    local api=self.api
    local world=api.GetWorldName and api.GetWorldName(); local account=api.GetDisplayName and api.GetDisplayName()
    local id=api.GetCurrentCharacterId and api.GetCurrentCharacterId(); local name=api.GetUnitName and api.GetUnitName('player')
    if type(world)~='string' or world=='' or type(account)~='string' or account=='' or type(id)~='string' or id=='' or
        not api.GetSettingsTable or not api.SetSettingsTable or not api.savedVars or type(api.savedVars.NewCharacterIdSettings)~='function' then
        self.diagnostics[#self.diagnostics+1]=diagnostic('storage_unavailable','storage','Character/world SavedVariables unavailable; settings are memory-only')
        return
    end
    local root=api.GetSettingsTable()
    if root==nil then root={}; api.SetSettingsTable(root)
    elseif type(root)~='table' or getmetatable(root) then
        local original=root; local diag={diagnostic('corrupt_path','root','Invalid SavedVariables root')}
        root={}; self:_Preserve(root,'root',original,diag); append(self.diagnostics,diag); api.SetSettingsTable(root)
    end
    local current=root
    for _,key in ipairs({world,account}) do
        local value=rawget(current,key)
        if value==nil then value={}; rawset(current,key,value)
        elseif type(value)~='table' or getmetatable(value) then
            local diag={diagnostic('corrupt_path',key,'Invalid SavedVariables path')}; self:_Preserve(root,key,value,diag); append(self.diagnostics,diag)
            value={}; rawset(current,key,value)
        end
        current=value
    end
    local envelope=rawget(current,id)
    -- Import only a missing ID leaf. Leave original name-key data intact; stock
    -- migration on the full global would otherwise overwrite an existing ID leaf.
    if envelope==nil and type(name)=='string' and name~=id and rawget(current,name)~=nil then
        local legacy=rawget(current,name); local issues={}; envelope=copy(legacy,nil,issues,'legacy'); append(self.diagnostics,issues)
    end
    if envelope==nil then envelope={version=1}; rawset(current,id,envelope)
    elseif type(envelope)~='table' or getmetatable(envelope) then
        local diag={diagnostic('corrupt_path','character','Invalid character envelope')}; self:_Preserve(root,'character',envelope,diag); append(self.diagnostics,diag)
        envelope={version=1}; rawset(current,id,envelope)
    else rawset(current,id,envelope) end
    if envelope.version~=1 then
        local diag={diagnostic('native_version','version','Preserved character envelope before stabilizing native version')}
        self:_Preserve(envelope,'envelope',envelope,diag); append(self.diagnostics,diag); envelope.version=1
    end
    -- Public helper supports table input; share exactly this leaf with global.
    -- Empty defaults prevent hidden repair of malformed user profile fields.
    local isolated={[world]={[account]={[id]=envelope}}}
    local ok,proxy=pcall(api.savedVars.NewCharacterIdSettings,api.savedVars,isolated,1,nil,{},world)
    if ok and type(proxy)=='table' then self.proxy=proxy; self.envelope=envelope
    else self.diagnostics[#self.diagnostics+1]=diagnostic('storage_unavailable','storage','SavedVariables helper failed safely') end
end
function Storage:Load()
    self:_Open()
    local profile=self.proxy and self.proxy.profile
    if profile~=nil then
        local candidate,diag=normalizedProfile(profile)
        if candidate then return candidate,copy(self.diagnostics) end
        self:_Preserve(self.envelope,'profile',profile,diag)
        local diagnostics=copy(self.diagnostics); append(diagnostics,diag)
        local fallback=self.defaultsProvider(); local valid=validate(fallback); assert(valid,'Invalid Storage defaults')
        return KanaEffects.Schema.CopyProfile(fallback),diagnostics
    end
    local fallback=self.defaultsProvider(); local valid=validate(fallback); assert(valid,'Invalid Storage defaults')
    return KanaEffects.Schema.CopyProfile(fallback),copy(self.diagnostics)
end
function Storage:Write(profile)
    local candidate,diag=normalizedProfile(profile); if not candidate then return false,diag end
    self:_Open()
    if not self.proxy then return false,copy(self.diagnostics) end
    self.proxy.profile=candidate; return true,{}
end
function Storage:LoadHistory()
    self:_Open(); if not self.proxy or self.proxy.history==nil then return {},copy(self.diagnostics) end
    local result,diag=historyData(self.proxy.history,true)
    if #diag>0 then self:_Preserve(self.envelope,'history',self.proxy.history,diag) end
    local diagnostics=copy(self.diagnostics); append(diagnostics,diag); return result,diagnostics
end
function Storage:WriteHistory(data)
    local result,diag=historyData(data); if #diag>0 then return false,diag end
    self:_Open(); if not self.proxy then return false,copy(self.diagnostics) end
    self.proxy.history=result; return true,{}
end
