local K = KanaArchiveAssist
local S = {}
K.ProfileSettings = S

function S.New(api, window)
    local panelId = 'KanaArchiveAssistSettings'
    local panel = api.LibAddonMenu2:RegisterAddonPanel(panelId, {
        type = 'panel',
        name = 'Kana Archive Assist',
        displayName = '|cFF0000Kana|r |cFFFFFFArchive Assist|r',
        author = 'Kana',
        version = '1.0.0',
    })
    api.LibAddonMenu2:RegisterOptionControls(panelId, {
        {type = 'button', name = 'Открыть профили и историю', width = 'full',
            func = function() window:Open() end},
    })
    return panel
end
