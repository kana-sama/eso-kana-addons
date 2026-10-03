local root = arg[0]:match('^(.*)/tests/[^/]+$') or '.'
local mapId, zoom, mapWidth = 27, .08, 920
EVENT_ADD_ON_LOADED, CT_LABEL, CENTER, TOPLEFT, DL_OVERLAY, TEXT_ALIGN_CENTER = 1, 2, 3, 4, 5, 6
DT_MEDIUM, DT_HIGH = 7, 8
ZO_MAP_CONSTANTS = {MAP_WIDTH=mapWidth, MAP_HEIGHT=mapWidth}
SLASH_COMMANDS = {}
function GetCurrentMapId() return mapId end
function GetNumMapBlobs() return 2 end
function GetMapBlobNameInfo(i)
 if i == 1 then return 'Гленумбра', .2, .3, .12, 1.2 end
 return 'Ротгар', .7, .2, .1, 1
end
function zo_strformat(_, text) return text end
SI_ZONE_NAME = 7
local init
EVENT_MANAGER = {RegisterForEvent=function(_,_,_,callback) init=callback end,
 UnregisterForEvent=function() end}
ZO_SavedVars = {NewAccountWide=function() return {enabled=true} end}
function ZO_PostHook(target, name, callback)
 local original=target[name]
 target[name]=function(self, ...)
  if original then original(self, ...) end
  callback(self, ...)
 end
end
ZO_WorldMapTiles_Manager = {}
local created={}
local function control(name, parent)
 local c={name=name,parent=parent,hidden=true}
 function c:SetFont(v) self.font=v end
 function c:SetColor(...) self.color={...} end
 function c:SetMouseEnabled(v) self.mouse=v end
 function c:SetPixelRoundingEnabled(v) self.round=v end
 function c:SetDrawLayer(v) self.layer=v end
 function c:SetDrawTier(v) self.tier=v end
 function c:SetDrawLevel(v) self.level=v end
 function c:SetHorizontalAlignment(v) self.align=v end
 function c:SetVerticalAlignment(v) self.valign=v end
 function c:SetText(v) self.text=v end
 function c:SetScale(v) self.scale=v end
 function c:SetWidth(v) self.width=v end
 function c:ClearAnchors() self.anchor=nil end
 function c:SetAnchor(...) self.anchor={...} end
 function c:SetHidden(v) self.hidden=v end
 function c:IsHidden() return self.hidden end
 function c:SetParent(v) self.parent=v end
 return c
end
WINDOW_MANAGER = {CreateControl=function(_, name, parent, kind)
 assert(kind == CT_LABEL)
 local c=control(name,parent);created[#created+1]=c;return c
end}
g_mapPanAndZoom={GetZoomMinMax=function() return .02, 1 end}
local native={hidden=false}
function native:SetHidden(value) self.hidden=value end
function native:IsHidden() return self.hidden end
local pool={}
function pool:ActiveObjectIterator() return next, {[1]=native}, nil end
function pool:ReleaseAllObjects() native.hidden=true end
ZO_WorldMapManager = {}
function ZO_WorldMapManager:UpdateBlobs() native.hidden=false;self.lastBlobZoom=zoom end
WORLD_MAP_MANAGER=setmetatable({blobNameLabelControlPool=pool,lastBlobZoom=zoom},{__index=ZO_WorldMapManager})
dofile(root..'/KanaColorMap.lua')
init(nil,'KanaColorMap')
local K=KanaColorMap
local parent={}
K.activeManager={parent=parent}
K:UpdateLabels(WORLD_MAP_MANAGER)
local function check()
 assert(K.visibleNames==2, 'both names displayed independently of native pool')
 assert(native.hidden, 'hide native duplicate only while custom labels render')
 for i,name in ipairs({'Гленумбра','Ротгар'}) do
  local entry=assert(K.nameLabels[i])
  assert(not entry.label.hidden and entry.label.text==name)
  assert(entry.label.font=='$(HANDWRITTEN_FONT)|34')
  assert(entry.label.layer==DL_OVERLAY and entry.label.level==6)
  assert(entry.label.color[1]==1 and entry.label.color[2]==1 and entry.label.color[3]==1,
   'foreground must be pure white')
  assert(entry.label.tier==DT_HIGH, 'foreground must render above dark copies')
  assert(entry.label.scale>=.75 and entry.label.mouse==false)
  assert(#entry.outline==8)
  for _,stroke in ipairs(entry.outline) do
   assert(not stroke.hidden and stroke.color[1]==0 and stroke.color[2]==0 and stroke.color[3]==0)
   assert(stroke.layer==DL_OVERLAY and stroke.level==5 and stroke.text==name)
   assert(stroke.tier==DT_MEDIUM)
   assert(stroke.scale==entry.label.scale and stroke.parent==parent)
  end
  for index,control in ipairs(created) do
   if control==entry.label then
    for _,stroke in ipairs(entry.outline) do
     local earlier=false
     for j=1,index-1 do if created[j]==stroke then earlier=true end end
     assert(earlier, 'dark copies must be created before white foreground')
    end
   end
  end
 end
end
check()
local firstCount=#created
K:Reset()
for _,c in ipairs(created) do assert(c.hidden) end
assert(K.visibleNames==0)
K.activeManager={parent=parent}
WORLD_MAP_MANAGER:UpdateBlobs()
check()
assert(#created==firstCount, 'reopen must reuse controls')
zoom=.9;WORLD_MAP_MANAGER:UpdateBlobs()
assert(K.nameLabels[1].label.scale==1.08, 'normal zoom still scales naturally')
assert(K.nameLabels[2].label.scale==.9)
ZO_MAP_CONSTANTS.MAP_WIDTH=1200;ZO_MAP_CONSTANTS.MAP_HEIGHT=1200
K:ShowLabels(K.activeManager)
assert(K.nameLabels[1].label.anchor[4]==.2*1200, 'reposition on map resize')
K:Reset();mapId=61;K.activeManager={parent=parent}
WORLD_MAP_MANAGER:UpdateBlobs()
assert(not native.hidden, 'detailed map keeps native names')
for _,c in ipairs(created) do assert(c.hidden) end
print('PASS: visible own labels, black outline, scale floor, zoom/resize, second open, restore')
