local ADDON_NAME = "KanaAetherChat"
local EVENT_NAME = ADDON_NAME .. "_NativeChat"

local function Initialize(_, addonName)
    if addonName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(EVENT_NAME, EVENT_ADD_ON_LOADED)
    local messenger = AetherChat.Messenger

    local function RestoreClosedChatEntry()
        -- AetherChat's initialization and layout changes dock the input even
        -- while closed. ESO's primary message container is anchored to that
        -- input, so moving it also moves the stock message area's bottom edge.
        if not messenger.isOpen then
            messenger.UndockNativeChatEntry()
        end
    end

    ZO_PostHook(messenger, "DockNativeChatEntry", RestoreClosedChatEntry)
    RestoreClosedChatEntry()
end

EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_ADD_ON_LOADED, Initialize)
