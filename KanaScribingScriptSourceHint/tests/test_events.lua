dofile('KanaScribingScriptSourceHint/Sources.lua')
dofile('KanaScribingScriptSourceHint/Tracking.lua')
local f = loadfile('KanaScribingScriptSourceHint/Events.lua')
if f then f() end
local A = KanaScribingScriptSourceHint
local passed = 0
local function test(name, fn)
    local ok, err = pcall(fn)
    if not ok then error(name .. ': ' .. tostring(err), 0) end
    passed = passed + 1
end
local function fixture()
    local events = {}
    local state = {target = '', targetType = 1, loot = {}, now = 100, mails = {}, boxType = 10}
    local api = {ITEMTYPE_CONTAINER = 10, ITEMTYPE_CONTAINER_STACKABLE = 11, ITEMTYPE_CRAFTED_ABILITY_SCRIPT = 20,
        INTERACT_TARGET_TYPE_ITEM = 1, SI_TOOLTIP_ITEM_NAME = 1, LINK_STYLE_DEFAULT = 0}
    for _, name in ipairs({'EVENT_LOOT_UPDATED', 'EVENT_LOOT_RECEIVED', 'EVENT_LOOT_CLOSED',
        'EVENT_PLAYER_ACTIVATED', 'EVENT_PLAYER_DEACTIVATED', 'EVENT_MAIL_READABLE',
        'EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS', 'EVENT_MAIL_REMOVED'}) do api[name] = name end
    api.EVENT_MANAGER = {RegisterForEvent = function(_, _, event, callback) events[event] = callback end}
    function api.GetItemLinkItemId(link) return tonumber(link:match('item:(%d+)')) or 0 end
    function api.GetItemLinkItemType(link)
        local id = api.GetItemLinkItemId(link)
        if id == 204550 or id == 204574 or id == 204604 then return 20 end
        return state.boxType
    end
    function api.GetItemLinkName(link)
        local id = api.GetItemLinkItemId(link)
        return ({[96386] = 'Guild box', [207980] = 'Zone box'})[id] or ''
    end
    function api.GetItemLinkItemUseReferenceId(link)
        return ({[204550] = 2, [204574] = 26, [204604] = 56})[api.GetItemLinkItemId(link)]
    end
    function api.GetCraftedAbilityScriptScribingSlot(id) return id < 24 and 1 or id < 44 and 2 or 3 end
    function api.zo_strformat(_, value) return value end
    function api.GetString(name, index)
        assert(name == 'SI_LFGITEMREWARDTYPE')
        return index == 1 and 'Undaunted Exploration Supplies' or 'Premium Undaunted Exploration Supplies'
    end
    function api.GetTimeStamp() return state.now end
    function api.GetLootTargetInfo() return state.target, state.targetType, 'Search', false end
    function api.GetNumLootItems() return #state.loot end
    function api.GetLootItemInfo(i) return i, 'Page', 'icon', 1, 1, 0, false, false, 1, false, false end
    function api.GetLootItemLink(i) return A.Sources.ItemLink(state.loot[i]) end
    function api.GetMailItemInfo(id)
        local m = state.mails[id]
        return '', '', m.subject, '', false, m.system, false, false, #m.items, 0, 0, 30, 0, 1
    end
    function api.GetAttachedItemLink(id, index) return A.Sources.ItemLink(state.mails[id].items[index]) end
    local tracker = A.Tracking.New({}, {world = 'EU', account = '@one', character = 'alice',
        now = api.GetTimeStamp, reset = function() return 200 end})
    assert(A.Events, 'event observation is not implemented')
    A.Events.Install(api, tracker, function() return true end)
    function state.fire(name, ...) if events[name] then events[name](name, ...) end end
    function state.receive(item, self)
        state.fire('EVENT_LOOT_RECEIVED', 'Alice', A.Sources.ItemLink(item), 1, 0, 1, self ~= false, false, '', item, false)
    end
    function state.done(source) return tracker:Received(source, 'EU', '@one', 'alice') end
    return state, api, tracker
end
test('seeing a script in a coffer is not receipt', function()
    local s = fixture()
    s.target = 'Guild box'; s.loot = {204550}
    s.fire('EVENT_LOOT_UPDATED')
    assert(not s.done('mages'))
    s.receive(204550)
    assert(s.done('mages'))
end)
test('last item auto loot retains only observed source and item', function()
    local s = fixture()
    s.target = 'Guild box'; s.loot = {204550}
    s.fire('EVENT_LOOT_UPDATED')
    s.target = ''; s.loot = {}
    s.receive(204550)
    assert(s.done('mages'))
end)
test('stackable reward coffers also identify daily receipt', function()
    local s = fixture()
    s.boxType = 11; s.fire('EVENT_PLAYER_ACTIVATED')
    s.target = 'Guild box'; s.receive(204550)
    assert(s.done('mages'))
end)
test('expired final item context cannot attribute a later drop', function()
    local s = fixture()
    s.target = 'Guild box'; s.loot = {204550}; s.fire('EVENT_LOOT_UPDATED')
    s.target = ''; s.now = 161; s.receive(204550)
    assert(not s.done('mages'))
end)
test('unknown source and other players cannot inherit a prior source', function()
    local s = fixture()
    s.target = 'Guild box'; s.loot = {204550}; s.fire('EVENT_LOOT_UPDATED')
    s.receive(204550, false)
    assert(not s.done('mages'))
    s.target = 'Treasure chest'; s.fire('EVENT_LOOT_UPDATED'); s.receive(204550)
    assert(not s.done('mages'))
end)
test('world object with coffer name is not a reward container', function()
    local s = fixture()
    s.target = 'Guild box'; s.targetType = 2; s.receive(204550)
    assert(not s.done('mages'))
end)
test('closed loot never supplies context to later world drops', function()
    local s = fixture()
    s.target = 'Guild box'; s.loot = {204550}; s.fire('EVENT_LOOT_UPDATED')
    s.fire('EVENT_LOOT_CLOSED'); s.target = ''; s.receive(204550)
    assert(not s.done('mages'))
end)
test('empty target cannot match an unobserved script', function()
    local s = fixture()
    s.target = 'Zone box'; s.loot = {204550}; s.fire('EVENT_LOOT_UPDATED')
    s.target = ''; s.receive(204574)
    assert(not s.done('boss'))
end)
test('mail opening does not count; successful attachment receipt does', function()
    local s = fixture()
    s.mails[1] = {subject = 'Premium Undaunted Exploration Supplies', system = true, items = {204604}}
    s.fire('EVENT_MAIL_READABLE', 1)
    assert(not s.done('dungeon'))
    s.fire('EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS', 1)
    assert(s.done('dungeon'))
end)
test('player mail cannot imitate a dungeon reward', function()
    local s = fixture()
    s.mails[1] = {subject = 'Premium Undaunted Exploration Supplies', system = false, items = {204604}}
    s.fire('EVENT_MAIL_READABLE', 1); s.fire('EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS', 1)
    assert(not s.done('dungeon'))
end)
test('system mail without a script cannot count', function()
    local s = fixture()
    s.mails[1] = {subject = 'Premium Undaunted Exploration Supplies', system = true, items = {123}}
    s.fire('EVENT_MAIL_READABLE', 1); s.fire('EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS', 1)
    assert(not s.done('dungeon'))
end)
print(string.format('%d tests passed', passed))
