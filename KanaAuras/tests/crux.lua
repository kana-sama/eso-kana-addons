local controls, events = {}, {}
SLASH_COMMANDS = {}
local now, buffs = 20, {}
local methods = {}
for _, method in ipairs({'SetMouseEnabled', 'SetMovable', 'SetDrawLayer', 'SetTextureCoords', 'SetBlendMode'}) do
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
local file=io.open('Crux.lua'); assert(file, 'Crux tracker missing'); file:close()
dofile('Crux.lua'); events[1](1,'KanaAuras')
local left,right,top=controls.KanaCruxLeft,controls.KanaCruxRight,controls.KanaCruxTop
local full=controls.KanaCruxFull
local function aura(count,ending,id)
    return {'Any language',0,ending or 0,1,count,'', '',1,1,0,id or 184220,false,true}
end
local function check(n)
    events.update()
    assert(left.hidden == (n == 0 or n == 3))
    assert(right.hidden == (n < 2 or n == 3))
    assert(top.hidden) -- Three stacks use the seamless full ring.
    assert(full.hidden == (n ~= 3))
    assert((full.handlers and full.handlers.OnUpdate ~= nil or false) == (n == 3))
end
check(0)
for _, n in ipairs({1,2,3,2,3,0}) do buffs={aura(n)}; check(n) end
buffs={aura(3,0,122658)}; check(0)
buffs={aura(2),aura(1)}; check(2)
buffs={aura(9)}; check(3)
local halo=controls.KanaCruxHalo1
local initial=halo.width
local initialRotation=halo.rotation
now=now+0.2; full.handlers.OnUpdate()
assert(halo.width~=initial and halo.width==halo.height, 'Pulse changes size without turning circle into oval')
assert(halo.rotation and halo.rotation ~= initialRotation, 'Smoke texture must move, not just pulse a static ring')
assert(controls.KanaCruxHalo2.rotation ~= halo.rotation, 'Smoke layers must move independently')
local callback=full.handlers.OnUpdate
events.update(); assert(callback==full.handlers.OnUpdate, 'Polling must not restart animation')
buffs={aura(3,now)}; check(0)
buffs={}; check(0)
print('PASS: Crux 0/1/2/3, exact ID, duplicate records, expiry, full ring, animation lifecycle')
