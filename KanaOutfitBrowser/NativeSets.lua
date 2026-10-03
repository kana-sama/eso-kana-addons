KanaOutfitBrowser = KanaOutfitBrowser or {}
local KOB = KanaOutfitBrowser
local Sets = {}
Sets.__index = Sets
KOB.NativeSets = Sets

local ADDON = "KanaOutfitBrowser"
local HEADER = "KanaOutfitSetHeader"
local function slots()
    return { OUTFIT_SLOT_HEAD, OUTFIT_SLOT_CHEST, OUTFIT_SLOT_SHOULDERS,
        OUTFIT_SLOT_HANDS, OUTFIT_SLOT_WAIST, OUTFIT_SLOT_LEGS, OUTFIT_SLOT_FEET }
end
local function lower(text)
    return zo_strlower(text or "")
end
local function tooltip(control, text)
    ZO_Tooltips_ShowTextTooltip(control, TOP, text)
end
local function hideTooltip()
    ZO_Tooltips_HideTextTooltip()
end

function Sets.New(book, panel, prefs)
    prefs.collapsed = prefs.collapsed or {}
    local self = setmetatable({ book = book, collectionsBook = book, panel = panel, prefs = prefs }, Sets)
    -- Stable synthetic category; no slot-specific methods or preview callbacks.
    self.category = {
        GetId = function() return -71001 end,
        GetName = function() return "Сеты" end,
        GetFormattedName = function() return "Сеты" end,
        CollectibleIterator = function() return function() return nil end end,
        GetCollectibleDataBySpecializedSort = function() return {} end,
        HasAnyNewCollectibles = function() return false end,
        IsSubcategory = function() return true end,
    }
    self.category.GetCategoryIndicies = function()
        local head = ZO_COLLECTIBLE_DATA_MANAGER:GetCategoryDataById(GetOutfitSlotDataCollectibleCategoryId(OUTFIT_SLOT_HEAD))
        return head:GetParentData():GetCategoryIndicies()
    end
    return self
end

function Sets:AddCategory(book)
    book = book or self.collectionsBook
    if book:GetRestyleCategoryData() and not book:GetRestyleCategoryData():IsSpecializedCollectibleCategoryEnabled() then return end
    local head = ZO_COLLECTIBLE_DATA_MANAGER:GetCategoryDataById(GetOutfitSlotDataCollectibleCategoryId(OUTFIT_SLOT_HEAD))
    local parentData = head and head:GetParentData()
    if not parentData then return end
    for _, node in ipairs(book.collectibleCategoryNodes) do
        if node.data.referenceData == parentData then
            self.node = book:AddCategory("ZO_TreeStatusLabelSubCategory", node, "Сеты", self.category)
            -- No native status mutation is needed for the synthetic category.
            return
        end
    end
end

function Sets:BeginSession()
    if self.model then return end
    local variants = KOB.Catalog.Build()
    self.prefs.catalogDiagnostics = KOB.Catalog.lastDiagnostics
    KOB.Catalog.MigratePreferences(self.prefs, KOB.Catalog.lastDiagnostics)
    self.model = KOB.NativeSetModel.New(variants, self.prefs)
    self.model:Open()
    self.pendingScroll = self.prefs.scrollPosition or 0
end

function Sets:SaveScrollPosition(value)
    if self.model and self.pendingScroll == nil
        and self.panel.collectibleCategoryData == self.category then
        -- ClearGridList resets the scrollbar after clearing its data. Ignore that reset.
        if #self.panel.gridListPanelList:GetData() == 0 then return end
        self.prefs.scrollPosition = value
        self.scrollAnchor = nil
        for index, row in ipairs(self.scrollRows or {}) do
            if row.bottom > value then
                self.scrollAnchor = { key = row.key, family = row.family, offset = value - row.top, index = index }
                break
            end
        end
    end
end

