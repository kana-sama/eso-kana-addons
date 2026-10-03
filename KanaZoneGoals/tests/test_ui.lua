dofile('Core.lua')
local K=KanaZoneGoals
K.saved={categories={},expanded={},custom={},hideCompleted=false,ignored={}}
ZO_PostHook=function(object,method,hook)
    assert(object==WORLD_MAP_ZONE_STORY_KEYBOARD and (method=='RefreshInfo' or method=='OnHiding'),'must hook the map panel, not the Zone Guide')
    local old=object[method];object[method]=function(self,...)old(self,...);hook(self,...) end
end
ZO_ScrollList_AddDataType=function(list,id,template,height,setup)list.types[id]={template=template,setup=setup} end
ZO_ScrollList_GetDataList=function(list)return list.entries end
ZO_ScrollList_CreateDataEntry=function(id,data)return {typeId=id,data=data} end
ZO_ScrollList_Commit=function(list)list.commits=list.commits+1 end
local list={entries={},types={},commits=0}
ZO_WORLD_MAP_ZONE_STORY_ROW_HEIGHT=40
local panel={list=list,zone=3,showing=true}
function panel:OnHiding()end
WORLD_MAP_ZONE_STORY_KEYBOARD=panel
ZONE_STORIES_KEYBOARD=setmetatable({},{__index=function()error('Zone Guide must not be touched')end})
function panel:GetCurrentZoneStoryZoneId()return self.zone end
function panel:IsShowing()return self.showing end
function panel:RefreshInfo()
    if self:IsShowing() then self.list.entries={{typeId=1,data={native=true}}};ZO_ScrollList_Commit(self.list) end
