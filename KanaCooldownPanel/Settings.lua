local addon = KanaCooldownPanel
local DEFAULTS = {
    fixedBars = false,
    frontBarPosition = 'bottom',
    activeBarPosition = 'bottom',
    alertStyle = 'red',
    iconStyle = 'square',
}

function addon:InitializeOptions(settings)
    self.settings = settings
    if type(settings.fixedBars) ~= 'boolean' then settings.fixedBars = DEFAULTS.fixedBars end
    for key, choices in pairs({
        frontBarPosition = {top = true, bottom = true},
        activeBarPosition = {top = true, bottom = true},
        alertStyle = {red = true, gold = true},
        iconStyle = {square = true, skill = true},
    }) do
        if not choices[settings[key]] then settings[key] = DEFAULTS[key] end
    end
end

function addon:InitializeSettings()
    local ru = GetCVar('language.2') == 'ru'
    -- LAM creates a global control with this name; keep it distinct from saved variables.
    local panelName = 'KanaCooldownPanelOptions'
    LibAddonMenu2:RegisterAddonPanel(panelName, {
        type = 'panel', name = 'KanaCooldownPanel', displayName = 'KanaCooldownPanel',
        author = 'Kana', version = '1.2.0', registerForRefresh = true, registerForDefaults = true,
    })
    local function Getter(key)
        return function() return addon.settings[key] end
    end
    local function Setter(key)
        return function(value)
            addon.settings[key] = value
            addon:Refresh()
        end
    end
    LibAddonMenu2:RegisterOptionControls(panelName, {
        {
            type = 'checkbox', name = ru and 'Фиксированные панели' or 'Fixed bars',
            tooltip = ru and 'Панели основного и запасного оружия сохраняют свои строки при смене оружия. Если выключено, текущая панель занимает выбранное положение активной панели.'
                or 'Keep primary and backup weapon bars in the same rows when swapping weapons. When disabled, the active bar stays at the selected active bar position.',
            getFunc = Getter('fixedBars'), setFunc = Setter('fixedBars'), default = DEFAULTS.fixedBars,
        },
        {
            type = 'dropdown', name = ru and 'Положение фронтбара' or 'Front bar position',
            tooltip = ru and 'Фронтбар — панель основного оружия. В форме вервольфа или с кольцом Дубовой души остаётся одна текущая строка.'
                or 'The front bar is the primary weapon bar. Werewolf form or Oakensoul still shows a single active row.',
            choices = ru and {'Сверху', 'Снизу'} or {'Top', 'Bottom'}, choicesValues = {'top', 'bottom'},
            disabled = function() return not addon.settings.fixedBars end,
            getFunc = Getter('frontBarPosition'), setFunc = Setter('frontBarPosition'), default = DEFAULTS.frontBarPosition,
        },
        {
            type = 'dropdown', name = ru and 'Положение активной панели' or 'Active bar position',
            tooltip = ru and 'В нефиксированном режиме активная панель всегда на выбранной стороне, независимо от оружия.'
                or 'With dynamic bars, the active bar always stays on this side, regardless of the equipped weapon.',
            choices = ru and {'Сверху', 'Снизу'} or {'Top', 'Bottom'}, choicesValues = {'top', 'bottom'},
            disabled = function() return addon.settings.fixedBars end,
            getFunc = Getter('activeBarPosition'), setFunc = Setter('activeBarPosition'), default = DEFAULTS.activeBarPosition,
        },
        {
            type = 'dropdown', name = ru and 'Тип alert-иконки' or 'Alert style',
            choices = ru and {'! на красном фоне', 'Светящаяся золотистая рамка'}
                or {'! on red background', 'Glowing golden frame'},
            choicesValues = {'red', 'gold'},
            tooltip = ru and 'Предупреждение об отсутствующем важном эффекте в бою. Выбранный фон или рамка пульсирует.'
                or 'Warns about missing important uptime in combat. The selected background or frame pulses.',
            getFunc = Getter('alertStyle'), setFunc = Setter('alertStyle'), default = DEFAULTS.alertStyle,
        },
        {
            type = 'dropdown', name = ru and 'Тип иконки' or 'Icon style',
            choices = ru and {'Квадратик', 'Иконка навыка'} or {'Square', 'Skill icon'}, choicesValues = {'square', 'skill'},
            tooltip = ru and 'Иконка навыка: непрозрачность от 0 при полном таймере до 0,9 перед окончанием; 1 при отсутствии эффекта. Белый таймер всегда читаемый.'
                or 'Skill icon opacity increases from 0 at full duration to 0.9 near expiry, then jumps to 1 when the effect is missing. The white timer remains visible.',
            getFunc = Getter('iconStyle'), setFunc = Setter('iconStyle'), default = DEFAULTS.iconStyle,
        },
    })
end
