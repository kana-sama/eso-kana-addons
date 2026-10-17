local T = dofile('KanaCombatBookmarks/tests/support.lua')
T.load('Names'); T.load('Model'); T.load('Integration')

local function setup()
    local storage, env = T.storage()
    local api = T.api()
    for name, value in pairs(env) do
        if name:match('^LIBCOMBAT_') then api[name] = value end
    end
    api.CombatMetricsFightData = storage
    KanaCombatBookmarks.Integration.Install(api)
    return storage, env, T.formatter(env)
end

local function fight(env)
    return {
        APIversion = 101050, starttime = 100000, combatstart = 100000, combatend = 110000,
        playerid = 48852, bosses = {[1] = 14547},
        units = {
            [48852] = {name = 'Player', unitType = 1},
            [14547] = {name = 'Enemy', unitType = 4},
        },
        calculated = {units = {}, DPSOut = 1, DPSIn = 0, HPSOut = 0, HPSIn = 0},
        log = {{env.LIBCOMBAT_EVENT_DAMAGE_OUT, 100500, env.ACTION_RESULT_DAMAGE, 48852, 14547, 18350, 49, 4, 0}},
        kanaCombatBookmarks = {version = 1, entries = {{id = 1, offsetMs = 750, name = 'Армагеддон'}}},
    }
end

T.test('ordinary CMX save loads a renderable log without losing bookmarks or changing saved data', function()
    local storage, env, lib = setup()
    local original = fight(env)
    storage.Save(original, false) -- Native CMX save button without Shift.
    local restored = storage.Load(1)
    local text = lib:GetCombatLogString(restored, restored.log[1], 16)
    assert(text:find('Enemy', 1, true))
    T.eq(#restored.log, 1); T.eq(restored.log[1][2], 100500)
    T.eq(restored.kanaCombatBookmarks.entries[1].name, 'Армагеддон')
    T.eq(restored.kanaCombatBookmarks.entries[1].offsetMs, 750)
    T.eq(original.log[1][4], 48852); T.eq(original.log[1][5], 14547)
    assert(original.units[14547]); T.eq(original.unitConversion, nil)
    -- Loading again decodes a fresh copy; the saved payload remains unchanged.
    local again = storage.Load(1)
    T.eq(lib:GetCombatLogString(again, again.log[1], 16), text)
end)

T.test('raw logs restore damage, healing, effects and resurrection without remapping abilities or boss indexes', function()
    local storage, env, lib = setup()
    local original = fight(env)
    original.log = {}
    for kind = env.LIBCOMBAT_EVENT_DAMAGE_OUT, env.LIBCOMBAT_EVENT_HEAL_SELF do
        original.log[#original.log + 1] = {kind, 100500, env.ACTION_RESULT_DAMAGE, 48852, 14547, 48852, 49, 4, 0}
    end
    for kind = env.LIBCOMBAT_EVENT_EFFECTS_IN, env.LIBCOMBAT_EVENT_GROUPEFFECTS_OUT do
        original.log[#original.log + 1] = {kind, 100600, 14547, 48852, 1, 1, 1, 1, 0}
    end
    for state = 1, 4 do
        original.log[#original.log + 1] = {env.LIBCOMBAT_EVENT_DEATH, 100700, state, 14547, 48852}
    end
    original.log[#original.log + 1] = {env.LIBCOMBAT_EVENT_BOSSHP, 100800, 1, 500, 1000}
    storage.Save(original, false)
    local restored = storage.Load(1)
    T.eq(#restored.log, #original.log); T.eq(restored.unitConversion, nil)
    for index, line in ipairs(restored.log) do
        local kind = line[1]
        if kind <= env.LIBCOMBAT_EVENT_HEAL_SELF then
            T.eq(restored.units[line[4]].name, 'Player'); T.eq(restored.units[line[5]].name, 'Enemy')
            T.eq(line[6], 48852); T.eq(line[7], 49)
        elseif kind <= env.LIBCOMBAT_EVENT_GROUPEFFECTS_OUT then
            T.eq(restored.units[line[3]].name, 'Enemy'); T.eq(line[4], 48852)
        elseif kind == env.LIBCOMBAT_EVENT_DEATH then
            T.eq(restored.units[line[4]].name, 'Enemy')
            if line[3] > 2 then T.eq(restored.units[line[5]].name, 'Player')
            else T.eq(line[5], 48852) end
        else
            T.eq(line[3], 1); T.eq(restored.units[restored.bosses[1]].name, 'Enemy')
        end
        T.eq(line[2], original.log[index][2])
        assert(lib:GetCombatLogString(restored, line, 16), 'formatter omitted event ' .. kind)
    end
end)

T.test('full, default and filtered CMX saves remain renderable', function()
    for _, mode in ipairs({'full', 'default', 'filtered'}) do
        local storage, env, lib = setup()
        local original = fight(env)
        original.log[2] = {env.LIBCOMBAT_EVENT_MESSAGES, 110000, env.LIBCOMBAT_MESSAGE_COMBATEND}
        if mode == 'full' then storage.Save(original, true)
        elseif mode == 'default' then storage.Save(original)
        else storage.Save(original, {[env.LIBCOMBAT_EVENT_DAMAGE_OUT] = true}) end
        local restored = storage.Load(1)
        assert(lib:GetCombatLogString(restored, restored.log[1], 16):find('Enemy', 1, true))
        T.eq(#restored.log, mode == 'filtered' and 1 or 2)
        T.eq(restored.log[1][2], 100500); T.eq(restored.unitConversion, nil)
        T.eq(restored.kanaCombatBookmarks.entries[1].offsetMs, 750)
    end
end)

T.test('saving a recovered log again preserves unit ownership and bookmark count', function()
    local storage, env, lib = setup()
    storage.Save(fight(env), false)
    local restored = storage.Load(1)
    local expected = lib:GetCombatLogString(restored, restored.log[1], 16)
    storage.Save(restored, false); storage.Save(restored, true)
    for index = 2, 3 do
        local again = storage.Load(index)
        T.eq(lib:GetCombatLogString(again, again.log[1], 16), expected)
        T.eq(#again.kanaCombatBookmarks.entries, 1)
    end
end)

T.test('missing or empty logs retain bookmark metadata', function()
    local storage, env = setup()
    local original = fight(env)
    storage.Save(original, {})
    original.log = nil; storage.Save(original, false)
    original.log = {}; storage.Save(original, false)
    for index = 1, 3 do
        local restored = storage.Load(index)
        T.eq(#(restored.log or {}), 0)
        T.eq(restored.kanaCombatBookmarks.entries[1].name, 'Армагеддон')
    end
end)

T.test('overlapping old and compact IDs are remapped once even if the loader returns the same object', function()
    local _, env = T.storage()
    local restored = fight(env)
    restored.units = {[1] = {name = 'Enemy'}, [2] = {name = 'Player'}}
    restored.playerid = 2; restored.unitConversion = {[1] = 2, [2] = 1}
    restored.log[1][4], restored.log[1][5] = 1, 2
    local api = T.api()
    for name, value in pairs(env) do if name:match('^LIBCOMBAT_') then api[name] = value end end
    api.CombatMetricsFightData.Load = function() return restored end
    KanaCombatBookmarks.Integration.Install(api)
    local loaded = api.CombatMetricsFightData.Load(1)
    T.eq(loaded.log[1][4], 2); T.eq(loaded.log[1][5], 1)
    T.eq(api.CombatMetricsFightData.Load(1), loaded)
    T.eq(loaded.log[1][4], 2); T.eq(loaded.log[1][5], 1)
end)

T.finish()
