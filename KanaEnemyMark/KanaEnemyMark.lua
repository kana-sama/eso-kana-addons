-- Enemy marker feature extracted from FancyActionBar+ 2.19.7.
-- Original authors: Incanus, dack_janiels, nogetrandom, andy.s.
-- FancyActionBar+ credits Untaunted for this feature.
local ADDON_NAME = "KanaEnemyMark"
local TEXTURE = "/eso-kana-addons/KanaEnemyMark/texture/redarrow.dds"
local defaults = { enabled = true, size = 26 }
local saved

local function ApplyMarker()
    if not saved.enabled then return end
    SetFloatingMarkerInfo(MAP_PIN_TYPE_AGGRO, saved.size, TEXTURE, TEXTURE, true, true)
    SetFloatingMarkerGlobalAlpha(1)
end

local function OnLoaded(_, addonName)
    if addonName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    saved = ZO_SavedVars:NewAccountWide("KanaEnemyMarkSV", 1, nil, defaults)
    ApplyMarker()

    local russian = GetCVar("language.2") == "ru"
    local LAM = LibAddonMenu2
    LAM:RegisterAddonPanel(ADDON_NAME .. "Settings", {
        type = "panel",
        name = ADDON_NAME,
        displayName = ADDON_NAME,
        author = "Kana",
        version = "1.0.0",
        registerForRefresh = true,
        registerForDefaults = true,
    })
    LAM:RegisterOptionControls(ADDON_NAME .. "Settings", {
        {
            type = "description",
            text = russian
                and "Красные стрелки над врагами, с которыми вы в бою. Функция перенесена из FancyActionBar+ (на основе Untaunted)."
                or "Red arrows above enemies you are fighting. Extracted from FancyActionBar+ (based on Untaunted).",
        },
        {
            type = "checkbox",
            name = russian and "Показывать метки врагов" or "Show enemy markers",
            getFunc = function() return saved.enabled end,
            setFunc = function(value) saved.enabled = value end,
            default = defaults.enabled,
            requiresReload = true,
            width = "full",
        },
        {
            type = "slider",
            name = russian and "Размер меток" or "Marker size",
            min = 10,
            max = 90,
            step = 1,
            getFunc = function() return saved.size end,
            setFunc = function(value)
                saved.size = value
                ApplyMarker()
            end,
            default = defaults.size,
            width = "full",
        },
    })
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnLoaded)
