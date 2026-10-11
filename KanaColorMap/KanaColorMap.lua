KanaColorMap = {}
local K = KanaColorMap
local NAME = "KanaColorMap"
local TAMRIEL_MAP_ID = 27
local TILE_COUNT = 16
K.overlays = {}

local function NormalizePath(path)
    if type(path) ~= "string" then return nil end
    return path:lower():gsub("\\", "/"):gsub("^/", "")
end

K.nativeNameColors = {}

function K:ResetLabels()
    for label, colors in pairs(self.nativeNameColors) do
        label:SetColor(unpack(colors.foreground))
        if colors.shadow and label.shadowLabel then
            label.shadowLabel:SetColor(unpack(colors.shadow))
        end
    end
    self.nativeNameColors = {}
    self.visibleNames = 0
end

function K:UpdateLabels(worldManager)
    if not self.saved or not self.saved.enabled or not self.activeManager
        or GetCurrentMapId() ~= TAMRIEL_MAP_ID then
        self:ResetLabels()
        return
    end
    self.visibleNames = 0
    if not worldManager.blobNameLabelControlPool then return end
    for _, label in worldManager.blobNameLabelControlPool:ActiveObjectIterator() do
        if not self.nativeNameColors[label] then
            local r, g, b, a = label:GetColor()
            local colors = {foreground={r, g, b, a}}
            if label.shadowLabel then
                r, g, b, a = label.shadowLabel:GetColor()
                colors.shadow = {r, g, b, a}
            end
            self.nativeNameColors[label] = colors
        end
        label:SetColor(1, 1, 1, 1)
        if label.shadowLabel then label.shadowLabel:SetColor(0, 0, 0, 1) end
        self.visibleNames = self.visibleNames + 1
    end
end

function K:Reset()
    self:ResetLabels()
    if self.hoverState then
        local state = self.hoverState
        if state.control:GetDrawLevel() == state.appliedLevel then
            state.control:SetDrawLevel(state.originalLevel)
        end
        self.hoverState = nil
    end
    for _, entry in pairs(self.overlays) do
        entry.control:SetHidden(true)
        if entry.border then entry.border:SetHidden(true) end
    end
    self.activeManager = nil
    self.visibleZones = 0
end

function K:Layout(manager)
    if self.activeManager ~= manager then return end
    for _, entry in pairs(self.overlays) do
        local zone, control = entry.zone, entry.control
        local renderX, renderY = zone.renderX or zone.x, zone.renderY or zone.y
        local renderWidth = zone.renderWidth or zone.width
        local renderHeight = zone.renderHeight or zone.height
        control:ClearAnchors()
        control:SetAnchor(TOPLEFT, manager.parent, TOPLEFT,
            renderX * ZO_MAP_CONSTANTS.MAP_WIDTH,
            renderY * ZO_MAP_CONSTANTS.MAP_HEIGHT)
        control:SetDimensions(renderWidth * ZO_MAP_CONSTANTS.MAP_WIDTH,
            renderHeight * ZO_MAP_CONSTANTS.MAP_HEIGHT)
    end
end

local function MatchesNativeZone(zone)
    local _, path, width, height, x, y, mapId = GetMapMouseoverInfo(zone.probeX, zone.probeY)
    if mapId ~= zone.id or NormalizePath(path) ~= NormalizePath(zone.sourceMask) then return false end
    local epsilon = 0.00001
    return math.abs(width - zone.width) < epsilon and math.abs(height - zone.height) < epsilon
        and math.abs(x - zone.x) < epsilon and math.abs(y - zone.y) < epsilon
end

