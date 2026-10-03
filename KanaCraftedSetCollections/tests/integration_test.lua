KanaCraftedSetCollections = {}
local addon = KanaCraftedSetCollections
zo_strlower = function(value)
    local uppercase = { "А", "Б", "В", "Г", "Д", "Е", "Ё", "Ж", "З", "И", "Й", "К", "Л", "М", "Н", "О", "П", "Р", "С", "Т", "У", "Ф", "Х", "Ц", "Ч", "Ш", "Щ", "Ъ", "Ы", "Ь", "Э", "Ю", "Я" }
    local lowercase = { "а", "б", "в", "г", "д", "е", "ё", "ж", "з", "и", "й", "к", "л", "м", "н", "о", "п", "р", "с", "т", "у", "ф", "х", "ц", "ч", "ш", "щ", "ъ", "ы", "ь", "э", "ю", "я" }
    value = value:lower()
    for i, letter in ipairs(uppercase) do value = value:gsub(letter, lowercase[i]) end
    return value
end
dofile("KanaCraftedSetCollections/Catalog.lua")
dofile("KanaCraftedSetCollections/Tile.lua")
dofile("KanaCraftedSetCollections/Integration.lua")
assert(type(addon.InstallBookHooks) == "function", "InstallBookHooks is missing")

local function control()
    return { SetHidden = function(self, value) self.hidden = value end,
             SetText = function(self, value) self.text = value end,
             SetValue = function(self, value) self.value = value end }
end
local function wrap(source)
    return setmetatable({ source = source, GetDataSource = function(self) return self.source end,
        SetDataSource = function(self, value) self.source = value end },
        { __index = function(self, key)
            local value = self.source[key]
            if type(value) == "function" then return function(_, ...) return value(self.source, ...) end end
            return value
        end })
end
ZO_EntryData = { New = function(_, source) return wrap(source) end }

local function iterator(list, filters)
    local i = 0
    return function()
        repeat
            i = i + 1
            local item = list[i]
            if not item then return end
            local passes = true
            for _, filter in ipairs(filters or {}) do
                if not filter(item) then passes = false; break end
            end
            if passes then return i, item end
        until false
    end
end
local function category(id, children)
    local data = { id = id, children = children or {} }
    function data:GetId() return self.id end
    function data:GetNumSubcategories() return #self.children end
    function data:SubcategoryIterator(filters) return iterator(self.children, filters) end
    function data:AnyChildPassesFilters() return false end
    function data:CollectionIterator() return function() end end
    function data:IsInstanceOf() return false end
    function data:HasAnyNewPieces() return false end
    function data:GetFormattedName() return tostring(self.id) end
    return data
end
local leaf = category(11)
local parent = category(1, { leaf })
local other = category(2)
local allCategories = { parent, other }
ITEM_SET_COLLECTIONS_SUMMARY_CATEGORY_DATA = category(0)
ITEM_SET_COLLECTIONS_DATA_MANAGER = {
    TopLevelItemSetCollectionCategoryIterator = function(_, filters) return iterator(allCategories, filters) end,
}

