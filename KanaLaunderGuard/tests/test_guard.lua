-- Run from eso-kana-addons: lua KanaLaunderGuard/tests/test_guard.lua
ITEMTYPE_TREASURE = 1
EVENT_ADD_ON_LOADED, EVENT_CLOSE_STORE = 1, 2
GAMEPAD_DIALOGS = { BASIC = 1 }
SI_DIALOG_CANCEL = 1
TAG_CATEGORY_TREASURE_TYPE, BAG_BACKPACK = 1, 1
UI_ALERT_CATEGORY_ALERT, SOUNDS = 1, { NEGATIVE_CLICK = 1 }
SI_TOOLTIP_ITEM_TAG_FORMATER = 1
local sales, bulkSales, alerts = 0, 0, 0
local referenceTags = { [63157] = 'Cosmetics', [61382] = 'Linens', [61107] = 'Accessories' }
local tags = {}
function GetItemLinkNumItemTags(link)
    return referenceTags[tonumber(link:match('item:(%d+)'))] and 1 or #tags
end
function GetItemLinkItemTagInfo(link, index)
    return referenceTags[tonumber(link:match('item:(%d+)'))] or tags[index], TAG_CATEGORY_TREASURE_TYPE
end
function zo_strformat(_, value) return value end
function SellInventoryItem() sales = sales + 1 end
function SellAllJunk() bulkSales = bulkSales + 1 end
function GetBagSize() return 1 end
local junk = false
function IsItemJunk() return junk end
function ZO_Alert() alerts = alerts + 1 end
local events, dialogs, calls = {}, {}, {}
local item = { kind = 1, stolen = true, id = 'original', count = 5 }
EVENT_MANAGER = {
    RegisterForEvent = function(_, _, event, fn) events[event] = fn end,
    UnregisterForEvent = function(_, _, event) events[event] = nil end,
}
function GetItemType() return item.kind end
function IsItemStolen() return item.stolen end
function GetItemUniqueId() return item.id end
function Id64ToString(id) return id end
function GetSlotStackSize() return item.count end
function GetItemLink() return '[Treasure]' end
function LaunderItem(bag, slot, count) calls[#calls + 1] = {bag, slot, count} end
function ZO_PreHook(name, hook)
    local original = _G[name]
    _G[name] = function(...) if not hook(...) then return original(...) end end
end
function ZO_PostHook() error("Inventory decoration must be removed") end
function ZO_Dialogs_RegisterCustomDialog(name, info) dialogs[name] = info end
local shown
function ZO_Dialogs_ShowPlatformDialog(name, data) shown = { name = name, data = data } end
function ZO_Dialogs_ReleaseAllDialogsOfName() shown = nil end
function zo_callLater(fn) fn() end
local function choose(index)
    local dialog = assert(shown, 'confirmation missing')
    local info = dialogs[dialog.name]
    shown = nil
    info.buttons[index].callback(dialog)
    if info.finishedCallback then info.finishedCallback(dialog) end
end
dofile('KanaLaunderGuard/KanaLaunderGuard.lua')
events[EVENT_ADD_ON_LOADED](nil, 'KanaLaunderGuard')

LaunderItem(1, 2, 5)
assert(#calls == 0, 'treasure laundered before approval')
choose(2)
assert(#calls == 0, 'cancel laundered treasure')

LaunderItem(1, 2, 3)
choose(1)
assert(#calls == 1 and calls[1][3] == 3, 'approval must launder exact quantity once')
LaunderItem(1, 2, 1)
assert(#calls == 1 and shown, 'approval leaked into another operation')
choose(2)

LaunderItem(1, 2, 5)
local originalDialog = shown
LaunderItem(1, 3, 4)
assert(shown == originalDialog and #calls == 1, 'repeat request replaced or bypassed confirmation')
choose(1)
assert(#calls == 2 and calls[2][2] == 2, 'approved wrong slot')

LaunderItem(1, 2, 5)
item.id = 'replacement'
choose(1)
assert(#calls == 2, 'replacement item was laundered')

LaunderItem(1, 2, 5)
item.count = 2
choose(1)
assert(#calls == 2, 'changed stack was laundered')
item.count = 5

LaunderItem(1, 2, 5)
local stale = shown
events[EVENT_CLOSE_STORE]()
dialogs[stale.name].buttons[1].callback(stale)
assert(#calls == 2, 'closed fence allowed stale confirmation')

LaunderItem(1, 2, 1)
local dismissed = shown
dialogs[dismissed.name].noChoiceCallback(dismissed)
shown = nil
LaunderItem(1, 2, 1)
assert(shown, 'dismissal left guard stuck')
choose(2)

item.kind = 2
LaunderItem(1, 2, 5)
assert(#calls == 3 and not shown, 'non-treasure blocked')
item.kind, item.stolen = 1, false
LaunderItem(1, 2, 5)
assert(#calls == 4 and not shown, 'non-stolen item blocked')
print('PASS: guard blocks before approval, cancel, exact approval, repeat, replacement, stack change, fence close, dismissal, unrelated items')

for _, tag in ipairs({'Cosmetics', 'Linens', 'Accessories', 'Other'}) do
    tags = {tag}
    for _, stolen in ipairs({false, true}) do
        item.stolen = stolen
        local before = sales
        SellInventoryItem(1, 2, 5)
        assert(sales == before + 1, 'treasure sale blocked: ' .. tag)
    end
    local before = #calls
    LaunderItem(1, 2, 5)
    assert(#calls == before and shown, 'treasure bypassed confirmation: ' .. tag)
    choose(2)
    assert(#calls == before, 'cancel laundered treasure: ' .. tag)
    LaunderItem(1, 2, 5)
    choose(1)
    assert(#calls == before + 1, 'confirmed treasure not laundered: ' .. tag)
end
tags = {'Other', 'Cosmetics'}
junk = true
SellAllJunk()
assert(bulkSales == 1, 'bulk junk sale blocked')
assert(alerts == 0, 'sale restriction alert remains')
print('PASS: unrestricted clean/stolen sales and bulk junk; all treasure categories require confirmation')
