local controls, events = {}, {}
local now, exists, attackable, dead = 10, true, true, false
local buffs = {}
local methods = {}
for _, name in ipairs({'SetAnchor', 'SetAnchorFill', 'SetMouseEnabled', 'SetFont', 'SetHorizontalAlignment', 'SetVerticalAlignment', 'SetBlendMode', 'SetMinMax'}) do
    methods[name] = function() end
end
function methods:SetDimensions(w,h) self.width,self.height=w,h end
function methods:SetHidden(v) self.hidden=v end
function methods:SetTexture(v) self.texture=v end
function methods:SetText(v) self.text=v end
function methods:SetColor(...) self.color={...} end
function methods:SetDesaturation(v) self.desaturation=v end
function methods:SetValue(v) self.value=v end
function methods:SetHandler(e,v) self.handlers=self.handlers or {}; self.handlers[e]=v end
local function control(name)
    local c=setmetatable({}, {__index=methods}); controls[name]=c; return c
end
WINDOW_MANAGER={CreateControl=function(_,name) return control(name) end, CreateTopLevelWindow=function(_,name) return control(name) end}
EVENT_ADD_ON_LOADED,EVENT_PLAYER_ACTIVATED,EVENT_RETICLE_TARGET_CHANGED=1,2,3
EVENT_MANAGER={RegisterForEvent=function(_,_,event,fn) events[event]=fn end, UnregisterForEvent=function(_,_,event) events[event]=nil end, RegisterForUpdate=function(_,_,_,fn) events.update=fn end}
HUD_SCENE={AddFragment=function() end}; HUD_UI_SCENE=HUD_SCENE
ZO_SimpleSceneFragment={New=function(_,root) return root end}
GetFrameTimeSeconds=function() return now end
DoesUnitExist=function(unit) assert(unit=='reticleover'); return exists end
IsUnitAttackable=function() return attackable end
IsUnitDead=function() return dead end
GetNumBuffs=function(unit) assert(unit=='reticleover'); return #buffs end
GetUnitBuffInfo=function(_,i) return unpack(buffs[i]) end
SLASH_COMMANDS={}
local file=io.open('HeatShock.lua'); assert(file, 'Heat Shock tracker is not implemented'); file:close()
dofile('HeatShock.lua'); events[1](1,'KanaAuras')
local content=controls.KanaHeatContent
local function aura(n,ending,id)
    return {'Тепловой шок', 7, ending, 1, n, 'test.dds', '', 1, 1, 0, id or 134340, false, false}
end
local function check(count,urgent)
    events.update()
    assert(content.hidden == (count == 0), 'Hide stones and timer together when no stacks remain')
    for i=1,3 do assert(controls['KanaHeatStone'..i].desaturation==(i<=count and 0 or 1)) end
    assert(controls.KanaHeatWarning.hidden==not urgent)
end
check(0,false)
buffs={aura(1,14)}; check(1,false)
assert(math.abs(controls.KanaHeatBar.value-4/7)<0.0001)
buffs={aura(3,12)}; check(3,false) -- Exactly 2 seconds is not urgent.
now=10.1; check(3,true)
assert(controls.KanaHeatWarning.text=='ОБНОВИ')
assert(content.handlers.OnUpdate, 'Urgency starts pulse')
now=12; check(0,false)
assert(not content.handlers.OnUpdate, 'Expiry stops pulse')
buffs={aura(3,19)}; check(3,false)
-- Target changes to one without the aura: no stale stacks or timer.
buffs={}; events[3](); check(0,false)
assert(controls.KanaHeatBar.value==0)
buffs={aura(3,17,999)}; check(0,false) -- Same name is insufficient with wrong ID.
buffs={aura(2,17),aura(3,17)}; check(3,false) -- Shared effect is not summed.
for _, state in ipairs({'missing','friendly','dead'}) do
    exists=state~='missing'; attackable=state~='friendly'; dead=state=='dead'
    events[3](); assert(content.hidden)
    assert(not content.handlers.OnUpdate)
end
exists,attackable,dead=true,true,false
buffs={aura(3,13)}; now=12.5; check(3,true)
print('PASS: Heat Shock ID, real target stacks/time, urgent boundary, refresh, expiry, target changes, pulse lifecycle')
