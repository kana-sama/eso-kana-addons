-- Bounded real native recents, with ability/artificial identity and recipient scope.
local History = {}
History.__index = History
KanaEffects.History = History
local function copy(value)
    if type(value) ~= "table" then return value end
    local result={}; for key,item in pairs(value) do result[key]=copy(item) end; return result
end
local function finite(value) return type(value)=="number" and value==value and math.abs(value)<math.huge end
local function positiveInteger(value) return finite(value) and value>0 and value==math.floor(value) end
local function key(id,tag,artificialId)
    return (artificialId and "artificial:" .. artificialId or tostring(id)) .. ":" .. tag
end
local function validIdentity(record)
    local c=record.catalog
    if type(c)~="table" then return false end
    if record.artificialEffectId~=nil then
        return finite(record.artificialEffectId) and record.artificialEffectId>=0 and record.artificialEffectId%1==0
            and record.abilityId==nil and c.abilityId==nil
            and c.artificialEffectId==record.artificialEffectId
    end
    return positiveInteger(record.abilityId) and c.abilityId==record.abilityId and c.artificialEffectId==nil
end
local function normalize(text)
    text=string.gsub(text,"%^.*$","")
    return string.lower(string.gsub(string.gsub(text,"^%s+",""),"%s+$",""))
end
function History.New(capacity, normalizeName, timestampProvider)
    capacity=capacity or 1000; assert(positiveInteger(capacity),"History capacity must be positive integer")
    assert(normalizeName==nil or type(normalizeName)=="function","History normalizer must be a function")
    assert(timestampProvider==nil or type(timestampProvider)=="function","History timestamp provider must be a function")
    return setmetatable({capacity=math.min(capacity,1000),records={},_currentSessionObservedAt={},size=0,sequence=0,
        normalizeName=normalizeName or normalize,timestampProvider=timestampProvider},History)
end
function History:_Remember(record)
    local id=key(record.abilityId,record.unitTag,record.artificialEffectId); local previous=self.records[id]
    self.sequence=self.sequence+1; record.sequence=self.sequence
    if not previous then self.size=self.size+1 end
    self.records[id]=record
    if self.size > self.capacity then
        local oldest,oldestSequence
        for candidate,row in pairs(self.records) do
            if not oldestSequence or row.sequence < oldestSequence then oldest,oldestSequence=candidate,row.sequence end
        end
        self.records[oldest]=nil; self._currentSessionObservedAt[oldest]=nil; self.size=self.size-1
    end
end
function History:Observe(observation)
    if observation.synthetic ~= false then return end
    local unit,catalog=observation.unit,observation.catalog
    if not unit or type(unit.tag)~="string" or unit.tag=="" or not validIdentity(observation) or
        not finite(observation.observedAt) then return end
    -- Imported frame values have no comparable session origin. Guard only real
    -- observations accepted since Import; durable recency is the sequence below.
    local id=key(observation.abilityId,unit.tag,observation.artificialEffectId); local previous=self._currentSessionObservedAt[id]
    if previous and observation.observedAt<previous then return end
    local lastSeen,lastSeenClock=observation.observedAt,"session-frame-seconds"
    if self.timestampProvider then
        local ok,stamp=pcall(self.timestampProvider)
        if ok and finite(stamp) and stamp>=0 and stamp==math.floor(stamp) then
            lastSeen,lastSeenClock=stamp,"native-timestamp-seconds"
        end
    end
    self._currentSessionObservedAt[id]=observation.observedAt
    self:_Remember({abilityId=observation.abilityId,artificialEffectId=observation.artificialEffectId,unitTag=unit.tag,lastSeen=lastSeen,lastSeenClock=lastSeenClock,
        catalog=copy(catalog),provenance=(catalog.provenance or "unknown") .. ";observed-scope:" .. unit.tag,synthetic=false})
end
function History:Query(query, filter, offset, limit)
    query=self.normalizeName(query or ""); filter=filter or {}; offset=math.max(0,math.floor(offset or 0)); limit=math.max(0,math.floor(limit or 50))
    local exact=tonumber(query); local records={}
    for _,record in pairs(self.records) do
        local catalog=record.catalog
        local matches=(filter.kind==nil or filter.kind==(record.artificialEffectId and "artificial" or "ability")) and
            (not filter.unitTag or filter.unitTag==record.unitTag) and
            (not filter.category or (catalog.categories or {})[filter.category]) and
            (not filter.level or filter.level==catalog.level or (filter.level=="pair" and catalog.familyId~=nil))
        if matches then
            if exact then matches=(record.artificialEffectId or record.abilityId)==exact
            else
                matches=query=="" or string.find(self.normalizeName(catalog.name or ""),query,1,true)~=nil
                if not matches then
                    for _,alias in ipairs(catalog.aliases or {}) do
                        if string.find(self.normalizeName(alias),query,1,true) then matches=true; break end
                    end
                end
            end
        end
        if matches then records[#records+1]=record end
    end
    table.sort(records,function(a,b)
        if a.sequence ~= b.sequence then return a.sequence>b.sequence end
        return key(a.abilityId,a.unitTag,a.artificialEffectId)<key(b.abilityId,b.unitTag,b.artificialEffectId)
    end)
    local result={}
    for i=offset+1,math.min(#records,offset+limit) do
        local record=records[i]
        result[#result+1]={selector={kind=record.artificialEffectId and "artificial" or "ability",id=record.artificialEffectId or record.abilityId},name=record.catalog.name or "",icon=record.catalog.icon or "",
            selectable=true,abilityIds={record.abilityId},unitTags={record.unitTag},lastSeen=record.lastSeen,lastSeenClock=record.lastSeenClock,provenance=record.provenance}
    end
    return result,#records
end
function History:Export()
    local result={}; for _,record in pairs(self.records) do result[#result+1]=copy(record) end
    table.sort(result,function(a,b) return a.sequence<b.sequence end)
    for _,record in ipairs(result) do record.sequence=nil end
    return result
end
function History:Import(data)
    -- Export list order is oldest-to-newest; last valid duplicate wins. Imported
    -- session frame metadata becomes legacy without stamping a new observation.
    self.records={}; self._currentSessionObservedAt={}; self.size=0; self.sequence=0
    if type(data)~="table" then return end
    for _,record in ipairs(data) do
        if type(record)=="table" and record.synthetic==false and validIdentity(record) and finite(record.lastSeen) and
            type(record.unitTag)=="string" and record.unitTag~="" and type(record.catalog)=="table" and
            (record.lastSeenClock==nil or record.lastSeenClock=="legacy-frame-seconds" or
                record.lastSeenClock=="session-frame-seconds" or (record.lastSeenClock=="native-timestamp-seconds" and
                record.lastSeen>=0 and record.lastSeen==math.floor(record.lastSeen))) then
            self:_Remember({abilityId=record.abilityId,artificialEffectId=record.artificialEffectId,unitTag=record.unitTag,lastSeen=record.lastSeen,
                lastSeenClock=record.lastSeenClock=="native-timestamp-seconds" and record.lastSeenClock or "legacy-frame-seconds",catalog=copy(record.catalog),
                provenance=type(record.provenance)=="string" and record.provenance or "imported-real-observation",synthetic=false})
        end
    end
end
