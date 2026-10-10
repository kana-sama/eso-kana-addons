local addon = KanaCooldownPanel
local NAME = 'KanaCooldownPanel'
local COLUMNS, MAX_ROWS = 5, 2
local CELL, GAP = 42, 4
local WIDTH = COLUMNS * CELL + (COLUMNS - 1) * GAP
local height = CELL * MAX_ROWS + GAP
local root, content, settings
local cells, labels, states = {}, {}, {}
local icons, tints, glows = {}, {}, {}
local dragging, dragMouseY, dragTop = false, 0, 0

local function ValidY(value)
    return type(value) == 'number' and value == value and math.abs(value) < math.huge
end

local function Anchor()
    local limit = math.max(0, GuiRoot:GetHeight() - height)
    local y = ValidY(settings.y) and settings.y or 80
    root:ClearAnchors()
    root:SetAnchor(TOP, GuiRoot, TOP, 0, math.max(0, math.min(limit, y)))
end

local function MigratePosition()
    if not ValidY(settings.y) then
        local oldY = type(KanaAurasSettings) == 'table' and KanaAurasSettings.mirrorY
        settings.y = ValidY(oldY) and oldY or 80
    end
end

local function Drag()
    if not dragging then return end
    local _, y = GetUIMousePosition()
    local limit = math.max(0, GuiRoot:GetHeight() - height)
    settings.y = math.max(0, math.min(limit, dragTop + y - dragMouseY))
    Anchor()
end

local function StopDrag()
    if not dragging then return end
    Drag()
    dragging = false
    root:SetHandler('OnUpdate', nil)
end

local function Pulse()
    local alpha = 0.6 + 0.2 * math.sin(GetFrameTimeSeconds() * math.pi * 2)
    for index, state in ipairs(states) do
        if state == 'missing' then
            if settings.alertStyle == 'gold' then
                glows[index]:SetAlpha(alpha)
            else
                cells[index]:SetCenterColor(0.95, 0.06, 0.04, alpha)
                tints[index]:SetCenterColor(0.95, 0.06, 0.04, alpha)
            end
        end
    end
end

function addon:Refresh()
    local bars = self:GetBars()
    height = #bars * CELL + (#bars - 1) * GAP
    root:SetDimensions(WIDTH, height)
    Anchor()
    local combat = IsUnitInCombat('player')
    local skillIcons = settings.iconStyle == 'skill'
    local goldAlert = settings.alertStyle == 'gold'
    local visible, pulsing = false, false
    local active, activeRowVisible = GetActiveHotbarCategory(), false
    for index = 1, COLUMNS * MAX_ROWS do
        local row = math.floor((index - 1) / COLUMNS) + 1
        local slot = ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + (index - 1) % COLUMNS + 1
        local state, text, remaining = 'skip', '', 0
        if bars[row] ~= nil then state, text, remaining = self:GetCellState(slot, bars[row], combat) end
        states[index] = state
        cells[index]:SetHidden(state == 'skip')
        local showIcon = skillIcons and state ~= 'skip'
        icons[index]:SetHidden(not showIcon)
        if showIcon then
            local texture = GetSlotTexture(slot, bars[row])
            icons[index]:SetTexture(texture)
            icons[index]:SetAlpha(self:GetIconAlpha(remaining or 0, GetActionSlotEffectDuration(slot, bars[row])))
        end
        local showGold = state == 'missing' and goldAlert
        glows[index]:SetHidden(not showGold)
        -- Warning tint sits above the icon, so a fully opaque skill cannot cover it.
        local showTint = showIcon and (state == 'soon' or (state == 'missing' and not goldAlert))
        tints[index]:SetHidden(not showTint)
        if showGold then text = '' end
        labels[index]:SetText(text)
        cells[index]:SetCenterColor(0, 0, 0, skillIcons and 0 or 0.55)
        if state == 'soon' then
            cells[index]:SetCenterColor(1, 0.42, 0.04, 0.8)
            tints[index]:SetCenterColor(1, 0.42, 0.04, 0.6)
        elseif state == 'missing' then
            pulsing = true
        end
        visible = visible or state ~= 'skip'
        if bars[row] == active and state ~= 'skip' then activeRowVisible = true end
    end
    if not visible then StopDrag() end
    -- Scene fragments control only the root. Empty content stays hidden when
    -- a fragment unhides the root on returning from a menu.
    content:SetHidden(not visible)
    self.activeBarHighlight:Update(bars, activeRowVisible)
    root:SetMouseEnabled(visible)
    content:SetHandler('OnUpdate', pulsing and Pulse or nil)
    if pulsing then Pulse() end
end

