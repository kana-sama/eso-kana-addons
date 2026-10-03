-- Shared real-observation store; all public reads and deltas are independent DTOs.
local Store = {}
Store.__index = Store
KanaEffects.Store = Store
local function copy(value)
    if type(value) ~= "table" then return value end
    local result={}; for key,item in pairs(value) do result[key]=copy(item) end; return result
end
local function unitKey(unit) return unit.tag .. ":" .. unit.generation end
local function compatible(current, incoming)
    return current.generation == incoming.generation and
        (current.unitId == nil or incoming.unitId == nil or current.unitId == incoming.unitId)
end
local function delta(revision)
    return {revision=revision,units={},unitIdentityChanged={},abilities={},artificialEffects={},families={},categories={},membershipChanged=false}
end
local function sameIdentity(previous,unit)
    return previous and previous.tag == unit.tag and previous.generation == unit.generation
        and previous.unitId == unit.unitId and previous.name == unit.name
end
local function markIdentity(change,unit)
    change.unitIdentityChanged[unit.tag]=true
    change.units[unitKey(unit)]=true
end
local function mark(change, observation)
    change.units[unitKey(observation.unit)]=true
    if observation.artificialEffectId then change.artificialEffects[observation.artificialEffectId]=true
    else change.abilities[observation.abilityId]=true end
    local catalog=observation.catalog or {}
    if catalog.familyId then change.families[catalog.familyId]=true end
    for id,present in pairs(catalog.categories or {}) do if present then change.categories[id]=true end end
    change.membershipChanged=true
end
function Store.New()
    return setmetatable({units={},revision=0,listeners={},listenerSequence=0},Store)
end
function Store:_Publish(change)
    if next(change.units) == nil then return change end
    self.revision=self.revision+1; change.revision=self.revision
    local listeners={}; for id in pairs(self.listeners) do listeners[#listeners+1]=id end; table.sort(listeners)
    for _,id in ipairs(listeners) do
        local callback=self.listeners[id]
        if callback then callback(copy(change)) end
    end
    return copy(change)
end
function Store:_Unit(unit, replacing)
    local current=self.units[unit.tag]
    if current then
        if unit.generation < current.unit.generation then return nil end
        if unit.generation == current.unit.generation and not compatible(current.unit,unit) then return nil end
        if unit.generation > current.unit.generation and not replacing then return nil end
    end
    return current
end
function Store:_Observation(observation, unit, previous)
    local result=copy(observation)
    result.unit=copy(unit); result.key=unitKey(unit) .. ":" .. result.effectSlot
    result.firstSeen=previous and previous.abilityId == result.abilityId and previous.artificialEffectId == result.artificialEffectId
        and previous.firstSeen or result.observedAt
    return result
end
function Store:Upsert(observation)
    local change=delta(self.revision); local unit=observation.unit
    local current=self:_Unit(unit,false)
    if self.units[unit.tag] and not current then return change end
    if not current then
        current={unit=copy(unit),rows={}}; self.units[unit.tag]=current; markIdentity(change,current.unit)
    else
        local nextUnit=copy(current.unit)
        if nextUnit.unitId == nil then nextUnit.unitId=unit.unitId end
        nextUnit.name=unit.name
        if not sameIdentity(current.unit,nextUnit) then
            current.unit=nextUnit
            for _,row in pairs(current.rows) do row.unit=copy(nextUnit) end
            markIdentity(change,nextUnit)
        end
    end
    local previous=current.rows[observation.effectSlot]
    if previous then mark(change,previous) end
    local row=self:_Observation(observation,current.unit,previous)
    current.rows[row.effectSlot]=row; mark(change,row)
    return self:_Publish(change)
end
function Store:Remove(unit, effectSlot, abilityId)
    local change=delta(self.revision); local current=self.units[unit.tag]
    if not current or not compatible(current.unit,unit) then return change end
    local previous=current.rows[effectSlot]
    if not previous or previous.abilityId ~= abilityId then return change end
    current.rows[effectSlot]=nil; mark(change,previous)
    return self:_Publish(change)
end
function Store:ReplaceUnit(unit, observations)
    local change=delta(self.revision); local previous=self:_Unit(unit,true)
    if self.units[unit.tag] and not previous then return change end
    local nextUnit=copy(unit)
    if previous and compatible(previous.unit,unit) and nextUnit.unitId == nil then nextUnit.unitId=previous.unit.unitId end
    if not sameIdentity(previous and previous.unit,nextUnit) then markIdentity(change,nextUnit) end
    local current={unit=nextUnit,rows={}}
    for _,observation in ipairs(observations) do
        assert(compatible(nextUnit,observation.unit) and nextUnit.tag == observation.unit.tag, "ReplaceUnit observation unit mismatch")
        local old=previous and compatible(previous.unit,nextUnit) and previous.rows[observation.effectSlot] or nil
        local row=self:_Observation(observation,nextUnit,old); current.rows[row.effectSlot]=row; mark(change,row)
    end
    if previous then
        for _,row in pairs(previous.rows) do mark(change,row) end
        if not compatible(previous.unit,nextUnit) then change.units[unitKey(previous.unit)]=true end
    end
    -- Empty unit transitions still invalidate target views and generation consumers.
    if not previous or not compatible(previous.unit,nextUnit) then
        change.units[unitKey(nextUnit)]=true; change.membershipChanged=true
    end
    self.units[unit.tag]=current
    return self:_Publish(change)
end
function Store:ReadUnit(unitTag)
    local result={}; local current=self.units[unitTag]
    if current then for _,row in pairs(current.rows) do result[#result+1]=copy(row) end end
    table.sort(result,function(a,b)
        if type(a.effectSlot)~=type(b.effectSlot) then return type(a.effectSlot)=="number" end
        return a.effectSlot < b.effectSlot
    end)
    return result
end
function Store:Snapshot(unitTag, capturedAt)
    local current=self.units[unitTag]
    return {unit=current and copy(current.unit) or nil,capturedAt=capturedAt,observations=self:ReadUnit(unitTag)}
end
function Store:Subscribe(callback)
    self.listenerSequence=self.listenerSequence+1; local id=self.listenerSequence
    self.listeners[id]=callback
    return function() self.listeners[id]=nil end
end
