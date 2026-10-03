-- Deliberately small native-control fixture, not a renderer. Coordinates returned
-- by GetLeft/GetDimensions include UI scale; setters and anchor offsets are raw.
-- Native constants/anchors copied from esoui/ingame/characterwindow/keyboard/
-- characterwindow_keyboard.xml and esoui/libraries/zo_templates/{windowtemplates,
-- scrolltemplates,buttontemplates}.xml. Text height is only a wrapping estimate;
-- actual glyph/font rendering and perceived contrast still need live ESO checks.
local G={}
local points={TOPLEFT={0,0},TOP={.5,0},TOPRIGHT={1,0},LEFT={0,.5},CENTER={.5,.5},RIGHT={1,.5},BOTTOMLEFT={0,1},BOTTOM={.5,1},BOTTOMRIGHT={1,1}}
local C={};C.__index=C
function C:GetName()return self.name end
function C:GetParent()return self.parent end
function C:GetNamedChild(n)return assert(self.children[n],self.name.." has no native child "..n)end
function C:SetAnchor(...)self.anchors[#self.anchors+1]={...}end
function C:ClearAnchors()self.anchors={}end
function C:GetNumAnchors()return #self.anchors end
function C:GetAnchor(n)return true,table.unpack(self.anchors[n+1])end
function C:SetDimensions(w,h)self.w=w;self.h=h end
function C:SetWidth(w)self.w=w end
function C:SetHeight(h)self.h=h end
function C:SetScale(s)self.scale=s end
function C:GetScale()return (self.scale or 1)*(self.parent and self.parent:GetScale()or self.fixture.scale)end
function C:SetHidden(v)self.hidden=v end
function C:IsHidden()return self.hidden end
function C:IsControlHidden()return self.hidden or (self.parent and self.parent:IsControlHidden())or false end
function C:SetEnabled(v)self.enabled=v end
function C:SetHandler(k,f)self.handlers[k]=f end
function C:GetHandler(k)return self.handlers[k]end
function C:SetText(t)self.text=t or "" end
function C:GetText()return self.text end
function C:SetFont(f)self.font=f end
function C:SetMaxLineCount(n)self.maxLines=n end
function C:SetWrapMode(v)self.wrapMode=v end
function C:SetResizeToFitDescendents(v)self.resize=v end
function C:SetMouseEnabled(v)self.mouse=v end
function C:SetClampedToScreen(v)self.clamped=v end
function C:SetColor(...)self.color={...}end
function C:SetAlpha(v)self.alpha=v end
function C:SetHorizontalAlignment(v)self.align=v end
function C:SetVerticalAlignment(v)self.verticalAlign=v end
function C:SetDrawTier(v)self.tier=v end
function C:GetTextWidth()
 local size=(self.font or ''):find('Small')and 16 or 20
 local _,chars=(self.text or ''):gsub('[^\128-\191]','')
 return chars*size*.52*self:GetScale()
end
function C:SetCenterColor(...)self.color={...}end
function C:SetEdgeColor(...)self.edgeColor={...}end
function C:SetEdgeTexture(...)self.edgeTexture={...}end
function C:SetTextureCoords(...)self.textureCoords={...} end
function C:SetTexture(texture)self.texture=texture end
function C:SetNormalTexture(texture)self.normalTexture=texture end
function C:SetPressedTexture(texture)self.pressedTexture=texture end
function C:GetTextureFileName()return self.texture end
function C:GetTextureCoords()return table.unpack(self.textureCoords or {0,1,0,1})end
function C:GetDrawLayer()return self.layer or 0 end
function C:GetDrawLevel()return self.level or 0 end
function C:SetDrawLevel(value)self.level=value end
function C:SetVertexColors(vertex,...)self.vertices=self.vertices or {};self.vertices[vertex]={...}end
function C:SetDrawLayer(layer)self.layer=layer end
function C:SetAnchorFill(parent)parent=parent or self.parent;self:ClearAnchors();self:SetAnchor(TOPLEFT,parent,TOPLEFT,0,0);self:SetAnchor(BOTTOMRIGHT,parent,BOTTOMRIGHT,0,0)end
function C:GetTextHeight()
 local size=(self.font or ""):find("Small")and 16 or 20
 local columns=math.max(1,math.floor(self:GetWidth()/self:GetScale()/(size*.52)))
 local lines=0
 for line in ((self.text or "").."\n"):gmatch("(.-)\n")do
  local _,chars=line:gsub("[^\128-\191]","");lines=lines+math.max(1,math.ceil(chars/columns))
 end
 return math.min(lines,self.maxLines or math.huge)*size*self:GetScale()
end
function C:Rect()
 if self.screen then return {l=0,t=0,r=self.fixture.width,b=self.fixture.height}end
 assert(not self.resolving,"cyclic anchors: "..self.name);self.resolving=true
 local scale=self:GetScale();local w=(self.w or 0)*scale;local h=(self.h or 0)*scale
 local xs,ys={},{}
 for _,a in ipairs(self.anchors)do
  local own=assert(points[a[1]],"unsupported anchor "..tostring(a[1]));local relative=a[2]or self.parent
  local rp=points[a[3]or a[1]];local r=relative:Rect()
  if a[6]~=ANCHOR_CONSTRAINS_Y then xs[#xs+1]={own[1],r.l+(r.r-r.l)*rp[1]+(a[4]or 0)*scale}end
  if a[6]~=ANCHOR_CONSTRAINS_X then ys[#ys+1]={own[2],r.t+(r.b-r.t)*rp[2]+(a[5]or 0)*scale}end
 end
 local function solve(values,size)
  for i=2,#values do if values[i][1]~=values[1][1]then size=(values[i][2]-values[1][2])/(values[i][1]-values[1][1]);break end end
  return #values>0 and values[1][2]-values[1][1]*size or 0,size
 end
 local l;l,w=solve(xs,w)
 if self.kind==CT_LABEL and not self.h then
  local size=(self.font or ""):find("Small")and 16 or 20
  local columns=math.max(1,math.floor(w/scale/(size*.52)));local lines=0
  for line in ((self.text or "").."\n"):gmatch("(.-)\n")do local _,n=line:gsub("[^\128-\191]","");lines=lines+math.max(1,math.ceil(n/columns))end
  h=math.min(lines,self.maxLines or math.huge)*size*scale
 end
 local t;t,h=solve(ys,h);self.resolving=false
 return {l=l,t=t,r=l+w,b=t+h}
end
function C:GetLeft()return self:Rect().l end
function C:GetRight()return self:Rect().r end
function C:GetTop()return self:Rect().t end
function C:GetBottom()return self:Rect().b end
function C:GetWidth()local r=self:Rect();return r.r-r.l end
function C:GetHeight()local r=self:Rect();return r.b-r.t end
function C:GetDimensions()return self:GetWidth(),self:GetHeight()end
function G.With(width,height,scale,fn)
 local f={width=width,height=height,scale=scale,controls={},saved={},equipment={}}
 function f:Put(k,v)if not self.saved[k]then self.saved[k]={_G[k]}end;_G[k]=v end
 function f:Control(name,parent,kind,w,h)
  if not name then self.controlSerial=(self.controlSerial or 0)+1;name="Anonymous"..self.controlSerial end
  local c=setmetatable({fixture=self,name=name,parent=parent,kind=kind,w=w,h=h,anchors={},children={},handlers={},hidden=false},C)
  self.controls[name]=c;return c
 end
 for k in pairs(points)do f:Put(k,k)end
 for _,k in ipairs({"CT_CONTROL","CT_LABEL","CT_BUTTON","CT_BACKDROP","CT_TEXTURE","DL_CONTROLS","DL_OVERLAY","DT_MEDIUM","DT_HIGH","TEXT_ALIGN_CENTER","SCENE_HIDDEN","SCENE_HIDING","SCENE_SHOWING","SCENE_SHOWN","TEXT_WRAP_MODE_ELLIPSIS","ANCHOR_CONSTRAINS_X","ANCHOR_CONSTRAINS_Y"})do f:Put(k,k)end
 f:Put('ZO_MEDIUM_TIER_KEYBOARD_STANDARD_DIALOG',100)
 f:Put('ZO_Scroll_SetOnInteractWithScrollbarCallback',function(c,fn)c.onInteractWithScrollbarCallback=fn end)
 f:Put('ZO_Scroll_SetScrollToRealOffsetAccountingForGradients',function(c,total,offset,duration)
  c.followCalls=(c.followCalls or 0)+1;c.followOffset=offset;c.followTotal=total;c.followDuration=duration
 end)
 local screen=f:Control("GuiRoot");screen.screen=true;screen.scale=1/scale;f:Put("GuiRoot",screen)
 local wm={}
 function wm:CreateControl(n,p,k)return f:Control(n,p,k)end
 function wm:CreateControlFromVirtual(n,p,template)
  local c=f:Control(n,p,CT_CONTROL)
  if template=="ZO_ScrollContainer"then
   local s=f:Control(n.."Scroll",c);c.children.Scroll=s;s:SetAnchorFill(c);s.anchors[2][4]=-16
   local child=f:Control(n.."ScrollChild",s);s.children.Child=child;child:SetAnchor(TOPLEFT,s,TOPLEFT,0,0)
  elseif template=="ZO_CheckButton"then c:SetDimensions(16,16)
  elseif template=="ZO_DefaultButton" or template=="ZO_CloseButton"then
   c.kind=CT_BUTTON
   local label=f:Control(n..'Label',c,CT_LABEL);label:SetAnchorFill(c)
   function c:GetLabelControl()return label end
   function c:SetText(value)C.SetText(self,value);label:SetText(value)end
   function c:SetFont(value)C.SetFont(self,value);label:SetFont(value)end
   -- API 101051 ButtonControl exposes SetText and GetLabelControl, but no
   -- label getters. A shared mock class used to conceal invalid GetText calls.
   setmetatable(c,{__index=function(_,key)
    if key=='GetText' or key=='GetTextWidth' or key=='GetTextHeight'then return nil end
    return C[key]
   end})
  else error("unmodelled virtual control "..template)end
  return c
 end
 f:Put("WINDOW_MANAGER",wm)
 -- scrolltemplates.lua ZO_ScrollList_Commit caches contentHeight-windowHeight
 -- in the native scrollbar. Anchor changes alone do not recalculate its range.
 f:Put("ZO_ScrollList_Commit",function(list)
  list.commitCount=(list.commitCount or 0)+1
  list.scrollableDistance=math.max(0,(list.contentHeight or 0)-list:GetHeight()/list:GetScale())
 end)
 local function native(n,p,w,h) local c=f:Control(n,p,nil,w,h);f:Put(n,c);return c end
 local background=native("ZO_SharedWideLeftPanelBackground",nil,535,500)
 background:SetAnchor(LEFT,screen,LEFT,0,-85)
 local rightTexture=native("ZO_SharedWideLeftPanelBackgroundRight",background,64,724)
 rightTexture:SetAnchor(TOPRIGHT,background,TOPRIGHT,65,-75)
 local leftTexture=native("ZO_SharedWideLeftPanelBackgroundLeft",background,1024,724)
 leftTexture:SetAnchor(TOPRIGHT,rightTexture,TOPLEFT,0,0)
 background.children.Left=leftTexture;background.children.Right=rightTexture
 local character=native("ZO_Character",nil,190,510)
 -- ZO_WideLeftPanelBG inherits ZO_ThinLeftPanelBG: 500 high, LEFT y=-85.
 character:SetAnchor(TOPLEFT,background,TOPLEFT,0,-40)
 character:SetAnchor(BOTTOMLEFT,background,BOTTOMLEFT,0,-30)
 local title=native("ZO_CharacterHeaderSectionTitle",character,200,32)
 title:SetAnchor(TOPLEFT,character,TOPLEFT,14,26)
 -- Native stats panel is 303 wide; its scroll extends another 24 units right.
 local stats=native("ZO_CharacterWindowStatsScroll",nil,327,462);stats:SetAnchor(TOPLEFT,character,TOPLEFT,256,63)
 -- Native inventory.xml and ZO_RightPanelBG: 575-wide background at RIGHT,
 -- inventory 565 wide with TOPLEFT -20 and BOTTOMLEFT -30 offsets.
 local inventory=native("ZO_PlayerInventory",nil,565,740)
 inventory:SetAnchor(TOPLEFT,screen,RIGHT,-575,-375)
 local bagBackground=native("ZO_SharedRightPanelBackground",nil,575,750)
 bagBackground:SetAnchor(TOPLEFT,inventory,TOPLEFT,20,20)
 local bagTexture=native("ZO_SharedRightPanelBackgroundLeft",bagBackground,1024,1024)
 bagTexture:SetAnchor(TOPLEFT,bagBackground,TOPLEFT,-65,-75)
 bagBackground.children.Left=bagTexture
 local panel=native("KanaWardrobePanel",nil,248,560)
 local file=assert(io.open(ROOT.."/UI.xml"));local xml=file:read("*a");file:close()
 local pw,ph=xml:match('name="KanaWardrobePanel".-<Dimensions x="(%d+)" y="(%d+)"')
 assert(pw,"panel XML dimensions missing");panel:SetDimensions(tonumber(pw),tonumber(ph))
 local content=f:Control("KanaWardrobePanelContent",panel);panel.children.Content=content;content:SetAnchorFill(panel)
 local function item(name,point,relative,relativePoint,x,y)
  local c=native("ZO_CharacterEquipmentSlots"..name,character,44,44);c:SetAnchor(point,relative or character,relativePoint,x,y)
  local icon=f:Control(c.name.."Icon",c);c.children.Icon=icon;icon:SetAnchor(TOPLEFT,c,TOPLEFT,2,2);icon:SetAnchor(BOTTOMRIGHT,c,BOTTOMRIGHT,-2,-2)
  c:SetHandler("OnDragStart",function()f.dragCount=(f.dragCount or 0)+1 end)
  f.equipment[#f.equipment+1]=c;return c
 end
 item("Head",TOP,character,TOPLEFT,87,100)
 local shoulder=item("Shoulder",TOPLEFT,character,TOPLEFT,10,156)
 local glove=item("Glove",TOP,shoulder,BOTTOM,0,10);item("Leg",TOP,glove,BOTTOM,0,10)
 local chest=item("Chest",TOPLEFT,character,TOPLEFT,124,156)
 local belt=item("Belt",TOP,chest,BOTTOM,0,10);item("Foot",TOP,belt,BOTTOM,0,10)
 local costume=item("Costume",TOPLEFT,character,TOPLEFT,10,345)
 local neck=item("Neck",LEFT,costume,RIGHT,4,0);local ring=item("Ring1",LEFT,neck,RIGHT,4,0);item("Ring2",LEFT,ring,RIGHT,4,0)
 local weapons=native("ZO_CharacterWeaponsSection",character,256,4);weapons:SetAnchor(TOPLEFT,character,TOPLEFT,0,400)
 local main=item("MainHand",TOPLEFT,character,TOPLEFT,10,432);local off=item("OffHand",LEFT,main,RIGHT,10,0);item("Poison",LEFT,off,RIGHT,10,0)
 local backup=item("BackupMain",TOPLEFT,main,BOTTOMLEFT,0,4);local backupOff=item("BackupOff",LEFT,backup,RIGHT,10,0);item("BackupPoison",LEFT,backupOff,RIGHT,10,0)
 f.scene={AddFragment=function()end,RegisterCallback=function(self,_,cb)self.callback=cb end}
 f:Put("SCENE_MANAGER",{GetScene=function()return f.scene end})
 f:Put("ZO_SimpleSceneFragment",{New=function(_,c)return {control=c}end})
 f:Put("ZO_CheckButton_SetToggleFunction",function(c,cb)c.toggle=cb end)
 f:Put("ZO_CheckButton_SetCheckState",function(c,v)c.checked=v end)
 f:Put("ZO_CheckButton_SetLabelText",function(c,v)
  if not c.label then c.label=f:Control(c.name.."Label",c,CT_LABEL);c.children.Label=c.label;c.label:SetAnchor(LEFT,c,RIGHT,5,0);c.label:SetFont("ZoFontGameBold")end
  c.labelText=v;c.label:SetText(v)
 end)
 f:Put("ZO_CheckButton_SetEnableState",function(c,v)c.enabled=v end)
 f:Put("INVENTORY_FRAGMENT",nil);f:Put("IsInGamepadPreferredMode",nil)
 local ok,err=xpcall(function()fn(f)end,debug.traceback)
 for k,v in pairs(f.saved)do _G[k]=v[1]end
 if not ok then error(err,0)end
end
function G.Contained(inner,outer,message)
 local a,b=inner:Rect(),outer:Rect();assert(a.l>=b.l-.01 and a.t>=b.t-.01 and a.r<=b.r+.01 and a.b<=b.b+.01,(message or inner.name.." outside "..outer.name)..string.format(" [%.1f %.1f %.1f %.1f] vs [%.1f %.1f %.1f %.1f]",a.l,a.t,a.r,a.b,b.l,b.t,b.r,b.b))
end
function G.Disjoint(a,b,message)
 local x,y=a:Rect(),b:Rect();assert(x.r<=y.l+.01 or x.l>=y.r-.01 or x.b<=y.t+.01 or x.t>=y.b-.01,message or a.name.." overlaps "..b.name)
end
return G
