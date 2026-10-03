local ADDON_NAME = "KanaNoRepeat"

local function HideReplayButton(interaction)
    if interaction and interaction.replayButton then
        interaction.replayButton:SetHidden(true)
    end
end

-- ESO recreates/shows this button whenever replay state changes.
ZO_PostHook(ZO_Interaction, "RefreshReplay", function(self)
    HideReplayButton(self)
end)

local function OnInteractionEvent()
    HideReplayButton(INTERACTION)
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= ADDON_NAME then return end

    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_CHATTER_BEGIN, OnInteractionEvent)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_CONVERSATION_UPDATED, OnInteractionEvent)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_INTERACT_VO_PLAYING_STATE_UPDATED, OnInteractionEvent)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_QUEST_OFFERED, OnInteractionEvent)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_QUEST_COMPLETE_DIALOG, OnInteractionEvent)

    OnInteractionEvent()
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
