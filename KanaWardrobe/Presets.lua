local KW = KanaWardrobe
local Presets = {}
KW.Presets = Presets
Presets.QUICK_ID = "__quick__"
local Repo = {}; Repo.__index = Repo
-- Runtime-only cache shared by every repository over the same account table.
-- No functions, derived index, or mutation revision enter SavedVariables.
local accountIndexes=setmetatable({}, {__mode="k"})
local function invalidate(repo)
    repo.index.revision=repo.index.revision+1
end
local function validUid(uid) return type(uid)=="string" and uid~="" and uid~="0" end
local function normalizeName(name)
    if type(name) ~= "string" then return nil, KW.Problem("invalidName") end
    name = name:gsub("[\r\n\t]", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if name=="" or name:find("|", 1, true) or name:find("[%z\1-\31\127]") then
        return nil, KW.Problem("invalidName")
    end
    if ZoUTF8StringLength(name)>48 then return nil, KW.Problem("nameTooLong", {max=48}) end
    return name
end
Presets.NormalizeName = normalizeName

function Presets.New(saved, server, account, characterId, characterName, emit)
    assert(saved.schemaVersion == nil or saved.schemaVersion == 1 or saved.schemaVersion == 2, "Unsupported KanaWardrobe saved schema")
    saved.schemaVersion = 2
    saved.servers = saved.servers or {}
    for _,world in pairs(saved.servers) do
        for _,acct in pairs(world.accounts or {}) do
            for _,char in pairs(acct.characters or {}) do
                for id,preset in pairs(char.presets or {}) do
                    local normalized=KW.BuildModel.Normalize(preset)
                    if normalized then char.presets[id]=normalized end
                end
                if char.quickPreset then
                    local normalized=KW.BuildModel.Normalize(char.quickPreset)
                    if normalized then char.quickPreset=normalized end
                end
            end
        end
    end
    saved.servers[server] = saved.servers[server] or {accounts={}}
    local accounts = saved.servers[server].accounts
    accounts[account] = accounts[account] or {characters={}}
    local characters = accounts[account].characters
    characterId = tostring(characterId)
    characters[characterId] = characters[characterId] or {order={}, presets={}, hidePresetItems=false, nextId=1}
    local character = characters[characterId]
    local index=accountIndexes[characters]
    if not index then index={revision=0,builtRevision=-1};accountIndexes[characters]=index end
    if character.name~=characterName then index.revision=index.revision+1 end
    character.name = characterName
    character.nextId = character.nextId or 1
    return setmetatable({characters=characters, character=character, characterId=characterId,
        emit=emit or function() end,index=index}, Repo)
end
local function runtime(preset)
    if not preset then return nil end
    local result=KW.Copy(preset)
    result.slots=result.equipment or {}
    return result
end
function Repo:Get(id) return runtime(id==Presets.QUICK_ID and self.character.quickPreset or self.character.presets[id]) end
function Repo:List()
    local result = {}
    for _, id in ipairs(self.character.order) do
        local preset = self:Get(id)
        if preset then result[#result+1] = preset end
    end
    return result
end
function Repo:NameExists(name, exceptId)
    local folded = zo_strlower(name)
    for id, preset in pairs(self.character.presets) do
        if id ~= exceptId and zo_strlower(preset.name) == folded then return true end
    end
    return false
end
function Repo:NewDraft()
    local id
    repeat
        id = self.characterId .. ":" .. tostring(self.character.nextId)
        self.character.nextId = self.character.nextId + 1
    until not self.character.presets[id]
    local base = KW.Text("NEW_PRESET")
    local name, suffix = base, 2
    while self:NameExists(name) do name=base .. " " .. tostring(suffix); suffix=suffix+1 end
    return runtime({id=id, name=name, revision=0, equipment={}})
end
function Repo:SaveQuick(input)
    if type(input)~="table" then return nil,KW.Problem("invalidPreset") end
    local legacy=input.equipment==nil and input.abilities==nil and input.attributes==nil and input.slots==nil
    local build,problem=KW.BuildModel.Normalize(legacy and {slots=input} or input)
    if not build then return nil,problem end
    local old=self.character.quickPreset
    if (legacy or input.slots~=nil) and old then
        build.abilities=KW.Copy(old.abilities)
        build.attributes=KW.Copy(old.attributes)
    end
    if not KW.BuildModel.HasParts(build) then return nil,KW.Problem("invalidPreset") end
    build.id=Presets.QUICK_ID;build.name=KW.Text("QUICK_PRESET");build.revision=(old and old.revision or 0)+1
    self.character.quickPreset=build
    invalidate(self)
    self.emit("PresetsChanged",{kind="quick",presetId=build.id,characterId=self.characterId})
    return runtime(build)
end
function Repo:Save(preset, expectedRevision)
    if type(preset)~="table" or type(preset.id)~="string" then
        return nil, KW.Problem("invalidPreset")
    end
    local old = self.character.presets[preset.id]
    if expectedRevision ~= (old and old.revision or 0) then return nil, KW.Problem("revisionConflict") end
    local name, problem = normalizeName(preset.name)
    if not name then return nil, problem end
    if self:NameExists(name,preset.id) then return nil, KW.Problem("duplicateName") end
    local stored,buildProblem=KW.BuildModel.Normalize(preset)
    if not stored then return nil,buildProblem end
    if preset.slots~=nil and old then
        stored.abilities=KW.Copy(old.abilities);stored.attributes=KW.Copy(old.attributes)
    end
    if not KW.BuildModel.HasParts(stored) then return nil,KW.Problem("invalidPreset") end
    stored.id=preset.id;stored.name=name;stored.revision=expectedRevision+1
    self.character.presets[preset.id] = stored
    if not old then self.character.order[#self.character.order+1] = preset.id end
    invalidate(self)
    self.emit("PresetsChanged", {kind=old and "updated" or "created", presetId=preset.id, characterId=self.characterId})
    return runtime(stored)
end
-- The private commit barrier runs after durable assignment and before public observers.
function Repo:PatchComponent(id,component,patch,name,expectedRevision,onCommitted)
    if component~="equipment" and component~="abilities" and component~="attributes" then return nil,KW.Problem("invalidComponent") end
    return self:PatchComponents(id,{[component]=patch},name,expectedRevision,onCommitted)
end
function Repo:PatchComponents(id,patches,name,expectedRevision,onCommitted)
    if type(patches)~="table" then return nil,KW.Problem("invalidComponentPatch") end
    local old=id and self.character.presets[id]
    if id~=nil and not old then return nil,KW.Problem("presetMissing") end
    if id==nil and expectedRevision~=nil or old and expectedRevision~=old.revision then return nil,KW.Problem("revisionConflict") end
    local candidate=old and KW.Copy(old) or {}
    for component,patch in pairs(patches)do
        if component~="equipment" and component~="abilities" and component~="attributes" then return nil,KW.Problem("invalidComponent") end
        if type(patch)~="table" or (patch.op~="replace" and patch.op~="remove") then return nil,KW.Problem("invalidComponentPatch") end
        if patch.op=="remove" then candidate[component]=nil
        else
            if patch.value==nil then return nil,KW.Problem("invalidComponentPatch") end
            local normalized,problem=KW.BuildModel.Normalize({[component]=patch.value})
            if not normalized then return nil,problem end
            candidate[component]=normalized[component]
        end
    end
    local normalized,problem=KW.BuildModel.Normalize(candidate);if not normalized then return nil,problem end
    if not KW.BuildModel.HasParts(normalized) then return nil,KW.Problem("invalidPreset") end
    local default=old and old.name or KW.Text("NEW_PRESET")
    if not old and name==nil then local suffix=2;while self:NameExists(default)do default=KW.Text("NEW_PRESET").." "..suffix;suffix=suffix+1 end end
    local validName,err=normalizeName(name==nil and default or name);if not validName then return nil,err end
    if self:NameExists(validName,id) then return nil,KW.Problem("duplicateName") end
    if id==nil then id=self:NewDraft().id end
    normalized.id=id;normalized.name=validName;normalized.revision=(old and old.revision or 0)+1
    self.character.presets[id]=normalized
    if not old then self.character.order[#self.character.order+1]=id end
    invalidate(self)
    if onCommitted then onCommitted(KW.Copy(normalized)) end
    self.emit("PresetsChanged",{kind=old and "updated" or "created",presetId=id,characterId=self.characterId})
    return runtime(normalized)
end

function Repo:Duplicate(id, expectedRevision)
    local source=self.character.presets[id]
    if not source then return nil,KW.Problem('presetMissing') end
    if source.revision~=expectedRevision then return nil,KW.Problem('revisionConflict') end
    local name,number=nil,1
    repeat
        local suffix=' ('..KW.Text('COPY')..(number>1 and ' '..number or '')..')'
        local base=source.name
        while ZoUTF8StringLength(base..suffix)>48 do
            base=base:gsub('[^\128-\191][\128-\191]*$','')
        end
        name=base:gsub('%s+$','')..suffix;number=number+1
    until not self:NameExists(name)
    local copy=KW.Copy(source)
    copy.id=self:NewDraft().id;copy.name=name;copy.revision=0
    return self:Save(copy,0)
end

function Repo:Delete(id, expectedRevision)
    local old=self.character.presets[id]
    if not old then return nil, KW.Problem("presetMissing") end
    if old.revision~=expectedRevision then return nil, KW.Problem("revisionConflict") end
    self.character.presets[id]=nil
    for index, orderedId in ipairs(self.character.order) do
        if orderedId==id then table.remove(self.character.order,index); break end
    end
    invalidate(self)
    self.emit("PresetsChanged", {kind="deleted",presetId=id,characterId=self.characterId})
    return true
end
function Repo:Memberships(uid, scope)
    if not validUid(uid) then return {} end
    local index=self.index
    if index.builtRevision~=index.revision then
        local byUid={}
        for characterId,character in pairs(self.characters)do
            local entries={}
            for _,id in ipairs(character.order)do entries[#entries+1]=character.presets[id] end
            if character.quickPreset then entries[#entries+1]=character.quickPreset end
            for order,preset in ipairs(entries)do
                local id=preset.id
                if preset then
                    local seen={}
                    for _,value in pairs(KW.BuildModel.Equipment(preset))do
                        if value.kind=="item" and validUid(value.uid) and not seen[value.uid] then
                            seen[value.uid]=true
                            local members=byUid[value.uid] or {};byUid[value.uid]=members
                            members[#members+1]={characterId=characterId,characterName=character.name,
                                presetId=id,name=preset.name,order=order}
                        end
                    end
                end
            end
        end
        for _,members in pairs(byUid)do
            table.sort(members,function(a,b)
                if a.characterId==b.characterId then return a.order<b.order end
                return a.characterId<b.characterId
            end)
        end
        index.byUid=byUid;index.builtRevision=index.revision
    end
    local result={}
    for _,member in ipairs(index.byUid[uid] or {})do
        if scope=="all" or member.characterId==self.characterId then result[#result+1]=KW.Copy(member) end
    end
    return result
end
