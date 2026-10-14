local K = KanaArchiveAchievements
local ADDON_NAME = 'KanaArchiveAchievements'

local function OnAddonLoaded(_, name)
    if name ~= ADDON_NAME or K.controller then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    local model = K.Model.New(_G, ArchiveHelper)
    local view = K.View.New(_G)
    K.controller = K.Controller.Install(_G, model, view)
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)
