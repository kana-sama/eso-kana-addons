dofile('Core.lua')
dofile('Providers.lua')
local K=KanaZoneGoals
K.mapGoals={};K.publicDungeons={};K.dailyGoals={};K.extraAchievements={}
LibMapData={textureNamesLookup={}}
LibQuestData={}
dofile('/Users/kana/Documents/Elder Scrolls Online/live/AddOns/LibQuestData/data/LibQuestData_QuestData.lua')
local realDungeon=assert(LibQuestData.quest_data[7237])
QUEST_TYPE_DUNGEON=5;QUEST_REPEAT_NOT_REPEATABLE=0
assert(realDungeon[1]==QUEST_TYPE_DUNGEON,'installed 7237 must be a dungeon quest')
LibQuestData.quest_data={[7237]=realDungeon,[10]={[1]=0,[2]=0},[11]={[1]=5,[2]=0}}
function LibQuestData:get_quest_repeat(id)return self.quest_data[id][2]end
function LibQuestData:get_quest_type(id)return self.quest_data[id][1]end
GetQuestZoneId=function(id)return id==7237 and 1497 or (id==11 and 999 or 816)end
GetZoneStoryZoneIdForZoneId=function(id)return id==1497 and 816 or (id==999 and 41 or id)end
GetQuestName=function(id)return 'Quest '..id end
GetNextAntiquityId=function()return nil end
K.BuildCatalog()
local found={}
for _,ids in pairs(K.questCatalog) do for _,id in ipairs(ids) do found[id]=true end end
assert(not found[7237],'Lep Seclusa quest must not become a side quest of Hews Bane')
assert(not found[11],'filter must exclude dungeon quests in other regions too')
assert(found[10] and K.questCatalog[816][1]==10,'ordinary regional side quest must remain')
print('PASS dungeon quests: actual 7237/parent-zone normalization/other regions/ordinary side quests')
