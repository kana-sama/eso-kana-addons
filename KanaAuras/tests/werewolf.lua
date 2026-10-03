local controls, events = {}, {}
SLASH_COMMANDS = {}
local now, buffs = 20, {}
local methods = {}
DT_LOW, DT_MEDIUM, DT_HIGH = 0, 1, 2
function methods:SetDrawTier(value) self.tier=value end
function methods:SetAlpha(value) self.alpha=value end
for _, method in ipairs({'SetMouseEnabled', 'SetMovable', 'SetDrawLevel', 'SetDrawLayer', 'SetTextureCoords', 'SetBlendMode'}) do
    methods[method] = function() end
end
function methods:SetDimensions(w, h) self.width, self.height = w, h end
function methods:SetAnchor(...) self.anchor = {...} end
function methods:GetBottom()
    return self.anchor[5] + (self.anchor[2]==ZO_ReticleContainerReticle and 540 or 0)
end
function methods:SetAnchorFill(other) self.fill = other end
function methods:SetHidden(value) self.hidden = value end
function methods:SetTexture(value) self.texture = value end
function methods:SetColor(...) self.color = {...} end
function methods:SetTextureRotation(value) self.rotation = value end
function methods:SetTransformNormalizedOriginPoint(x,y) self.origin={x,y} end
function methods:SetTransformRotation(x,y,z) self.transformRotation=z end
function methods:SetHandler(event, callback)
    self.handlers = self.handlers or {}
    self.handlers[event] = callback
end
local function control(name)
    local result = setmetatable({}, {__index = methods})
    if name then controls[name] = result end
    return result
end
WINDOW_MANAGER = {
    CreateControl = function(_, name) return control(name) end,
    CreateTopLevelWindow = function(_, name) return control(name) end,
}
EVENT_ADD_ON_LOADED, EVENT_PLAYER_ACTIVATED, EVENT_RETICLE_TARGET_CHANGED = 1, 2, 3
EVENT_MANAGER = {
    RegisterForEvent = function(_, _, event, callback) events[event] = callback end,
    UnregisterForEvent = function(_, _, event) events[event] = nil end,
    RegisterForUpdate = function(_, _, _, callback) events.update = callback end,
}
ZO_ReticleContainerReticle = {}
GuiRoot = {}
GuiRoot.GetHeight=function() return 1080 end
ZO_ReticleContainerReticle.GetCenter=function() return 960,540 end
MOUSE_BUTTON_INDEX_LEFT=1
EVENT_GLOBAL_MOUSE_UP=9
local mouseX,mouseY=500,200
GetUIMousePosition=function() return mouseX,mouseY end
CENTER = 'CENTER'
ZO_SimpleSceneFragment = {New = function(_, root) return root end}
HUD_SCENE = {AddFragment = function() end}
HUD_UI_SCENE = HUD_SCENE
zo_strformat = function(_, text) return (text:gsub('%^.*$', '')) end
GetFrameTimeSeconds = function() return now end
GetNumBuffs = function(unit) assert(unit == 'player'); return #buffs end
GetUnitBuffInfo = function(unit, i) assert(unit == 'player'); return unpack(buffs[i]) end

TOP, BOTTOM, TOPLEFT = 'TOP', 'BOTTOM', 'TOPLEFT'
EVENT_COMBAT_EVENT=8
ACTION_RESULT_POWER_ENERGIZE=10
COMBAT_UNIT_TYPE_PLAYER=1
EVENT_MANAGER.AddFilterForEvent=function() end
COMBAT_MECHANIC_FLAGS_ULTIMATE = 8
COMBAT_MECHANIC_FLAGS_WEREWOLF = 16
local fury, furyMax=0,1000
function methods:ClearAnchors() self.anchor=nil end
function methods:SetTextureCoords(...) self.coords={...} end
local transformed, power, maximum = false, 500, 500
IsPlayerInWerewolfForm=function() return transformed end
GetUnitPower=function(unit, kind)
    assert(unit=='player')
    if kind==16 then return fury,furyMax,furyMax end
    assert(kind==8)
    return power,maximum,maximum
end
local socketVisible
KanaAurasCreateBloodSockets=function(parent) return function(show) socketVisible=show end end
d=function() end
assert(loadfile('WerewolfForm.lua'), 'Werewolf form tracker missing')()
events[1](1,'KanaAuras')
local content=controls.KanaWerewolfFormContent
local root=controls.KanaWerewolfFormWindow
local refresh=events.update
local function tick(dt)
    now=now+dt
    if content.handlers and content.handlers.OnUpdate then content.handlers.OnUpdate() end
