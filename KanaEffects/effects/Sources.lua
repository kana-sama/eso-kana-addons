-- One addon-level owner of native filtered events and initial/full scans.
local Sources = {}
Sources.__index = Sources
KanaEffects.Sources = Sources
local sequence=0
local function copy(unit)
    return {tag=unit.tag,generation=unit.generation,unitId=unit.unitId,name=unit.name}
end
local function finite(value) return type(value)=="number" and value==value and math.abs(value)<math.huge end
local function identity(value) return finite(value) and value>0 and value==math.floor(value) and value or nil end
local function boss(tag) return string.match(tag,"^boss%d+$")~=nil end
local function lifetime(beginTime,endTime,toggled)
    -- Native buffdebuffstyles.lua uses equal applied timestamps for no expiry.
    -- Missing/malformed timestamps are not a zero-duration native observation.
    if not finite(beginTime) or not finite(endTime) or beginTime<0 or endTime<beginTime then return "unknown" end
    if endTime>beginTime then return "finite",endTime-beginTime end
    return toggled and "toggle" or "permanent"
end
function Sources.New(api,catalog,store,history,diagnostics)
    sequence=sequence+1
    return setmetatable({api=api,catalog=catalog,store=store,history=history,owner="KanaEffectsSources" .. sequence,
        diagnostics=diagnostics,requested={},states={},generations={},subscriptions={},running=false,epoch=0},Sources)
end
function Sources:_Register(owner,event,callback,tag)
    if event==nil then return end
    local manager=self.api.eventManager; manager:RegisterForEvent(owner,event,callback)
    if tag then manager:AddFilterForEvent(owner,event,self.api.constants.REGISTER_FILTER_UNIT_TAG,tag) end
    self.subscriptions[owner]={event=event,tag=tag}
end
function Sources:_Unregister(owner)
    local subscription=self.subscriptions[owner]
    if subscription then
        self.api.eventManager:UnregisterForEvent(owner,subscription.event); self.subscriptions[owner]=nil
    end
end
function Sources:_NextUnit(tag,name)
    self.generations[tag]=(self.generations[tag] or 0)+1
    return {tag=tag,generation=self.generations[tag],name=name or ""}
end
function Sources:_Observation(unit,id,slot,name,icon,beginTime,endTime,stacks,effectType,castBy,sourceType)
    if not identity(id) or not identity(slot) then return nil end
    local api,constants=self.api,self.api.constants
    local caster=castBy=="self" and "player" or nil
    local toggled=caster and api.IsAbilityDurationToggled and api.IsAbilityDurationToggled(id,caster)==true
    local lifetime,fullDuration=lifetime(beginTime,endTime,toggled)
    -- Applied buff times are authoritative; a skill's nominal duration can
    -- describe a different application and cannot override endTime-beginTime.
    local kind="unknown"
    if effectType==constants.BUFF_EFFECT_TYPE_BUFF and effectType~=nil then kind="buff"
    elseif effectType==constants.BUFF_EFFECT_TYPE_DEBUFF and effectType~=nil then kind="debuff" end
    return {key=unit.tag .. ":" .. unit.generation .. ":" .. slot,unit=copy(unit),abilityId=id,effectSlot=slot,
        kind=kind,startTime=finite(beginTime) and beginTime>=0 and beginTime or nil,
        endTime=lifetime=="finite" and endTime or nil,lifetime=lifetime,fullDuration=fullDuration,
        stacks=stacks or 0,castBy=castBy,sourceType=sourceType,observedAt=api.Now(),synthetic=false,
        catalog=self.catalog:Describe(id,{casterUnitTag=caster,unitTag=unit.tag,name=name,icon=icon})}
