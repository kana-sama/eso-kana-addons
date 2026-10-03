KanaOutfitBrowser = KanaOutfitBrowser or {}
local KOB = KanaOutfitBrowser

KOB.UI = KOB.UI or {}
local UI = KOB.UI
UI.__index = UI

local ACTION_LAYER = "KanaOutfitBrowserScene"
local SCENE_NAME = "kanaOutfitBrowser"
local STYLE_DATA_TYPE = 1
local HEADER_DATA_TYPE = 2
local STYLE_ROW_HEIGHT = 46
local HEADER_ROW_HEIGHT = 32

local WEIGHT_NAMES = {
    [1] = "Лёгкая броня",
    [2] = "Средняя броня",
    [3] = "Тяжёлая броня",
    [4] = "Единый комплект",
}

local WEIGHT_SHORT = {
    [1] = "Л",
    [2] = "С",
    [3] = "Т",
    [4] = "Единый",
}

local function createLabel(name, parent, font)
    local label = WINDOW_MANAGER:CreateControl(name, parent, CT_LABEL)
    label:SetFont(font or "ZoFontGame")
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    return label
end

local function showTooltip(control, text)
    ZO_Tooltips_ShowTextTooltip(control, TOP, text)
end

local function hideTooltip()
    ZO_Tooltips_HideTextTooltip()
end

