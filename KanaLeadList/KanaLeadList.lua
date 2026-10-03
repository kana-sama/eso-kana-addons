local ADDON = "KanaLeadList"
local ILL = ILeadList
local ru = GetCVar("language.2") == "ru"
local FIRST_DIG = ru and "Можно выкопать впервые" or "Can scry, never excavated"
local HIDE_SIMPLE = ru and "Скрыть обычные и простую мебель" or "Hide obvious and simple furnishings"
local saved

-- Lua string ordering uses strcoll. On macOS ru_RU.UTF-8, distinct
-- Cyrillic strings can collate equally and trigger LeadList's name tiebreaker.
-- Compare UTF-8 bytes explicitly; never change the process-wide locale.
local function compareText(a, b)
    for i = 1, math.min(#a, #b) do
        local x, y = string.byte(a, i), string.byte(b, i)
        if x ~= y then return x < y and -1 or 1 end
    end
    if #a == #b then return 0 end
    return #a < #b and -1 or 1
end

local function sortText(text)
    text = zo_strlower(text or "")
    text = text:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("%^.*", ""):gsub("ё", "е")
    return (text:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function installSorting()
    local original = ILLUnitList.SortScrollList
    function ILLUnitList:SortScrollList()
        if self.currentSortKey ~= "Zone" then return original(self) end
        local entries = ZO_ScrollList_GetDataList(self.list)
        local keys = {}
        for _, entry in ipairs(entries) do
            keys[entry] = {sortText(entry.data.Zone), sortText(entry.data.Lead)}
        end
        table.sort(entries, function(a, b)
            local result = compareText(keys[a][1], keys[b][1])
            if result == 0 then result = compareText(keys[a][2], keys[b][2]) end
            if result == 0 then
                local x, y = a.data.Aid, b.data.Aid
                if x == y then return false end
                result = x < y and -1 or 1
            end
            if self.currentSortOrder == ZO_SORT_ORDER_UP then return result < 0 end
            return result > 0
        end)
    end
end

-- The game's Services category contains crafting/armory stations, storage,
-- training dummies, Mundus stones, etc. Category IDs are locale independent.
-- This is category metadata, not a hand-maintained list of antiquity IDs.
local SERVICES_CATEGORY_ID = 25
local function isDecorativeFurniture(furnitureId)
    if not furnitureId or furnitureId == 0 then return false end
    local categoryId = GetFurnitureDataCategoryInfo(furnitureId)
    -- Keep unclassified rewards: missing metadata is not evidence of decoration.
    return categoryId ~= nil and categoryId > 0 and categoryId ~= SERVICES_CATEGORY_ID
end

local function isSimpleReward(rewardId, visited)
    if not rewardId or rewardId == 0 then return false end
    visited = visited or {}
    if visited[rewardId] then return false end
    visited[rewardId] = true
    local kind = GetRewardType(rewardId)
    if kind == REWARD_ENTRY_TYPE_ITEM then
        local link = GetItemRewardItemLink(rewardId, 1, 0, LINK_STYLE_DEFAULT)
        if not link or link == "" then return false end
        local itemType, specializedType = GetItemLinkItemType(link)
        if itemType ~= ITEMTYPE_FURNISHING then return false end
        if specializedType == SPECIALIZED_ITEMTYPE_FURNISHING_CRAFTING_STATION
            or specializedType == SPECIALIZED_ITEMTYPE_FURNISHING_ATTUNABLE_STATION
            or specializedType == SPECIALIZED_ITEMTYPE_FURNISHING_TARGET_DUMMY then
            return false
        end
        return isDecorativeFurniture(GetItemLinkFurnitureDataId(link))
    elseif kind == REWARD_ENTRY_TYPE_COLLECTIBLE then
        local collectibleId = GetCollectibleRewardCollectibleId(rewardId)
        if not collectibleId or collectibleId == 0 then return false end
        if GetCollectibleCategoryType(collectibleId) ~= COLLECTIBLE_CATEGORY_TYPE_FURNITURE then return false end
        return isDecorativeFurniture(GetCollectibleFurnitureDataId(collectibleId))
    elseif kind == REWARD_ENTRY_TYPE_REWARD_LIST then
        local listId = GetRewardListIdFromReward(rewardId)
        local count = GetNumRewardListEntries(listId)
        if count == 0 then return false end
        for index = 1, count do
            if not isSimpleReward(GetRewardListEntryInfo(listId, index), visited) then return false end
        end
        return true
    end
    return false
end

local function hideReward(data, scryMode)
    -- Same treasure/motif rules as LeadList's "Hide obvious". Its low-quality
    -- furniture rule is replaced with classification of the complete reward.
    if scryMode then
        if data.Set == ILL.TREASURE and data.Diff == 1 then return true end
    elseif data.Set == ILL.MOTIF_CHAPTER or (data.Set == ILL.TREASURE and data.Diff < 4) then
        return true
    end
    local rewardId
    if data.SetId and data.SetId > 0 then
        rewardId = GetAntiquitySetRewardId(data.SetId)
    else
        rewardId = GetAntiquityRewardId(data.Aid)
    end
    return isSimpleReward(rewardId)
end

local function installFilters()
    local original = ILLUnitList.FilterScrollList
    function ILLUnitList:FilterScrollList()
        local choices = ILL.savedVars.DropdownChoice
        local major, setType = choices.Major, choices.SetType
        local firstDig, hideSimple = major == FIRST_DIG, setType == HIDE_SIMPLE
        saved.firstDig, saved.hideSimple = firstDig, hideSimple
        -- Let upstream keep handling zone selection and every existing filter.
        -- Restore selections even if another addon or upstream raises an error.
        if firstDig then choices.Major = ILL.DropdownData.ChoicesMajor[ILL_DROPDOWN_MAJOR_CANSCRY] end
        if hideSimple then choices.SetType = ILL.DropdownData.ChoicesSetType[ILL_DROPDOWN_SETTYPE_ALL] end
        local ok, err = pcall(original, self)
        choices.Major, choices.SetType = major, setType
        if not ok then error(err) end
        if not firstDig and not hideSimple then return end
        local entries = ZO_ScrollList_GetDataList(self.list)
        local scryMode = firstDig or major == ILL.DropdownData.ChoicesMajor[ILL_DROPDOWN_MAJOR_CANSCRY]
        for i = #entries, 1, -1 do
            local data = entries[i].data
            if (firstDig and data.Dug ~= 0) or (hideSimple and hideReward(data, scryMode)) then
                table.remove(entries, i)
            end
        end
    end
end

local function addChoice(name, label, tooltip)
    local choices = ILL.DropdownData["Choices" .. name]
    local index = #choices + 1
    choices[index] = label
    ILL.DropdownData["Tooltips" .. name][index] = tooltip
    -- The dependency may already have built its combo boxes before our event.
    local control = _G["ILL_Dropdown" .. name]
    local combo = control and control.comboBox
    if combo then
        local entry = combo:CreateItemEntry(label, function()
            ILL.savedVars.DropdownChoice[name] = label
            combo:SetSelectedItem(label)
            ClearTooltip(InformationTooltip)
            PlaySound(SOUNDS.POSITIVE_CLICK)
            ILL.UnitList:RefreshData()
        end)
        combo:AddItem(entry)
    end
end

local function installTooltips()
    local rewardTooltip
    local function clearReward()
        if rewardTooltip then ClearTooltipImmediately(rewardTooltip) end
    end
    local originalEnter, originalExit = ILL.RowMouseEnter, ILL.RowMouseExit
    function ILL.RowMouseEnter(control)
        clearReward()
        originalEnter(control)
        local data = control.data
        if not data or not data.Aid then return end
        local rewardId
        if data.SetId and data.SetId > 0 then
            rewardId = GetAntiquitySetRewardId(data.SetId)
        else
            rewardId = GetAntiquityRewardId(data.Aid)
        end
        if not rewardId or rewardId == 0 then return end
        if not rewardTooltip then
            local topLevel = WINDOW_MANAGER:CreateControlFromVirtual("KanaLeadListRewardTooltipTopLevel", GuiRoot, "TooltipTopLevel")
            rewardTooltip = WINDOW_MANAGER:CreateControlFromVirtual("KanaLeadListRewardTooltip", topLevel, "ZO_ItemIconTooltip")
            rewardTooltip:SetHidden(true)
        end
        -- Keep the original lead/source tooltip and add the native final reward
        -- next to it, without borrowing shared item/comparison tooltip controls.
        if InformationTooltip:GetLeft() >= rewardTooltip:GetWidth() + 8 then
            InitializeTooltip(rewardTooltip, InformationTooltip, TOPRIGHT, -8, 0, TOPLEFT)
        else
            InitializeTooltip(rewardTooltip, InformationTooltip, TOPLEFT, 8, 0, TOPRIGHT)
        end
        rewardTooltip:SetReward(rewardId, 1, 0)
    end
    function ILL.RowMouseExit(control)
        clearReward()
        return originalExit(control)
    end
    local originalHide = ILLMainWindow:GetHandler("OnHide")
    ILLMainWindow:SetHandler("OnHide", function(...)
        clearReward()
        if originalHide then return originalHide(...) end
    end)
end

local function installScrying()
    local originalSetup = ILLUnitList.SetupUnitRow
    function ILLUnitList:SetupUnitRow(control, data)
        originalSetup(self, control, data)
        if control.kanaLeadListScryingInstalled then return end
        control.kanaLeadListScryingInstalled = true
        local originalDoubleClick = control:GetHandler("OnMouseDoubleClick")
        control:SetHandler("OnMouseDoubleClick", function(row, button, ...)
            if button ~= MOUSE_BUTTON_INDEX_LEFT then
                if originalDoubleClick then return originalDoubleClick(row, button, ...) end
                return
            end
            -- Scroll-list controls are pooled: read the current row on each click.
            local antiquityId = row.data and row.data.Aid
            if not antiquityId then return end
            local result = CanScryForAntiquity(antiquityId)
            if result ~= ANTIQUITY_SCRYING_RESULT_SUCCESS then
                ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, GetString("SI_ANTIQUITYSCRYINGRESULT", result))
                return
            end
            SCENE_MANAGER:HideTopLevel(ILLMainWindow)
            ClearTooltipImmediately(InformationTooltip)
            ScryForAntiquity(antiquityId)
        end)
    end
end

local function installColumns()
    local keys = {"Lead", "Zone", "Location", "Lore", "Dug", "Set", "Expiration"}
    local headers = ILLMainWindowHeaders
    local widths, baseWidths, rows = {}, {}, setmetatable({}, {__mode = "k"})
    local measure = WINDOW_MANAGER:CreateControl("KanaLeadListColumnMeasure", GuiRoot, CT_LABEL)
    measure:SetHidden(true)
    if type(saved.hiddenColumns) ~= "table" then saved.hiddenColumns = {} end
    local hidden = saved.hiddenColumns
    local function visibleCount()
        local count = 0
        for _, key in ipairs(keys) do if not hidden[key] then count = count + 1 end end
        return count
    end
    if visibleCount() == 0 then hidden.Lead = nil end
    local totalWidth = 0
    for _, key in ipairs(keys) do
        widths[key] = headers:GetNamedChild(key):GetWidth()
        baseWidths[key] = widths[key]
        totalWidth = totalWidth + widths[key]
    end
    -- Include the empty part of the header in the right-click target.
    headers:SetWidth(totalWidth)
    local textColumns = {Lead=true, Zone=true, Location=true, Set=true}
    local function calculateWidths()
        local available = ILLMainWindowList:GetNamedChild("Contents"):GetWidth()
        if available <= 0 then available = totalWidth end
        local desired, used, deficit = {}, 0, 0
        for i, key in ipairs(keys) do
            if not hidden[key] then
                measure:SetFont(headers:GetNamedChild(key):GetNamedChild("Name"):GetFont())
                desired[key] = measure:GetStringWidth(zo_strupper(ILL.SORTHEADER_NAMES[i])) + 24
                widths[key] = baseWidths[key]
                used = used + widths[key]
            end
        end
        measure:SetFont("ZoFontWinH4")
        -- Measure every filtered row, not just the current scroll viewport.
        for _, entry in ipairs(ZO_ScrollList_GetDataList(ILL.UnitList.list)) do
            for _, key in ipairs(keys) do
                if not hidden[key] then
                    local value = entry.data[key]
                    if key == "Expiration" then
                        if entry.data.HaveLead then
                            local seconds = math.max(0, tonumber(value) or 0)
                            value = string.format("%dd %dh %dm", math.floor(seconds / 86400), math.floor(seconds / 3600) % 24, math.floor(seconds / 60) % 60)
                        else value = "" end
                    end
                    desired[key] = math.max(desired[key], measure:GetStringWidth(tostring(value or "")) + 12)
                end
            end
        end
        if used > available then
            for key in pairs(desired) do widths[key] = widths[key] * available / used end
            used = available
        end
        for key, need in pairs(desired) do deficit = deficit + math.max(0, need - widths[key]) end
        local extra = math.min(math.max(0, available - used), deficit)
        if deficit > 0 then
            for key, need in pairs(desired) do
                widths[key] = widths[key] + extra * math.max(0, need - widths[key]) / deficit
            end
        end
        -- Once all clipped content fits, give the remainder to text columns.
        local remaining, weight = available - used - extra, 0
        for key in pairs(desired) do if textColumns[key] then weight = weight + desired[key] end end
        for key in pairs(desired) do
            if weight > 0 then
                if textColumns[key] then widths[key] = widths[key] + remaining * desired[key] / weight end
            else
                widths[key] = widths[key] + remaining / visibleCount()
            end
        end
        headers:SetWidth(available)
    end
    local function layout(parent)
        local x = 0
        for _, key in ipairs(keys) do
            local child = parent:GetNamedChild(key)
            child:SetHidden(hidden[key] == true)
            child:SetWidth(widths[key])
            child:ClearAnchors()
            child:SetAnchor(TOPLEFT, parent, TOPLEFT, x, 0)
            if not hidden[key] then x = x + widths[key] end
        end
    end
    local function apply()
        calculateWidths()
        layout(headers)
        for control in pairs(rows) do layout(control) end
        if hidden[ILL.UnitList.currentSortKey] then
            for _, key in ipairs(keys) do
                if not hidden[key] then
                    ILL.UnitList.sortHeaderGroup:SelectHeaderByKey(key)
                    break
                end
            end
        end
    end
    local originalSetup = ILLUnitList.SetupUnitRow
    function ILLUnitList:SetupUnitRow(control, data)
        originalSetup(self, control, data)
        rows[control] = true
        layout(control)
    end
    local originalFilter = ILLUnitList.FilterScrollList
    function ILLUnitList:FilterScrollList()
        originalFilter(self)
        calculateWidths()
        layout(headers)
        for control in pairs(rows) do layout(control) end
    end
    local function showColumnsMenu()
        ClearTooltipImmediately(InformationTooltip)
        ClearMenu()
        local entries = {}
        local function updateChecks()
            local count = visibleCount()
            for _, key in ipairs(keys) do
                local index = entries[key]
                local visible = not hidden[key]
                local enabled = not visible or count > 1
                UpdateMenuItemState(index, visible)
                local entry = ZO_Menu.items[index]
                entry.item.enabled = enabled
                ZO_CheckButton_SetEnableState(entry.checkbox, enabled)
            end
        end
        for i, key in ipairs(keys) do
            entries[key] = AddMenuItem(ILL.SORTHEADER_NAMES[i], function()
                -- Guard in the callback too, even if a stale menu invokes it.
                if hidden[key] or visibleCount() > 1 then
                    hidden[key] = not hidden[key]
                    apply()
                end
                updateChecks()
            end, MENU_ADD_OPTION_CHECKBOX)
        end
        updateChecks()
        -- ESO clears a menu when its owner becomes effectively hidden.
        -- A column can disappear inside its checkbox callback; the container stays.
        ShowMenu(headers)
    end
    local function hookHeader(control)
        local original = control:GetHandler("OnMouseUp")
        control:SetMouseEnabled(true)
        control:SetHandler("OnMouseUp", function(self, button, upInside, ...)
            if button == MOUSE_BUTTON_INDEX_RIGHT then
                if upInside then showColumnsMenu() end
                return
            end
            if original then return original(self, button, upInside, ...) end
        end)
    end
    hookHeader(headers)
    for _, key in ipairs(keys) do hookHeader(headers:GetNamedChild(key)) end
    apply()
end

local function installCurrentZoneHighlight()
    -- Scope the guarded native coloring loop to LeadList. Some row children
    -- may not resolve during reuse; keep all original color/hover decisions.
    function ILLUnitList:ColorRow(control, data, mouseIsOver)
        if not self.automaticallyColorRows then return end
        for i = 1, control:GetNumChildren() do
            local child = control:GetChild(i)
            if child and not child.nonRecolorable then
                local kind = child:GetType()
                local textColor, iconColor = self:GetRowColors(data, mouseIsOver, child)
                local color
                if kind == CT_LABEL then color = textColor
                elseif kind == CT_TEXTURE then color = iconColor end
                if color then
                    local r, g, b = color:UnpackRGB()
                    child:SetColor(r, g, b, child:GetControlAlpha())
                end
            end
        end
    end
    local rows = setmetatable({}, {__mode = "k"})
    local function playerZone()
        -- Follow the character, not the zone currently browsed on the world map.
        local zoneId = GetZoneId(GetUnitZoneIndex("player"))
        local seen = {}
        while zoneId and zoneId > 0 and zoneId ~= ILL.ZONEID_ARTAEUM and not seen[zoneId] do
            seen[zoneId] = true
            local parent = GetParentZoneId(zoneId)
            if not parent or parent == 0 or parent == zoneId then break end
            zoneId = parent
        end
        if zoneId == ILL.ZONEID_WSKYRIMCAVERN then zoneId = ILL.ZONEID_WSKYRIM end
        if zoneId == ILL.ZONEID_THEREACHCAVERN then zoneId = ILL.ZONEID_THEREACH end
        return zoneId
    end
    local function matches(zoneId, current)
        if not zoneId or not current or current == 0 then return false end
        if zoneId == current or zoneId == ILL.ZONEID_ALLZONES then return true end
        local groups = {
            {ILL.ZONEID_ARTAEUM_SUMMERSET, ILL.ZONEID_ARTAEUM, ILL.ZONEID_SUMMERSET},
            {ILL.ZONEID_EASTMARCH_RIFT, ILL.ZONEID_EASTMARCH, ILL.ZONEID_RIFT},
            {ILL.ZONEID_CYRODIIL_IMPERIALCITY, ILL.ZONEID_CYRODIIL, ILL.ZONEID_IMPERIALCITY},
            {ILL.ZONEID_GALEN_HIGHISLE, ILL.ZONEID_GALEN, ILL.ZONEID_HIGHISLE},
        }
        for _, group in ipairs(groups) do
            if zoneId == group[1] and (current == group[2] or current == group[3]) then return true end
        end
        return false
    end
    local function update(control, current)
        control.kanaCurrentZoneHighlight:SetHidden(not (control.data and matches(control.data.ZoneId, current)))
    end
    local originalSetup = ILLUnitList.SetupUnitRow
    function ILLUnitList:SetupUnitRow(control, data)
        originalSetup(self, control, data)
        if not control.kanaCurrentZoneHighlight then
            local texture = WINDOW_MANAGER:CreateControl(nil, control, CT_TEXTURE)
            texture.nonRecolorable = true
            texture:SetAnchorFill(control)
            texture:SetDrawLayer(DL_BACKGROUND)
            texture:SetColor(0.1, 0.65, 0.9, 0.22)
            texture:SetMouseEnabled(false)
            control.kanaCurrentZoneHighlight = texture
            rows[control] = true
        end
        update(control, playerZone())
    end
    local function refresh()
        local current = playerZone()
        for control in pairs(rows) do update(control, current) end
    end
    EVENT_MANAGER:RegisterForEvent(ADDON .. "CurrentZone", EVENT_ZONE_CHANGED, refresh)
    EVENT_MANAGER:RegisterForEvent(ADDON .. "CurrentZone", EVENT_PLAYER_ACTIVATED, refresh)
end

local function initialize()
    saved = ZO_SavedVars:NewAccountWide("KanaLeadListSavedVariables", 1, nil, {firstDig = false, hideSimple = false})
    addChoice("Major", FIRST_DIG, ru and "Зацепка есть, а эту древность ещё ни разу не выкапывали." or "You have the lead and have never excavated this antiquity.")
    addChoice("SetType", HIDE_SIMPLE, ru and "Скрыть обычные награды и декоративную мебель. Станки, манекены, хранилища и другие услуги остаются; учитывается награда за весь набор." or "Hide obvious rewards and decorative furnishings. Keep crafting stations, target dummies, storage and other services; classify the complete set reward.")
    -- Upstream rejects unknown saved labels while initializing its dropdowns.
    -- Our own booleans restore these two choices on the next login/reload.
    if saved.firstDig then ILL.savedVars.DropdownChoice.Major = FIRST_DIG end
    if saved.hideSimple then ILL.savedVars.DropdownChoice.SetType = HIDE_SIMPLE end
    for _, name in ipairs({"Major", "SetType"}) do
        local control = _G["ILL_Dropdown" .. name]
        if control and control.comboBox then control.comboBox:SetSelectedItem(ILL.savedVars.DropdownChoice[name]) end
    end
    installSorting()
    installFilters()
    installTooltips()
    installScrying()
    installColumns()
    installCurrentZoneHighlight()
    ILL.UnitList:RefreshData()
end

EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_ADD_ON_LOADED, function(_, name)
    if name ~= ADDON then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_ADD_ON_LOADED)
    if ILL.UnitList and ILL.savedVars then
        initialize()
    else
        EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_PLAYER_ACTIVATED, function()
            EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_PLAYER_ACTIVATED)
            initialize()
        end)
    end
end)
