local root = 'KanaScribingScriptSourceHint/'
KanaScribingScriptSourceHint = {}
local function load(name)
    local f = loadfile(root .. name .. '.lua')
    if f then f() end
end
load('Sources')
load('Tracking')
local A = KanaScribingScriptSourceHint
local passed = 0
local function test(name, fn)
    local ok, err = pcall(fn)
    if not ok then error(name .. ': ' .. tostring(err), 0) end
    passed = passed + 1
end
test('ordinary focus lists all three distinct activities', function()
    assert(A.Sources, 'source classification is not implemented')
    assert(table.concat(A.Sources.ForScript(2, 1), ',') == 'delve,mages,worthy')
end)
test('ordinary signature and affix use their own activities', function()
    assert(table.concat(A.Sources.ForScript(26, 2), ',') == 'boss,fighters,cyrodiil')
    assert(table.concat(A.Sources.ForScript(56, 3), ',') == 'event,undaunted,imperial,dungeon')
end)
test('each daily pool exposes exactly three distinct icons with task and pickup location', function()
    for _, entry in ipairs({{2, 1}, {26, 2}, {56, 3}}) do
        local sources = A.Sources.DailyForScript(entry[1], entry[2])
        assert(#sources == 3)
        local textures = {}
        for _, source in ipairs(sources) do
            local info = A.Sources.details[source]
            assert(info and info.description ~= '' and info.location ~= '')
            assert(info.icon and not textures[info.icon], 'icons must distinguish daily types')
            textures[info.icon] = true
        end
    end
    assert(#A.Sources.DailyForScript(31, 2) == 0)
end)
test('quest and guild pickups never advertise daily drops', function()
    for _, id in ipairs({5,24,64,18,32,44,48,1,16,20,25,34,41,50,59,60,31}) do
        assert(#A.Sources.ForScript(id, id < 24 and 1 or id < 44 and 2 or 3) == 0)
    end
end)
test('unknown scripts use native hint without invented daily sources', function()
    assert(#A.Sources.ForScript(999, 1) == 0)
    assert(#A.Sources.ForScript(nil, 0) == 0)
end)
local function tracker(saved)
    return A.Tracking.New(saved or {}, {now = function() return 100 end,
        reset = function() return 200 end, world = 'EU', account = '@one', character = 'alice'})
end
test('receipt is separate for character account server and source', function()
    local saved = {}
    local t = tracker(saved)
    assert(not t:Received('mages', 'EU', '@one', 'alice'))
    t:Record('mages')
    assert(t:Received('mages', 'EU', '@one', 'alice'))
    assert(not t:Received('mages', 'EU', '@one', 'bob'))
    assert(t:Received('mages', 'EU', '@one'))
    assert(not t:Received('fighters', 'EU', '@one'))
    assert(not t:Received('mages', 'NA', '@one'))
    assert(not t:Received('mages', 'EU', '@two'))
    assert(tracker(saved):Received('mages', 'EU', '@one', 'alice'))
end)
test('receipts expire exactly at reset', function()
    local t = tracker()
    t:Record('mages')
    t.context.now = function() return 199 end
    assert(t:Received('mages', 'EU', '@one', 'alice'))
    t.context.now = function() return 200 end
    assert(not t:Received('mages', 'EU', '@one', 'alice'))
    assert(not t:Received('mages', 'EU', '@one'))
end)
test('correction retains another characters account receipt', function()
    local t = tracker()
    t:Record('mages')
    t.context.character = 'bob'
    t:Record('mages')
    t:SetReceived('mages', 'EU', '@one', 'alice', false)
    assert(t:Received('mages', 'EU', '@one'))
    t:SetReceived('mages', 'EU', '@one', 'bob', false)
    assert(not t:Received('mages', 'EU', '@one'))
end)
test('only confirmed source and positive personal script loot counts', function()
    local t = tracker()
    assert(not t:Loot('guild_mages', 2, 1, false, 1))
    assert(not t:Loot('guild_mages', 2, 1, true, 0))
    assert(not t:Loot(nil, 2, 1, true, 1))
    assert(not t:Loot('guild_mages', 56, 3, true, 1))
    assert(not t:Loot('guild_mages', 5, 1, true, 1))
    assert(t:Loot('guild_mages', 2, 1, true, 1))
    assert(t:Received('mages', 'EU', '@one', 'alice'))
end)
test('shared zone coffer is disambiguated by actual script type', function()
    local t = tracker()
    t:Loot('zone', 2, 1, true, 1)
    assert(t:Received('delve', 'EU', '@one', 'alice'))
    assert(not t:Received('boss', 'EU', '@one'))
    t:Loot('zone', 26, 2, true, 1)
    assert(t:Received('boss', 'EU', '@one', 'alice'))
    t:Loot('zone', 56, 3, true, 1)
    assert(t:Received('event', 'EU', '@one', 'alice'))
end)
test('daily reset fallback respects EU and NA boundaries', function()
    assert(A.Tracking.NextReset(10799, 'EU Megaserver', 0) == 10800)
    assert(A.Tracking.NextReset(10800, 'EU Megaserver', 0) == 97200)
    assert(A.Tracking.NextReset(35999, 'NA Megaserver', 0) == 36000)
    assert(A.Tracking.NextReset(36000, 'NA Megaserver', 0) == 122400)
    assert(A.Tracking.NextReset(100, 'EU Megaserver', 150) == 150)
    assert(A.Tracking.NextReset(100, 'EU Megaserver', 90000) == 10800)
end)
print(string.format('%d tests passed', passed))