end
K.CollectGoals=function(zone)return zone==3 and {{key='fish',category='fishing',name='Fish',current=0,total=2}} or {},{} end
dofile('UI.lua')
assert(type(K.AttachMapPanel)=='function','missing exploration panel on the map')
K.AttachMapPanel(panel);K.AttachMapPanel(panel)
panel:RefreshInfo()
assert(list.entries[1].data.native,'native exploration rows lost')
assert(#list.entries==2,'expected native row and category without a separating header; no duplicate hooks')
K.saved.expanded.fishing=true;panel:RefreshInfo()
assert(#list.entries==2 and list.entries[2].data.group,'category must stay a single native bar; goals belong in hover tooltip')
K.saved.categories.fishing=false;panel:RefreshInfo()
assert(#list.entries==2 and list.entries[2].data.empty,'disabled category must disappear')
K.saved.categories.fishing=true;panel.zone=19;panel:RefreshInfo()
assert(list.entries[2].data.empty,'previous zone goals leaked')
local commits=list.commits
panel.showing=false;panel:RefreshInfo()
assert(list.commits==commits,'hidden panel must not be rebuilt')
print('PASS map UI: correct panel/native rows/single hook/expand/filter/zone switch/hidden panel')

local texture,range,value,text,color
local label={SetText=function(_,v)text=v end,SetColor=function(_,...)color={...}end}
local row={icon={SetTexture=function(_,v)texture=v end},
    progressBar={SetMinMax=function(_,a,b)range={a,b}end,SetValue=function(_,v)value=v end},
    progressBarProgressLabel=label}
ZO_NORMAL_TEXT={UnpackRGB=function()return 0.5,0.5,0.5 end}
ZO_SELECTED_TEXT={UnpackRGB=function()return 1,1,1 end}
K.SetupRow(row,{group={id='fishing',completed=2,total=7}})
assert(texture:find('achievements_indexicon_fishing_up.dds',1,true) and range[2]==7 and value==2 and text=='2/7')
K.SetupRow(row,{group={id='fishing',completed=7,total=7}})
assert(color[1]==0.5,'completed bar must use the native completed color')
local items=K.TooltipEntries({goals={{name='Goal',current=1,total=2,criteria={
    {name='Done',current=1,total=1},{name='Remaining',current=0,total=1}}}}})
assert(#items==3 and items[2].complete and not items[3].complete,'hover must list completed and incomplete subgoals')
local many={goals={}}
for i=1,100 do many.goals[i]={name='Goal '..i,current=0,total=1} end
assert(#K.TooltipEntries(many)==100,'large tooltip must not truncate the goal list')
print('PASS native design: icon/bar/counter/completed color/hover subgoals/untruncated list')

local function texture()
    return {height=724,mouseEnabled=true,IsMouseEnabled=function(self)return self.mouseEnabled end,SetMouseEnabled=function(self,v)self.mouseEnabled=v end,GetHeight=function(self)return self.height end,GetTop=function()return 100 end,
        SetHeight=function(self,height)self.height=height end}
end
local left,right=texture(),texture()
GuiRoot={GetBottom=function()return 1080 end}
local background={GetNamedChild=function(_,name)return name=='Left' and left or right end}
K.ExtendMapBackground(background)
assert(not left.mouseEnabled and not right.mouseEnabled)
assert(left.height==1140 and right.height==1140,'both background textures must reach below the screen')
K.ExtendMapBackground(background)
K.RestoreMapBackground()
assert(left.mouseEnabled and right.mouseEnabled)
assert(left.height==724 and right.height==724,'original shared textures must be restored after repeated refreshes')
print('PASS background: both textures extended/idempotence/original heights restored')
local function anchorControl()
    return {anchors={},ClearAnchors=function(self)self.anchors={}end,
        SetAnchor=function(self,...)self.anchors[#self.anchors+1]={...}end}
end
TOPLEFT=1;TOPRIGHT=2;BOTTOMLEFT=3;BOTTOMRIGHT=4
local title,divider={},{}
function title:SetHidden(v)self.hidden=v end
function divider:SetHidden(v)self.hidden=v end
local container,scroll=anchorControl(),anchorControl()
function container:GetNamedChild(n)return n=='Title' and title or divider end
GuiRoot.GetLeft=function()return 0 end
background.GetLeft=function()return 0 end
background.GetRight=function()return 380 end
right.anchors={}
right.ClearAnchors=container.ClearAnchors;right.SetAnchor=container.SetAnchor
right.GetAnchor=function()return true,TOPRIGHT,background,TOPRIGHT,65,-75 end
ZO_SharedMediumLeftPanelBackground=background
K.ResizeMapPanel({control=container,list=scroll})
assert(container.anchors[1][5]==100 and container.anchors[2][5]==-30,'panel must span top area to screen bottom')
assert(title.hidden and divider.hidden and scroll.anchors[1][5]==0,'remove title and reserved list gap')
assert(right.anchors[1][2]==container,'background must follow the raised panel')
K.RestoreMapBackground()
assert(right.anchors[1][2]==background and right.anchors[1][5]==-75,'restore native background anchor')
print('PASS raised panel/header removal/list anchors/background alignment and restoration')

MOUSE_BUTTON_INDEX_LEFT=1;MOUSE_BUTTON_INDEX_RIGHT=2
K.saved={categories={},ignored={}}
K.RowClicked({kzgData={group={id='quests'}}},MOUSE_BUTTON_INDEX_RIGHT)
K.GoalClicked({kzgData={goal={key='quest:1'},zoneId=41}},MOUSE_BUTTON_INDEX_RIGHT)
assert(next(K.saved.categories)==nil and next(K.saved.ignored)==nil,'right click must not hide goals or categories')
print('PASS mouse: background click-through/restored mouse state/no right-click mutations')
local forwarded=0
K.mapPanel={IsShowing=function()return true end}
ZO_WorldMapContainer={}
ZO_WorldMap_MouseUp=function(control,button,inside)
    assert(control==ZO_WorldMapContainer and button==MOUSE_BUTTON_INDEX_RIGHT and inside)
    forwarded=forwarded+1
end
K.GoalClicked({kzgData={goal={key='quest:1'},zoneId=41}},MOUSE_BUTTON_INDEX_RIGHT)
K.RowClicked({kzgData={group={id='quests'}}},MOUSE_BUTTON_INDEX_RIGHT)
K.MapRightClick(MOUSE_BUTTON_INDEX_RIGHT)
assert(forwarded==3 and next(K.saved.categories)==nil and next(K.saved.ignored)==nil)
print('PASS right-click forwarding: goal/category/tooltip use native map handler')
