local FakeApi = {}
TestSupport.FakeApi = FakeApi
function FakeApi.New(clock)
    local api = { buffs = {}, units = {}, events = {}, updates = {}, capabilities = {},
        constants = {}, controls = {}, calls = {} }
    api.Now = function() return clock:Now() end
    api.NormalizeName = function(text) return string.lower(text or "") end
    api.GetNumBuffs = function(tag) return #(api.buffs[tag] or {}) end
    api.GetUnitBuffInfo = function(tag, index) return unpack(assert(api.buffs[tag][index]), 1, 13) end
    api.DoesUnitExist = function(tag) return api.units[tag] ~= nil end
    api.GetUnitName = function(tag) return api.units[tag] and api.units[tag].name or "" end
    api.eventManager = {}
    function api.eventManager:RegisterForEvent(owner, event, callback)
        api.events[owner] = api.events[owner] or {}; api.events[owner][event] = callback
    end
    function api.eventManager:UnregisterForEvent(owner, event)
        if api.events[owner] then api.events[owner][event] = nil end
    end
    function api.eventManager:AddFilterForEvent() end
    function api.eventManager:RegisterForUpdate(owner, interval, callback)
        api.updates[owner] = { interval = interval, callback = callback }
    end
    function api.eventManager:UnregisterForUpdate(owner) api.updates[owner] = nil end
    function api:Emit(event, ...)
        local callbacks = {}
        for _, registered in pairs(self.events) do
            if registered[event] then callbacks[#callbacks + 1] = registered[event] end
        end
        for _, callback in ipairs(callbacks) do callback(event, ...) end
    end
    return api
end
