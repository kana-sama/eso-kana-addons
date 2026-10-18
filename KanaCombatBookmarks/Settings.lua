local addon = KanaCombatBookmarks
local Settings = {}
addon.Settings = Settings

Settings.defaults = {
    bookmarks = true,
    sound = true,
    alerts = true,
    log = true,
    loadedLogRepair = true,
}

function Settings.Enabled(key, api)
    local owner = api and api.KanaCombatBookmarks or addon
    return not owner.settings or owner.settings[key] ~= false
end

function Settings.Initialize(api)
    local owner = api.KanaCombatBookmarks
    if owner.settings then return end
    owner.settings = api.ZO_SavedVars:NewAccountWide('KanaCombatBookmarksSV', 1, nil, Settings.defaults)
    local menu = api.LibAddonMenu2
    if not menu then return end
    local panelId = 'KanaCombatBookmarks_Panel'
    menu:RegisterAddonPanel(panelId, {
        type = 'panel',
        name = 'Kana CombatMetrics: bookmarks',
        displayName = '|cFF0000Kana|r |c4488FFCombatMetrics|r: |cFFFFFFbookmarks|r',
        author = 'Kana',
        version = '1.0.0',
        registerForRefresh = true,
        registerForDefaults = true,
    })
    local options = {}
    for _, item in ipairs({
        {'bookmarks', 'Добавлять закладки в бою'},
        {'sound', 'Звук при добавлении закладки'},
        {'alerts', 'Уведомления о закладках'},
        {'log', 'Показывать закладки в подробном логе'},
        {'loadedLogRepair', 'Исправлять отображение участников старых логов'},
    }) do
        local key, label = item[1], item[2]
        options[#options + 1] = {
            type = 'checkbox',
            name = label,
            getFunc = function() return owner.settings[key] ~= false end,
            setFunc = function(value) owner.settings[key] = value end,
            default = true,
            requiresReload = true,
            width = 'full',
        }
    end
    menu:RegisterOptionControls(panelId, options)
end