end
function Sources:_ArtificialObservations(unit,rows)
    local api=self.api
    if unit.tag~="player" or not api.GetNextActiveArtificialEffectId or not api.GetArtificialEffectInfo then return end
    local seen,id={}
    while true do
        id=api.GetNextActiveArtificialEffectId(id)
        -- Artificial IDs are zero-based: ESO Plus currently uses ID 0.
        if not finite(id) or id<0 or id%1~=0 or seen[id] then break end
        seen[id]=true
        local name,icon,effectType,sortOrder,beginTime,endTime=api.GetArtificialEffectInfo(id)
        if type(name)=="string" and name~="" and type(icon)=="string" and icon~="" then
            local durationKind,fullDuration=lifetime(beginTime,endTime)
            local kind="unknown"
            if effectType~=nil and effectType==api.constants.BUFF_EFFECT_TYPE_BUFF then kind="buff"
            elseif effectType~=nil and effectType==api.constants.BUFF_EFFECT_TYPE_DEBUFF then kind="debuff" end
            rows[#rows+1]={unit=copy(unit),artificialEffectId=id,effectSlot="artificial:" .. id,kind=kind,
                startTime=finite(beginTime) and beginTime>=0 and beginTime or nil,
                endTime=durationKind=="finite" and endTime or nil,lifetime=durationKind,fullDuration=fullDuration,
                stacks=0,castBy="unknown",sourceKind="artificial",observedAt=api.Now(),synthetic=false,
                catalog=self.catalog:DescribeArtificial(id)}
        end
    end