function K:Apply(manager)
    self:Reset()
    if not self.saved or not self.saved.enabled or not manager or not KanaColorMapData
        or GetCurrentMapId() ~= TAMRIEL_MAP_ID then return end
    local columns, rows = GetMapNumTiles()
    if columns ~= 4 or rows ~= 4 then return end

    -- Never replace or desaturate the world atlas. Original parchment remains visible
    -- everywhere outside the exact alpha masks of existing, recognized zones.
    for i = 1, TILE_COUNT do
        local original = string.format("art/maps/tamriel/tamriel_%d.dds", i - 1)
        local tile = manager:GetActiveObject(i)
        if not tile or NormalizePath(GetMapTileTexture(i)) ~= original
            or NormalizePath(tile:GetTextureFileName()) ~= original then
            return
        end
    end

    for _, zone in ipairs(KanaColorMapData.zones) do
        if MatchesNativeZone(zone) then
            local entry = self.overlays[zone.id]
            if not entry then
                local control = WINDOW_MANAGER:CreateControl(NAME .. "Zone" .. zone.id, manager.parent, CT_TEXTURE)
                control:SetMouseEnabled(false)
                -- Art at 1, every contour at 2, native hover temporarily at 3.
                control:SetDrawLevel(1)
                control:SetPixelRoundingEnabled(false)
                control:SetMaskMode(CONTROL_MASK_MODE_BASIC)
                control:SetMaskTexture(zone.mask)
                control:SetTexture(zone.art)
                entry = {control = control, zone = zone}
                if zone.border then
                    local border = WINDOW_MANAGER:CreateControl(NAME .. "Border" .. zone.id, manager.parent, CT_TEXTURE)
                    border:SetMouseEnabled(false)
                    -- All contours above ALL zone artwork, including neighbors.
                    border:SetDrawLevel(2)
                    border:SetPixelRoundingEnabled(false)
                    border:SetAnchorFill(control)
                    border:SetTexture(zone.border)
                    entry.border = border
                end
                self.overlays[zone.id] = entry
            end
            entry.control:SetParent(manager.parent)
            entry.control:SetHidden(false)
            if entry.border then
                entry.border:SetParent(manager.parent)
                entry.border:SetHidden(false)
            end
            self.visibleZones = self.visibleZones + 1
        end
    end
    if self.visibleZones == 0 then return end
    -- Preserve native hover above the new contour pass; restore on reset/off.
    local hover = manager.parent:GetNamedChild("MouseoverBlob")
    if hover then
        local level = hover:GetDrawLevel()
        local appliedLevel = math.max(level, 3)
        self.hoverState = {control=hover, originalLevel=level, appliedLevel=appliedLevel}
        hover:SetDrawLevel(appliedLevel)
    end
    self.activeManager = manager
    self:Layout(manager)
end

function K:Refresh()
    if WORLD_MAP_TILES_MANAGER then
        WORLD_MAP_TILES_MANAGER:UpdateTextures()
    else
        self:Reset()
    end
end

function K:Command(text)
    local command = (text or ""):lower():match("^%s*(.-)%s*$")
    if command == "on" or command == "off" then
        self.saved.enabled = command == "on"
        self:Refresh()
    elseif command ~= "" and command ~= "status" then
        d("KanaColorMap: /kcm on | off | status")
        return
    end
    d("KanaColorMap: " .. (self.saved.enabled and "включено" or "выключено")
        .. "; цветных зон: " .. tostring(self.visibleZones or 0)
        .. "; названий: " .. tostring(self.visibleNames or 0))
end

local function OnLoaded(_, addonName)
    if addonName ~= NAME or K.initialized then return end
    K.initialized = true
    EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED)
    K.saved = ZO_SavedVars:NewAccountWide("KanaColorMapSV", 1, nil, { enabled = true })

    ZO_PostHook(ZO_WorldMapTiles_Manager, "UpdateTextures", function(manager)
        K:Apply(manager)
    end)
    ZO_PostHook(ZO_WorldMapTiles_Manager, "LayoutTiles", function(manager)
        K:Layout(manager)
    end)
    if ZO_WorldMapManager then
        ZO_PostHook(ZO_WorldMapManager, "UpdateBlobs", function(manager)
            K:UpdateLabels(manager)
        end)
    end
    SLASH_COMMANDS["/kcm"] = function(text) K:Command(text) end
    K:Refresh()
end

EVENT_MANAGER:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, OnLoaded)