local grid = { entries = {}, commits = 0 }
function grid:ClearGridList() self.entries = {} end
function grid:AddEntry(entry) self.entries[#self.entries + 1] = entry end
function grid:CommitGridList() self.commits = self.commits + 1 end
local tree = { nodes = {} }
function tree:Reset() self.nodes = {} end
function tree:AddNode(_, entry, parentNode)
    local node = { entry = entry, parent = parentNode }
    self.nodes[#self.nodes + 1] = node
    return node
end
function tree:Commit() end
function tree:GetSelectedData() return self.selected end

local pool = {}
function pool:AcquireObject() return wrap({}) end
local book = {
    categoryTree = tree, gridListPanelList = grid, entryDataObjectPool = pool,
    searchEditBox = { GetText = function(self) return self.text or "" end },
    categoryFilters = { function(data) return data:AnyChildPassesFilters() end },
    setFilters = {}, pieceFilters = {}, collapsedSetIds = {},
    categoryProgress = control(), selectReconstructItemHeaderLabel = control(),
    categoriesRefreshGroup = { MarkDirty = function() end },
}
function book:IsReconstructing() return self.reconstructing or false end
function book:HasSearchFilter() return self.searchEditBox:GetText() ~= "" end
function book:GetSelectedCategory() return self.categoryTree:GetSelectedData() end
function book:IsSetHeaderCollapsed(id) return self.collapsedSetIds[id] or false end
function book:AddCategory(data, parentNode, filters)
    local wrapped = ZO_EntryData:New(data)
    wrapped.node = self.categoryTree:AddNode("category", wrapped, parentNode)
    for _, child in data:SubcategoryIterator(filters) do self:AddCategory(child, wrapped.node, filters) end
end
function book:RefreshCategories()
    self.categoryTree:Reset()
    local selected = self:GetSelectedCategory()
    if not self:IsReconstructing() then self:AddCategory(ITEM_SET_COLLECTIONS_SUMMARY_CATEGORY_DATA) end
    for _, data in ITEM_SET_COLLECTIONS_DATA_MANAGER:TopLevelItemSetCollectionCategoryIterator(self.categoryFilters) do
        self:AddCategory(data, nil, self.categoryFilters)
    end
    self.categoryTree:Commit()
    if not selected then self.noSelectionRefresh = true end
end
function book:RefreshCategoryContentList()
    self.gridListPanelList:ClearGridList()
    if self:GetSelectedCategory() and self:GetSelectedCategory():GetId() ~= addon.FALLBACK_CATEGORY_ID then
        self.gridListPanelList:AddEntry({ native = true })
    end
    self.gridListPanelList:CommitGridList()
end
function book:RefreshCategoryProgress() self.nativeProgress = true end
function book:SetupGridHeaderEntry(control, data)
    self.nativeHeader = true
end
function book:OnContentHeaderMouseEnter() self.nativeTooltip = true end

local mapped = { setId = 101, name = "Алмазный сет", itemLink = "item:101", zoneIds = { 123 }, zoneByCategory = { [11] = 123 }, traitsNeeded = 6 }
local fallback = { setId = 102, name = "Забытый сет", itemLink = "item:102", zoneIds = { 456 }, zoneByCategory = {}, traitsNeeded = 3 }
local catalog = { byCategory = { [11] = { mapped } }, fallback = { fallback } }
assert(addon.InstallBookHooks(book, catalog), "book hooks must install")
assert(addon.InstallBookHooks(book, catalog), "installation must be idempotent")

book.searchEditBox.text = "алмазный"
book:RefreshCategories()
assert(#tree.nodes == 3, "crafted-only search must retain the summary, parent and leaf; got " .. #tree.nodes)
tree.selected = tree.nodes[3].entry
book:RefreshCategoryContentList()
assert(#grid.entries == 2 and grid.entries[1].native, "native entries must survive")
assert(addon.IsCraftedEntry(grid.entries[2]) and addon.IsCraftedEntry(grid.entries[2].gridHeaderData),
    "one crafted tile and its header must be appended")
assert(grid.entries[2].gridHeaderData:GetId() == 101, "crafted header must identify its set")
local craftedHeader = grid.entries[2].gridHeaderData

local function uiControl()
    local result = control()
    function result:SetAnchor(point, relativeTo, relativePoint, offsetX, offsetY)
        self.anchors = self.anchors or {}
        self.anchors[#self.anchors + 1] = { point, relativeTo, relativePoint, offsetX, offsetY }
    end
    function result:SetDimensions() end
    function result:SetHeight() end
    function result:SetFont() end
    function result:SetColor() end
    return result
end
WINDOW_MANAGER = { CreateControl = uiControl }
ZO_ToggleButton_SetState = function() end
TOGGLE_BUTTON_CLOSED, TOGGLE_BUTTON_OPEN = 1, 2
TOPLEFT, TOPRIGHT, BOTTOMLEFT, BOTTOMRIGHT = 1, 2, 3, 4
local headerControl = { nameLabel = control(), costLabel = control(), costHeader = control(),
    progressBar = control(), expandedStateButton = control() }
book:SetupGridHeaderEntry(headerControl, { header = craftedHeader })
assert(headerControl.costLabel.hidden and headerControl.costHeader.hidden and headerControl.progressBar.hidden,
    "crafted header must hide reconstruction cost and the unnecessary progress bar")
assert(headerControl.kanaRequirementLabel.text == "Требуется 6 изученных особенностей",
    "full trait requirement must be visible")
assert(headerControl.kanaRequirementLabel.anchors[1][2] == headerControl.nameLabel,
    "requirement must use a full-width line below the set name")
assert(headerControl.kanaMapButton == nil, "crafted header must have no map button")
book:SetupGridHeaderEntry(headerControl, { header = { GetId = function() return 999 end } })
assert(headerControl.kanaRequirementLabel.hidden, "reused native header must hide the crafted requirement")
assert(not headerControl.costLabel.hidden and not headerControl.costHeader.hidden
    and not headerControl.progressBar.hidden and book.nativeHeader,
    "native header setup must restore cost and progress controls")

book.searchEditBox.text = "other"
book:RefreshCategories()
assert(#tree.nodes == 1, "nonmatching query must remove crafted-only categories")
tree.selected = ZO_EntryData:New(leaf)
book:RefreshCategoryContentList()
assert(#grid.entries == 1 and grid.entries[1].native, "nonmatching query must not append crafted entries")

book.searchEditBox.text = "забытый"
book:RefreshCategories()
assert(#tree.nodes == 2 and tree.nodes[2].entry:GetId() == addon.FALLBACK_CATEGORY_ID,
    "unmapped crafted set must appear in fallback category")
tree.selected = tree.nodes[2].entry
book:RefreshCategoryProgress()
assert(book.categoryProgress.hidden, "fallback must not divide by zero or show fake category progress")
book:RefreshCategoryContentList()
assert(#grid.entries == 1 and addon.IsCraftedEntry(grid.entries[1]), "fallback must contain its set")

book.searchEditBox.text = ""
book.reconstructing = true
book:RefreshCategories()
assert(#tree.nodes == 0, "reconstruction must not show crafted-only categories")
tree.selected = ZO_EntryData:New(leaf)
book:RefreshCategoryContentList()
assert(#grid.entries == 1 and grid.entries[1].native, "reconstruction must not show crafted entries")

local reused = craftedHeader
reused:SetDataSource({ GetId = function() return 999 end })
assert(not addon.IsCraftedEntry(reused), "pool reuse must clear the crafted identity")

local failedCommit = function() error("native commit failed") end
tree.Commit = failedCommit
local originalFilters = book.categoryFilters
assert(not pcall(function() book:RefreshCategories() end), "native category error must be propagated")
assert(book.categoryFilters == originalFilters and tree.Commit == failedCommit,
    "temporary category hooks must be restored after an error")
grid.CommitGridList = failedCommit
assert(not pcall(function() book:RefreshCategoryContentList() end), "native grid error must be propagated")
assert(grid.CommitGridList == failedCommit, "temporary grid hook must be restored after an error")
print("integration_test: ok")
