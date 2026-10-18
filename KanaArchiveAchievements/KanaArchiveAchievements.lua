local K = KanaArchiveAchievements
local ADDON_NAME = 'KanaArchiveAchievements'

local function OnAddonLoaded(_, name)
    if name ~= ADDON_NAME or K.controller then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    local settings = ZO_SavedVars:NewAccountWide('KanaArchiveAchievementsSavedVariables', 1, nil, {
        indicators = true,
        tooltips = true,
    })
    LibAddonMenu2:RegisterAddonPanel('KanaArchiveAchievements_Panel', {
        type = 'panel',
        name = 'Kana Archive Helper: achievement hints',
        displayName = '|cFF0000Kana|r |c4488FFArchive Helper|r: |cFFFFFFachievement hints|r',
        author = 'Kana',
        version = '1.0.0',
        registerForRefresh = true,
        registerForDefaults = true,
    })
    local options = {}
    for _, option in ipairs({
        {'indicators', 'Помечать выборы для достижений'},
        {'tooltips', 'Показывать подсказки достижений'},
    }) do
        local key, label = option[1], option[2]
        options[#options + 1] = {
            type = 'checkbox',
            name = label,
            getFunc = function() return settings[key] end,
            setFunc = function(value) settings[key] = value end,
            default = true,
            requiresReload = true,
            width = 'full',
        }
    end
    LibAddonMenu2:RegisterOptionControls('KanaArchiveAchievements_Panel', options)
    local model = K.Model.New(_G, ArchiveHelper)
    local view = K.View.New(_G)
    K.controller = K.Controller.Install(_G, model, view, settings)
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)
