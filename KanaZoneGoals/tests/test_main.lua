dofile('Core.lua')
local K=KanaZoneGoals
local callbacks,updates={},{}
local names={'EVENT_ADD_ON_LOADED','EVENT_PLAYER_ACTIVATED','EVENT_ACHIEVEMENT_UPDATED',
    'EVENT_ACHIEVEMENT_AWARDED','EVENT_ACHIEVEMENTS_UPDATED','EVENT_ITEM_SET_COLLECTION_UPDATED',
    'EVENT_ITEM_SET_COLLECTIONS_UPDATED','EVENT_ANTIQUITY_UPDATED','EVENT_COLLECTIBLE_UPDATED','EVENT_QUEST_REMOVED','EVENT_INVENTORY_SINGLE_SLOT_UPDATE','EVENT_INVENTORY_FULL_UPDATE'}
for i,name in ipairs(names) do _G[name]=i end
EVENT_MANAGER={RegisterForEvent=function(_,_,event,cb)callbacks[event]=cb end,
    UnregisterForEvent=function(_,_,event)callbacks[event]=nil end,
    RegisterForUpdate=function(_,name,_,cb)updates[name]=cb end,
    UnregisterForUpdate=function(_,name)updates[name]=nil end}
ZO_SavedVars={NewAccountWide=function(_,name,version,namespace,defaults,world)
    assert(name=='KanaZoneGoalsSavedVariables' and world=='EU');return defaults end}
GetWorldName=function()return 'EU' end
SLASH_COMMANDS={}
local built,attached,refreshed=0,0,0
K.RegisterSettings=function()end
K.OpenSettings=function()end
K.BuildCatalog=function()built=built+1 end
K.AttachMapPanel=function(guide)assert(guide==WORLD_MAP_ZONE_STORY_KEYBOARD);attached=attached+1 end
K.Refresh=function()refreshed=refreshed+1 end
K.ScheduleRefresh=K.Refresh
LibSets={AreSetsLoaded=function()return true end}
dofile('Main.lua')
callbacks[EVENT_ADD_ON_LOADED](nil,'OtherAddon')
assert(not K.saved)
callbacks[EVENT_ADD_ON_LOADED](nil,K.name)
assert(SLASH_COMMANDS['/kzg']==K.OpenSettings)
callbacks[EVENT_PLAYER_ACTIVATED]()
assert(not K.ready,'do not lock out retries if guide is unavailable')
WORLD_MAP_ZONE_STORY_KEYBOARD={list={}}
callbacks[EVENT_PLAYER_ACTIVATED]()
callbacks[EVENT_PLAYER_ACTIVATED]()
assert(K.ready and built==1 and attached==1 and refreshed==1,'activation must be idempotent')
assert(callbacks[EVENT_INVENTORY_SINGLE_SLOT_UPDATE]==K.ScheduleRefresh)
assert(callbacks[EVENT_INVENTORY_FULL_UPDATE]==K.ScheduleRefresh)
updates[K.name..'LibraryReady']()
assert(not updates[K.name..'LibraryReady'])
print('PASS lifecycle: addon filtering/account settings/delayed guide/idempotent activation/library readiness')
