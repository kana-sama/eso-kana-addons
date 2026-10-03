local ADDON_NAME = "KanaAetherChat"
local EVENT_NAME = ADDON_NAME .. "_Widget"

local function Initialize(_, addonName)
    if addonName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(EVENT_NAME, EVENT_ADD_ON_LOADED)

    local widget = AetherChat.Messenger.minBar
    if not widget then return end
    local saved = ZO_SavedVars:NewAccountWide("KanaAetherChatSavedVariables", 1, "Widget", {
        hideWidget = true,
    })

    -- The HUD fragment and /aethericon both call SetHidden. Suppress their
    -- attempts to show this control while the persistent setting is enabled.
    ZO_PreHook(widget, "SetHidden", function(_, hidden)
        return saved.hideWidget and not hidden
    end)

    local function Apply()
        local isHUD = SCENE_MANAGER:IsShowing("hud") or SCENE_MANAGER:IsShowing("hudui")
        widget:SetHidden(saved.hideWidget or not isHUD)
    end
    Apply()

    LibAddonMenu2:RegisterAddonPanel("KanaAetherChat_Panel", {
        type = "panel",
        name = ADDON_NAME,
        displayName = ADDON_NAME,
        author = "Kana",
        version = "1.5.0",
        registerForRefresh = true,
        registerForDefaults = true,
    })
    LibAddonMenu2:RegisterOptionControls("KanaAetherChat_Panel", {
        {
            type = "checkbox",
            name = "Скрыть плавающий виджет",
            tooltip = "Полностью скрывает плавающий значок AetherChat. Чат по-прежнему открывается назначенной клавишей. Настройка общая для всех персонажей и сохраняется после перезагрузки интерфейса.",
            getFunc = function() return saved.hideWidget end,
            setFunc = function(value)
                saved.hideWidget = value
                Apply()
            end,
            default = true,
            width = "full",
        },
    })
end

EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_ADD_ON_LOADED, Initialize)
