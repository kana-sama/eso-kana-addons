local ADDON_NAME = "KanaAetherChat"
local EVENT_NAME = ADDON_NAME .. "_Scroll"

local function Initialize(_, addonName)
    if addonName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(EVENT_NAME, EVENT_ADD_ON_LOADED)

    local messenger = AetherChat.Messenger
    local buffer = messenger.window:GetNamedChild("Messages")
    if not buffer then return end
    local preserveView = false

    -- Native TextBuffer:AddMessage keeps the viewed lines anchored when scrolled
    -- up. Only suppress AetherChat's subsequent forced jump to the newest line.
    ZO_PreHook(buffer, "SetScrollPosition", function(_, line)
        return preserveView and line == 0
    end)
    ZO_PreHook(buffer, "Clear", function()
        -- Channel changes/search rebuilds intentionally start a new view.
        preserveView = false
    end)

    local function PreserveDuring(name)
        local original = messenger[name]
        if not original then return end
        messenger[name] = function(...)
            local previous = preserveView
            preserveView = buffer:GetScrollPosition() > 0
            original(...)
            preserveView = previous
        end
    end

    PreserveDuring("OnMessageReceived")
    PreserveDuring("OnFriendPlayerStatusChanged")
    PreserveDuring("OnGuildMemberPlayerStatusChanged")
end

EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_ADD_ON_LOADED, Initialize)