local function Initialize(_, addonName)
    if addonName ~= NAME then return end
    EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED)
    KanaCooldownPanelSettings = type(KanaCooldownPanelSettings) == 'table' and KanaCooldownPanelSettings or {}
    settings = KanaCooldownPanelSettings
    addon:InitializeOptions(settings)
    if not ValidY(settings.y) then settings.y = nil end
    settings.characters = type(settings.characters) == 'table' and settings.characters or {}
    local characterId = GetCurrentCharacterId()
    local character = settings.characters[characterId]
    if type(character) ~= 'table' then
        character = {}
        settings.characters[characterId] = character
    end
    character.skills = type(character.skills) == 'table' and character.skills or {}
    addon.skills = character.skills

    root = WINDOW_MANAGER:CreateTopLevelWindow(NAME .. 'Window')
    root:SetDrawTier(DT_LOW)
    root:SetDimensions(WIDTH, height)
    root:SetMouseEnabled(false)
    root:SetHidden(true)
    Anchor()
    content = WINDOW_MANAGER:CreateControl(NAME .. 'Content', root, CT_CONTROL)
    content:SetAnchorFill(root)
    content:SetMouseEnabled(false)
    content:SetHidden(true)
    addon:CreateActiveBarHighlight(content, WIDTH, CELL, GAP)

    for index = 1, COLUMNS * MAX_ROWS do
        local column = (index - 1) % COLUMNS
        local row = math.floor((index - 1) / COLUMNS)
        local cell = WINDOW_MANAGER:CreateControl(NAME .. 'Cell' .. index, content, CT_BACKDROP)
        cell:SetDimensions(CELL, CELL)
        cell:SetAnchor(TOPLEFT, content, TOPLEFT, column * (CELL + GAP), row * (CELL + GAP))
        cell:SetCenterColor(0, 0, 0, 0.55)
        cell:SetEdgeColor(0, 0, 0, 0)
        cell:SetDrawLayer(DL_BACKGROUND)
        cell:SetDrawLevel(1)
        cell:SetMouseEnabled(false)
        cell:SetHidden(true)
        cells[index] = cell

        local icon = WINDOW_MANAGER:CreateControl(NAME .. 'Icon' .. index, cell, CT_TEXTURE)
        icon:SetAnchorFill(cell)
        icon:SetDrawLayer(DL_CONTROLS)
        icon:SetMouseEnabled(false)
        icon:SetHidden(true)
        icons[index] = icon

        local tint = WINDOW_MANAGER:CreateControl(NAME .. 'Tint' .. index, cell, CT_BACKDROP)
        tint:SetAnchorFill(cell)
        tint:SetEdgeColor(0, 0, 0, 0)
        tint:SetDrawLayer(DL_OVERLAY)
        tint:SetDrawLevel(1)
        tint:SetMouseEnabled(false)
        tint:SetHidden(true)
        tints[index] = tint

        local glow = WINDOW_MANAGER:CreateControl(NAME .. 'Glow' .. index, cell, CT_TEXTURE)
        -- Same cropped glow as ESO's native action button, scaled to our 42px cell.
        glow:SetTexture('EsoUI/Art/HUD/Gamepad/gp_skillGlow.dds')
        glow:SetTextureCoords(0.1875, 0.8125, 0.1875, 0.8125)
        glow:SetAnchor(TOPLEFT, cell, TOPLEFT, -8, -8)
        glow:SetAnchor(BOTTOMRIGHT, cell, BOTTOMRIGHT, 8, 8)
        glow:SetColor(1, 0.72, 0.16, 1)
        glow:SetBlendMode(TEX_BLEND_MODE_ADD)
        glow:SetDrawLayer(DL_OVERLAY)
        glow:SetDrawLevel(2)
        glow:SetMouseEnabled(false)
        glow:SetHidden(true)
        glows[index] = glow

        local label = WINDOW_MANAGER:CreateControl(NAME .. 'Text' .. index, cell, CT_LABEL)
        label:SetAnchorFill(cell)
        label:SetFont('ZoFontGameBold')
        label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        label:SetMouseEnabled(false)
        label:SetColor(1, 1, 1, 1)
        label:SetDrawLayer(DL_OVERLAY)
        label:SetDrawLevel(3)
        label:SetText('')
        labels[index] = label
    end

    root:SetHandler('OnMouseDown', function(_, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT or content:IsHidden() then return end
        local _, y = GetUIMousePosition()
        dragging, dragMouseY, dragTop = true, y, root:GetTop()
        root:SetHandler('OnUpdate', Drag)
    end)
    root:SetHandler('OnMouseUp', function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then StopDrag() end
    end)
    root:SetHandler('OnHide', function()
        StopDrag()
        addon.activeBarHighlight:Reset()
    end)
    local function Refresh() addon:Refresh() end
    -- Refresh before the first frame after a scene opens, even between polls.
    root:SetHandler('OnShow', Refresh)
    local fragment = ZO_SimpleSceneFragment:New(root)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_ACTIVATED, function()
        -- All addons have loaded here, regardless of KanaAuras load order.
        MigratePosition()
        Refresh()
    end)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_COMBAT_STATE, Refresh)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED, Refresh)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_GLOBAL_MOUSE_UP, function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then StopDrag() end
    end)
    addon:InstallMenu()
    addon:InitializeSettings()
    EVENT_MANAGER:RegisterForUpdate(NAME, 100, Refresh)
    Refresh()
end

EVENT_MANAGER:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, Initialize)
