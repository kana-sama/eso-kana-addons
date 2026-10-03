local K=KanaZoneGoals
local EM=EVENT_MANAGER
local function activate()
    if K.ready then return end
    K.mapPanel=WORLD_MAP_ZONE_STORY_KEYBOARD
    if not K.mapPanel or not K.mapPanel.list then return end
    K.BuildCatalog()
    K.AttachMapPanel(K.mapPanel)
    K.ready=true
    K.Refresh()
end
local function loaded(_,name)
    if name~=K.name then return end
    EM:UnregisterForEvent(K.name,EVENT_ADD_ON_LOADED)
    K.saved=ZO_SavedVars:NewAccountWide('KanaZoneGoalsSavedVariables',1,nil,{
        categories={},expanded={},custom={},ignored={},hideCompleted=false,
    },GetWorldName())
    K.RegisterSettings()
    SLASH_COMMANDS['/kzg']=K.OpenSettings
    EM:RegisterForEvent(K.name,EVENT_PLAYER_ACTIVATED,activate)
    for _,event in ipairs({EVENT_ACHIEVEMENT_UPDATED,EVENT_ACHIEVEMENT_AWARDED,EVENT_ACHIEVEMENTS_UPDATED,
        EVENT_ITEM_SET_COLLECTION_UPDATED,EVENT_ITEM_SET_COLLECTIONS_UPDATED,EVENT_ANTIQUITY_UPDATED,
        EVENT_COLLECTIBLE_UPDATED,EVENT_QUEST_REMOVED,
        EVENT_INVENTORY_SINGLE_SLOT_UPDATE,EVENT_INVENTORY_FULL_UPDATE}) do
        EM:RegisterForEvent(K.name,event,K.ScheduleRefresh)
    end
    -- LibSets finishes asynchronously; refresh while its first data load is pending.
    local attempts=0
    EM:RegisterForUpdate(K.name..'LibraryReady',1000,function()
        attempts=attempts+1
        if K.ready and LibSets.AreSetsLoaded() then K.ScheduleRefresh();EM:UnregisterForUpdate(K.name..'LibraryReady')
        elseif attempts>=30 then EM:UnregisterForUpdate(K.name..'LibraryReady') end
    end)
end
EM:RegisterForEvent(K.name,EVENT_ADD_ON_LOADED,loaded)