local function collectMissingSlots(variant)
    local slotIds = {}
    for key, value in pairs(variant.missingSlots or {}) do
        if type(value) == "number" then
            slotIds[#slotIds + 1] = value
        elseif value then
            slotIds[#slotIds + 1] = key
        end
    end
    table.sort(slotIds, function(left, right)
        return tostring(left) < tostring(right)
    end)

    local names = {}
    for _, slotId in ipairs(slotIds) do
        local name
        if GetString then
            name = GetString("SI_OUTFITSLOT", slotId)
        end
        names[#names + 1] = (name and name ~= "") and name or tostring(slotId)
    end
    return names
end

local function formatVariantTooltip(ui, variant)
    local lines = { variant.name, WEIGHT_NAMES[variant.weight] or "Комплект брони" }
    if ui.controller.accountPrefs.favorites[variant.key] then
        lines[#lines + 1] = "В любимом"
    end
    if ui.controller.accountPrefs.hidden[variant.key] then
        lines[#lines + 1] = "Скрытый комплект"
    end
    local missing = collectMissingSlots(variant)
    if #missing > 0 then
        lines[#lines + 1] = "Неполный комплект: " .. table.concat(missing, ", ")
    end
    return table.concat(lines, "\n")
end

local function resetButton(button)
    button:SetHandler("OnClicked", nil)
    button:SetHandler("OnMouseEnter", nil)
    button:SetHandler("OnMouseExit", nil)
    button:SetHidden(false)
    button:SetEnabled(true)
    button:SetAlpha(1)
    button:SetText("")
    button:SetState(BSTATE_NORMAL, false)
    button:SetNormalFontColor(0.78, 0.78, 0.78, 1)
    button:SetPressedFontColor(1, 1, 1, 1)
    button:SetMouseOverFontColor(1, 1, 1, 1)
    button:SetDisabledFontColor(0.35, 0.35, 0.35, 1)
end

local function prepareStyleRow(control)
    control.rowData = nil
    control:SetAlpha(1)
    resetButton(control:GetNamedChild("Style"))
    resetButton(control:GetNamedChild("Light"))
    resetButton(control:GetNamedChild("Medium"))
    resetButton(control:GetNamedChild("Heavy"))
    resetButton(control:GetNamedChild("Unified"))
end

local function prepareHeaderRow(control)
    control.rowData = nil
    control:GetNamedChild("Title"):SetText("")
end

function UI.ResetStyleRowForPool(control)
    prepareStyleRow(control)
    control:SetHidden(true)
end

function UI.ResetHeaderRowForPool(control)
    prepareHeaderRow(control)
    control:SetHidden(true)
end

function UI.AddSceneFragments(scene, mouseGroup, frameGroup, optionsFragment, previewFragment, rootFragment)
    scene:AddFragmentGroup(mouseGroup)
    scene:AddFragmentGroup(frameGroup)
    -- Both staging paths failed in the client; retain ordinary player framing.
    scene:AddFragment(rootFragment)
end

function UI.OnSceneStateChanged(self, oldState, newState)
    if newState == SCENE_SHOWING then
        if not self.controller.open then
            self.controller:Open(true)
        end
        PushActionLayerByName(ACTION_LAYER)
    elseif newState == SCENE_SHOWN then
        self.controller:OnSceneShown()
    elseif newState == SCENE_HIDING then
        RemoveActionLayerByName(ACTION_LAYER)
        -- Stop the controller before leaving the Collections tab.
        self.controller:Close()
    end
end

function UI.New(controller)
    local self = setmetatable({}, UI)
    self.controller = controller
    self.status = controller.status
    self.statusText = controller.statusText
    self.rowsSignature = nil
    self.dataIndexByKey = {}
    self.lastSelectedKey = nil
    self:CreateControls()
    self:CreateScene()
    return self
end

function UI:CreateControls()
    local root = KanaOutfitBrowserRoot
    self.root = root

    local panel = WINDOW_MANAGER:CreateControl("KanaOutfitBrowserRightPanel", root, CT_BACKDROP)
    panel:SetWidth(870)
    panel:SetAnchor(TOPRIGHT, ZO_MainMenuSceneGroupBar, BOTTOMRIGHT, 6, 20)
    panel:SetAnchor(BOTTOMRIGHT, GuiRoot, BOTTOMRIGHT, -34, -82)
    panel:SetCenterTexture("EsoUI/Art/Tooltips/UI-TooltipCenter.dds")
    panel:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds", 128, 16)
    panel:SetCenterColor(0.025, 0.03, 0.04, 0.88)
    panel:SetEdgeColor(0.55, 0.47, 0.30, 0.9)
    panel:SetMouseEnabled(true)
    self.panel = panel

    local title = createLabel("KanaOutfitBrowserTitle", panel, "ZoFontWinH2")
    title:SetText("Примерочная комплектов")
    title:SetColor(0.95, 0.88, 0.68, 1)
    title:SetAnchor(TOPLEFT, panel, TOPLEFT, 24, 14)
    title:SetDimensions(700, 42)

    local closeButton = WINDOW_MANAGER:CreateControlFromVirtual("KanaOutfitBrowserClose", panel, "ZO_CloseButton")
    closeButton:ClearAnchors()
    closeButton:SetAnchor(TOPRIGHT, panel, TOPRIGHT, -15, 15)
    closeButton:SetDimensions(28, 28)
    closeButton:SetHandler("OnClicked", function()
        self:Hide()
    end)

    local checkBox = WINDOW_MANAGER:CreateControlFromVirtual("KanaOutfitBrowserShowHidden", panel, "ZO_CheckButton")
    checkBox:SetAnchor(TOPLEFT, panel, TOPLEFT, 28, 63)
    ZO_CheckButton_SetLabelText(checkBox, "Показать скрытые")
    ZO_CheckButton_SetToggleFunction(checkBox, function(_, checked)
        self.controller:SetShowHidden(checked)
    end)
    self.showHiddenCheckBox = checkBox

    local styleHeader = createLabel("KanaOutfitBrowserStyleHeader", panel, "ZoFontGameBold")
    styleHeader:SetText("Стиль")
    styleHeader:SetColor(0.75, 0.75, 0.75, 1)
    styleHeader:SetAnchor(TOPLEFT, panel, TOPLEFT, 38, 100)
    styleHeader:SetDimensions(330, 26)

    local columnNames = { "Лёгкая", "Средняя", "Тяжёлая" }
    local offsets = { 414, 552, 690 }
    for index, text in ipairs(columnNames) do
        local label = createLabel("KanaOutfitBrowserColumn" .. index, panel, "ZoFontGameBold")
        label:SetText(text)
        label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        label:SetColor(0.75, 0.75, 0.75, 1)
        label:SetAnchor(TOPLEFT, panel, TOPLEFT, offsets[index], 100)
        label:SetDimensions(132, 26)
    end

    local list = WINDOW_MANAGER:CreateControlFromVirtual("KanaOutfitBrowserList", panel, "ZO_ScrollList")
    list:SetAnchor(TOPLEFT, panel, TOPLEFT, 22, 130)
    list:SetAnchor(BOTTOMRIGHT, panel, BOTTOMRIGHT, -20, -68)
    ZO_ScrollList_AddDataType(list, STYLE_DATA_TYPE, "KanaOutfitBrowserStyleRow", STYLE_ROW_HEIGHT,
        function(control, data) self:SetupStyleRow(control, data) end, nil, nil, UI.ResetStyleRowForPool)
    ZO_ScrollList_AddDataType(list, HEADER_DATA_TYPE, "KanaOutfitBrowserHeaderRow", HEADER_ROW_HEIGHT,
        function(control, data) self:SetupHeaderRow(control, data) end, nil, nil, UI.ResetHeaderRowForPool)
    ZO_ScrollList_AddResizeOnScreenResize(list)
    self.list = list

    local emptyLabel = createLabel("KanaOutfitBrowserEmpty", panel, "ZoFontWinH3")
    emptyLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    emptyLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    emptyLabel:SetColor(0.72, 0.72, 0.72, 1)
    emptyLabel:SetAnchor(CENTER, list, CENTER, 0, 0)
    emptyLabel:SetDimensions(650, 120)
    emptyLabel:SetHidden(true)
    self.emptyLabel = emptyLabel

    local help = createLabel("KanaOutfitBrowserHelp", panel, "ZoFontGame")
    help:SetText("↑ ↓ — строка      ← → — вариант")
    help:SetColor(0.55, 0.55, 0.55, 1)
    help:SetAnchor(BOTTOMLEFT, panel, BOTTOMLEFT, 28, -50)
    help:SetDimensions(700, 34)

    local selectedName = createLabel("KanaOutfitBrowserSelectedName", root, "ZoFontWinH2")
    selectedName:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 58, 92)
    selectedName:SetDimensions(610, 38)
    selectedName:SetColor(0.98, 0.92, 0.76, 1)
    self.selectedName = selectedName

    local selectedWeight = createLabel("KanaOutfitBrowserSelectedWeight", root, "ZoFontWinH4")
    selectedWeight:SetAnchor(TOPLEFT, selectedName, BOTTOMLEFT, 0, 1)
    selectedWeight:SetDimensions(610, 30)
    selectedWeight:SetColor(0.80, 0.80, 0.80, 1)
    self.selectedWeight = selectedWeight

    local starButton = WINDOW_MANAGER:CreateControl("KanaOutfitBrowserFavorite", root, CT_BUTTON)
    starButton:SetDimensions(32, 32)
    starButton:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 700, 96)
    starButton:SetNormalTexture("EsoUI/Art/Collections/Favorite_StarOnly.dds")
    starButton:SetPressedTexture("EsoUI/Art/Collections/Favorite_StarOnly.dds")
    starButton:SetMouseOverTexture("EsoUI/Art/Collections/Favorite_StarOnly.dds")
    starButton:SetHandler("OnClicked", function() self.controller:ToggleFavorite() end)
    starButton:SetHandler("OnMouseEnter", function(control)
        local selected = self.controller.model and self.controller.model:GetSelected()
        local favorited = selected and self.controller.accountPrefs.favorites[selected.key]
        showTooltip(control, favorited and "Убрать из любимого" or "В любимое")
    end)
    starButton:SetHandler("OnMouseExit", hideTooltip)
    self.starButton = starButton

    local hideButton = WINDOW_MANAGER:CreateControl("KanaOutfitBrowserHide", root, CT_BUTTON)
    hideButton:SetDimensions(32, 32)
    hideButton:SetAnchor(LEFT, starButton, RIGHT, 14, 0)
    hideButton:SetHandler("OnClicked", function() self.controller:ToggleHidden() end)
    hideButton:SetHandler("OnMouseEnter", function(control)
        local selected = self.controller.model and self.controller.model:GetSelected()
        local hidden = selected and self.controller.accountPrefs.hidden[selected.key]
        showTooltip(control, hidden and "Вернуть в список" or "Скрыть комплект")
    end)
    hideButton:SetHandler("OnMouseExit", hideTooltip)
    self.hideButton = hideButton

    local previewButton = WINDOW_MANAGER:CreateControlFromVirtual("KanaOutfitBrowserPreviewButton", root, "ZO_DefaultButton")
    previewButton:SetDimensions(160, 32)
    previewButton:SetAnchor(LEFT, hideButton, RIGHT, 18, 0)
    previewButton:SetText("Примерить")
    previewButton:SetHidden(true)
    previewButton:SetHandler("OnMouseDown", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT and self.controller.preview then
            self.controller.preview:VerifyAfterInput()
        end
    end)
    self.previewButton = previewButton

    local statusLabel = createLabel("KanaOutfitBrowserStatus", root, "ZoFontGame")
    statusLabel:SetAnchor(TOPLEFT, selectedWeight, BOTTOMLEFT, 0, 12)
    statusLabel:SetDimensions(760, 80)
    statusLabel:SetVerticalAlignment(TEXT_ALIGN_TOP)
    statusLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    self.statusLabel = statusLabel

    local previousButton = WINDOW_MANAGER:CreateControlFromVirtual("KanaOutfitBrowserPrevious", root, "ZO_DefaultButton")
    previousButton:SetDimensions(72, 34)
    previousButton:SetText("←")
    previousButton:SetAnchor(BOTTOMLEFT, GuiRoot, BOTTOMLEFT, 82, -104)
    previousButton:SetHandler("OnClicked", function() self.controller:MoveHorizontal(-1) end)
    self.previousButton = previousButton

    local positionLabel = createLabel("KanaOutfitBrowserPosition", root, "ZoFontWinH4")
    positionLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    positionLabel:SetAnchor(LEFT, previousButton, RIGHT, 12, 0)
    positionLabel:SetDimensions(150, 34)
    self.positionLabel = positionLabel

    local nextButton = WINDOW_MANAGER:CreateControlFromVirtual("KanaOutfitBrowserNext", root, "ZO_DefaultButton")
    nextButton:SetDimensions(72, 34)
    nextButton:SetText("→")
    nextButton:SetAnchor(LEFT, positionLabel, RIGHT, 12, 0)
    nextButton:SetHandler("OnClicked", function() self.controller:MoveHorizontal(1) end)
    self.nextButton = nextButton
end

function UI:CreateScene()
    self.scene = ZO_Scene:New(SCENE_NAME, SCENE_MANAGER)
    self.scene:RegisterCallback("StateChange", function(oldState, newState)
        UI.OnSceneStateChanged(self, oldState, newState)
    end)

    self.rootFragment = ZO_FadeSceneFragment:New(self.root)
    UI.AddSceneFragments(
        self.scene,
        FRAGMENT_GROUP.MOUSE_DRIVEN_UI_WINDOW,
        FRAGMENT_GROUP.FRAME_TARGET_STANDARD_RIGHT_PANEL,
        nil,
        nil,
        self.rootFragment
    )
end

function UI:SetupHeaderRow(control, data)
    prepareHeaderRow(control)
    control:SetHidden(false)
    control.rowData = data
    control:GetNamedChild("Title"):SetText(data.row.title or "")
end

function UI:SetupVariantButton(button, variant, selectedKey)
    resetButton(button)
    if not variant then
        button:SetText("—")
        button:SetEnabled(false)
        button:SetAlpha(0.5)
        return
    end

    local favorite = self.controller.accountPrefs.favorites[variant.key]
    local hidden = self.controller.accountPrefs.hidden[variant.key]
    local text = WEIGHT_SHORT[variant.weight] or "?"
    if favorite then
        text = text .. "  ★"
        button:SetNormalFontColor(0.95, 0.73, 0.28, 1)
    end
    if hidden then
        text = text .. "  ⊘"
        button:SetAlpha(0.5)
    end
    button:SetText(text)
    if variant.key == selectedKey then
        button:SetState(BSTATE_PRESSED, true)
    end
    button:SetHandler("OnClicked", function()
        self.controller:Select(variant.key)
    end)
    button:SetHandler("OnMouseEnter", function(control)
        showTooltip(control, formatVariantTooltip(self, variant))
    end)
    button:SetHandler("OnMouseExit", hideTooltip)
end

function UI:SetupStyleRow(control, data)
    prepareStyleRow(control)
    control:SetHidden(false)
    control.rowData = data
    local row = data.row
    local selected = self.controller.model and self.controller.model:GetSelected()
    local selectedKey = selected and selected.key or nil
    local styleButton = control:GetNamedChild("Style")
    styleButton:SetText(row.name or "")
    styleButton:SetHandler("OnClicked", function()
        self.controller:SelectRow(row)
    end)

    local rowSelected = false
    for _, variant in pairs(row.variants) do
        if variant.key == selectedKey then
            rowSelected = true
            break
        end
    end
    if rowSelected then
        styleButton:SetState(BSTATE_PRESSED, true)
    end

    local unified = row.variants[4]
    local unifiedButton = control:GetNamedChild("Unified")
    local lightButton = control:GetNamedChild("Light")
    local mediumButton = control:GetNamedChild("Medium")
    local heavyButton = control:GetNamedChild("Heavy")
    if unified then
        lightButton:SetHidden(true)
        mediumButton:SetHidden(true)
        heavyButton:SetHidden(true)
        unifiedButton:SetHidden(false)
        self:SetupVariantButton(unifiedButton, unified, selectedKey)
    else
        unifiedButton:SetHidden(true)
        self:SetupVariantButton(lightButton, row.variants[1], selectedKey)
        self:SetupVariantButton(mediumButton, row.variants[2], selectedKey)
        self:SetupVariantButton(heavyButton, row.variants[3], selectedKey)
    end
end

function UI:GetRowsSignature(rows)
    local pieces = {}
    for _, row in ipairs(rows) do
        if row.kind == "header" then
            pieces[#pieces + 1] = "H:" .. tostring(row.title)
        else
            local keys = { "S:" .. tostring(row.styleKey) }
            for weight = 1, 4 do
                keys[#keys + 1] = row.variants[weight] and row.variants[weight].key or "-"
            end
            pieces[#pieces + 1] = table.concat(keys, ":")
        end
    end
    return table.concat(pieces, "|")
end

function UI:RefreshRows(rows, selectedKey)
    local signature = self:GetRowsSignature(rows)
    local rebuilt = signature ~= self.rowsSignature
    if rebuilt then
        self.rowsSignature = signature
        self.dataIndexByKey = {}
        ZO_ScrollList_Clear(self.list)
        local scrollData = ZO_ScrollList_GetDataList(self.list)
        for _, row in ipairs(rows) do
            local dataType = row.kind == "header" and HEADER_DATA_TYPE or STYLE_DATA_TYPE
            local data = { row = row }
            scrollData[#scrollData + 1] = ZO_ScrollList_CreateDataEntry(dataType, data)
            if row.kind == "style" then
                local dataIndex = #scrollData
                for _, variant in pairs(row.variants) do
                    self.dataIndexByKey[variant.key] = dataIndex
                end
            end
        end
        ZO_ScrollList_Commit(self.list)
    else
        local scrollData = ZO_ScrollList_GetDataList(self.list)
        self.dataIndexByKey = {}
        for index, row in ipairs(rows) do
            local entry = scrollData[index]
            if entry then
                entry.data.row = row
            end
            if row.kind == "style" then
                for _, variant in pairs(row.variants) do
                    self.dataIndexByKey[variant.key] = index
                end
            end
        end
        ZO_ScrollList_RefreshVisible(self.list)
    end

    if selectedKey and (rebuilt or selectedKey ~= self.lastSelectedKey) then
        local dataIndex = self.dataIndexByKey[selectedKey]
        if dataIndex then
            ZO_ScrollList_ScrollDataIntoView(self.list, dataIndex, nil, true)
        end
    end
    self.lastSelectedKey = selectedKey
end

function UI:RefreshStatus(selected)
    local status = self.controller.status
    local text = self.controller.statusText or ""
    if selected and status == "ready" then
        local missing = collectMissingSlots(selected)
        if #missing > 0 then
            text = "Неполный комплект: " .. table.concat(missing, ", ")
        elseif text == "" then
            text = "Комплект готов"
        end
    end

    if status == "error" then
        self.statusLabel:SetColor(1, 0.35, 0.3, 1)
    elseif status == "unavailable" then
        self.statusLabel:SetColor(1, 0.65, 0.25, 1)
    elseif status == "loading" then
        self.statusLabel:SetColor(0.65, 0.78, 1, 1)
    elseif status == "empty" then
        self.statusLabel:SetColor(0.7, 0.7, 0.7, 1)
    else
        self.statusLabel:SetColor(0.72, 0.9, 0.65, 1)
    end
    self.statusLabel:SetText(text)
end

function UI:SetStatus(status, text)
    self.status = status
    self.statusText = text or ""
end

function UI:Refresh()
    if not self.controller.model then
        return
    end
    local model = self.controller.model
    local selected = model:GetSelected()
    local selectedKey = selected and selected.key or nil
    local rows = model:GetRows()
    local position, total = model:GetPosition()

    self:RefreshRows(rows, selectedKey)
    self.emptyLabel:SetHidden(total ~= 0)
    if total == 0 then
        self.emptyLabel:SetText("Все комплекты скрыты.\nВключи «Показать скрытые», чтобы вернуть их.")
    end

    if self.controller.characterPrefs.showHidden then
        ZO_CheckButton_SetChecked(self.showHiddenCheckBox)
    else
        ZO_CheckButton_SetUnchecked(self.showHiddenCheckBox)
    end

    self.selectedName:SetText(selected and selected.name or "Комплект не выбран")
    self.selectedWeight:SetText(selected and (WEIGHT_NAMES[selected.weight] or "Комплект брони") or "")
    self.positionLabel:SetText(string.format("%d / %d", position, total))
    self.previousButton:SetEnabled(position > 1)
    self.nextButton:SetEnabled(position > 0 and position < total)

    local hasSelection = selected ~= nil
    self.previewButton:SetEnabled(hasSelection)
    self.starButton:SetEnabled(hasSelection)
    self.hideButton:SetEnabled(hasSelection)
    if hasSelection and self.controller.accountPrefs.favorites[selected.key] then
        self.starButton:SetAlpha(1)
    else
        self.starButton:SetAlpha(hasSelection and 0.45 or 0.2)
    end

    local hidden = hasSelection and self.controller.accountPrefs.hidden[selected.key]
    if hidden then
        self.hideButton:SetNormalTexture("EsoUI/Art/Miscellaneous/Keyboard/visible_up.dds")
        self.hideButton:SetPressedTexture("EsoUI/Art/Miscellaneous/Keyboard/visible_down.dds")
        self.hideButton:SetMouseOverTexture("EsoUI/Art/Miscellaneous/Keyboard/visible_over.dds")
    else
        self.hideButton:SetNormalTexture("EsoUI/Art/Miscellaneous/Keyboard/hidden_up.dds")
        self.hideButton:SetPressedTexture("EsoUI/Art/Miscellaneous/Keyboard/hidden_down.dds")
        self.hideButton:SetMouseOverTexture("EsoUI/Art/Miscellaneous/Keyboard/hidden_over.dds")
    end
    self.hideButton:SetAlpha(hasSelection and 0.85 or 0.2)
    self:RefreshStatus(selected)
end

function UI:BindPreviewControls()
    local preview = self.controller.preview
    preview:BindControl(self.previewButton, "OnClicked")
    preview:BindControl(self.root, "OnKeyUp")
end

function UI:Show()
    SCENE_MANAGER:Show(SCENE_NAME)
end

function UI:Hide()
    SCENE_MANAGER:Hide(SCENE_NAME)
end

function KOB.HandleHorizontal(delta)
    if KOB.controller and KOB.controller.open then
        KOB.controller:MoveHorizontal(delta)
    end
    return true
end

function KOB.HandleVertical(delta)
    if KOB.controller and KOB.controller.open then
        KOB.controller:MoveVertical(delta)
    end
    return true
end

function KOB.HandleClose()
    if KOB.controller and KOB.controller.open then
        KOB.controller.ui:Hide()
    end
    return true
end

function KOB.HandleKeyDown(key)
    if key == KEY_LEFTARROW then
        KOB.HandleHorizontal(-1)
    elseif key == KEY_RIGHTARROW then
        KOB.HandleHorizontal(1)
    elseif key == KEY_UPARROW then
        KOB.HandleVertical(-1)
    elseif key == KEY_DOWNARROW then
        KOB.HandleVertical(1)
    elseif key == KEY_ESCAPE then
        return KOB.HandleClose()
    else
        return false
    end
    if KOB.controller and KOB.controller.open and KOB.controller.preview then
        -- Native OnKeyUp runs directly from the engine. Observe only after
        -- selection has changed, so readback refers to the new variant.
        KOB.controller.preview:VerifyAfterInput()
    end
    return true
end
