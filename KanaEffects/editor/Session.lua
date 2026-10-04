-- Transactional configuration only; live Store/time are owned by Runtime.
local Session={}; Session.__index=Session; KanaEffects.Session=Session
local function copy(v) if type(v)~='table' then return v end; local r={}; for k,x in pairs(v) do r[k]=copy(x) end; return r end
local function equal(a,b)
    if type(a)~=type(b) then return false end; if type(a)~='table' then return a==b end
    for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end; return true
end
local function reject(code,path,message) return false,{{code=code,path=path,message=message}} end
local function validate(p)
    local ok,diag=KanaEffects.Schema.Validate(p); if not ok then return false,diag end
    local compiled; compiled,diag=KanaEffects.Rules.Compile(p.sets,p.longThreshold,p.widgets,p.hidden); if not compiled then return false,diag end
    return #diag==0,diag
end
local function serializable(value,active)
    local kind=type(value)
    if kind=='table' then
        if getmetatable(value) or active[value] then return false end; active[value]=true
        for k,v in pairs(value) do if (type(k)~='string' and type(k)~='number') or not serializable(v,active) then return false end end
        active[value]=nil; return true
    end
    return kind=='nil' or kind=='string' or kind=='boolean' or (kind=='number' and value==value and math.abs(value)<math.huge)
end
local function find(list,id) for i,v in ipairs(list) do if v.id==id then return v,i end end end
local function coordinate(n) return type(n)=='number' and n==n and n<math.huge and n>=1 and n%1==0 end
local function slot(w,r,c) return w.slots[r] and w.slots[r][c] end
local function assign(w,r,c,v)
    if v~=nil then w.slots[r]=w.slots[r] or {}; w.slots[r][c]=copy(v)
    elseif w.slots[r] then w.slots[r][c]=nil; if next(w.slots[r])==nil then w.slots[r]=nil end end
end
function Session.New(storage)
    local committed,diag=storage:Load()
    return setmetatable({storage=storage,committed=committed,diagnostics=diag,listeners={},sequence=0},Session)
end
function Session:_Notify()
    local callbacks={}; for id,fn in pairs(self.listeners) do callbacks[id]=fn end
    local generation=self.generation
    for id,fn in pairs(callbacks) do
        if generation~=self.generation then break end
        if self.listeners[id]==fn then fn(self:ReadDraft()) end
    end
end
function Session:Begin()
    if not self.draft then self.draft=KanaEffects.Schema.CopyProfile(self.committed); self.generation=(self.generation or 0)+1; self:_Notify() end
    return self:ReadDraft()
end
function Session:ReadDraft() return self.draft and KanaEffects.Schema.CopyProfile(self.draft) or nil end
function Session:IsDirty() return self.draft~=nil and not equal(self.draft,self.committed) end
function Session:Subscribe(callback)
    assert(type(callback)=='function','Session subscription requires callback'); self.sequence=self.sequence+1; local id=self.sequence; self.listeners[id]=callback
    return function() self.listeners[id]=nil end
