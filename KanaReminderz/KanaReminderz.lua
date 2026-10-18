local ADDON_NAME = "KanaReminderz"
local SETTINGS_PANEL = "KanaReminderz_Settings"
local VISIBLE_NAME = "|cFF0000Kana|r |c4488FFReminderz|r|cFFFFFF: progress filter|r"
local defaults = {onlyHighestTier = true}

local function RegisterSettings(settings)
    LibAddonMenu2:RegisterAddonPanel(SETTINGS_PANEL, {
        type = "panel",
        name = VISIBLE_NAME,
        displayName = VISIBLE_NAME,
        author = "Kana",
        version = "1.0.2",
        registerForDefaults = true,
    })
    LibAddonMenu2:RegisterOptionControls(SETTINGS_PANEL, {
        {
            type = "checkbox",
            name = "Только самая большая ступень серии достижений",
            tooltip = "Показывать прогресс только последней ступени серии независимо от завершения предыдущих, " ..
                "которую связывает сама игра. Сообщения о получении достижений сохраняются. " ..
                "Если выключено, Reminderz показывает прогресс всех ступеней.",
            default = defaults.onlyHighestTier,
            getFunc = function() return settings.onlyHighestTier end,
            setFunc = function(value) settings.onlyHighestTier = value end,
            width = "full",
        },
    })
end

local function Initialize(_, addonName)
    if addonName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    -- Independent options: the original Reminderz continues to own its settings.
    local settings = ZO_SavedVars:NewAccountWide("KanaReminderzOptions", 1, nil, defaults)
    if settings.onlyCurrentTier ~= nil then
        settings.onlyHighestTier = settings.onlyCurrentTier
        settings.onlyCurrentTier = nil
    end
    RegisterSettings(settings)

    local original = Reminderz and Reminderz.EVENT_ACHIEVEMENT_UPDATED
    if type(original) ~= "function" or not Reminderz.settings
        or type(GetNextAchievementInLine) ~= "function" then
        d("KanaReminderz: не удалось подключить фильтр достижений; Reminderz работает без изменений.")
        return
    end

    -- Wrap the upstream handler; leave formatting, chat routing and awards to it.
    Reminderz.EVENT_ACHIEVEMENT_UPDATED = function(eventCode, achievementId, ...)
        if settings.onlyHighestTier and GetNextAchievementInLine(achievementId) ~= 0 then
            return
        end
        return original(eventCode, achievementId, ...)
    end

    -- Reminderz registered its function before this dependent addon loaded.
    -- Rebind that existing subscription. Its settings toggle subsequently uses
    -- the wrapped table member, so turning tracking off/on remains functional.
    if Reminderz.settings.trackAchievements then
        EVENT_MANAGER:UnregisterForEvent(Reminderz.name, EVENT_ACHIEVEMENT_UPDATED)
        EVENT_MANAGER:RegisterForEvent(Reminderz.name, EVENT_ACHIEVEMENT_UPDATED,
            Reminderz.EVENT_ACHIEVEMENT_UPDATED)
    end
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, Initialize)
