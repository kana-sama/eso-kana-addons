dofile('Core.lua')
dofile('Providers.lua')
dofile('UI.lua')
local K=KanaZoneGoals
K.saved={categories={},hideCompleted=false}
REWARD_ENTRY_TYPE_ITEM=1;REWARD_ENTRY_TYPE_COLLECTIBLE=2;REWARD_ENTRY_TYPE_REWARD_LIST=3
ITEMTYPE_TREASURE=10;ITEMTYPE_SIEGE=11;ITEMTYPE_FURNISHING=12
COLLECTIBLE_CATEGORY_TYPE_FURNITURE=20;COLLECTIBLE_CATEGORY_TYPE_HOUSE_BANK=21
local types={[1]=10,[2]=11,[3]=12,[4]=30,[5]=31,[6]=20,[7]=21,[8]=40,[9]=41,[10]=42,[11]=43,[12]=44}
GetAntiquitySetId=function(id)return id>=6 and id or 0 end
GetAntiquityRewardId=function(id)return id end
GetAntiquitySetRewardId=function(id)return id end
GetRewardType=function(id)if id==100 then return 3 end;return id<=5 and 1 or 2 end
GetItemRewardItemId=function(id)return id end
GetItemRewardItemLink=function(id)return '|H1:item:'..id..':30:1|h' end
GetItemLinkQuality=function()return 5 end
GetAntiquitySetQuality=function()return 4 end
GetCollectibleRewardCollectibleId=function(id)return id end
GetCollectibleCategoryType=function(id)return types[id] end
GetCollectibleName=function(id)return 'Collectible '..id end
GetItemLinkItemType=function(link)return types[tonumber(link:match('item:(%d+)'))] end
GetItemLinkName=function(link)return 'Item '..link:match('item:(%d+)') end
local recovered=0
GetNumAntiquitiesRecovered=function()return recovered end
GetAntiquityName=function()return 'Часть^F' end
GetAntiquityQuality=function()return 5 end
GetAntiquityZoneId=function()return 41 end
GetZoneNameById=function(id)return id==41 and 'Стоунфолз^M' or 'Другая область^F' end
GetNumAntiquityLoreEntries=function()error('codex must not affect completion')end
ILeadList={Locations={[4]={'Босс пещеры','Босс','Пещера'}},FindScryDifferentZones={[4]=19}}
for _,id in ipairs({1,2,3,6,7}) do assert(not K.AntiquityGoal(id),'excluded treasure/siege/furniture included: '..id) end
for _,id in ipairs({4,5,8,9,10,11,12}) do assert(K.AntiquityGoal(id),'item or collectible reward missing: '..id) end
local g=K.AntiquityGoal(4)
assert(g.current==0 and g.total==1 and g.rewardName=='Item 4')
assert(g.leadSource=='Другая область — Босс пещеры')
local groups=K.GroupGoals({g},{})
local lines=K.TooltipEntries(groups[1],41)
assert(#lines==1 and lines[1].wrapped and lines[1].name=='Часть' and lines[1].rewardName=='Item 4' and lines[1].leadSource=='Другая область — Босс пещеры')
assert(not lines[1].name:find('0/1',1,true))
recovered=5
g=K.AntiquityGoal(4)
assert(g.current==1 and g.total==1 and not g.leadSource)
groups=K.GroupGoals({g},{})
lines=K.TooltipEntries(groups[1],41)
assert(#lines==1 and lines[1].name=='Часть' and lines[1].complete and not lines[1].wrapped)
GetRewardListIdFromReward=function()return 1 end
GetNumRewardListEntries=function()return 2 end
GetRewardListEntryInfo=function(_,i)return i==1 and 1 or 8 end
assert(K.IncludedAntiquityReward(100)=='Collectible 8','bundle containing sellable item must retain allowed collectible')
GetRewardListEntryInfo=function()return 100 end
assert(not K.IncludedAntiquityReward(100),'reward cycle must terminate')
dofile('/Users/kana/Documents/Elder Scrolls Online/live/AddOns/LeadList/locale/locationsdata_en.lua')
dofile('/Users/kana/Documents/Elder Scrolls Online/live/AddOns/LeadList/locale/locationsdata_ru.lua')
assert(K.AntiquityLeadSource(130):find('Вороний Лес',1,true))
print('PASS antiquity rewards: exclusion types/items/collectibles/multipart/first excavation/no codex/sources/reward bundles')
