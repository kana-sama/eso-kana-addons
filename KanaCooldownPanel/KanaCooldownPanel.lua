local addon = KanaCooldownPanel
local NAME = 'KanaCooldownPanel'
local COLUMNS, MAX_ROWS = 5, 2
local CELL, GAP = 42, 4
local WIDTH = COLUMNS * CELL + (COLUMNS - 1) * GAP
local height = CELL * MAX_ROWS + GAP
local root, content, settings
local cells, labels, states = {}, {}, {}
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
        if state == 'missing' then cells[index]:SetCenterColor(0.95, 0.06, 0.04, alpha) end
    end
end

function addon:Refresh()
    local bars = self:GetBars()
    height = #bars * CELL + (#bars - 1) * GAP
    root:SetDimensions(WIDTH, height)
    Anchor()
    local combat = IsUnitInCombat('player')
    local visible, pulsing = false, false
    for index = 1, COLUMNS * MAX_ROWS do
        local row = math.floor((index - 1) / COLUMNS) + 1
        local slot = ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + (index - 1) % COLUMNS + 1
        local state, text = 'skip', ''
        if bars[row] ~= nil then state, text = self:GetCellState(slot, bars[row], combat) end
        states[index] = state
        cells[index]:SetHidden(state == 'skip')
        labels[index]:SetText(text)
        if state == 'active' then
            cells[index]:SetCenterColor(0, 0, 0, 0.55)
        elseif state == 'soon' then
            cells[index]:SetCenterColor(1, 0.42, 0.04, 0.8)
        elseif state == 'missing' then
            pulsing = true
        end
        visible = visible or state ~= 'skip'
    end
    if not visible then StopDrag() end
    -- Scene fragments control only the root. Empty content stays hidden when
    -- a fragment unhides the root on returning from a menu.
    content:SetHidden(not visible)
    root:SetMouseEnabled(visible)
    content:SetHandler('OnUpdate', pulsing and Pulse or nil)
    if pulsing then Pulse() end
end

local function Initialize(_, addonName)
    if addonName ~= NAME then return end
    EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED)
    KanaCooldownPanelSettings = type(KanaCooldownPanelSettings) == 'table' and KanaCooldownPanelSettings or {}
    settings = KanaCooldownPanelSettings
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

    for index = 1, COLUMNS * MAX_ROWS do
        local column = (index - 1) % COLUMNS
        local row = math.floor((index - 1) / COLUMNS)
        local cell = WINDOW_MANAGER:CreateControl(NAME .. 'Cell' .. index, content, CT_BACKDROP)
        cell:SetDimensions(CELL, CELL)
        cell:SetAnchor(TOPLEFT, content, TOPLEFT, column * (CELL + GAP), row * (CELL + GAP))
        cell:SetCenterColor(0, 0, 0, 0.55)
        cell:SetEdgeColor(0, 0, 0, 0)
        cell:SetMouseEnabled(false)
        cell:SetHidden(true)
        cells[index] = cell

        local label = WINDOW_MANAGER:CreateControl(NAME .. 'Text' .. index, cell, CT_LABEL)
        label:SetAnchorFill(cell)
        label:SetFont('ZoFontGameBold')
        label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        label:SetMouseEnabled(false)
        label:SetColor(1, 1, 1, 1)
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
    root:SetHandler('OnHide', StopDrag)
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
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_GLOBAL_MOUSE_UP, function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then StopDrag() end
    end)
    addon:InstallMenu()
    EVENT_MANAGER:RegisterForUpdate(NAME, 100, Refresh)
    Refresh()
end

EVENT_MANAGER:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, Initialize)
