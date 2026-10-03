KanaCraftedSetCollections = KanaCraftedSetCollections or {}
local addon = KanaCraftedSetCollections

addon.FALLBACK_CATEGORY_ID = -987654321

local function EntryRow(entry)
    if not addon.IsCraftedEntry(entry) then return nil end
    local source = entry.GetDataSource and entry:GetDataSource() or entry
    return source.row
end

local function CurrentQuery(book)
    return book.searchEditBox and book.searchEditBox:GetText() or ""
end

local function MatchingRows(book, rows)
    return addon.FilterRows(rows, CurrentQuery(book))
end

local function CategoryHasCrafted(book, catalog, categoryData)
    if #MatchingRows(book, catalog.byCategory[categoryData:GetId()]) > 0 then return true end
    for _, child in categoryData:SubcategoryIterator() do
        if CategoryHasCrafted(book, catalog, child) then return true end
    end
    return false
end

local function FallbackCategory()
    local category = { kanaCraftedFallback = true }
    function category:GetId() return addon.FALLBACK_CATEGORY_ID end
    function category:GetNumSubcategories() return 0 end
    function category:SubcategoryIterator() return function() end end
    function category:CollectionIterator() return function() end end
    function category:IsInstanceOf() return false end
    function category:HasAnyNewPieces() return false end
    function category:GetFormattedName()
        if GetCVar and GetCVar("language.2") == "ru" then return "Другие места крафта" end
        return "Other crafting locations"
    end
    function category:GetKeyboardIcons()
        return "EsoUI/Art/Collections/collections_tabIcon_itemSets_up.dds",
               "EsoUI/Art/Collections/collections_tabIcon_itemSets_down.dds",
               "EsoUI/Art/Collections/collections_tabIcon_itemSets_over.dds"
    end
    return category
end

local function RowsForSelectedCategory(book, catalog)
    local selected = book:GetSelectedCategory()
    if not selected then return nil end
    local categoryId = selected:GetId()
    if categoryId == addon.FALLBACK_CATEGORY_ID then return catalog.fallback end
    return catalog.byCategory[categoryId]
end

local function AppendCraftedRows(book, catalog)
    if book:IsReconstructing() then return end
    local rows = MatchingRows(book, RowsForSelectedCategory(book, catalog))
    local pool = book.entryDataObjectPool
    local grid = book.gridListPanelList
    for _, row in ipairs(rows) do
        if row.itemLink then
            local header = pool:AcquireObject()
            header:SetDataSource(addon.MakeHeader(row))
            header.collapsed = book:IsSetHeaderCollapsed(row.setId)

            local piece = pool:AcquireObject()
            piece:SetDataSource(addon.MakePiece(row))
            piece.gridHeaderData = header
            grid:AddEntry(piece)
        end
    end
end

local function EnsureHeaderControls(control)
    if control.kanaRequirementLabel then return end
    local label = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
    label:SetAnchor(TOPLEFT, control.nameLabel, BOTTOMLEFT, 0, 5)
    label:SetAnchor(TOPRIGHT, control.nameLabel, BOTTOMRIGHT, 0, 5)
    label:SetHeight(20)
    label:SetFont("ZoFontGameSmall")
    label:SetColor(0.8, 0.8, 0.8, 1)
    control.kanaRequirementLabel = label
end

local function SetupCraftedHeader(control, data)
    local row = EntryRow(data.header)
    EnsureHeaderControls(control)
    control.nameLabel:SetText(row.name)
    control.costLabel:SetHidden(true)
    control.costHeader = control.costHeader or control:GetNamedChild("CostHeader")
    control.costHeader:SetHidden(true)
    control.progressBar:SetHidden(true)
    if data.header.collapsed then
        ZO_ToggleButton_SetState(control.expandedStateButton, TOGGLE_BUTTON_CLOSED)
    else
        ZO_ToggleButton_SetState(control.expandedStateButton, TOGGLE_BUTTON_OPEN)
    end

    local traits = tonumber(row.traitsNeeded)
    local requirement = traits and string.format("Требуется %d изученных особенностей", traits)
        or "Требования к особенностям неизвестны"
    control.kanaRequirementLabel:SetText(requirement)
    control.kanaRequirementLabel:SetHidden(false)
