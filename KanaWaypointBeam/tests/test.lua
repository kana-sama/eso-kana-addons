-- Run from eso-kana-addons: lua KanaWaypointBeam/tests/test.lua
CT_TEXTURE = 1
MAP_PIN_TYPE_PLAYER_WAYPOINT = 2
PING_EVENT_ADDED = 1
PING_EVENT_REMOVED = 2
EVENT_ADD_ON_LOADED = 3
EVENT_MAP_PING = 4
EVENT_PLAYER_ACTIVATED = 5

local events = {}
local pingCallbacks = {}
local updates = {}
EVENT_MANAGER = {
    RegisterForEvent = function(_, name, event, callback) events[event] = callback end,
    UnregisterForEvent = function() end,
    RegisterForUpdate = function(_, name, _, callback) updates[name] = callback end,
}

local function control(name)
    return {
        name = name,
        SetHidden = function(self, hidden) self.hidden = hidden end,
        IsHidden = function(self) return self.hidden end,
        Create3DRenderSpace = function(self) self.is3D = true end,
        SetTexture = function(self, path) self.texture = path end,
        SetColor = function(self, r, g, b, a) self.color = {r, g, b, a} end,
        Set3DRenderSpaceUsesDepthBuffer = function(self, value) self.depth = value end,
        Set3DRenderSpaceOrigin = function(self, x, z, y) self.origin = {x, z, y} end,
        Set3DLocalDimensions = function(self, width, height) self.size = {width, height} end,
        Set3DRenderSpaceOrientation = function(self, ...) self.orientation = {...} end,
    }
end

local controls = {}
GuiRoot = {}
WINDOW_MANAGER = {
    CreateTopLevelWindow = function(_, name)
        controls[name] = control(name)
        return controls[name]
    end,
    CreateControl = function(_, name)
        controls[name] = control(name)
        return controls[name]
    end,
}

local waypointX, waypointY = 0, 0
local playerX, playerY = 10000, 20000
function GetMapPlayerWaypoint() return waypointX, waypointY end
function GetPlayerCameraHeading() return 0.75 end
function GetUnitRawWorldPosition() return 1, playerX, 30000, playerY end
function WorldPositionToGuiRender3DPosition(x, z, y) return x, z, y end
LibGPS3 = {
    LocalToWorld = function(_, x, y)
        if x == 0.25 and y == 0.75 then return 10000, 30000, 20000 end
    end,
}
LibMapPing2 = {
    RegisterCallback = function(_, name, callback) pingCallbacks[name] = callback end,
}

dofile("KanaWaypointBeam/KanaWaypointBeam.lua")
assert(events[EVENT_ADD_ON_LOADED], "addon must register initialization")
events[EVENT_ADD_ON_LOADED](EVENT_ADD_ON_LOADED, "KanaWaypointBeam")
assert(controls.KanaWaypointBeamRoot.is3D,
    "3D beam parent must have render space, as in HarvestMap")
local beam = controls.KanaWaypointBeamTexture
assert(beam and beam.hidden, "beam must start hidden")

waypointX, waypointY = 0.25, 0.75
assert(pingCallbacks.AfterPingAdded, "waypoint callback must handle delayed ping events")
pingCallbacks.AfterPingAdded(MAP_PIN_TYPE_PLAYER_WAYPOINT, "waypoint", waypointX, waypointY, true)
assert(not beam.hidden, "waypoint should show beam")
assert(beam.is3D and beam.origin[1] == 100 and beam.origin[3] == 200,
    "beam should be anchored to waypoint world position")
local lowest, highest = math.huge, -math.huge
for name, segment in pairs(controls) do
    if name:match("^KanaWaypointBeamTexture") and not segment.hidden then
        lowest = math.min(lowest, segment.origin[2] - segment.size[2] / 2)
        highest = math.max(highest, segment.origin[2] + segment.size[2] / 2)
    end
end
assert(highest - lowest >= 4000, "beam should cover several kilometers vertically")
assert(beam.color[3] > beam.color[1] and beam.color[3] > beam.color[2],
    "beam should be blue")
assert(controls.KanaWaypointBeamRoot.depth == true,
    "beam parent should use the scene depth buffer")
for name, segment in pairs(controls) do
    if name:match("^KanaWaypointBeamTexture") then
        assert(segment.depth == true, "every part of the beam should be hidden by world geometry")
    end
end
assert(beam.size[1] <= 6, "nearby beam should stay narrow")
playerX, playerY = 210000, 20000
updates.KanaWaypointBeamFaceCamera()
assert(beam.size[1] >= 25, "beam must widen when the player is far away")

waypointX, waypointY = 0, 0
pingCallbacks.AfterPingRemoved(MAP_PIN_TYPE_PLAYER_WAYPOINT, "waypoint", 0, 0, true)
for name, segment in pairs(controls) do
    if name:match("^KanaWaypointBeamTexture") then
        assert(segment.hidden, "removing waypoint should hide the entire beam")
    end
end

print("KanaWaypointBeam behavior OK")