end
function Sources:_Scan(state)
    if self.diagnostics then self.diagnostics:Count("source_scans") end
    local rows={}; local tag=state.unit.tag
    if state.exists then
        for index=1,self.api.GetNumBuffs(tag) do
            local name,beginTime,endTime,slot,stacks,icon,_,effectType,abilityType,statusEffectType,id,canClickOff,castByPlayer=
                self.api.GetUnitBuffInfo(tag,index)
            local castBy=castByPlayer==true and "self" or castByPlayer==false and "other" or "unknown"
            local row=self:_Observation(state.unit,id,slot,name,icon,beginTime,endTime,stacks,effectType,castBy,nil)
            if row then rows[#rows+1]=row end
        end
        self:_ArtificialObservations(state.unit,rows)
    end
    self.store:ReplaceUnit(state.unit,rows)
    for _,row in ipairs(rows) do self.history:Observe(row) end
end
function Sources:_Sync(tag,reset,scan)
    local exists=self.api.DoesUnitExist(tag)==true
    local name=exists and self.api.GetUnitName(tag) or ""
    local state=self.states[tag]
    if not state or reset or state.exists~=exists or state.unit.name~=name then
        self:_Unregister(self.owner .. ":" .. tag)
        state={unit=self:_NextUnit(tag,name),exists=exists}; self.states[tag]=state
        if exists then
            local epoch=self.epoch
            self:_Register(self.owner .. ":" .. tag,self.api.constants.EVENT_EFFECT_CHANGED,function(...)
                if self.running and self.epoch==epoch and self.states[tag]==state and self.requested[tag] then self:_Effect(state,...) end
            end,tag)
        end
        self:_Scan(state)
    elseif scan then self:_Scan(state) end
end
function Sources:_Effect(state,_,change,slot,name,tag,beginTime,endTime,stacks,icon,deprecatedBuffType,effectType,abilityType,statusEffectType,unitName,unitId,id,sourceType)
    if self.diagnostics then self.diagnostics:Count("source_events") end
    if tag~=state.unit.tag then return end
    local api,constants=self.api,self.api.constants
    local availableId=identity(unitId)
    -- No snapshot getter identifies the reticle/boss entity. Any such diff can
    -- be queued from a previous target, including the same name/slot/ability.
    if tag~="player" or not api.DoesUnitExist(tag) or (unitName and unitName~=state.unit.name) or
        (state.unit.unitId and availableId and state.unit.unitId~=availableId) then
        self:_Sync(tag,false,true); return
    end
    if change==constants.EFFECT_RESULT_FADED then
        self.store:Remove(state.unit,slot,id); return
    end
    if change~=constants.EFFECT_RESULT_GAINED and change~=constants.EFFECT_RESULT_UPDATED then
        self:_Sync(tag,false,true); return
    end
    -- Player's stable tag allows an event-provided ID; initial scans never fabricate it.
    if availableId and not state.unit.unitId then state.unit.unitId=availableId end
    local castBy=sourceType~=nil and sourceType==constants.COMBAT_UNIT_TYPE_PLAYER and "self" or "unknown"
    local row=self:_Observation(state.unit,id,slot,name,icon,beginTime,endTime,stacks,effectType,castBy,sourceType)
    if row then self.store:Upsert(row); self.history:Observe(row) end
end
function Sources:_GlobalSubscriptions()
    for _,suffix in ipairs({"full","reticle","bosses","artificialAdded","artificialRemoved"}) do self:_Unregister(self.owner .. ":" .. suffix) end
    if next(self.requested)==nil then return end
    local constants,epoch=self.api.constants,self.epoch
    local function current() return self.running and self.epoch==epoch end
    self:_Register(self.owner .. ":full",constants.EVENT_EFFECTS_FULL_UPDATE,function()
        if current() then for tag in pairs(self.requested) do self:_Sync(tag,false,true) end end
    end)
    if self.requested.player and self.api.GetNextActiveArtificialEffectId and self.api.GetArtificialEffectInfo then
        local function refreshArtificial()
            if current() and self.requested.player then self:_Sync("player",false,true) end
        end
        self:_Register(self.owner .. ":artificialAdded",constants.EVENT_ARTIFICIAL_EFFECT_ADDED,refreshArtificial)
        self:_Register(self.owner .. ":artificialRemoved",constants.EVENT_ARTIFICIAL_EFFECT_REMOVED,refreshArtificial)
    end
    if self.requested.reticleover then
        self:_Register(self.owner .. ":reticle",constants.EVENT_RETICLE_TARGET_CHANGED,function()
            if current() and self.requested.reticleover then self:_Sync("reticleover",true,true) end
        end)
    end
    local wantsBoss=false; for tag in pairs(self.requested) do if boss(tag) then wantsBoss=true end end
    if wantsBoss then
        self:_Register(self.owner .. ":bosses",constants.EVENT_BOSSES_CHANGED,function()
            -- forceReset=false and equal names cannot prove identity continuity.
            if current() then for tag in pairs(self.requested) do if boss(tag) then self:_Sync(tag,true,true) end end end
        end)
    end
end
function Sources:Start(unitTags)
    if self.running then self:Reconfigure(unitTags); return end
    local api=self.api
    assert(api.eventManager and type(api.eventManager.AddFilterForEvent)=="function" and
        api.constants.REGISTER_FILTER_UNIT_TAG~=nil,"Sources requires native unit-tag event filters")
    self.running=true; self.epoch=self.epoch+1; self:Reconfigure(unitTags)
end
function Sources:Reconfigure(unitTags)
    if not self.running then self:Start(unitTags); return end
    local requested={}
    for key,value in pairs(unitTags or {}) do
        local tag=type(key)=="number" and value or value==true and key or nil
        assert(type(tag)=="string" and tag~="","Sources requires unit-tag list or set")
        requested[tag]=true
    end
    for tag in pairs(self.requested) do
        if not requested[tag] then
            self:_Unregister(self.owner .. ":" .. tag); self.states[tag]=nil
            self.store:ReplaceUnit(self:_NextUnit(tag),{})
        end
    end
    self.requested=requested; self:_GlobalSubscriptions()
    for tag in pairs(requested) do self:_Sync(tag,false,false) end
end
-- Zone activation is a boundary for reticle/boss identity, even at equal names.
function Sources:Refresh()
    if not self.running then return end
    for tag in pairs(self.requested) do self:_Sync(tag,tag~="player",true) end
end
function Sources:Stop()
    if not self.running then return end
    self.running=false; self.epoch=self.epoch+1
    local owners={}; for owner in pairs(self.subscriptions) do owners[#owners+1]=owner end
    for _,owner in ipairs(owners) do self:_Unregister(owner) end
    for tag in pairs(self.requested) do self.store:ReplaceUnit(self:_NextUnit(tag),{}) end
    self.states={}; self.requested={}
end