end
function Session:Apply(command)
    if not self.draft then return reject('session_closed','session','Begin editing first') end
    if type(command)~='table' or not serializable(command,{}) then return reject('invalid_command','command','Expected serializable closed command') end
    local allowed={
        ['widget.add']='type widget',['widget.delete']='type widgetId',['widget.duplicate']='type widgetId newId',['widget.patch']='type widgetId patch',['widget.rename']='type widgetId name previousName',
        ['slot.assign']='type widgetId row column selector',['slot.clear']='type widgetId row column',['slot.transfer']='type from to copy',
        ['set.put']='type set',['set.delete']='type setId',['hidden.add']='type selector',['hidden.remove']='type selector',['hidden.clear']='type',
        ['profile.threshold']='type seconds',['editor.toolbar']='type x y'}
    local fields=allowed[command.type]; if not fields then return reject('invalid_command','command.type','Unknown editor command') end
    local keys={}; for key in string.gmatch(fields,'%S+') do keys[key]=true end
    for key in pairs(command) do if not keys[key] then return reject('unknown_field','command.'..tostring(key),'Unknown command field') end end
    local p=KanaEffects.Schema.CopyProfile(self.draft); local t=command.type
    local w,index
    if string.sub(t,1,7)=='widget.' and t~='widget.add' or t=='slot.assign' or t=='slot.clear' then
        w,index=find(p.widgets,command.widgetId); if not w then return reject('unknown_widget','widgetId','Widget does not exist') end
    end
    if t=='widget.add' then
        if type(command.widget)~='table' then return reject('invalid_command','widget','Add requires widget') end
        p.widgets[#p.widgets+1]=copy(command.widget)
    elseif t=='widget.delete' then table.remove(p.widgets,index)
    elseif t=='widget.duplicate' then local duplicate=copy(w); duplicate.id=command.newId; p.widgets[#p.widgets+1]=duplicate
    elseif t=='widget.rename' then
        if type(command.name)~='string' then return reject('invalid_command','name','Expected panel name') end
        if command.previousName~=nil and command.previousName~=w.name then return reject('stale_rename','previousName','Panel name changed before confirmation') end
        local previous=w.name; w.name=command.name
        KanaEffects.Rules.RenamePanelReferences(p,previous,w.name)
    elseif t=='widget.patch' then
        if type(command.patch)~='table' then return reject('invalid_command','patch','Expected widget patch') end
        local previousName=w.name
        local permitted={name=true,type=true,unitTag=true,style=true,layout=true,anchor=true,rules=true}
        for key,v in pairs(command.patch) do
            if not permitted[key] then return reject('unknown_field','patch.'..tostring(key),'Immutable or unknown widget field') end
            if type(v)=='table' and type(w[key])=='table' then for field,child in pairs(v) do w[key][field]=copy(child) end
            else w[key]=copy(v) end
        end
        if type(w.name)=='string' and previousName~=w.name then KanaEffects.Rules.RenamePanelReferences(p,previousName,w.name) end
    elseif t=='slot.assign' or t=='slot.clear' then
        if not coordinate(command.row) or not coordinate(command.column) then return reject('invalid_number','slot','Invalid slot address') end
        if t=='slot.assign' and command.selector==nil then return reject('invalid_selector','selector','Assign requires selector') end
        assign(w,command.row,command.column,t=='slot.assign' and command.selector or nil)
    elseif t=='slot.transfer' then
        local function address(a)
            if type(a)~='table' then return end
            for key in pairs(a) do if key~='widgetId' and key~='row' and key~='column' then return end end
            if coordinate(a.row) and coordinate(a.column) then return find(p.widgets,a.widgetId) end
        end
        local a,b=command.from,command.to; local from,to=address(a),address(b)
        if not from or not to or (command.copy~=nil and type(command.copy)~='boolean') then return reject('invalid_command','transfer','Invalid transfer address or copy flag') end
        local source,destination=slot(from,a.row,a.column),slot(to,b.row,b.column)
        if a.widgetId~=b.widgetId or a.row~=b.row or a.column~=b.column then
            assign(to,b.row,b.column,source); if not command.copy then assign(from,a.row,a.column,destination) end
        end
    elseif t=='set.put' then
        if type(command.set)~='table' then return reject('invalid_command','set','Expected set definition') end
        local previous,i=find(p.sets,command.set.id)
        p.sets[i or #p.sets+1]=copy(command.set)
        if previous and previous.name~=command.set.name and type(command.set.name)=='string' then
            KanaEffects.Rules.RenameReferences(p,previous.name,command.set.name,previous.id)
        end
    elseif t=='set.delete' then
        local set,i=find(p.sets,command.setId); if not set then return reject('unknown_set','setId','Set does not exist') end
        local refs=KanaEffects.Rules.ReferenceOwners(p,set.id)
        if #refs>0 then return reject('set_in_use','setId','Referenced by '..table.concat(refs,', ')) end
        table.remove(p.sets,i)
    elseif t=='hidden.add' or t=='hidden.remove' then
        -- Validate the selector through the Profile schema before key matching.
        local candidate=KanaEffects.Schema.CopyProfile(p); candidate.hidden={copy(command.selector)}
        if command.selector==nil then return reject('invalid_selector','selector','Expected selector') end
        local valid,diag=KanaEffects.Schema.Validate(candidate); if not valid then return false,diag end
        local key=KanaEffects.Selectors.Key(command.selector); local found
        for i=#p.hidden,1,-1 do if KanaEffects.Selectors.Key(p.hidden[i])==key then found=true; if t=='hidden.remove' then table.remove(p.hidden,i) end end end
        if t=='hidden.add' and not found then p.hidden[#p.hidden+1]=copy(command.selector) end
    elseif t=='hidden.clear' then p.hidden={}
    elseif t=='profile.threshold' then p.longThreshold=command.seconds
    elseif t=='editor.toolbar' then p.editor={toolbarX=command.x,toolbarY=command.y} end
    local ok,diag=validate(p); if not ok then return false,diag end
    if not equal(p,self.draft) then self.draft=KanaEffects.Schema.CopyProfile(p); self.generation=(self.generation or 0)+1; self:_Notify() end
    return true,{}
end
function Session:Save()
    if not self.draft then return reject('session_closed','session','No active draft') end
    local ok,diag=validate(self.draft); if not ok then return false,diag end
    local candidate=KanaEffects.Schema.CopyProfile(self.draft); ok,diag=self.storage:Write(candidate); if not ok then return false,diag end
    self.committed=candidate; self.draft=nil; self.generation=(self.generation or 0)+1; self:_Notify(); return true,diag
end
function Session:Cancel()
    if not self.draft then return end
    self.draft=nil; self.generation=(self.generation or 0)+1; self:_Notify()
end
