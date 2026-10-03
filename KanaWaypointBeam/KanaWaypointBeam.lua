local ADDON_NAME = "KanaWaypointBeam"
local BEAM_HEIGHT = 4000 -- meters; kept in shorter pieces for render-space clipping
local SEGMENT_HEIGHT = 500 -- meters
local BELOW_PLAYER = 300 -- meters; waypoint map coordinates do not include elevation
local MIN_WIDTH = 4 -- meters nearby
local MAX_WIDTH = 60 -- meters at long range

local root
local beams = {}
local beamWorldX
local beamWorldY

local function HideBeam()
    for _, beam in ipairs(beams) do beam:SetHidden(true) end
end

local function UpdateAppearance()
    if beams[1]:IsHidden() then return end
    local _, playerX, _, playerY = GetUnitRawWorldPosition("player")
    local width = MIN_WIDTH
    if playerX and playerY then
        local dx = (beamWorldX - playerX) / 100
        local dy = (beamWorldY - playerY) / 100
        local distance = math.sqrt(dx * dx + dy * dy)
        width = math.max(MIN_WIDTH, math.min(MAX_WIDTH, distance / 50))
    end
    local heading = GetPlayerCameraHeading()
    for _, beam in ipairs(beams) do
        beam:Set3DLocalDimensions(width, SEGMENT_HEIGHT)
        beam:Set3DRenderSpaceOrientation(0, heading, 0)
    end
end

local function UpdateBeam(x, y)
    if not x or not y or (x == 0 and y == 0) then
        HideBeam()
        return
    end

    local worldX, worldHeight, worldY = LibGPS3:LocalToWorld(x, y)
    if not worldX or not worldHeight or not worldY then
        HideBeam()
        return
    end

    local centerHeight = worldHeight / 100 - BELOW_PLAYER + BEAM_HEIGHT / 2
    beamWorldX, beamWorldY = worldX, worldY
    for index, beam in ipairs(beams) do
        local offset = (index - 0.5) * SEGMENT_HEIGHT - BEAM_HEIGHT / 2
        beam:Set3DRenderSpaceOrigin(worldX / 100, centerHeight + offset, worldY / 100)
        beam:SetHidden(false)
    end
    UpdateAppearance()
end

local function RefreshWaypoint()
    UpdateBeam(GetMapPlayerWaypoint())
end

local function Initialize()
    root = WINDOW_MANAGER:CreateTopLevelWindow("KanaWaypointBeamRoot")
    root:Create3DRenderSpace()
    root:Set3DRenderSpaceUsesDepthBuffer(true)
    for index = 1, BEAM_HEIGHT / SEGMENT_HEIGHT do
        local name = "KanaWaypointBeamTexture" .. (index == 1 and "" or index)
        local beam = WINDOW_MANAGER:CreateControl(name, root, CT_TEXTURE)
        beam:Create3DRenderSpace()
        beam:SetTexture("eso-kana-addons/KanaWaypointBeam/beam.dds")
        beam:SetColor(0.05, 0.35, 1, 0.85)
        beam:Set3DRenderSpaceUsesDepthBuffer(true)
        beam:SetHidden(true)
        beams[index] = beam
    end

    LibMapPing2:RegisterCallback("AfterPingAdded", function(pingType, _, x, y)
        if pingType == MAP_PIN_TYPE_PLAYER_WAYPOINT then UpdateBeam(x, y) end
    end)
    LibMapPing2:RegisterCallback("AfterPingRemoved", function(pingType)
        if pingType == MAP_PIN_TYPE_PLAYER_WAYPOINT then HideBeam() end
    end)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, function()
        local originX, originHeight, originY = WorldPositionToGuiRender3DPosition(0, 0, 0)
        root:Set3DRenderSpaceOrigin(originX, originHeight, originY)
        RefreshWaypoint()
    end)
    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "FaceCamera", 100, UpdateAppearance)
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "Load", EVENT_ADD_ON_LOADED, function(_, addonName)
    if addonName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. "Load", EVENT_ADD_ON_LOADED)
    Initialize()
end)
