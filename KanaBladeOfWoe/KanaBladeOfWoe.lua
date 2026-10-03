local ADDON_NAME = "KanaBladeOfWoe"
local defaults = {enabled = true, restoreProtection = false}
local saved

local function RestoreProtection()
    if not saved.restoreProtection then return end
    SetSetting(SETTING_TYPE_COMBAT, COMBAT_SETTING_PREVENT_ATTACKING_INNOCENTS, "1")
    saved.restoreProtection = false
end

local function IsBladeOfWoeAvailable()
    local name, icon = GetSynergyInfo()
    if type(icon) == "string" and icon:find("_darkbrotherhood_003", 1, true) then
        return true
    end
    return type(name) == "string" and name ~= "" and name == GetAbilityName(78219)
end

local function Refresh()
    if not saved.enabled or not IsBladeOfWoeAvailable() then
        RestoreProtection()
        return
    end
    if GetSetting_Bool(SETTING_TYPE_COMBAT, COMBAT_SETTING_PREVENT_ATTACKING_INNOCENTS) then
        -- Persist ownership of the temporary override so a UI reload can recover
        -- the original setting even if no deactivation event was delivered.
        saved.restoreProtection = true
        SetSetting(SETTING_TYPE_COMBAT, COMBAT_SETTING_PREVENT_ATTACKING_INNOCENTS, "0")
    end
end

local function RegisterSettings()
    local russian = GetCVar("language.2") == "ru"
    local panelId = ADDON_NAME .. "Settings"
    local LAM = LibAddonMenu2
    LAM:RegisterAddonPanel(panelId, {
        type = "panel",
        name = ADDON_NAME,
        displayName = ADDON_NAME,
        author = "Kana",
        version = "1.0.0",
        registerForRefresh = true,
        registerForDefaults = true,
    })
    LAM:RegisterOptionControls(panelId, {
        {
            type = "checkbox",
            name = russian and "Разрешать Клинок Горя" or "Allow Blade of Woe",
            tooltip = russian
                and "Временно отключает запрет атак на мирных NPC, пока доступен Клинок Горя. После исчезновения подсказки возвращает защиту. Пока защита снята, обычные атаки тоже разрешены."
                or "Temporarily disables Prevent Attacking Innocents while Blade of Woe is available, then restores it. Ordinary attacks are also possible during this interval.",
            default = defaults.enabled,
            getFunc = function() return saved.enabled end,
            setFunc = function(value)
                saved.enabled = value
                Refresh()
            end,
            width = "full",
        },
    })
end

local function OnLoaded(_, addonName)
    if addonName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    saved = ZO_SavedVars:NewAccountWide("KanaBladeOfWoeSV", 1, nil, defaults)
    RestoreProtection()
    RegisterSettings()
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_SYNERGY_ABILITY_CHANGED, Refresh)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, Refresh)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_DEACTIVATED, RestoreProtection)
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnLoaded)
