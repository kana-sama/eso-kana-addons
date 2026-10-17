local T = dofile('KanaCombatBookmarks/tests/support.lua')
T.test('names implementation', function() T.load('Names') end)
if T.failed > 0 then T.finish() end
local Names = KanaCombatBookmarks.Names
T.test('all approved names are drawn once before reuse', function()
    local f = assert(io.open('docs/superpowers/specs/assets/kana-combat-bookmarks-names-ru.json'))
    local text = f:read('*a'); f:close()
    local expected, count = {}, 0
    for group in text:gmatch('"names"%s*:%s*%[(.-)%]') do
        for name in group:gmatch('"(.-)"') do expected[name] = true; count = count + 1 end
    end
    T.eq(count, 48)
    local used, gen = {}, Names.New(function(n) return n end, {})
    for i = 1, 48 do
        local name = gen:Next()
        assert(expected[name] and not used[name], 'missing or duplicate name: ' .. name)
        used[name] = true
    end
    for i = 1, 48 do
        local name = gen:Next()
        assert(expected[name:gsub(' · 2$', '')] and name:match(' · 2$') and not used[name])
        used[name] = true
    end
    assert(gen:Next():match(' · 3$'))
end)
T.test('randomness is injected and existing names survive regeneration', function()
    local calls = 0
    local gen = Names.New(function(n) calls = calls + 1; return 1 end, {})
    local first = gen:Next()
    local second = gen:Next()
    assert(first ~= second and calls > 0)
    local restored = Names.New(function(n) return 1 end, {{name = first}, {name = second}})
    for i = 1, 46 do local name = restored:Next(); assert(name ~= first and name ~= second) end
    assert(restored:Next():match(' · 2$'))
end)
T.finish()
