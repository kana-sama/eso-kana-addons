dofile('Core.lua')
dofile('Providers.lua')
dofile('UI.lua')
local K=KanaZoneGoals
K.saved={categories={},hideCompleted=false}
local completed,active={},{}
HasCompletedQuest=function(id)return completed[id] or false end
HasQuest=function(id)return active[id] or false end
LibQuestData={completed_quests=completed,known_removed_quest={[3442]=true}}
LibQuestData_Internal={}
dofile('/Users/kana/Documents/Elder Scrolls Online/live/AddOns/LibQuestData/LibQuestData_Filters.lua')
assert(not K.QuestUnavailable(4026),'Zeren must stay available before the mutually exclusive choice')
completed[4028]=true
assert(K.QuestUnavailable(4026),'real LibQuestData choice: Breaking the Tide blocks Zeren in Peril')
assert(not K.QuestUnavailable(4028),'completed quests retain their checkmark')
active[4026]=true
assert(not K.QuestUnavailable(4026),'active journal quest must override stale availability metadata')
active[4026]=nil
assert(K.QuestUnavailable(3442),'known removed quests must be unavailable')
assert(not LibQuestData_Internal:prerequisites_completed(143))
assert(not K.QuestUnavailable(143),'missing prerequisite alone is not irreversible unavailability')
local goals={}
for i=1,6 do goals[i]={key='quest:'..i,category='quests',name='Quest '..i,current=i<3 and 1 or 0,total=1,unavailable=i==6} end
local groups,done,total=K.GroupGoals(goals,{})
assert(done==2 and total==5 and groups[1].total==5 and #groups[1].goals==6)
local entries=K.TooltipEntries(groups[1])
local unavailable
for _,entry in ipairs(entries) do if entry.unavailable then unavailable=entry end end
assert(unavailable and not unavailable.complete,'unavailable row must remain in the checklist')
local red,alpha,texture,iconAlpha,iconWidth,textX
ZO_SELECTED_TEXT={UnpackRGB=function()return 1,1,1 end}
local label={ClearAnchors=function()end,SetAnchor=function(_,_,_,_,x)textX=x end,SetText=function()end,SetWidth=function()end,SetHeight=function()end,SetWrapMode=function()end,
    SetColor=function(_,r,g,b)red=r==1 and g==0 and b==0 end,SetAlpha=function(_,a)alpha=a end}
local checkbox={SetResizeToFitFile=function()end,SetDimensions=function(_,w,h)iconWidth=w;assert(w==h)end,ClearAnchors=function()end,SetAnchor=function()end,SetTexture=function(_,v)texture=v end,SetColor=function()end,SetAlpha=function(_,v)iconAlpha=v end}
local row={SetHidden=function()end,SetResizeToFitDescendents=function()end,SetDimensions=function()end,
    GetNamedChild=function(_,name)return name=='Label' and label or checkbox end}
K.SetupTooltipCell(row,unavailable,320)
assert(red and alpha==1 and iconAlpha==1 and texture:find('decline_up.dds',1,true))
K.SetupTooltipCell(row,{name='Completed',complete=true},320)
assert(not red and iconAlpha==1 and texture:find('check.dds',1,true),'pooled rows must restore normal checkmark/color')
local onlyBlocked=K.GroupGoals({goals[6]},{})
assert(#onlyBlocked==1 and onlyBlocked[1].total==0 and #onlyBlocked[1].goals==1)
print('PASS unavailable quests: real Zeren choice/removed/active/completed/prerequisites/2 of 5 with six rows/red prohibition/pooled reset')

assert(iconWidth==20 and textX==28,'fixed status icon size and text column must survive recycling')
