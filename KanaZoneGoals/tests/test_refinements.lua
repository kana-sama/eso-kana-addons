dofile('Core.lua')
dofile('Providers.lua')
dofile('UI.lua')
local K=KanaZoneGoals
K.saved={categories={},custom={},hideCompleted=false}
assert(K.CleanName('Стоунфолз^M')=='Стоунфолз')
GetZoneNameById=function()return 'Стоунфолз^M' end
local meetings=K.TooltipEntries({id='meetings',goals={{name='Я люблю М’Айка',current=1,total=1,complete=true,
    criteria={{name='Стоунфолз^M',current=1,total=1}}}}},41)
assert(#meetings==1 and meetings[1].name=='Я люблю М’Айка' and meetings[1].complete)
GetNumItemSetCollectionPieces=function()error('set tooltip must not enumerate items')end
assert(#K.TooltipEntries({id='sets',goals={{name='Set',setId=1,current=2,total=22}}})==1)
-- Load the installed RFT's actual ordering data using harmless stand-in column objects.
ITEM_FUNCTIONAL_QUALITY_MAGIC=2;ITEM_FUNCTIONAL_QUALITY_ARCANE=3;ITEM_FUNCTIONAL_QUALITY_ARTIFACT=4
RFT={window={column1={},column2={},column3={},column4={}}}
dofile('/Users/kana/Documents/Elder Scrolls Online/live/AddOns/RareFishTracker/RareFishOrders100017.lua')
zo_iconFormatInheritColor=function()return '' end
SI_RARE_FISH_TRACKER_TYPE_OCEAN=1;SI_RARE_FISH_TRACKER_TYPE_LAKE=2
SI_RARE_FISH_TRACKER_TYPE_RIVER=3;SI_RARE_FISH_TRACKER_TYPE_FOUL=4
GetString=function(id)return ({'Солёная вода','Озёрная вода','Речная вода','Грязная вода'})[id] end
RFT.MakeOrders()
dofile('/Users/kana/Documents/Elder Scrolls Online/live/AddOns/RareFishTracker/AchievementData100017.lua')
GetAchievementNumCriteria=function()return 12 end
GetAchievementCriterion=function(_,i)return 'Fish '..i..' (Water)',1,1 end
GetItemLinkName=function(link)return 'Fish item '..link:match('item:(%d+)')..'^N' end
GetItemLinkQuality=function()return 2 end
local fish=K.FishingGoals(477,41)
local groups,done,total=K.GroupGoals(fish,{})
assert(done==12 and total==12 and groups[1].completed==12 and groups[1].total==12)
local lines=K.TooltipEntries(groups[1],41)
local waters,fishCount={},0
for _,line in ipairs(lines) do
    if line.heading then waters[line.name]=true else
        fishCount=fishCount+1
        assert(not line.name:find('Water') and not line.name:find('^',1,true) and not line.name:find('1 / 1',1,true))
        assert(line.quality==2 or line.quality==3,'fish rarity must come from RFT')
    end
end
local waterCount=0;for _ in pairs(waters) do waterCount=waterCount+1 end
assert(fishCount==12 and waterCount==4,'Stonefalls: 12 fish grouped under four water types')
local icons={}
for _,category in ipairs(K.categories) do
    local icon=assert(K.categoryIcons[category.id]);assert(not icons[icon],'repeated category icon');icons[icon]=true
end
assert(not K.categoryById.codex and K.categoryById.antiquities)
print('PASS refinements: grammar/local redundancy/singletons/sets/real RFT Stonefalls fish/water/rarity/unique icons/combined antiquities')

local cold=K.FishingGoals(490,347)
for _,g in ipairs(cold) do assert(g.water=='Грязная вода','RFT zone-specific water mapping ignored') end

K.saved.excludeDungeonSets=true
LibSets={IsDungeonSet=function(id)return id==4 end,IsMonsterSet=function(id)return id==5 end,
    IsTrialSet=function(id)return id==6 end,GetItemSetCollectionZoneIds=function(category)
        if category==1 then return {41} elseif category==2 then return {181} end
    end}
GetItemSetCollectionCategoryId=function(id)return id end
GetZoneStoryZoneIdForZoneId=function(id)return id end
assert(K.IncludeSet(1,41) and not K.IncludeSet(2,41) and not K.IncludeSet(3,41))
assert(not K.IncludeSet(4,41) and not K.IncludeSet(5,41) and not K.IncludeSet(6,41))
K.saved.excludeDungeonSets=false
assert(K.IncludeSet(4,41) and not K.IncludeSet(2,41) and not K.IncludeSet(3,41))
GetItemLinkQuality=function()return 4 end
assert(K.TextQuality('|H1:item:1:30:1|hRelic|h')==4)
assert(K.CleanName('|cAA22FFRelic^N|r')=='|cAA22FFRelic|r')
print('PASS collection-region filter/instance toggle/item-link rarity/embedded item colors')

local rows=K.FishingTooltipRows(lines)
assert(#rows==9 and rows[5].spacer,'four equal water groups need two four-row blocks and a gap')
assert(rows[1].left.heading and rows[1].right.heading and rows[6].left.heading and rows[6].right.heading)
local count=0
for _,row in ipairs(rows) do
    for _,side in ipairs({'left','right'}) do
        if row[side] and not row[side].heading then count=count+1 end
    end
end
assert(count==12,'two-column layout lost fish')
local uneven=K.FishingTooltipRows({{heading=true,name='A'},{name='a'},
    {heading=true,name='B'},{name='b'},{name='c'},{heading=true,name='C'},{name='d'}})
assert(uneven[3].left==nil and uneven[3].right.name=='c' and uneven[4].spacer)
local width
K.SetupTooltipCell({SetHidden=function()end,SetResizeToFitDescendents=function()end,
    SetDimensions=function(_,w)width=w end},nil,320)
assert(width==320,'empty left cell must preserve the right column position')
zo_strformat=function(format,name)
    if format=='<<C:1>>' and name=='пескарка' then return 'Пескарка' end
    return name
end
local caps=K.TooltipEntries({id='fishing',goals={{name='пескарка',water='Вода',current=1,total=1}}})
assert(caps[2].name=='Пескарка','fish must use ESO localized initial capitalization')
print('PASS fishing layout: two columns/group gaps/uneven groups/no lost fish/capitalization')

local ancient=K.TooltipEntries({id='antiquities',goals={{name='Ожерелье',current=0,total=1,
    antiquityQuality=5,complete=false,rewardName='Мифик',leadSource='Пещера — босс'}}})
assert(#ancient==1 and ancient[1].name=='Ожерелье' and ancient[1].rewardName=='Мифик' and ancient[1].leadSource=='Пещера — босс' and ancient[1].antiquityQuality==5)
assert(ancient[1].wrapped and not ancient[1].complete)
print('PASS mythic tooltip: one entry/mythic and source/no counters/rarity')
local quests={};for i=1,7 do quests[i]={name='Quest '..i} end
local questRows=K.QuestTooltipRows(quests)
assert(#questRows==4 and questRows[1].left==quests[1] and questRows[1].right==quests[5])
assert(questRows[4].left==quests[4] and questRows[4].right==nil)
local alpha,color
local label={ClearAnchors=function()end,SetAnchor=function()end,SetText=function()end,SetWidth=function()end,SetHeight=function()end,SetWrapMode=function()end,
    SetAlpha=function(_,a)alpha=a end,SetColor=function(_,r,g,b,a)color={r,g,b};alpha=a or 1 end}
ZO_SELECTED_TEXT={UnpackRGB=function()return 1,1,1 end}
GetItemQualityColor=function()return {UnpackRGB=function()return 0,1,0 end}end
local row={SetHidden=function()end,SetResizeToFitDescendents=function()end,SetDimensions=function()end,
    GetNamedChild=function(_,name)if name=='Label' then return label else return {SetResizeToFitFile=function()end,SetDimensions=function()end,ClearAnchors=function()end,SetAnchor=function()end,SetAlpha=function()end,SetTexture=function()end,SetColor=function()end} end end}
K.SetupTooltipCell(row,{name='Fish',quality=2,complete=false},320)
assert(alpha==0.55 and color[2]==1,'incomplete rarity text must be dimmed without changing hue')
K.SetupTooltipCell(row,{name='Fish',quality=2,complete=true},320)
assert(alpha==1,'reused completed row must reset dimming')
K.SetupTooltipCell(row,{name='Water',heading=true},320)
assert(alpha==1,'group headings must remain bright')
print('PASS quest columns/odd list/dimming/rarity/pooled row reset/headings')

GetAntiquityQualityColor=function()return {UnpackRGB=function()return 1,0.8,0 end}end
K.SetupTooltipCell(row,{name='Necklace',antiquityQuality=5,complete=false},320)
assert(alpha==0.55 and color[1]==1 and color[2]==0.8,'antiquity color must not reset dimming')
K.SetupTooltipCell(row,{name='Meeting',complete=false},320)
assert(alpha==0.55,'plain checklist row must dim too')
print('PASS dimming after color assignment: antiquities/items/plain text/completed/headings')
