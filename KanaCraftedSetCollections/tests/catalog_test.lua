local addon = {}
KanaCraftedSetCollections = addon
LIBSETS_SETTYPE_CRAFTED = 7
GetItemLinkIcon = function(link) return "icon:" .. link end

local upper = "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ"
local lower = "абвгдеёжзийклмнопрстуфхцчшщъыьэюя"
local russianLower = {}
for i = 1, #upper, 2 do
    russianLower[upper:sub(i, i + 1)] = lower:sub(i, i + 1)
end
zo_strlower = function(value)
    return (value:gsub("[\208\209][\128-\191]", russianLower)):lower()
end

local sets = {
    [101] = { name = "Alpha", zones = { 11 }, item = 1001, traits = 3 },
    [102] = { name = "Beta", zones = { 11, 12, 12 }, item = 1002, traits = 5 },
    [103] = { name = "Кузнец", zones = { 13 }, item = 1003, traits = 0 },
    [104] = { name = "Нет предмета", zones = { 11 }, item = nil, traits = 2 },
    [105] = { name = "Only Beta Zone", zones = { 12 }, item = 1005, traits = 2 },
}
local lib = {
    GetSetTypeSetsData = function(setType)
        assert(setType == LIBSETS_SETTYPE_CRAFTED)
        return sets
    end,
    GetItemSetCollectionToZoneIds = function()
        return {
            { parentCategory = 1, category = 10, zoneIds = { 11 } },
            { parentCategory = 4, category = 20, zoneIds = { 12 } },
            { parentCategory = 5, category = 30, zoneIds = { 13 }, isDungeon = true },
        }
    end,
    GetSetName = function(id) return sets[id].name end,
    GetZoneIds = function(id) return sets[id].zones end,
    GetSetItemId = function(id) return sets[id].item end,
    buildItemLink = function(id) return "item:" .. id end,
    GetTraitsNeeded = function(id) return sets[id].traits end,
}

local chunk = loadfile("KanaCraftedSetCollections/Catalog.lua")
if chunk then chunk() end
assert(type(addon.BuildCatalog) == "function", "BuildCatalog is missing")

local catalog = addon.BuildCatalog(lib)
local function ids(rows)
    local result = {}
    for _, row in ipairs(rows or {}) do result[#result + 1] = row.setId end
    table.sort(result)
    return table.concat(result, ",")
end
assert(ids(catalog.byCategory[10]) == "101,102", "zone 11 must contain Alpha and Beta once")
assert(ids(catalog.byCategory[20]) == "102,105", "zone 12 must contain both matching sets once")
assert(ids(catalog.byCategory[30]) == "", "dungeon category cannot receive a crafted set")
assert(ids(catalog.fallback) == "103", "unmapped set must remain findable")
assert(catalog.byCategory[10][1].itemLink == "item:1001", "example link must come from LibSets")
assert(catalog.byCategory[10][1].traitsNeeded == 3, "trait requirement must come from LibSets")
assert(catalog.byCategory[20][1].zoneByCategory[20] == 12, "map target must match the displayed category")
assert(ids(addon.FilterRows(catalog.byCategory[10], "ALPHA")) == "101", "English search is case-insensitive")
assert(ids(addon.FilterRows(catalog.fallback, "КУЗ")) == "103", "Russian search is case-insensitive")

local function category(id, children)
    return { GetId = function() return id end,
        SubcategoryIterator = function()
            local i = 0
            return function()
                i = i + 1
                if children and children[i] then return i, children[i] end
            end
        end }
end
ITEM_SET_COLLECTIONS_DATA_MANAGER = {
    TopLevelItemSetCollectionCategoryIterator = function()
        local emitted = false
        return function()
            if emitted then return end
            emitted = true
            return 1, category(1, { category(10) })
        end
    end,
}
local liveCatalog = addon.BuildCatalog(lib)
assert(not liveCatalog.byCategory[20], "stale LibSets category must not create an invisible entry")
assert(ids(liveCatalog.fallback) == "103,105", "set without a live native category must fall back")
print("catalog_test: ok")
