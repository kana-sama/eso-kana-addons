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

K.nameLabels = {}
local NAME_OFFSETS = {{-3,-3}, {-3,0}, {-3,3}, {0,-3}, {0,3}, {3,-3}, {3,0}, {3,3}}
local MIN_NAME_SCALE = 0.75

local function CreateNameControl(name, parent, color, tier, level)
    local label = WINDOW_MANAGER:CreateControl(name, parent, CT_LABEL)
    label:SetFont("$(HANDWRITTEN_FONT)|34")
    label:SetColor(color[1], color[2], color[3], color[4])
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetDrawLayer(DL_OVERLAY)
    label:SetDrawTier(tier)
    label:SetDrawLevel(level)
    label:SetPixelRoundingEnabled(false)
    label:SetMouseEnabled(false)
    return label
end

function K:ResetLabels()
    for _, entry in pairs(self.nameLabels) do
        entry.label:SetHidden(true)
        for _, stroke in ipairs(entry.outline) do stroke:SetHidden(true) end
    end
    self.nameSignature = nil
    self.nameParent = nil
    self.visibleNames = 0
    if self.nativeNamesManager then
        local manager = self.nativeNamesManager
        manager.blobNameLabelControlPool:ReleaseAllObjects()
        manager.blobNamesVisible = false
        manager.blobNamesReset = true
        manager.blobNamesDirty = true
        self.nativeNamesManager = nil
    end
end

function K:ShowLabels(tilesManager)
    if not self.saved or not self.saved.enabled or GetCurrentMapId() ~= TAMRIEL_MAP_ID
        or not tilesManager or not GetNumMapBlobs or not GetMapBlobNameInfo
        or not g_mapPanAndZoom then return end
    local parent = tilesManager.parent
    local _, zoomMax = g_mapPanAndZoom:GetZoomMinMax()
    if not zoomMax or zoomMax <= 0 then return end
    local zoom = (WORLD_MAP_MANAGER and WORLD_MAP_MANAGER.lastBlobZoom or zoomMax) / zoomMax
    local count = GetNumMapBlobs()
    local mapWidth, mapHeight = ZO_MAP_CONSTANTS.MAP_WIDTH, ZO_MAP_CONSTANTS.MAP_HEIGHT
    local signature = string.format("%d|%.6f|%.2f|%.2f", count, zoom, mapWidth, mapHeight)
    if self.nameSignature == signature and self.nameParent == parent then return end
    self.nameSignature, self.nameParent = signature, parent
    self.visibleNames = 0
    for index = 1, count do
        local name, x, y, width, nameScale = GetMapBlobNameInfo(index)
        local entry = self.nameLabels[index]
        if name and name ~= "" and x and y and width and nameScale and nameScale > 0 then
            if not entry then
                entry = {outline={}}
                for i = 1, #NAME_OFFSETS do
                    entry.outline[i] = CreateNameControl(NAME .. "MapName" .. index .. "Outline" .. i,
                        parent, {0, 0, 0, 1}, DT_MEDIUM, 5)
                end
                entry.label = CreateNameControl(NAME .. "MapName" .. index, parent,
                    {1, 1, 1, 1}, DT_HIGH, 6)
                self.nameLabels[index] = entry
            end
            local text = zo_strformat(SI_ZONE_NAME, name)
            local scale = math.max(MIN_NAME_SCALE, zoom * nameScale)
            local uiWidth = math.max(100, width * mapWidth) / scale
            local centerX, centerY = x * mapWidth, y * mapHeight
            for i, stroke in ipairs(entry.outline) do
                stroke:SetParent(parent)
                stroke:SetText(text)
                stroke:SetWidth(uiWidth)
                stroke:SetScale(scale)
                stroke:ClearAnchors()
                stroke:SetAnchor(CENTER, parent, TOPLEFT,
                    centerX + NAME_OFFSETS[i][1], centerY + NAME_OFFSETS[i][2])
                stroke:SetHidden(false)
            end
            local label = entry.label
            label:SetParent(parent)
            label:SetText(text)
            label:SetWidth(uiWidth)
            label:SetScale(scale)
            label:ClearAnchors()
            label:SetAnchor(CENTER, parent, TOPLEFT, centerX, centerY)
            label:SetHidden(false)
            self.visibleNames = self.visibleNames + 1
        elseif entry then
            entry.label:SetHidden(true)
            for _, stroke in ipairs(entry.outline) do stroke:SetHidden(true) end
        end
    end
    for index, entry in pairs(self.nameLabels) do
        if index > count then
            entry.label:SetHidden(true)
            for _, stroke in ipairs(entry.outline) do stroke:SetHidden(true) end
        end
    end
end

function K:UpdateLabels(worldManager)
    if not self.activeManager or GetCurrentMapId() ~= TAMRIEL_MAP_ID then
        if self.visibleNames and self.visibleNames > 0 or self.nativeNamesManager then
            self:ResetLabels()
        end
        return
    end
    self:ShowLabels(self.activeManager)
    if self.visibleNames > 0 and worldManager.blobNameLabelControlPool then
        for _, label in worldManager.blobNameLabelControlPool:ActiveObjectIterator() do
            label:SetHidden(true)
        end
        self.nativeNamesManager = worldManager
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
        control:ClearAnchors()
        control:SetAnchor(TOPLEFT, manager.parent, TOPLEFT,
            zone.x * ZO_MAP_CONSTANTS.MAP_WIDTH, zone.y * ZO_MAP_CONSTANTS.MAP_HEIGHT)
        control:SetDimensions(zone.width * ZO_MAP_CONSTANTS.MAP_WIDTH,
            zone.height * ZO_MAP_CONSTANTS.MAP_HEIGHT)
    end
    if self.visibleNames and self.visibleNames > 0 then self:ShowLabels(manager) end
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
    self:ShowLabels(manager)
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
