local ADDON_NAME = "KanaAetherChat"
local EVENT_NAME = ADDON_NAME .. "_LastChannel"

local function Initialize(_, addonName)
    if addonName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(EVENT_NAME, EVENT_ADD_ON_LOADED)
    local messenger = AetherChat.Messenger
    local saved = ZO_SavedVars:NewCharacterIdSettings("KanaAetherChatSavedVariables", 1, nil, {})
    local restored = false

    local function Remember()
        if not restored then return end
        saved.lastChannel = messenger.GetActiveChannel()
        local slot = saved.lastChannel and saved.lastChannel:match("^guild(%d+)$")
        saved.guildId = slot and GetGuildId(tonumber(slot)) or nil
    end
    ZO_PostHook(messenger, "SelectChannel", Remember)

    -- Wait until the player's guilds and AetherChat's saved custom/whisper tabs
    -- are available. Startup selections must not overwrite the saved channel.
    EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_PLAYER_ACTIVATED, function()
        EVENT_MANAGER:UnregisterForEvent(EVENT_NAME, EVENT_PLAYER_ACTIVATED)
        local wanted = saved.lastChannel
        if saved.guildId then
            wanted = nil
            for slot = 1, GetNumGuilds() do
                if GetGuildId(slot) == saved.guildId then
                    wanted = "guild" .. slot
                    break
                end
            end
        end
        if wanted then
            for _, item in ipairs(messenger.BuildChannelItems()) do
                if item.id == wanted and not item.isFolder then
                    -- Restore the selected tab, without opening the window or
                    -- focusing input. The normal hotkey completes input setup.
                    messenger.SelectChannel(wanted, false, false)
                    break
                end
            end
        end
        restored = true
        Remember()
    end)
end

EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_ADD_ON_LOADED, Initialize)