end
-- Existing state assertions inspect the settled display.
events.update=function() refresh();tick(.2) end

assert(content.hidden and not (content.handlers and content.handlers.OnUpdate))
transformed=true; events.update()
assert(not content.hidden and content.handlers.OnUpdate)
assert(root.anchor[2]==ZO_ReticleContainerReticle and root.anchor[5]==-90)
local function filledWidth()
    local c=controls.KanaWerewolfFormFill1
    return c.hidden and 0 or c.width
end
local full=filledWidth()
assert(full>100)
power=250;events.update();assert(math.abs(filledWidth()-full*.5)<.001)
power=50;events.update();assert(math.abs(filledWidth()-full*.1)<.001)
assert(controls.KanaWerewolfFormFill1.color[1]>controls.KanaWerewolfFormFill1.color[3], 'Low resource red')
local alpha=controls.KanaWerewolfFormFill1.color[4]
now=now+.25;content.handlers.OnUpdate();assert(controls.KanaWerewolfFormFill1.color[4]~=alpha)
power=0;events.update();assert(filledWidth()==0 and not content.hidden)
power=900;events.update();assert(math.abs(filledWidth()-full)<.001)
maximum=0;events.update();assert(content.hidden and not (content.handlers and content.handlers.OnUpdate))
maximum=500;power=500
local ring={}
CombatMetronome={SV={Progressbar={radialCooldown=true,radialCenterX=500,radialCenterY=400,radialOuterRadius=60}},Progressbar={radial={root=ring}}}
events.update();assert(root.anchor[2]==GuiRoot and root.anchor[1]==BOTTOM and root.anchor[3]==TOPLEFT and root.anchor[4]==500 and root.anchor[5]==310)
CombatMetronome.SV.Progressbar.radialCooldown=false;events.update()
assert(root.anchor[2]==ZO_ReticleContainerReticle)
transformed=false;events.update();assert(content.hidden and not (content.handlers and content.handlers.OnUpdate))
print('PASS: Werewolf form, real Ultimate fraction, clamp, low pulse, zero/max, cooldown ring anchor, hiding')

SLASH_COMMANDS['/kanawolf']('height 55')
assert(root.anchor[5]==-115 and KanaAurasSettings.wolfGap==55)
SLASH_COMMANDS['/kanawolf']('height nope')
assert(KanaAurasSettings.wolfGap==55)
SLASH_COMMANDS['/kanawolf']('height -1')
assert(KanaAurasSettings.wolfGap==55)
SLASH_COMMANDS['/kanawolf']('height reset')
assert(KanaAurasSettings.wolfGap==30 and root.anchor[5]==-90)
assert(not socketVisible)

transformed=true;events.update()
assert(controls.KanaWerewolfFormWolfGlow.hidden)
local function furyProgress()
 local total=0
 for i=1,4 do
  local c=controls['KanaWerewolfFormBorder'..i]
  assert(c, 'Fury must follow the diamond perimeter')
  if not c.hidden then total=total+(i%2==1 and c.width or c.height)/(68/math.sqrt(2)) end
 end
 return total/4
end
assert(not controls.KanaWerewolfFormFury1, 'No separate Fury bar')
assert(furyProgress()==0)
fury=500;events.update();local half=furyProgress();assert(half>0)
fury=999;events.update();assert(controls.KanaWerewolfFormWolfGlow.hidden)
fury=1000;events.update();assert(not controls.KanaWerewolfFormWolfGlow.hidden)
assert(math.abs(furyProgress()-half*2)<.001)
local glow=controls.KanaWerewolfFormWolfGlow
local alpha,width=glow.color[4],glow.width
now=now+.2;content.handlers.OnUpdate()
assert(glow.color[4]~=alpha and glow.width~=width, 'Full Fury wolf must pulse in brightness and size')
fury=0;events.update();assert(glow.hidden)
furyMax=0;events.update();assert(furyProgress()==0 and glow.hidden)
furyMax=1000;fury=1000;events.update();transformed=false;events.update()
assert(content.hidden and glow.hidden and not content.handlers.OnUpdate)
print('PASS: Fury independent fraction, full threshold, animated wolf, spend, invalid max and form exit')

