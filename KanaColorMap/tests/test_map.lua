local root = arg[0]:match('^(.*)/tests/[^/]+$') or '.'
local currentMap, columns, rows, foreignTile, changedBlob = 27, 4, 4
local events, messages, created = {}, {}, {}
EVENT_ADD_ON_LOADED, CT_TEXTURE, TOPLEFT, DL_BACKGROUND = 1, 2, 3, 4
CONTROL_MASK_MODE_BASIC = 1
ZO_MAP_CONSTANTS = {MAP_WIDTH=920, MAP_HEIGHT=920}
zo_mod, zo_floor = math.fmod, math.floor
SLASH_COMMANDS = {}
EVENT_MANAGER = {
 RegisterForEvent=function(_,name,_,fn) events[name]=fn end,
 UnregisterForEvent=function(_,name) events[name]=nil end,
}
local saved = {enabled=true}
ZO_SavedVars = {NewAccountWide=function() return saved end}
function GetCurrentMapId() return currentMap end
function GetMapNumTiles() return columns, rows end
function GetMapTileTexture(i)
 if foreignTile==i then return 'OtherMap/custom.dds' end
 return string.format(currentMap==27 and 'art/maps/tamriel/tamriel_%d.dds' or 'art/maps/eastmarch/eastmarch_base_%d.dds',i-1)
