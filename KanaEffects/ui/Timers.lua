-- Pure formatter and shared scheduler. Native update ownership belongs to Controls.
local Timers = {}
KanaEffects.Timers = Timers
local EPSILON = 0.0000001
-- Select one visible countdown. Permanent and unknown durations are active
-- levels without a finite deadline; they never create an invented timer.
function Timers.Select(entry)
    if not entry.pair then
        return entry.single and entry.single.kind=='finite' and entry.single or nil, entry.level
    end
    local minor,major=entry.minor,entry.major
    local minorActive=minor and minor.kind~='missing'
    local majorActive=major and major.kind~='missing'
    local first=minor and minor.kind=='finite' and minor or nil
    local second=major and major.kind=='finite' and major or nil
    local state=first
    if second and (not state or second.endTime<state.endTime) then state=second end
    return state, minorActive and majorActive and 'timer' or minorActive and 'minor' or majorActive and 'major' or nil
end
function Timers.Format(state, now)
    if not state then return nil, nil end
    if state.kind == 'missing' then return '—', nil end
    if state.kind == 'permanent' then return '', nil end
    if state.kind ~= 'finite' then return '', nil end
    local remaining = math.max(0, state.endTime - now)
    if remaining == 0 then return '0.0', nil end
    local text, boundary, afterBoundary
    if remaining > 999 * 3600 then
        text, boundary = '999h+', 999 * 3600
    elseif remaining >= 3600 then
        local value = math.ceil(remaining / 3600)
        text, boundary = tostring(value) .. 'h', math.max(3600, (value - 1) * 3600)
        if remaining == 3600 then boundary = 3600; afterBoundary=true end
    elseif remaining >= 60 then
        local value = math.ceil(remaining / 60)
        text, boundary = tostring(value) .. 'm', math.max(60, (value - 1) * 60)
        afterBoundary = remaining == 60
    elseif remaining >= 3 then
        local value = math.floor(remaining)
        text, boundary, afterBoundary = tostring(value), value, true
    else
        local value = math.floor(remaining * 10)
        text, boundary, afterBoundary = string.format('%d.%d', math.floor(value / 10), value % 10), value / 10, true
    end
    -- At a floor bucket's exact boundary the old string still applies. Schedule
    -- just past it; the native driver remains limited to one update per 100ms.
    local nextAt = state.endTime - boundary + (afterBoundary and EPSILON or 0)
    if nextAt <= now then nextAt = now + EPSILON end
    return text, math.min(state.endTime, nextAt)
end
function Timers.New(clock)
    return setmetatable({clock=clock, watches={}, observers={}, count=0, visible=true, active=false}, {__index=Timers})
end
function Timers:_Activity()
    local active = not self.disposed and self.visible and self.count > 0
    if self.active == active then return end
    self.active = active
    self.activityGeneration = (self.activityGeneration or 0) + 1
    local generation = self.activityGeneration
    local observers = {}; for callback in pairs(self.observers) do observers[#observers+1] = callback end
    for _,callback in ipairs(observers) do
        -- A nested visibility/watch/dispose transition owns the newer broadcast.
        -- Comparing the boolean alone misses transitions away and back to the
        -- same value while this older notification is still on the call stack.
        if self.activityGeneration ~= generation then break end
        if self.observers[callback] then callback(active) end
    end
end
function Timers:SubscribeActivity(callback)
    if self.disposed then return function() end end
    self.observers[callback] = true; callback(self.active)
    local subscribed = true
    return function() if subscribed then subscribed=false; self.observers[callback]=nil end end
end
function Timers:Watch(key, state, onText, onExpire)
    if self.disposed then return end
    if self.watches[key] then self.watches[key]=nil; self.count=self.count-1 end
    if not state then self:_Activity(); return end
    local now = self.clock:Now()
    local text, nextAt = Timers.Format(state, now)
    if state.kind == 'finite' then
        local job = {endTime=state.endTime, text=text, nextAt=nextAt or now, onText=onText, onExpire=onExpire}
        self.watches[key] = job; self.count = self.count + 1
    end
    onText(text)
    self:_Activity()
end
function Timers:Unwatch(key)
    if self.watches[key] then self.watches[key]=nil; self.count=self.count-1; self:_Activity() end
end
function Timers:Advance(now)
    if self.disposed or not self.visible or self.count == 0 then return end
    -- Snapshot references make callback-driven release/replacement deterministic:
    -- callbacks of removed jobs cannot fire from the old iteration.
    local due = {}
    for key,job in pairs(self.watches) do
        if now >= job.nextAt then due[#due+1] = {key=key,job=job} end
    end
    for _,item in ipairs(due) do
        local key,job = item.key,item.job
        if not self.disposed and self.visible and self.watches[key] == job then
            local text,nextAt = Timers.Format({kind='finite',endTime=job.endTime},now)
            job.nextAt = nextAt or now
            if text ~= job.text then job.text=text; job.onText(text) end
            if self.watches[key] == job and now >= job.endTime then
                self.watches[key]=nil; self.count=self.count-1
                if job.onExpire then job.onExpire() end
            end
        end
    end
    self:_Activity()
end
function Timers:SetVisible(visible)
    if self.disposed then return end
    self.visible = visible == true
    if self.visible then self:Advance(self.clock:Now()) end
    self:_Activity()
end
function Timers:Dispose()
    if self.disposed then return end
    self.disposed=true; self.watches={}; self.count=0; self:_Activity(); self.observers={}
end