transformed=true;power=500;fury=1000;events.update()
local formFull, furyFull=filledWidth(),furyProgress()
power=0;fury=0;refresh()
assert(math.abs(filledWidth()-formFull)<.001 and math.abs(furyProgress()-furyFull)<.001, 'No immediate jump')
assert(glow.hidden, 'Readiness ends immediately, not after easing')
tick(.09)
assert(math.abs(filledWidth()-formFull*.5)<.001 and math.abs(furyProgress()-furyFull*.5)<.001)
refresh();tick(.09)
assert(filledWidth()<.001 and furyProgress()<.001, 'Unchanged polls do not restart easing')
power=500;refresh();tick(.06)
local before=filledWidth()
power=100;refresh();assert(math.abs(filledWidth()-before)<.001, 'Retarget without jump')
tick(.18);assert(math.abs(filledWidth()-formFull*.2)<.001)
transformed=false;events.update();power=400;transformed=true;refresh()
assert(math.abs(filledWidth()-formFull*.8)<.001, 'Reopening snaps to current resource')
print('PASS: both bars ease in 180ms, retarget continuously, no poll restart, immediate readiness')

CombatMetronome.SV.Progressbar.radialCooldown=true
CombatMetronome.Progressbar.radial=nil
refresh();local beforeY=root.anchor[5]
CombatMetronome.Progressbar.radial={root={height=0}}
refresh();assert(root.anchor[5]==beforeY)
CombatMetronome.Progressbar.radial.root.height=120
refresh();assert(root.anchor[5]==beforeY, 'Combat reveal cannot move panel')
CombatMetronome.SV.Progressbar.radialOuterRadius=80
refresh();assert(root.anchor[5]==beforeY-20, 'Explicit radius edits still apply')

transformed=true;fury=0;refresh();fury=1000;refresh()
local start=now
local bar=controls.KanaWerewolfFormBorder1
now=start+.25;content.handlers.OnUpdate()
assert(math.abs(bar.color[4]-1)<.001 and math.abs(glow.color[4]-.2)<.001, 'Bar leads')
now=start+.5;content.handlers.OnUpdate()
assert(math.abs(bar.color[4]-.5)<.001 and math.abs(glow.color[4]-1)<.001, 'Wolf follows')
refresh()
now=start+1.5;content.handlers.OnUpdate()
assert(math.abs(glow.color[4]-1)<.001, 'Shared rhythm stays fixed across polls and cycles')
print('PASS: full Fury bar/wolf synchronized cycle and fixed 250ms delay')

-- Rampage is a timed player effect, not inferred from spending Fury.
transformed=true;power=500;fury=0;buffs={};events.update()
local start=now
buffs={{'Rampage',start,start+20,1,1,'', '',1,1,0,267418,false,true}}
refresh()
assert(not controls.KanaWerewolfFormBloodMist.hidden)
assert(not controls.KanaWerewolfFormEye1.hidden and not glow.hidden)
local timerFull=furyProgress();assert(math.abs(timerFull-1)<.001)
now=start+10;refresh()
assert(math.abs(furyProgress()-timerFull*.5)<.001, 'Rampage uses actual remaining time')
assert(controls.KanaWerewolfFormBorder1.color[1]>controls.KanaWerewolfFormBorder1.color[2])
local rotation=controls.KanaWerewolfFormBloodMist.rotation
now=now+.1;content.handlers.OnUpdate()
assert(furyProgress()<timerFull*.5 and controls.KanaWerewolfFormBloodMist.rotation~=rotation, 'Continuous countdown and blood motion')
-- Recover mid-effect after leaving and re-entering HUD state.
transformed=false;refresh();transformed=true;refresh()
assert(furyProgress()<timerFull*.5 and furyProgress()>timerFull*.45)
buffs={};refresh()
assert(controls.KanaWerewolfFormBloodMist.hidden and controls.KanaWerewolfFormEye1.hidden)
assert(glow.hidden, 'Removed buff clears ultimate mode immediately')
for _,id in ipairs({267425,267426,267427,267428}) do
 buffs={{'Enduring Rampage',now,now+20,1,1,'', '',1,1,0,id,false,true}};refresh()
 assert(not controls.KanaWerewolfFormBloodMist.hidden)