end

function addon.InstallBookHooks(book, catalog)
    if not book or not catalog or not book.categoryTree or not book.gridListPanelList
        or not book.entryDataObjectPool or not book.categoriesRefreshGroup
        or not book.categoryTree.Commit or not book.gridListPanelList.CommitGridList
        or not book.RefreshCategories
        or not book.RefreshCategoryContentList or not book.SetupGridHeaderEntry
        or not book.RefreshCategoryProgress or not book.OnContentHeaderMouseEnter
        or not ZO_EntryData then
        return false
    end
    if book.kanaCraftedHooksInstalled then return true end

    local nativeRefreshCategories = book.RefreshCategories
    book.RefreshCategories = function(self, ...)
        local originalFilters = self.categoryFilters
        local originalCommit = self.categoryTree.Commit
        if not self:IsReconstructing() and #originalFilters > 0 then
            self.categoryFilters = { function(data)
                local nativePasses = true
                for _, filter in ipairs(originalFilters) do
                    if not filter(data) then nativePasses = false; break end
                end
                return nativePasses or CategoryHasCrafted(self, catalog, data)
            end }
        end
        self.categoryTree.Commit = function(tree, ...)
            if not self:IsReconstructing() and #MatchingRows(self, catalog.fallback) > 0 then
                self:AddCategory(self.kanaCraftedFallbackCategory)
            end
            return originalCommit(tree, ...)
        end
        local ok, result = pcall(nativeRefreshCategories, self, ...)
        self.categoryTree.Commit = originalCommit
        self.categoryFilters = originalFilters
        if not ok then error(result) end
        return result
    end

    local nativeRefreshList = book.RefreshCategoryContentList
    book.RefreshCategoryContentList = function(self, ...)
        local grid = self.gridListPanelList
        local nativeCommit = grid.CommitGridList
        grid.CommitGridList = function(gridSelf, ...)
            AppendCraftedRows(self, catalog)
            return nativeCommit(gridSelf, ...)
        end
        local ok, result = pcall(nativeRefreshList, self, ...)
        grid.CommitGridList = nativeCommit
        if not ok then error(result) end
        return result
    end

    local nativeSetupHeader = book.SetupGridHeaderEntry
    book.SetupGridHeaderEntry = function(self, control, data, selected)
        if addon.IsCraftedEntry(data.header) then
            return SetupCraftedHeader(control, data)
        end
        if control.kanaRequirementLabel then
            control.kanaRequirementLabel:SetHidden(true)
        end
        control.costLabel:SetHidden(false)
        if control.costHeader then control.costHeader:SetHidden(false) end
        control.progressBar:SetHidden(false)
        return nativeSetupHeader(self, control, data, selected)
    end

    local nativeHeaderMouseEnter = book.OnContentHeaderMouseEnter
    book.OnContentHeaderMouseEnter = function(self, control, ...)
        local header = control.dataEntry and control.dataEntry.data and control.dataEntry.data.header
        local row = EntryRow(header)
        if row then
            ClearTooltip(ItemTooltip)
            InitializeTooltip(ItemTooltip, control, RIGHT, -5, 0, LEFT)
            ItemTooltip:SetLink(row.itemLink)
            return
        end
        return nativeHeaderMouseEnter(self, control, ...)
    end

    local nativeProgress = book.RefreshCategoryProgress
    book.RefreshCategoryProgress = function(self, ...)
        local selected = self:GetSelectedCategory()
        if selected and selected:GetId() == addon.FALLBACK_CATEGORY_ID then
            self.categoryProgress:SetHidden(true)
            self.selectReconstructItemHeaderLabel:SetHidden(true)
            return
        end
        return nativeProgress(self, ...)
    end

    book.kanaCraftedFallbackCategory = FallbackCategory()
    book.kanaCraftedHooksInstalled = true
    book.categoriesRefreshGroup:MarkDirty("List")
    return true
end
