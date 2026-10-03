-- Run from the eso-kana-addons directory: lua KanaWritRecipes/tests/test.lua
local callbacks = {}
EVENT_ADD_ON_LOADED, EVENT_PLAYER_ACTIVATED = 1, 2
EVENT_OPEN_STORE, EVENT_OPEN_BANK, EVENT_OPEN_GUILD_BANK, EVENT_TRADING_HOUSE_RESPONSE_RECEIVED = 3, 4, 5, 6
LINK_STYLE_DEFAULT = 0
EVENT_MANAGER = {
    RegisterForEvent = function(_, _, event, fn) callbacks[event] = fn end,
    UnregisterForEvent = function(_, _, event) callbacks[event] = nil end,
}
function GetCVar() return "ru" end
function GetItemLinkItemId(link) return tonumber(link:match("item:(%d+)")) or 0 end
local function link(id) return "|H1:item:" .. id .. ":0|h|h" end
function GetItemLink(bag, slot) assert(bag == 1 and slot == 0); return link(45935) end
function GetStoreItemLink(index) assert(index == 3); return link(68192) end
function GetBuybackItemLink(index) assert(index == 4); return link(45888) end
function SecurePostHook(object, method, fn)
    local original = object[method]
    object[method] = function(...) original(...); fn(...) end
end
local function list()
    return { dataTypes = { [1] = { setupCallback = function(row, data) row.name:SetText(data.name) end } } }
end
local backpack, bank, guildbank = list(), list(), list()
PLAYER_INVENTORY = { inventories = { {listView = backpack}, {listView = bank}, {listView = guildbank} } }
STORE_WINDOW = {list = list()}
BUY_BACK_WINDOW = {list = list()}
TRADING_HOUSE = {searchResultsList = list(), postedItemsList = list()}
local label = { text = "" }
function label:SetText(text) self.text = text end
function label:GetText() return self.text end
local row = {name = label, GetNamedChild = function(self, name) if name == "Name" then return self.name end end}
local file = io.open("KanaWritRecipes/KanaWritRecipes.lua")
if file then
    file:close()
    dofile("KanaWritRecipes/Recipes.lua")
    dofile("KanaWritRecipes/KanaWritRecipes.lua")
    callbacks[EVENT_ADD_ON_LOADED](EVENT_ADD_ON_LOADED, "KanaWritRecipes")
    callbacks[EVENT_PLAYER_ACTIVATED]()
end
local function setup(view, data) view.dataTypes[1].setupCallback(row, data) end
local function marked() return label.text:find("Дейлик", 1, true) ~= nil end
for _, view in ipairs({backpack, bank, guildbank}) do
    setup(view, {name = "Куриная грудка", bagId = 1, slotIndex = 0})
    assert(marked(), "daily recipe must be marked in inventory and banks, including slot zero")
    setup(view, {name = "Other recipe", itemLink = link(999999)})
    assert(label.text == "Other recipe", "recycled rows must not retain markers")
end
setup(STORE_WINDOW.list, {name = "Fruit and Cheese", slotIndex = 3})
assert(marked(), "NPC merchant recipe must be marked")
setup(BUY_BACK_WINDOW.list, {name = "Fishy Stick", slotIndex = 4})
assert(marked(), "buyback recipe must be marked")
for _, view in ipairs({TRADING_HOUSE.searchResultsList, TRADING_HOUSE.postedItemsList}) do
    setup(view, {name = "Hagraven", itemLink = link(68219)})
    assert(marked(), "guild trader recipe must be marked")
    setup(view, {name = "Prepared food", itemLink = link(54171)})
    assert(not marked(), "prepared food must not be marked as a recipe")
end
callbacks[EVENT_OPEN_STORE]()
setup(STORE_WINDOW.list, {name = "Fruit and Cheese", slotIndex = 3})
local _, count = label.text:gsub("Дейлик", "")
assert(count == 1, "repeated installation must not duplicate marker")
setup(backpack, {name = "No item data"})
assert(label.text == "No item data", "missing item data must be harmless")
print("PASS: inventory, banks, NPC store, buyback, guild trader, row reuse, idempotence, missing data")