end
now=now+20;refresh();assert(controls.KanaWerewolfFormBloodMist.hidden)
buffs={{'Unrelated',now,now+20,1,1,'', '',1,1,0,184220,false,true}};refresh()
assert(controls.KanaWerewolfFormBloodMist.hidden)
print('PASS: Rampage real 20s timer, continuous drain, resume, removal, morphs, expiry and unrelated buffs')

-- A faint extension previews one full corpse (+75), capped at the real maximum.
transformed=true;buffs={};power=250;maximum=500;events.update()
local preview=controls.KanaWerewolfFormDevourPreview
assert(not preview.hidden and math.abs(preview.width-300*.86*75/500)<.001)
assert(preview.color[4]<=.25 and preview.color[4]>0)
assert(math.abs(preview.coords[1]-(.07+.86*.5))<.001)
power=480;events.update();assert(math.abs(preview.width-300*.86*20/500)<.001)
power=500;events.update();assert(preview.hidden)
power=0;events.update();assert(not preview.hidden and math.abs(preview.width-300*.86*75/500)<.001)
maximum=1000;power=500;events.update();assert(math.abs(preview.width-300*.86*75/1000)<.001)
transformed=false;events.update();assert(content.hidden)
print('PASS: translucent full-devour forecast, real maximum, clipping and form visibility')

transformed=true;buffs={};maximum=500;power=200;events.update()
local function feed(id)
 events[EVENT_COMBAT_EVENT](EVENT_COMBAT_EVENT,ACTION_RESULT_POWER_ENERGIZE,false,'Feed',0,0,'',1,'',1,15,8,0,false,1,1,id or 266520)
end
local function endpoint() return preview.coords[2] end
power=215;feed();tick(.2)
local fixed=endpoint()
assert(math.abs(fixed-(.07+.86*275/500))<.001)
local widthBefore=preview.width
for i=2,4 do
 now=now+.8;power=power+15;feed();tick(.2)
 assert(math.abs(endpoint()-fixed)<.001, 'Meal endpoint remains pinned')
 assert(preview.width<widthBefore, 'Actual fill consumes forecast area')
 widthBefore=preview.width
end
now=now+.8;power=275;feed();tick(.18)
assert(preview.hidden or preview.width<.001)
tick(.03);assert(endpoint()>fixed, 'Only move preview after meal completes')
power=290;feed();tick(.2);fixed=endpoint()
now=now+.5;power=300;feed(184220);tick(.1)
assert(endpoint()==fixed, 'Unrelated energize cannot restart meal')
tick(.6);assert(endpoint()>fixed, 'Interrupted meal releases forecast after missing next tick')
print('PASS: feeding pins endpoint, ticks fill preview, completion and interruption unlock it')

-- Drag vertically anywhere on screen, keep X locked and persist across initialization.
buffs={};transformed=true;events.update()
local originalY=root.anchor[5]
assert(root.handlers and root.handlers.OnMouseDown, 'HUD needs cursor dragging')
root.handlers.OnMouseDown(root,1)
mouseX=900;mouseY=300
root.handlers.OnUpdate()
assert(root.anchor[4]==500 and root.anchor[5]==originalY+100, 'Only vertical cursor delta applies')
refresh();assert(root.anchor[5]==originalY+100, 'Resource polling cannot undo drag')
events[EVENT_GLOBAL_MOUSE_UP](EVENT_GLOBAL_MOUSE_UP,1)
assert(KanaAurasSettings.wolfY==originalY+100 and not root.handlers.OnUpdate)
mouseY=100;refresh();assert(root.anchor[5]==originalY+100, 'Released cursor no longer moves HUD')
root.handlers.OnMouseDown(root,1);mouseY=2000;root.handlers.OnUpdate()
assert(root.anchor[5]==1080, 'Clamp at screen bottom, not old gap limit')
mouseY=-2000;root.handlers.OnUpdate();assert(root.anchor[5]==150, 'Keep whole HUD on screen')
events[EVENT_GLOBAL_MOUSE_UP](EVENT_GLOBAL_MOUSE_UP,1)
dofile('WerewolfForm.lua');events[1](1,'KanaAuras')
root=controls.KanaWerewolfFormWindow
assert(root.anchor[5]==150, 'Saved position survives reload')
SLASH_COMMANDS['/kanawolf']('height reset')
assert(KanaAurasSettings.wolfY==nil and root.anchor[5]==290, 'Reset restores ring-relative positioning')
print('PASS: vertical drag, locked X, polling, global release, screen limits, persistence and reset')