end
function d(s) messages[#messages+1]=s end
KanaColorMapData = {zones={
 {id=667,x=.184,y=.186,width=.1401,height=.1157,probeX=.27,probeY=.24,sourceMask='/art/maps/tamriel/tamriel-wrothgar.dds',mask='eso-kana-addons/KanaColorMap/masks/667.dds',art='eso-kana-addons/KanaColorMap/textures/zones/667.dds'},
 {id=30,x=.113,y=.342,width=.1435,height=.0947,probeX=.18,probeY=.39,sourceMask='/art/maps/tamriel/tamriel-alikr.dds',mask='eso-kana-addons/KanaColorMap/masks/30.dds',art='eso-kana-addons/KanaColorMap/textures/zones/30.dds'},
}}
function GetMapMouseoverInfo(x,y)
 for _,z in ipairs(KanaColorMapData.zones) do
  if x==z.probeX and y==z.probeY and z.id~=changedBlob then
   -- Live ESO returned 0 at Stonefalls' old island probe, 7 on the mainland.
   if z.id~=7 or (math.abs(x-.7632371188)<1e-9 and math.abs(y-.4561108350)<1e-9) then
    return 'Zone',z.sourceMask,z.width,z.height,z.x,z.y,z.id
   end
  end
 end
 return '', '', 0,0,0,0,0
end
local function control()
 local c={desaturation=.12,hidden=false}
 function c:SetTexture(v) self.texture=v end
 function c:GetTextureFileName() return self.texture end
 function c:SetDesaturation(v) self.desaturation=v end
 function c:GetDesaturation() return self.desaturation end
 function c:SetHidden(v) self.hidden=v end
 function c:SetMouseEnabled(v) self.mouse=v end
 function c:SetDrawLayer(v) self.layer=v end
 function c:SetDrawLevel(v) self.level=v end
 function c:GetDrawLevel() return self.level or 0 end
 function c:SetPixelRoundingEnabled(v) self.pixelRounding=v end
 function c:SetMaskTexture(v) self.mask=v end
 function c:SetMaskMode(v) self.maskMode=v end
 function c:SetDimensions(w,h) self.w,self.h=w,h end
 function c:ClearAnchors() self.anchor=nil end
 function c:SetAnchor(point,parent,relative,x,y) self.anchor={point,parent,relative,x,y} end
 function c:SetParent(parent) self.parent=parent end
 function c:SetAnchorFill(parent) self.fill=parent end
 return c
end
WINDOW_MANAGER={CreateControl=function(_,name,parent)
 local c=control();c.name=name;c.parent=parent;created[#created+1]=c;return c
end}
local hooks=0
function ZO_PostHook(object,method,callback)
 hooks=hooks+1
 local original=object[method]
 object[method]=function(self,...) original(self,...);callback(self,...) end
end
if arg[1] then
 ZO_ControlPool={Subclass=function() return {} end}
 dofile(arg[1])
else
 ZO_WorldMapTiles_Manager={}
 function ZO_WorldMapTiles_Manager:UpdateTextures()
  self.horizontalTiles,self.verticalTiles=GetMapNumTiles()
  self:LayoutTiles()
  for i=1,columns*rows do self:GetActiveObject(i):SetTexture(GetMapTileTexture(i)) end
 end
 function ZO_WorldMapTiles_Manager:LayoutTiles() end
end
local tiles={}
for i=1,16 do tiles[i]=control() end
local hover=control();hover.level=2
local parent={GetNamedChild=function(_,name) if name=='MouseoverBlob' then return hover end end}
local manager=setmetatable({parent=parent}, {__index=ZO_WorldMapTiles_Manager})
function manager:ReleaseAllObjects() end
function manager:AcquireObject(i) return tiles[i] end
function manager:GetActiveObject(i) return tiles[i] end
WORLD_MAP_TILES_MANAGER=manager
dofile(root..'/KanaColorMap.lua')
local init=events.KanaColorMap
init(nil,'AnotherAddon')
assert(hooks==0)
init(nil,'KanaColorMap')
local initialHooks=hooks
init(nil,'KanaColorMap')
assert(hooks==initialHooks and events.KanaColorMap==nil)
local function assertNativeBackground()
 assert(hover.level==3,'native hover must remain above all outlines')
 for i=1,16 do
  assert(tiles[i].texture==GetMapTileTexture(i), 'base atlas must remain native; no color outside zone masks')
  assert(tiles[i].desaturation==.12,'preserve native background saturation while overlays are enabled')
 end
end
local function assertRestored()
 assert(hover.level==2,'restore native hover draw level')
 for i=1,columns*rows do
  assert(tiles[i].texture==GetMapTileTexture(i))
  assert(tiles[i].desaturation==.12,'restore pre-addon desaturation')
 end
 for _,c in ipairs(created) do assert(c.hidden,'no region overlay on a detailed map/disabled addon') end
end
assertNativeBackground()
assert(#created==2,'only real exported and currently recognized zones may be colored')
for i,z in ipairs(KanaColorMapData.zones) do
 local c=created[i]
 assert(c.texture==z.art and c.mask==z.mask and c.maskMode==CONTROL_MASK_MODE_BASIC)
 assert(c.mouse==false and c.level<2, 'overlay must not intercept clicks or cover hover highlight')
 assert(math.abs(c.w-z.width*920)<1e-6)
 assert(c.anchor[4]==z.x*920 and c.anchor[5]==z.y*920)
end
manager:UpdateTextures()
assertNativeBackground();assert(#created==2,'reuse controls')
ZO_MAP_CONSTANTS.MAP_WIDTH=1200
manager:LayoutTiles()
assert(created[1].w==KanaColorMapData.zones[1].width*1200,'resize region with native map')
currentMap=61;manager:UpdateTextures();assertRestored()
currentMap=27;manager:UpdateTextures();assertNativeBackground()
SLASH_COMMANDS['/kcm']('off');assert(saved.enabled==false);assertRestored()
SLASH_COMMANDS['/kcm']('on');assertNativeBackground()
columns,rows=2,2;manager:UpdateTextures();assertRestored()
columns,rows=4,4;foreignTile=16;manager:UpdateTextures();assertRestored()
foreignTile=nil;changedBlob=667;manager:UpdateTextures();assertNativeBackground()
assert(created[1].hidden and not created[2].hidden,'no artwork on an unrecognized/removed zone')
changedBlob=nil;manager:UpdateTextures()
for i=1,16 do tiles[i].texture=GetMapTileTexture(i) end
tiles[16].texture='OtherMap/override.dds'
KanaColorMap:Apply(manager)
for _,c in ipairs(created) do assert(c.hidden) end
WORLD_MAP_TILES_MANAGER=nil;SLASH_COMMANDS['/kcm']('off');assert(saved.enabled==false)
WORLD_MAP_TILES_MANAGER=manager;manager:UpdateTextures();assertRestored()
SLASH_COMMANDS['/kcm']('status');assert(#messages>0)
dofile(root..'/Zones.lua')
-- A fresh activation using the real dataset, independent of the two-zone fixture.
KanaColorMap.overlays={}
SLASH_COMMANDS['/kcm']('on')
assert(KanaColorMap.overlays[7] and not KanaColorMap.overlays[7].control.hidden,
 'Stonefalls must use the mainland probe confirmed by the live client')
assert(KanaColorMap.visibleZones==#KanaColorMapData.zones,'all packaged zones must pass validation')
for _,zone in ipairs(KanaColorMapData.zones) do
 local entry=KanaColorMap.overlays[zone.id]
 assert(entry.border,'every world-map zone needs a continuous border: '..zone.id)
 assert(entry.border.parent==manager.parent and entry.border.fill==entry.control)
 assert(entry.border.mouse==false and entry.border.level>entry.control.level)
 assert(entry.border.level<hover.level,'native hover stays above contours')
 assert(not entry.border.hidden)
end
changedBlob=1887;manager:UpdateTextures()
assert(KanaColorMap.overlays[1887].border.hidden,'hide border when zone validation fails')
changedBlob=nil;manager:UpdateTextures()
SLASH_COMMANDS['/kcm']('off');assertRestored()
print('PASS: original parchment background, native zone masks, region layout, map isolation, restore/toggle, compatibility')
