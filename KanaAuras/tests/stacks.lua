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
dofile('KanaAuras.lua')
events[1](1, 'OtherAddon')
assert(not controls.KanaAurasWindow)
events[1](1, 'KanaAuras')
local left, right, top = controls.KanaAurasLeft, controls.KanaAurasRight, controls.KanaAurasTop
assert(left and right and top, 'Must create left, right and top stack segments')
assert(controls.KanaAurasWindow.anchor[2] == ZO_ReticleContainerReticle,
    'Segments must follow the reticle rather than the old row offset')
local function check(a, b, c)
    events.update()
    if c then
        assert(left.hidden and right.hidden and top.hidden, 'Full-stack artwork must replace base sprites without doubled contours')
    else
        assert(not left.hidden == a and not right.hidden == b and top.hidden,
            'Incorrect segment visibility')
    end
    local glow = controls.KanaAurasGlow
    assert(glow, 'Full-stack fire glow must exist')
    assert(not glow.hidden == c, 'Glow must appear only at three stacks and clear immediately below three')
end
local function aura(name, stacks, finish)
    return {name, 10, finish or 30, 1, stacks, 'aura.dds', '', 1, 1, 0, 42, false, true}
end
check(false, false, false)
for _, value in ipairs({1, 2, 3, 2, 1, 0, 7}) do
    buffs = {aura('Кипящая ярость', value)}
    check(value >= 1, value >= 2, value >= 3)
end
buffs = {aura('Горение', 3), aura('Кипящая ярость героя', 3)}
check(false, false, false)
buffs = {aura('КИПЯЩАЯ ЯРОСТЬ^f', 2)}
check(true, true, false)
buffs = {aura('Кипящая ярость', 1), aura('Кипящая ярость', 2)}
check(true, true, false) -- Duplicate records must not invent a third stack.
now = 30
check(false, false, false)
buffs = {aura('Кипящая ярость', 3, 0)}
check(true, true, true)
local glow = controls.KanaAurasGlow
assert(glow.handlers and glow.handlers.OnUpdate, 'Three stacks must start frame animation')
local halo = controls.KanaAurasHaloLeft
assert(halo, 'Three stacks need an animated outer fire halo')
local before = halo.width
now = now + 0.17
glow.handlers.OnUpdate()
assert(halo.width ~= before, 'Fire halo must move over time')
assert(halo.width == halo.height, 'Animation must preserve circular proportions')
local activeHandler = glow.handlers.OnUpdate
events.update()
assert(glow.handlers.OnUpdate == activeHandler, 'Polling must not restart animation')
buffs = {aura('Кипящая ярость', 2, 0)}
check(true, true, false)
assert(not glow.handlers.OnUpdate, 'Losing third stack must stop frame animation')
buffs = {aura('Кипящая ярость', 3, 0)}
check(true, true, true)
assert(glow.handlers.OnUpdate, 'Regaining third stack must restart fire animation')
buffs = {}
check(false, false, false)
assert(not glow.handlers.OnUpdate, 'Removing aura must stop animation')
print('PASS: 0/1/2/3 stacks, decreasing stacks, clamp, exact aura, duplicates, expiry, removal, reticle anchor')
