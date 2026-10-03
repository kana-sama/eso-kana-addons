-- Tests renderer output at the ESO control boundary (no game runtime required).
CombatMetronome = {}

CENTER, TOPLEFT, TOP, BOTTOM = 1, 2, 3, 4
CT_CONTROL, CT_POLYGON, CT_BACKDROP = 5, 6, 9
DL_OVERLAY, POLYGON_POINT_LAYOUT_CLOCKWISE = 7, 8
local Control = {}
Control.__index = Control
function Control:SetHidden(v) self.hidden = v end
function Control:IsHidden() return self.hidden end
function Control:SetDimensions(w,h) self.w,self.h = w,h end
function Control:SetAnchor(...) self.anchor = {...} end
function Control:ClearAnchors() self.anchor = nil end
function Control:SetMouseEnabled(v) end
function Control:GetName() return self.name end
function Control:SetClampedToScreen(v) self.clamped=v end
function Control:SetDrawLayer(v) end
function Control:SetDrawLevel(v) end
function Control:SetPointLayout(v) end
function Control:SetSmoothingEnabled(v) end
function Control:SetBorderThickness(a,b,c) end
function Control:SetBorderColor(...) end
function Control:SetEdgeColor(...) end
function Control:SetEdgeTexture(...) end
function Control:SetCenterColor(...) self.color = {...} end
function Control:AddPoint(x,y) self.points[#self.points+1] = {x,y} end
function Control:SetPoint(i,x,y) assert(self.points[i]); self.points[i] = {x,y} end
function Control:GetWidth() return self.w end
function Control:GetHeight() return self.h end
WINDOW_MANAGER = {controls={}}
function WINDOW_MANAGER:CreateControl(name,parent,kind)
    local c = setmetatable({name=name,points={},parent=parent,kind=kind}, Control)
    self.controls[#self.controls+1]=c
    return c
end
local function control() return WINDOW_MANAGER:CreateControl(nil,nil,CT_CONTROL) end
GuiRoot = control(); GuiRoot:SetDimensions(1920,1080)
function Control:GetHandler(name) return self.handlers and self.handlers[name] end
function Control:SetHandler(name, fn) self.handlers=self.handlers or {}; self.handlers[name]=fn end
function Control:GetLeft() return self.left or 10 end
function Control:GetTop() return self.top or 20 end
function Control:SetDimensionConstraints(...) self.constraints={...} end
local events, scenes = {}, {}
EVENT_ADD_ON_LOADED=100
EVENT_MANAGER={RegisterForEvent=function(_,name,event,fn) events[name]=fn end, UnregisterForEvent=function(_,name) events[name]=nil end}
SCENE_MANAGER={RegisterCallback=function(_,name,fn) scenes[#scenes+1]=fn end}
function GetDisplayName() return '@test' end
function GetCurrentCharacterId() return 'character1' end
function d(msg) error(msg) end
local cm=CombatMetronome
cm.SV={global=true,Progressbar={width=300,height=30,backgroundColor={0,0,0,.5},makeItFancy=true}}
CombatMetronomeSavedVars={Default={['@test']={
 ['$AccountWide']={Progressbar={radialCooldown=true,radialCenterX=700,radialCenterY=400,radialOuterRadius=60,radialInnerRadius=45}},
 character1={Progressbar={radialCooldown=false,radialCenterX=222}},
}}}
local linearCalls,updates,moves,resizes=0,0,0,0
function cm:BuildUI()
 local pb=self.Progressbar or {frame=control(),spellIcon=control(),timeLabel=control(),spellLabel=control()}
 self.Progressbar=pb
 if not pb.bar then
  pb.bar={background=control(),backgroundTexture=control(),borderL=control(),borderR=control(),segments={{progress=.1,color={1,0,0,1}},{progress=.75,color={0,.6,1,1}}}}
  function pb.bar:Update() linearCalls=linearCalls+1 end
  function pb.bar:SetHidden(v) self.background:SetHidden(v) end
 end
 pb.frame:SetHandler('OnMoveStop',function() moves=moves+1 end)
 pb.frame:SetHandler('OnResizeStop',function() resizes=resizes+1 end)
 local function anchors()
  pb.spellIcon:ClearAnchors(); pb.spellIcon:SetAnchor(TOPLEFT,pb.frame,TOPLEFT,0,0)
 end
 local function size() pb.frame:SetDimensions(cm.SV.Progressbar.width,cm.SV.Progressbar.height);anchors() end
 local function position() pb.frame:ClearAnchors();pb.frame:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,10,20) end
 local ui={Size=size,Anchors=anchors,Position=position,HiddenStates=function() pb.bar:SetHidden(false); cm:HideFancy(false) end,BarColors=function() end}
 size(); position();pb.bar:SetHidden(false)
 self.localPosition=position
 return ui
end
function cm:HideFancy(v)
 local bar=self.Progressbar.bar
 bar.backgroundTexture:SetHidden(v);bar.borderL:SetHidden(v);bar.borderR:SetHidden(v)
end
function cm:BuildMenu() self.menu={options={Progressbar={{name='Position / Size'}}}} end
function cm:ResetBarValues() for _,s in ipairs(self.Progressbar.bar.segments) do s.progress=0 end end
function cm:Update()
 updates=updates+1
 self.Progressbar.spellIcon:SetAnchor(TOPLEFT,self.Progressbar.frame,TOPLEFT,0,0)
 self.Progressbar.bar:Update()
end
-- Dependency has already initialized before extension files load.
local ui=cm:BuildUI();cm.Progressbar.UI=ui;cm:BuildMenu()
local root=arg[1]
dofile(root..'/Bootstrap.lua');dofile(root..'/Radial.lua');dofile(root..'/Integration.lua')
assert(not cm.Progressbar.radial,'must wait until own addon-loaded event')
events.KanaCooldownMetronome(nil,'KanaCooldownMetronome')
local a=KanaCooldownMetronome
assert(a.initialized and not events.KanaCooldownMetronome)
assert(a.settings.radialCooldown and a.settings.radialCenterX==700,'must migrate account profile')
assert(KanaCooldownMetronomeSavedVars.profiles['@test'].character1.radialCenterX==222,'must migrate other characters')
assert(cm.SV.Progressbar.radialCooldown==nil,'must not add settings to base SV')
assert(cm.Progressbar.frame.w==120 and cm.Progressbar.frame.anchor[4]==700)
assert(cm.menu.options.Progressbar[1].kanaCooldownMetronome)
a:ExtendMenu();assert(#cm.menu.options.Progressbar==2,'duplicate menu entry')
cm:Update();assert(updates==1 and linearCalls==0,'must use original updater and radial rendering')
assert(cm.Progressbar.spellIcon.anchor[1]==BOTTOM)
cm:HideFancy(false);assert(cm.Progressbar.bar.backgroundTexture.hidden)
ui.HiddenStates();assert(cm.Progressbar.bar.backgroundTexture.hidden)
cm.localPosition();for _,fn in ipairs(scenes) do fn() end
assert(cm.Progressbar.frame.anchor[4]==700,'scene callback must restore ring position')
cm.Progressbar.frame:GetHandler('OnMoveStop')()
assert(moves==0 and a.settings.radialCenterX==70,'radial drag must not modify linear position')
local options=cm.menu.options.Progressbar[1].controls
options[1].setFunc(false)
assert(cm.Progressbar.frame.w==300 and cm.Progressbar.frame.h==30,'must restore linear size')
assert(cm.Progressbar.spellIcon.anchor[1]==TOPLEFT,'must restore linear icon')
assert(not cm.Progressbar.bar.background.hidden and not cm.Progressbar.bar.backgroundTexture.hidden)
cm.Progressbar.frame:GetHandler('OnMoveStop')();cm.Progressbar.frame:GetHandler('OnResizeStop')()
assert(moves==1 and resizes==1,'must preserve linear handlers')
cm:Update();assert(updates==2 and linearCalls>=1)
options[1].setFunc(true);a.settings.radialCenterX=888;a:LoadSettings()
assert(a.settings.radialCenterX==888,'migration must not overwrite extension settings')
cm:BuildMenu();assert(cm.menu.options.Progressbar[1].kanaCooldownMetronome,'menu rebuild must retain radial options')
cm:ResetBarValues();assert(cm.Progressbar.bar.segments[2].progress==0)
cm.SV.global=false;a:LoadSettings()
assert(a.settings.radialCenterX==222 and not a.settings.radialCooldown,'must select character profile')
print('PASS extension: late load, all-profile migration, independent persistence, menu, visibility, layout, drag, linear fallback')
