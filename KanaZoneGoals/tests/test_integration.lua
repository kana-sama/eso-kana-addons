dofile('Core.lua')
dofile('Providers.lua')
local K=KanaZoneGoals
K.saved={categories={},custom={},ignored={}}
K.mapGoals={{'a_base',872,1,'meetings',false},{'b_base',872,2,'meetings',false},
    {'conflict_base',900,1,'special',false}}
K.publicDungeons={{3,100,30}}
K.dailyGoals={{200,101}}
K.extraAchievements={{3,102,'styles'}}
K.collectibleGoals={{3,700},{19,701}}
LibMapData={textureNamesLookup={['one/a_base_0']={1,3},['two/b_base_0']={2},
    ['x/conflict_base_0']={1,2}}}
local visitedMaps={}
GetMapInfoById=function(id)
    assert(type(id)=='number','GetMapInfoById requires one numeric map ID, not the texture lookup list')
    visitedMaps[id]=true
    return '',0,0,id==3 and 1 or id
end
GetZoneId=function(id)return ({[1]=3,[2]=19})[id] end
GetZoneStoryZoneIdForZoneId=function(id)return id==30 and 3 or id end
GetFastTravelNodePOIIndicies=function()return 1,1 end
LibSets={IsDungeonSet=function(id)return id==402 end,IsMonsterSet=function(id)return id==403 end,IsTrialSet=function(id)return id==404 end,IsPublicDungeonZoneId=function()return false end,AreSetsLoaded=function()return true end,
    GetSetIdsByDropZone=function(id)assert(id==3);return {[400]=true,[401]=true,[402]=true,[403]=true,[404]=true} end}
GetItemSetCollectionCategoryId=function(id)return id end
LibSets.GetItemSetCollectionZoneIds=function()return {3} end
GetNumItemSetCollectionPieces=function(id)return id~=401 and 3 or 0 end
GetNumItemSetCollectionSlotsUnlocked=function()return 2 end
GetItemSetName=function(id)return 'Set '..id end
GetAchievementInfo=function(id)return 'Achievement '..id,'Description',10,'icon' end
GetAchievementNumCriteria=function()return 2 end
GetAchievementCriterion=function(_,i)return 'Criterion '..i,i==1 and 1 or 0,1 end
IsAchievementComplete=function()return false end
GetAchievementRewardCollectible=function(id)return id==102,id==102 and 700 or 0 end
GetCollectibleName=function(id)return 'Collectible '..id end
GetCollectibleDescription=function()return 'Unlock' end
IsCollectibleUnlocked=function()return true end
RFT={zoneToAchievement={[3]={471},[30]={471},[19]={472}}}
QUEST_REPEAT_NOT_REPEATABLE=0
QUEST_TYPE_DUNGEON=5
LibQuestData={quest_data={[10]={},[11]={},[12]={},[13]={},[14]={}},
    get_quest_type=function()return 0 end,
    get_quest_repeat=function(_,id)return id==13 and 1 or 0 end,
    is_prologue_quest=function(_,id)return id==14 end}
GetQuestZoneId=function()return 3 end
GetQuestName=function(id)return 'Quest '..id end
HasQuest=function()return false end
HasCompletedQuest=function(id)return id==11 end
ZONE_COMPLETION_TYPE_PRIORITY_QUESTS=1
GetNumZoneActivitiesForZoneCompletionType=function()return 1 end
GetZoneActivityIdForZoneCompletionType=function()return 10 end
GetNextAntiquityId=function(id)if not id then return 50 elseif id==50 then return 51 end end
GetAntiquityZoneId=function()return 3 end
DoesAntiquityPassVisibilityRequirements=function(id)return id==50 end
GetAntiquityName=function()return 'Antiquity' end
GetAntiquityQuality=function()return 4 end
REWARD_ENTRY_TYPE_ITEM=1
GetAntiquitySetId=function(id)return id==50 and 10 or 0 end
GetAntiquitySetRewardId=function()return 11 end
GetAntiquityRewardId=function()return 0 end
GetItemLinkItemType=function()return 100 end
GetItemLinkName=function()return 'Reward' end
ITEMTYPE_TREASURE=10;ITEMTYPE_SIEGE=11;ITEMTYPE_FURNISHING=12
GetRewardType=function()return REWARD_ENTRY_TYPE_ITEM end
GetItemRewardItemId=function()return 12 end
GetItemRewardItemLink=function(id)return '|H1:item:'..id..':30:1|h' end
GetItemLinkQuality=function()return 5 end
GetAntiquitySetQuality=function()return 4 end
GetItemLinkSetInfo=function()return true,'Mythic',0,0,0,999 end
LibSets.IsMythicSet=function(id)return id==999 end
GetNumAntiquitiesRecovered=function()return 5 end
GetNumAntiquityLoreEntries=function()return 3 end
GetNumAntiquityLoreEntriesAcquired=function()return 1 end
K.BuildCatalog()
assert(visitedMaps[1] and visitedMaps[2] and visitedMaps[3],
    'all map IDs in each texture lookup list must be resolved')
assert(not K.catalog[3][900] and not K.catalog[19][900],'ambiguous map cannot select arbitrary zone')
assert(K.catalog[3][872].criteria[1] and not K.catalog[3][872].criteria[2])
assert(K.catalog[3][100].whole and K.catalog[3][101].category=='dailies')
local goals,notices=K.CollectGoals(3)
local groups,done,total=K.GroupGoals(goals,K.saved.categories)
local byKey={}
for _,group in ipairs(groups) do for _,g in ipairs(group.goals) do byKey[g.key]=g end end
assert(#notices==0)
assert(byKey['set:400'].current==2 and not byKey['set:401'],'set-ID dictionary and craftable exclusion')
assert(byKey['achievement:872'].total==1 and byKey['achievement:872'].current==1)
assert(byKey['fish:471:1'] and byKey['fish:471:2'] and not byKey['fish:472:1'],'fish zones/dedup')
assert(byKey['antiquity:50'].current==1 and not byKey['antiquity:51'],'visibility and first recovery')
assert(not byKey['codex:50'] and byKey['antiquity:50'].total==1 and not byKey['antiquity:50'].criteria)
assert(not byKey['quest:10'] and byKey['quest:11'] and byKey['quest:12'] and not byKey['quest:13'] and not byKey['quest:14'])
assert(byKey['collectible:700'].complete and not byKey['collectible:701'],'reward API and region')
assert(not byKey['set:402'] and not byKey['set:403'] and not byKey['set:404'],'instance sets excluded by default')
K.saved.excludeDungeonSets=false
local all=K.CollectGoals(3)
local instanceCount=0;for _,g in ipairs(all) do if g.setId and g.setId>=402 then instanceCount=instanceCount+1 end end
assert(instanceCount==3,'setting must restore dungeon/monster/trial sets')
K.saved.excludeDungeonSets=true
local count=0;for _ in pairs(byKey) do count=count+1 end
assert(count==total,'reward from achievement and fragments must deduplicate')
K.saved.categories.collectibles=false
local _,_,without=K.GroupGoals(K.CollectGoals(3),K.saved.categories)
assert(without==total-1,'disabled category excluded from total')
LibQuestData=nil;RFT=nil;LibSets.AreSetsLoaded=function()return false end
local _,missing=K.CollectGoals(3)
assert(#missing==3,'missing optional dependencies must be explained')
print('PASS integration: catalogs/sets/fishing/quests/antiquities/rewards/dependencies/disabled totals')