-- Clockwise from top: right upper, right lower, left lower, left upper.
transformed=true;buffs={};fury=125;events.update();now=now+.3;events.update()
local q={}
for i=1,4 do q[i]=controls['KanaWerewolfFormBorder'..i] end
assert(not q[1].hidden and q[2].hidden and q[3].hidden and q[4].hidden)
assert(math.abs(q[1].width-34/math.sqrt(2))<.001)
assert(math.abs(controls.KanaWerewolfFormBorderPlane.transformRotation-math.pi/4)<.001, 'Crop in side-aligned coordinates: cut must be perpendicular to diamond edge')
fury=750;events.update();now=now+.3;events.update()
assert(not q[3].hidden and q[4].hidden)
assert(controls.KanaWerewolfFormWolf.color[2]==1, 'Wolf stays silver before full Fury')
fury=1000;events.update();now=now+.3;events.update()
assert(not q[4].hidden and controls.KanaWerewolfFormWolf.color[3]<.5)
buffs={{'Rampage',now,now+20,1,1,'','',1,1,0,267418,false,true}}
events.update();now=now+5;events.update()
assert(q[4].hidden and not q[3].hidden, 'Red perimeter drains counterclockwise from top')
assert(controls.KanaWerewolfFormWolf.color[2]<.2)
assert(controls.KanaWerewolfFormCrest.anchor[5]==64, 'Crest overlaps remaining form bar')
print('PASS: diamond clockwise fill, silver until full, reverse red drain, single bar layout')

-- AetherChat can load/show later. Keep all HUD descendants below the chat tier.
assert(root.tier==DT_LOW, 'HUD belongs to the low draw tier')
local chatTier=DT_LOW
AetherChat_MessengerWindow={GetDrawTier=function() return chatTier end,
 SetDrawTier=function(_, value) chatTier=value end}
events.update();assert(chatTier==DT_MEDIUM, 'Late AetherChat window must cover HUD')
chatTier=DT_HIGH;events.update();assert(chatTier==DT_HIGH, 'Never lower an elevated chat window')
AetherChat_MessengerWindow=nil;events.update()
print('PASS: HUD below AetherChat, late loading, existing higher tier and absent addon')

-- Feeding overlay is driven by real award events, independent of predicted gain.
transformed=false;events.update();transformed=true;buffs={};power=200;events.update()
local meal=controls.KanaWerewolfFormMeal
assert(meal and meal.hidden, 'No feeding indicator outside a meal')
feed(184220);assert(meal.hidden, 'Other energize events cannot start feeding UI')
power=215;feed();assert(not meal.hidden)
local halo=controls.KanaWerewolfFormMealHalo1
assert(not halo.hidden and halo.width==72 and halo.height==44 and halo.color[4]>.9, 'Award blooms beyond the checkpoint')
local line=controls.KanaWerewolfFormMealLine
local spark=controls.KanaWerewolfFormMealSpark
local startX=spark.anchor[4]
now=now+.5;events.update()
assert(spark.anchor[4]<startX and line.width<258, 'Countdown moves from right to left')
for i=2,5 do
 assert(controls['KanaWerewolfFormMealTick'..i].color[4]>.3 and controls['KanaWerewolfFormMealTick'..i].color[4]<.6, 'Upcoming checkpoints subdued but visible')
 assert(controls['KanaWerewolfFormMealFlash'..i].hidden, 'Only actual awards flash')
 assert(controls['KanaWerewolfFormMealHalo'..i].hidden, 'Future checkpoints have no halo')
end
for i=2,5 do
 now=now+(i==2 and .5 or 1);power=power+15;feed()
 assert(controls['KanaWerewolfFormMealTick'..i].color[4]>=.9, 'Actual award lights its checkpoint')
end
assert(spark.anchor[4]==21, 'Fifth award reaches left endpoint')
now=now+.3;events.update();assert(not meal.hidden and meal.alpha<1)
now=now+.3;events.update();assert(meal.hidden, 'Completion fades out')
power=300;feed();now=now+1.35;events.update();assert(not meal.hidden and meal.alpha<1)
now=now+.3;events.update();assert(meal.hidden, 'Missing next tick fades interrupted meal')
feed();transformed=false;events.update();assert(meal.hidden, 'Form exit clears overlay')
print('PASS: feeding overlay starts on award, smooth reverse motion, five real checkpoints, fade and interruption')
