local T = {passed = 0, failed = 0}
function T.test(name, fn)
    local ok, err = pcall(fn)
    if ok then T.passed = T.passed + 1
    else T.failed = T.failed + 1; io.stderr:write(name .. ': ' .. tostring(err) .. '\n') end
end
function T.eq(a, b) assert(a == b, tostring(a) .. ' ~= ' .. tostring(b)) end
function T.finish()
    print(string.format('%d passed, %d failed', T.passed, T.failed))
    if T.failed > 0 then os.exit(1) end
end
function T.load(name)
    local chunk = loadfile('KanaCombatBookmarks/' .. name .. '.lua')
    assert(chunk, name .. ' implementation missing')
    chunk()
end
function T.api()
    local a = {now = 100000, alerts = {}, sounds = {}, callbacks = {}, saves = {}}
    a.LIBCOMBAT_EVENT_MESSAGES = 16
    a.LIBCOMBAT_EVENT_FIGHTSUMMARY = 2
    a.LIBCOMBAT_MESSAGE_COMBATSTART = 1
    a.LIBCOMBAT_MESSAGE_COMBATEND = 2
    a.UI_ALERT_CATEGORY_ALERT = 1
    a.SOUNDS = {LOCKPICKING_CHAMBER_LOCKED = 'Lockpicking_chamber_locked'}
    a.GetGameTimeMilliseconds = function() return a.now end
    a.IsPlayerInAvAWorld = function() return a.ava or false end
    a.IsActiveWorldBattleground = function() return false end
    a.ZO_AlertNoSuppression = function(category, sound, text)
        assert(sound == nil, 'alert must not double-play sound')
        a.alerts[#a.alerts + 1] = text
    end
    a.PlaySound = function(sound) a.sounds[#a.sounds + 1] = sound end
    a.CMX = {db = {}, currentdata = {log = {}}, lastfights = {}}
    a.LibCombat = {data = {inCombat = false}}
    function a.LibCombat:RegisterForCombatEvent(name, kind, callback)
        assert(not a.callbacks[kind], 'duplicate registration')
        a.callbacks[kind] = callback
    end
    a.CombatMetricsFightData = {Save = function(fight) a.saves[#a.saves + 1] = fight.kanaCombatBookmarks end}
    function a:start(time)
        self.now = time or self.now
        self.LibCombat.data.inCombat = true
        table.insert(self.CMX.currentdata.log, {16, self.now, 1})
        self.callbacks[16](16, self.now, 1)
    end
    function a:stop(time)
        self.now = time
        self.LibCombat.data.inCombat = false
        table.insert(self.CMX.currentdata.log, {16, self.now, 2})
        self.callbacks[16](16, self.now, 2)
    end
    function a:finish(start, ending, beforeCallback)
        local fight = {combatstart = start, combatend = ending, log = self.CMX.currentdata.log}
        self.CMX.lastfights[#self.CMX.lastfights + 1] = fight
        self.CMX.currentdata = {log = {}}
        if beforeCallback then self.CombatMetricsFightData.Save(fight) end
        self.callbacks[2](2, fight)
        return fight
    end
    return a
end
function T.storage()
    local root = os.getenv('ESO_ADDONS_ROOT') or '..'
    local function read(path)
        local f = assert(io.open(root .. '/' .. path, 'rb'), 'Set ESO_ADDONS_ROOT to installed CMX/LibDataEncode')
        local text = f:read('*a'); f:close(); return text
    end
    local env = setmetatable({}, {__index = _G})
    env._G = env
    env.unpack = table.unpack or unpack
    env.GetDisplayName = function() return '@test' end
    env.GetEventManager = function() return {RegisterForEvent = function() end} end
    env.GetAPIVersion = function() return 101050 end
    env.ZO_InitializingObject = {}
    function env.ZO_InitializingObject:Subclass()
        local c = {}; c.__index = c; return setmetatable(c, {__index = self})
    end
    function env.ZO_InitializingObject:New(...)
        local object = setmetatable({}, self); object:Initialize(...); return object
    end
    env.ZO_ShallowTableCopy = function(t) local r = {}; for k,v in pairs(t) do r[k] = v end; return r end
    env.ZO_DeepTableCopy = function(t, r)
        r = r or {}; for k,v in pairs(t) do r[k] = type(v) == 'table' and env.ZO_DeepTableCopy(v) or v end; return r
    end
    env.NonContiguousCount = function(t) local n = 0; for _ in pairs(t) do n = n + 1 end; return n end
    env.zo_floor = math.floor
    env.zo_round = function(v) return math.floor(v + 0.5) end
    env.CMX = {Log = function() end}
    env.EVENT_ADD_ON_LOADED = 1
    for name,value in read('LibCombat/LibCombat.lua'):gmatch('(LIBCOMBAT_[A-Z0-9_]+)%s*=%s*(%-?%d+)') do
        env[name] = tonumber(value)
    end
    local storage = read('CombatMetrics/CombatMetricsFightData/CombatMetricsFightData.lua')
    local nextId = 100
    for name in storage:gmatch('[A-Z][A-Z0-9_]+') do
        if (name:match('^ACTION_RESULT_') or name:match('^COMBAT_MECHANIC_FLAGS_')) and env[name] == nil then
            nextId = nextId + 1; env[name] = nextId
        end
    end
    local function run(source, name)
        local chunk
        if setfenv then chunk = assert(loadstring(source, name)); setfenv(chunk, env)
        else chunk = assert(load(source, name, 't', env)) end
        chunk()
    end
    -- Lua 5.1 accepts \] as ]; newer Lua interpreters reject that string escape.
    local encoder = read('LibDataEncode/LibDataEncode.lua'):gsub(string.char(92) .. ']', ']')
    run(encoder, '@installed-LibDataEncode')
    run(storage, '@installed-CombatMetricsFightData')
    env.InitializeCMXFightData()
    return env.CombatMetricsFightData, env
end

function T.formatter(env)
    local root = os.getenv('ESO_ADDONS_ROOT') or '..'
    local file = assert(io.open(root .. '/LibCombat/LibCombat.lua', 'rb'))
    local source = file:read('*a'):gsub('\r\n', '\n'); file:close()
    local formatter = assert(source:match('(function lib:GetCombatLogString%(.-)\nlocal function Initialize%('))
    env.lib = {}
    env.stringformat = string.format
    env.GetString = function(id) return tostring(id or '') end
    env.ZO_CachedStrFormat = function(_, ...)
        local parts = {}
        for i = 1, select('#', ...) do parts[i] = tostring(select(i, ...)) end
        return table.concat(parts, ' ')
    end
    env.GetAbilityString = function(id) return 'ability ' .. tostring(id) end
    env.UnitTypeString = {}
    local chunk
    if setfenv then chunk = assert(loadstring(formatter, '@installed-LibCombat-formatter')); setfenv(chunk, env)
    else chunk = assert(load(formatter, '@installed-LibCombat-formatter', 't', env)) end
    chunk()
    return env.lib
end
return T
