local addon = {}
KanaCraftedSetCollections = addon

local chunk = loadfile("KanaCraftedSetCollections/Tile.lua")
if chunk then chunk() end
assert(type(addon.MakeHeader) == "function", "MakeHeader is missing")

local row = { setId = 42, name = "Крафтовый сет", itemLink = "item:42", icon = "set-icon", traitsNeeded = 6 }
local header = addon.MakeHeader(row)
local piece = addon.MakePiece(row)
assert(header:GetId() == 42 and header:GetNumPieces() == 1 and header:GetNumUnlockedPieces() == 1,
    "crafted set must look fully collected")
assert(piece:IsUnlocked() and not piece:IsNew(), "example item must look collected but not new")
assert(piece:GetItemLink() == "item:42" and piece:GetIcon() == "set-icon", "sample item must retain the source link")

ZO_ItemSetCollectionPieceTile_Keyboard = {
    CanReconstruct = function() return true end,
    RefreshMouseoverVisuals = function(self) self.nativeTooltip = true end,
}
local tooltipLink
ItemTooltip = { SetLink = function(_, link) tooltipLink = link end }
ClearTooltip = function() end
InitializeTooltip = function() end
RIGHT, LEFT = 1, 2

assert(type(addon.InstallTileHooks) == "function", "InstallTileHooks is missing")
assert(addon.InstallTileHooks(), "tile hooks must install")
local crafted = {
    itemSetCollectionPieceData = piece,
    IsMousedOver = function() return true end,
    control = { GetParent = function() return { GetLeft = function() return 200 end } end,
                GetLeft = function() return 100 end },
}
assert(not ZO_ItemSetCollectionPieceTile_Keyboard.CanReconstruct(crafted), "crafted tile must never reconstruct")
ZO_ItemSetCollectionPieceTile_Keyboard.RefreshMouseoverVisuals(crafted)
assert(tooltipLink == "item:42", "crafted tooltip must show the real item link")
assert(not crafted.nativeTooltip, "crafted tooltip must bypass collection-only tooltip")

local native = { itemSetCollectionPieceData = { IsUnlocked = function() return true end } }
assert(ZO_ItemSetCollectionPieceTile_Keyboard.CanReconstruct(native), "native reconstruction must stay available")
ZO_ItemSetCollectionPieceTile_Keyboard.RefreshMouseoverVisuals(native)
assert(native.nativeTooltip, "native tooltip must stay available")
print("tile_test: ok")
