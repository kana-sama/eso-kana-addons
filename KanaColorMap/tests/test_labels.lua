local root = arg[0]:match('^(.*)/tests/[^/]+$') or '.'
unpack = unpack or table.unpack -- ESO uses Lua 5.1.
local mapId, zoom = 27, .08
EVENT_ADD_ON_LOADED = 1
SLASH_COMMANDS = {}
function GetCurrentMapId() return mapId end
function GetNumMapBlobs() return 1 end
function GetMapBlobNameInfo() return 'Ротгар', .5, .4, .2, 1 end
function zo_strformat(_, name) return name end
SI_ZONE_NAME = 1
ZO_MAP_CONSTANTS = {MAP_WIDTH=920, MAP_HEIGHT=920}
CT_LABEL, DL_OVERLAY, DT_HIGH, CENTER, TOPLEFT, TEXT_ALIGN_CENTER = 1, 2, 3, 4, 5, 6
function ZO_WorldMap_GetPanAndZoom()
    return {GetZoomMinMax=function() return .02, 1 end}
end

local init
EVENT_MANAGER = {
    RegisterForEvent=function(_, _, _, callback) init=callback end,
    UnregisterForEvent=function() end,
}
ZO_SavedVars = {NewAccountWide=function() return {enabled=true} end}
function ZO_PostHook(target, method, callback)
    local original = target[method]
    target[method] = function(self, ...)
        if original then original(self, ...) end
        callback(self, ...)
    end
end
ZO_WorldMapTiles_Manager = {}

local created = 0
WINDOW_MANAGER = {CreateControl=function()
    created = created + 1
    local control = {}
    for _, method in ipairs({'SetFont', 'SetColor', 'SetHorizontalAlignment',
        'SetVerticalAlignment', 'SetDrawLayer', 'SetDrawTier', 'SetDrawLevel',
        'SetPixelRoundingEnabled', 'SetMouseEnabled', 'SetParent', 'SetText',
        'SetWidth', 'SetScale', 'ClearAnchors', 'SetAnchor', 'SetHidden'}) do
        control[method] = function() end
    end
    return control
end}

local function label(r, g, b, a)
    local control = {color={r,g,b,a}, hidden=true, alpha=0, scale=1, text='Ротгар'}
    function control:GetColor() return unpack(self.color) end
    function control:SetColor(...) self.color={...} end
    function control:SetHidden(value) self.hidden=value end
    return control
end
local native = label(.33, .27, .15, 1)
native.shadowLabel = label(.79, .63, .3, 1)
local originalText = native.text
local pool = {active={}, releases=0}
function pool:ActiveObjectIterator() return next, self.active, nil end
function pool:ReleaseAllObjects()
    self.releases=self.releases+1
    self.active={}
    native.hidden=true
end
ZO_WorldMapManager = {}
function ZO_WorldMapManager:UpdateBlobs()
    self.lastBlobZoom=zoom
    if zoom >= .15 then
        pool.active={[1]=native}
        native.hidden=false
        native.alpha=.6
        native.scale=zoom
    else
        pool:ReleaseAllObjects()
    end
end
WORLD_MAP_MANAGER = setmetatable({blobNameLabelControlPool=pool}, {__index=ZO_WorldMapManager})

dofile(root..'/KanaColorMap.lua')
init(nil, 'KanaColorMap')
local K = KanaColorMap
K.activeManager = {parent={}}

WORLD_MAP_MANAGER:UpdateBlobs()
assert(created==0 and K.visibleNames==0, 'zoomed-out map must not create or show zone names')
assert(native.hidden, 'native visibility threshold remains intact')

zoom=.5
WORLD_MAP_MANAGER:UpdateBlobs()
assert(created==0, 'addon must not create replacement name controls')
assert(not native.hidden and native.alpha==.6 and native.scale==zoom,
    'native visibility, fade, and scale remain intact')
assert(native.text==originalText and native.color[1]==1 and native.color[2]==1 and native.color[3]==1,
    'native handwritten text stays in place and becomes white')
assert(native.shadowLabel.color[1]==0 and native.shadowLabel.color[2]==0
    and native.shadowLabel.color[3]==0, 'native backing becomes black')
assert(pool.releases==1, 'addon must not release native names')

K:Reset()
assert(native.color[1]==.33 and native.color[2]==.27 and native.color[3]==.15,
    'native foreground color restores on leaving Tamriel')
assert(native.shadowLabel.color[1]==.79 and native.shadowLabel.color[2]==.63
    and native.shadowLabel.color[3]==.3, 'native shadow color restores')
assert(native.text==originalText and native.scale==zoom and pool.releases==1,
    'reset does not change text, zoom, or native pool state')

K.activeManager = {parent={}}
WORLD_MAP_MANAGER:UpdateBlobs()
assert(native.color[1]==1 and pool.releases==1 and created==0,
    'reopening reuses and recolors native names')
mapId=61
WORLD_MAP_MANAGER:UpdateBlobs()
assert(native.color[1]==.33 and native.shadowLabel.color[1]==.79,
    'detailed zone maps retain native colors')
print('PASS: native labels only, zoom/fade preserved, white text, dark backing, restore/reopen')
