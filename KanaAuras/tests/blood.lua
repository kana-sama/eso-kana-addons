local controls, events = {}, {}
SLASH_COMMANDS = {}
local now, buffs = 20, {}
local methods = {}
for _, method in ipairs({'SetMouseEnabled', 'SetMovable', 'SetDrawLayer', 'SetDrawLevel', 'SetTextureCoords', 'SetBlendMode'}) do
    methods[method] = function() end
end
function methods:SetDimensions(w, h) self.width, self.height = w, h end
function methods:SetAnchor(...) self.anchor = {...} end
function methods:SetAnchorFill(other) self.fill = other end
function methods:SetHidden(value) self.hidden = value end
function methods:SetTexture(value) self.texture = value end
function methods:SetColor(...) self.color = {...} end
function methods:SetTextureRotation(value) self.rotation = value end
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
CENTER = 'CENTER'
ZO_SimpleSceneFragment = {New = function(_, root) return root end}
HUD_SCENE = {AddFragment = function() end}
HUD_UI_SCENE = HUD_SCENE
zo_strformat = function(_, text) return (text:gsub('%^.*$', '')) end
GetFrameTimeSeconds = function() return now end
GetNumBuffs = function(unit) assert(unit == 'player'); return #buffs end
GetUnitBuffInfo = function(unit, i) assert(unit == 'player'); return unpack(buffs[i]) end
local file=io.open('BloodHunger.lua'); assert(file, 'Blood Hunger tracker missing'); file:close()
dofile('BloodHunger.lua')
local parent=control('SharedFrame')
local update=KanaAurasCreateBloodSockets(parent)
events.update=function() update(true) end
local content=controls.KanaBloodHungerContent
local full=controls.KanaBloodHungerFull
local function aura(count,ending,id)
    return {'Any language',0,ending or 0,1,count,'', '',1,1,0,id or 267744,false,true}
end
local function check(n)
    events.update()
    assert(not content.hidden, 'Empty sockets remain visible in form')
    assert(full.hidden == (n ~= 4), 'Full glow only at four stacks')
    assert((full.handlers and full.handlers.OnUpdate ~= nil or false) == (n == 4))
    for i=1,4 do
        assert(controls['KanaBloodHungerActive'..i].hidden == (i>n or n==4))
    end
end
check(0)
for _,n in ipairs({1,2,3,4,3,4,0}) do buffs={aura(n)}; check(n) end
buffs={aura(4,0,184220)}; check(0)
buffs={aura(2),aura(1)}; check(2)
buffs={aura(9)}; check(4)
local smoke=controls.KanaBloodHungerSmoke1
local shimmer=smoke.color[4]
local color=controls.KanaBloodHungerGlow1.color[4]
now=now+0.2; full.handlers.OnUpdate()
assert(smoke.color[4]~=shimmer, 'Blood texture shimmers within the fixed segment')
assert(controls.KanaBloodHungerGlow1.color[4]~=color, 'Full charge must pulse')
local callback=full.handlers.OnUpdate
events.update(); assert(full.handlers.OnUpdate==callback)
buffs={aura(4,now)}; check(0)
buffs={}; check(0)
local previousX=-100
assert(controls.KanaBloodHungerContent.fill==parent, 'Sockets share form frame')
for i=1,4 do
    local a=controls['KanaBloodHungerActive'..i].anchor
    local orb=controls['KanaBloodHungerActive'..i]
    assert(a[4]>previousX, 'Sockets fill left to right')
    assert(orb.width==60 and orb.height==12, 'Stacks use slim equal-height segments')
    assert(75+a[5]-orb.height/2==99, 'Segments align immediately below the bar with a 4-unit gap')
    if i>1 then assert(a[4]-previousX==64, 'Equal spacing between segments') end
    assert(75+a[5]+orb.height/2<=150, 'Sockets remain within draggable HUD')
    previousX=a[4]
end
buffs={aura(4)};check(4);update(false)
assert(content.hidden and not full.handlers.OnUpdate, 'Leaving form stops socket effects')
print('PASS: Blood Hunger sockets, states, expiry, animation lifecycle and shared frame')

buffs={};update(true)
buffs={aura(1)};update(true)
local orb=controls.KanaBloodHungerActive1
local flash=controls.KanaBloodHungerArrival1
local base=60
assert(orb.width==base and flash.width==base and not flash.hidden and content.handlers.OnUpdate)
local peak=flash.color[4]
now=now+.12;content.handlers.OnUpdate()
assert(orb.width==base and flash.width==base and flash.color[4]<peak, 'Light settles without resizing')
local flashed=flash.color[4];update(true)
assert(flash.color[4]==flashed, 'Polling must not restart arrival')
now=now+.31;content.handlers.OnUpdate()
assert(orb.width==base and flash.hidden and not content.handlers.OnUpdate)
buffs={aura(2)};update(true)
assert(flash.hidden and not controls.KanaBloodHungerArrival2.hidden, 'Only gained stack flashes')
buffs={aura(4)};update(true)
assert(not controls.KanaBloodHungerArrival4.hidden and controls.KanaBloodHungerCore4.width==base)
buffs={aura(1)};update(true)
assert(controls.KanaBloodHungerArrival4.hidden, 'Removed stack stops spring immediately')
update(false)
assert(not content.handlers.OnUpdate and not full.handlers.OnUpdate)
print('PASS: new-stack flash, brightness flash and settle, partial/full transitions, cancellation')

buffs={aura(4)};update(true)
for j=1,10 do
 now=now+.05
 full.handlers.OnUpdate()
 if content.handlers.OnUpdate then content.handlers.OnUpdate() end
 for i=1,4 do
  for _,name in ipairs({'Active','Core','Glow','Arrival','Dormant','Smoke'}) do
   local c=controls['KanaBloodHunger'..name..i]
   assert(c.width==60 and c.height==12, 'Every layer stays inside its fixed segment')
  end
 end
end
buffs={};check(0)
assert(not content.hidden and not full.handlers.OnUpdate and not content.handlers.OnUpdate)

assert(controls.KanaBloodHungerArrival1.texture=='eso-kana-addons/KanaAuras/textures/EsoBloodSegment1Flash.dds')