function Sets:RestoreScrollPosition()
    if not self.model or self.panel.collectibleCategoryData ~= self.category then return end
    local grid = self.panel.gridListPanelList
    local previousRows = self.scrollRows or {}
    local rows, byKey = {}, {}
    for _, entry in ipairs(grid:GetData()) do
        local data = entry.data or {}
        local header = data.header
        local key = data.kobRowKey or (type(header) == "table" and ("header:" .. header.key))
        if key and entry.top and not byKey[key] then
            local row = { key = key, family = data.kobFamilyKey or header.key, top = entry.top, bottom = entry.bottom }
            rows[#rows + 1], byKey[key] = row, row
        end
    end
    self.scrollRows = rows
    if self.pendingScroll == nil then return end
    local target = self.pendingScroll
    local anchor = self.pendingAnchor
    if anchor then
        local row = byKey[anchor.key]
        if row then
            target = row.top + math.min(anchor.offset, math.max(0, row.bottom - row.top - 1))
        else
            -- Removed by a filter: prefer the next surviving row, then the preceding one.
            for i = anchor.index + 1, #previousRows do
                row = byKey[previousRows[i].key]
                if row then break end
            end
            if not row then
                for i = math.min(anchor.index - 1, #previousRows), 1, -1 do
                    row = byKey[previousRows[i].key]
                    if row then break end
                end
            end
            row = row or byKey["header:" .. anchor.family]
            if row then target = row.top end
        end
    end
    grid:ScrollToAbsoluteValue(target, nil, true)
    self.pendingScroll, self.pendingAnchor = nil, nil
    -- An empty committed search result is different from the transient clear
    -- above: its old anchor must not survive into the next search rebuild.
    self.scrollAnchor = nil
    self.prefs.scrollPosition = grid:GetScrollValue()
    self:SaveScrollPosition(grid:GetScrollValue())
end

function Sets:AddCollapsedHeader(family)
    local grid = self.panel.gridListPanelList
    grid:FillRowWithEmptyCells(grid.currentHeaderData)
    if #grid:GetData() > 0 then grid:AddLineBreak(grid.headerPrePadding) end
    ZO_ScrollList_AddOperation(grid.list, grid.templateOperationIds[HEADER], { header = family })
    grid.currentHeaderData, grid.currentHeaderName = family, family
    grid:AddLineBreak(grid.headerPostPadding)
end

function Sets:LeaveSession()
    self.model = nil
    self.pendingScroll, self.pendingAnchor, self.scrollAnchor, self.scrollRows = nil, nil, nil, nil
    self.showHidden:SetHidden(true)
    self.showUnknown:SetHidden(true)
    self.panel.gridListPanelControl:SetAnchor(TOPRIGHT, self.panel.typeFilterControl, BOTTOMRIGHT, 0, 9)
    self.panel.typeFilterControl:SetHidden(self.panel.typeFilterDropDown:GetNumItems() <= 2)
    if self.savedAutoFill ~= nil then
        self.panel.gridListPanelList.autoFillRows = self.savedAutoFill
        self.savedAutoFill = nil
    end
end

function Sets:DecorateHeader(control, family)
    local title, eye, star = control:GetNamedChild("Title"), control:GetNamedChild("Hide"), control:GetNamedChild("Favorite")
    title:SetText(family.name)
    local arrow = control:GetNamedChild("ExpandedState")
    ZO_ToggleButton_SetState(arrow, self.prefs.collapsed[family.key] and TOGGLE_BUTTON_CLOSED or TOGGLE_BUTTON_OPEN)
    local function toggleCollapsed()
        self.prefs.collapsed[family.key] = not self.prefs.collapsed[family.key] or nil
        self.panel:RefreshVisible()
    end
    arrow:SetHandler("OnClicked", toggleCollapsed)
    title:SetHandler("OnMouseUp", function(_, button, upInside)
        if button == MOUSE_BUTTON_INDEX_LEFT and upInside then
            toggleCollapsed()
        end
    end)
    if family.hidden then
        title:SetColor(0.42, 0.42, 0.42, 1)
    elseif family.favorite then
        title:SetColor(0.92, 0.80, 0.48, 1)
    else
        title:SetColor(0.80, 0.79, 0.69, 1)
    end
    local eyeName = family.hidden and "hidden" or "visible"
    local eyeBase = "EsoUI/Art/Miscellaneous/Keyboard/" .. eyeName
    eye:SetNormalTexture(eyeBase .. "_up.dds")
    eye:SetPressedTexture(eyeBase .. "_down.dds")
    eye:SetMouseOverTexture(eyeBase .. "_over.dds")
    local starTexture = "eso-kana-addons/KanaOutfitBrowser/Textures/star_" .. (family.favorite and "filled" or "outline") .. ".dds"
    star:SetNormalTexture(starTexture)
    star:SetPressedTexture(starTexture)
    star:SetMouseOverTexture(starTexture)
    eye:SetHandler("OnClicked", function()
        self.model:ToggleHidden(family.key)
        self.panel.gridListPanelList:RefreshGridList()
    end)
    star:SetHandler("OnClicked", function()
        self.model:ToggleFavorite(family.key)
        self.panel.gridListPanelList:RefreshGridList()
    end)
    eye:SetHandler("OnMouseEnter", function(c)
        tooltip(c, family.hidden and "Вернуть сет при следующем входе" or "Скрыть сет при следующем входе")
    end)
    star:SetHandler("OnMouseEnter", function(c)
        tooltip(c, family.favorite and "Убрать из любимого; порядок изменится при следующем входе" or "В любимое; поднять при следующем входе")
    end)
    eye:SetHandler("OnMouseExit", hideTooltip)
    star:SetHandler("OnMouseExit", hideTooltip)
end

function Sets:Inject()
    local panel, grid = self.panel, self.panel.gridListPanelList
    -- The native pool resets the data source only, not addon-owned fields.
    -- ReleaseAllObjects has just run; clear headers before any entries are reused.
    for _, entry in ipairs(self.injectedEntries or {}) do
        entry.gridHeaderName, entry.gridHeaderTemplate = nil, nil
        entry.kobRowKey, entry.kobFamilyKey = nil, nil
    end
    self.injectedEntries = {}
    local atStation = self.stationBook and SCENE_MANAGER:IsShowing("restyle_station_keyboard")
    if panel.collectibleCategoryData ~= self.category
        or not (atStation or SCENE_MANAGER:IsShowing("outfitStylesBook")) then
        if self.model then self:LeaveSession() end
        return
    end
    self.book = atStation and self.stationBook or self.collectionsBook
    if self.model and self.pendingScroll == nil then
        self.pendingScroll = self.prefs.scrollPosition or 0
        self.pendingAnchor = self.scrollAnchor
    end
    self:BeginSession()
    if self.savedAutoFill == nil then self.savedAutoFill = grid.autoFillRows end
    grid.autoFillRows = false
    panel.typeFilterControl:SetHidden(true)
    self.showHidden:SetHidden(false)
    ZO_CheckButton_SetCheckState(self.showHidden, self.prefs.showHidden == true)

    local query = lower(self.book.contentSearchEditBox:GetText())
    local showLocked = ZO_OUTFIT_MANAGER:GetShowLocked()
    self.showUnknown:SetHidden(false)
    ZO_CheckButton_SetCheckState(self.showUnknown, self.prefs.showUnknown == true)
    ZO_CheckButton_SetEnableState(self.showUnknown, showLocked)
    panel.gridListPanelControl:SetAnchor(TOPRIGHT, panel.typeFilterControl, BOTTOMRIGHT, 0, 39)
    local seen, unlocked, total = {}, 0, 0
    for _, family in ipairs(self.model:GetSets()) do
        if query == "" or string.find(lower(family.name), query, 1, true) then
            local collapsedHeaderAdded = false
            for _, variant in ipairs(family.variants) do
                local sources, lockedSlots, hasPart, hasKnownPart = {}, {}, false, false
                for index, slot in ipairs(slots()) do
                    local part = variant.slots[slot]
                    local data = part and ZO_COLLECTIBLE_DATA_MANAGER:GetCollectibleDataById(part.collectibleId)
                    if data and not data:IsHiddenFromCollection() then
                        if data:IsUnlocked() then hasKnownPart = true end
                        if not seen[data:GetId()] then
                            seen[data:GetId()] = true
                            total = total + 1
                            if data:IsUnlocked() then unlocked = unlocked + 1 end
                        end
                        if showLocked or data:IsUnlocked() then
                            sources[index], hasPart = data, true
                        else
                            lockedSlots[index] = true
                        end
                    end
                end
                if hasPart and (hasKnownPart or (showLocked and self.prefs.showUnknown == true)) then
                    if self.prefs.collapsed[family.key] then
                        if not collapsedHeaderAdded then self:AddCollapsedHeader(family); collapsedHeaderAdded = true end
                    else
                    for index = 1, 7 do
                        local data, entry = sources[index]
                        if data then
                            entry = panel.entryDataObjectPool:AcquireObject()
                            entry:SetDataSource(data)
                            ZO_UpdateCollectibleEntryDataIconVisuals(entry, panel:GetActorCategory())
                            self.injectedEntries[#self.injectedEntries + 1] = entry
                        else
                            -- Keep native empty-cell behavior (no preview/click),
                            -- but distinguish a filtered locked part from no part.
                            entry = { isEmptyCell = true,
                                iconFile = lockedSlots[index] and "EsoUI/Art/Miscellaneous/status_locked.dds" or nil }
                        end
                        entry.gridHeaderName, entry.gridHeaderTemplate = family, HEADER
                        entry.kobRowKey, entry.kobFamilyKey = variant.key, family.key
                        -- Original grid template and input handlers: exactly the
                        -- same data insertion path validated by the belt probe.
                        grid:AddEntry(entry)
                    end
                    grid:AddLineBreak(0)
                    end
                end
            end
        end
    end
    panel.progressBar:SetMinMax(0, total)
    panel.progressBar:SetValue(unlocked)
    panel.progressBarProgressLabel:SetText(string.format("%d / %d", unlocked, total))
end

function Sets:Initialize()
    local panel = self.panel
    panel.gridListPanelList:AddHeaderTemplate(HEADER, 34, function(control, data)
        self:DecorateHeader(control, data.header)
    end, nil, ZO_ObjectPool_DefaultResetControl)
    self.showHidden = WINDOW_MANAGER:CreateControlFromVirtual("KanaOutfitSetsShowHidden", panel.control, "ZO_CheckButton")
    self.showHidden:SetAnchor(LEFT, panel.typeFilterControl, LEFT, 0, 0)
    ZO_CheckButton_SetLabelText(self.showHidden, "Показать скрытые")
    ZO_CheckButton_SetToggleFunction(self.showHidden, function(_, checked)
        self.prefs.showHidden = checked == true
        if self.model then self.model:SetShowHidden(checked) end
        panel:RefreshVisible()
    end)
    self.showHidden:SetHidden(true)

    self.showUnknown = WINDOW_MANAGER:CreateControlFromVirtual("KanaOutfitSetsShowUnknown", panel.control, "ZO_CheckButton")
    self.showUnknown:SetAnchor(TOPLEFT, panel.showLockedCheckBox, BOTTOMLEFT, 0, 8)
    ZO_CheckButton_SetLabelText(self.showUnknown, "Показать полностью неизвестные")
    ZO_CheckButton_SetToggleFunction(self.showUnknown, function(_, checked)
        if not ZO_OUTFIT_MANAGER:GetShowLocked() then return end
        self.prefs.showUnknown = checked == true
        panel:RefreshVisible()
    end)
    self.showUnknown:SetHidden(true)

    SecurePostHook(self.collectionsBook, "AddAllSpecializedCollectibleCategories", function() self:AddCategory(self.collectionsBook) end)
    self.stationBook = ZO_RESTYLE_STATION_KEYBOARD
    SecurePostHook(self.stationBook, "AddSlotCollectibleCategories", function() self:AddCategory(self.stationBook) end)
    SecurePostHook(panel.entryDataObjectPool, "ReleaseAllObjects", function() self:Inject() end)
    SecurePostHook(panel.gridListPanelList, "CommitGridList", function() self:RestoreScrollPosition() end)
    ZO_PostHookHandler(panel.gridListPanelList.list.scrollbar, "OnValueChanged", function(_, value)
        self:SaveScrollPosition(value)
    end)
    SecurePostHook(panel, "SetCategoryReferenceData", function(_, reference)
        if reference ~= self.category then self:LeaveSession() end
    end)
    ZO_OUTFIT_STYLES_BOOK_SCENE:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_HIDING then self:LeaveSession() end
    end)
    ZO_RESTYLE_SCENE:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_HIDING then self:LeaveSession() end
    end)
end

EVENT_MANAGER:RegisterForEvent(ADDON .. "NativeSets", EVENT_ADD_ON_LOADED, function(_, name)
    if name ~= ADDON then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON .. "NativeSets", EVENT_ADD_ON_LOADED)
    local saved = ZO_SavedVars:NewAccountWide("KanaOutfitBrowserSavedVariables", 1, nil, {}, GetWorldName())
    saved.nativeSets = saved.nativeSets or { favorites = {}, hidden = {}, showHidden = false }
    local browser = Sets.New(ZO_OUTFIT_STYLES_BOOK_KEYBOARD, ZO_OUTFIT_STYLES_PANEL_KEYBOARD, saved.nativeSets)
    KOB.nativeSets = browser
    browser:Initialize()
    -- Collect once after the real client data becomes available, even if the
    -- user does not open Sets. A subsequent reload writes the snapshot to disk.
    EVENT_MANAGER:RegisterForEvent(ADDON .. "CatalogAudit", EVENT_PLAYER_ACTIVATED, function()
        EVENT_MANAGER:UnregisterForEvent(ADDON .. "CatalogAudit", EVENT_PLAYER_ACTIVATED)
        KOB.Catalog.Build()
        saved.nativeSets.catalogDiagnostics = KOB.Catalog.lastDiagnostics
    end)
end)
