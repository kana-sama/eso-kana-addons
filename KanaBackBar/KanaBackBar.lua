local NAME = 'KanaBackBar'
local DEFAULTS = {showGlow = true, showBrackets = true, mainBar = HOTBAR_CATEGORY_PRIMARY}
local RED, GREEN, BLUE = 0.4, 0.95, 0.8

local function Initialize(_, addonName)
    if addonName ~= NAME then return end
    EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED)

    local saved = ZO_SavedVars:NewCharacterIdSettings('KanaBackBarSV', 1, nil, DEFAULTS)
    for _, key in ipairs({'showGlow', 'showBrackets'}) do
        if type(saved[key]) ~= 'boolean' then saved[key] = DEFAULTS[key] end
    end
    if saved.mainBar ~= HOTBAR_CATEGORY_PRIMARY and saved.mainBar ~= HOTBAR_CATEGORY_BACKUP then
        saved.mainBar = DEFAULTS.mainBar
    end

    local root = WINDOW_MANAGER:CreateTopLevelWindow(NAME .. 'Window')
    root:SetAnchorFill(GuiRoot)
    root:SetDrawTier(DT_LOW)
    root:SetMouseEnabled(false)
    root:SetHidden(true)

    local glow = WINDOW_MANAGER:CreateControl(NAME .. 'Glow', root, CT_TEXTURE)
    glow:SetAnchorFill(root)
    glow:SetTexture('eso-kana-addons/KanaBackBar/textures/EdgeGlow.dds')
    glow:SetColor(RED, GREEN, BLUE, 0.3)
    glow:SetBlendMode(TEX_BLEND_MODE_ADD)
    glow:SetDrawLayer(DL_OVERLAY)
    glow:SetMouseEnabled(false)
    glow:SetHidden(true)

    local brackets = WINDOW_MANAGER:CreateControl(NAME .. 'Brackets', root, CT_CONTROL)
    brackets:SetDimensions(70, 24)
    brackets:SetMouseEnabled(false)
    brackets:SetHidden(true)
    for index, segment in ipairs({
        {0, 0, 2, 24}, {0, 0, 8, 2}, {0, 22, 8, 2},
        {68, 0, 2, 24}, {62, 0, 8, 2}, {62, 22, 8, 2},
    }) do
        local part = WINDOW_MANAGER:CreateControl(NAME .. 'Bracket' .. index, brackets, CT_BACKDROP)
        part:SetDimensions(segment[3], segment[4])
        part:SetAnchor(TOPLEFT, brackets, TOPLEFT, segment[1], segment[2])
        part:SetCenterColor(RED, GREEN, BLUE, 0.85)
        part:SetEdgeColor(0, 0, 0, 0)
        part:SetDrawLayer(DL_OVERLAY)
        part:SetMouseEnabled(false)
    end

    local function Refresh()
        -- Read the actual bar, including failed swaps and special hotbars.
        local active = GetActiveHotbarCategory()
        local sideBar = (active == HOTBAR_CATEGORY_PRIMARY or active == HOTBAR_CATEGORY_BACKUP)
            and active ~= saved.mainBar
        brackets:ClearAnchors()
        brackets:SetAnchor(CENTER, ZO_ReticleContainerReticle or GuiRoot, CENTER, 0, 0)
        glow:SetHidden(not (sideBar and saved.showGlow))
        brackets:SetHidden(not (sideBar and saved.showBrackets))
    end

    -- Scene fragments own the root; each effect keeps its own visibility.
    root:SetHandler('OnShow', Refresh)
    local fragment = ZO_SimpleSceneFragment:New(root)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_ACTIVATED, Refresh)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED, Refresh)

    local russian = GetCVar('language.2') == 'ru'
    local panelName = NAME .. 'Options'
    LibAddonMenu2:RegisterAddonPanel(panelName, {
        type = 'panel', name = NAME, displayName = NAME, author = 'Kana', version = '1.0.0',
        registerForRefresh = true, registerForDefaults = true,
    })
    local function Getter(key)
        return function() return saved[key] end
    end
    local function Setter(key)
        return function(value)
            saved[key] = value
            Refresh()
        end
    end
    LibAddonMenu2:RegisterOptionControls(panelName, {
        {
            type = 'checkbox', name = russian and 'Свечение по краям экрана' or 'Screen-edge glow',
            tooltip = russian and 'Мягкое свечение по всем четырём краям экрана, пока активна сайдовая панель.'
                or 'A soft glow along all four screen edges while the side bar is active.',
            getFunc = Getter('showGlow'), setFunc = Setter('showGlow'), default = DEFAULTS.showGlow,
            width = 'full',
        },
        {
            type = 'checkbox', name = russian and 'Скобки возле прицела' or 'Reticle brackets',
            tooltip = russian and 'Две скобки по сторонам от прицела, пока активна сайдовая панель.'
                or 'Two brackets beside the reticle while the side bar is active.',
            getFunc = Getter('showBrackets'), setFunc = Setter('showBrackets'), default = DEFAULTS.showBrackets,
            width = 'full',
        },
        {
            type = 'dropdown', name = russian and 'Основная панель' or 'Main bar',
            tooltip = russian and 'Панель, на которой вы проводите большую часть времени. Оба сигнала на ней скрыты. Настройки сохраняются отдельно для каждого персонажа.'
                or 'The bar you use most of the time. Both effects are hidden on it. Settings are saved separately for each character.',
            choices = russian and {'Основное оружие (1)', 'Запасное оружие (2)'}
                or {'Primary weapon pair (1)', 'Backup weapon pair (2)'},
            choicesValues = {HOTBAR_CATEGORY_PRIMARY, HOTBAR_CATEGORY_BACKUP},
            getFunc = Getter('mainBar'), setFunc = Setter('mainBar'), default = DEFAULTS.mainBar,
            width = 'full',
        },
    })
    Refresh()
end

EVENT_MANAGER:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, Initialize)
