EVENT_ADD_ON_LOADED, EVENT_PLAYER_ACTIVATED = 1, 2
local handlers = {}
EVENT_MANAGER = {
    RegisterForEvent = function(_, name, event, callback) handlers[event] = callback end,
    UnregisterForEvent = function(_, name, event) handlers[event] = nil end,
}
local warnings = {}
d = function(message) warnings[#warnings + 1] = message end

KanaCraftedSetCollections = {
    BuildCatalog = function() return { byCategory = {}, fallback = {} } end,
    InstallTileHooks = function() return true end,
    InstallBookHooks = function() return true end,
}
LibSets = { fullyLoaded = true }
ITEM_SET_COLLECTIONS_BOOK_KEYBOARD = {}
ZO_ItemSetCollectionPieceTile_Keyboard = {}
dofile("KanaCraftedSetCollections/Main.lua")
assert(handlers[EVENT_ADD_ON_LOADED], "addon-load handler must register")
handlers[EVENT_ADD_ON_LOADED](nil, "KanaCraftedSetCollections")
assert(KanaCraftedSetCollections.initialized and KanaCraftedSetCollections.catalog,
    "ready LibSets and book must initialize once")
assert(not handlers[EVENT_PLAYER_ACTIVATED] and #warnings == 0,
    "successful initialization must not warn or wait for another event")

handlers = {}
KanaCraftedSetCollections = {
    BuildCatalog = function() error("should not build before LibSets") end,
    InstallTileHooks = function() error("should not hook before LibSets") end,
}
LibSets = nil
dofile("KanaCraftedSetCollections/Main.lua")
handlers[EVENT_ADD_ON_LOADED](nil, "KanaCraftedSetCollections")
assert(handlers[EVENT_PLAYER_ACTIVATED], "late LibSets must get a single retry")
handlers[EVENT_PLAYER_ACTIVATED]()
assert(#warnings == 1 and not handlers[EVENT_PLAYER_ACTIVATED],
    "failed initialization must report once and remove its retry")

handlers = {}
KanaCraftedSetCollections = {
    BuildCatalog = function() return { byCategory = {}, fallback = {} } end,
    InstallTileHooks = function() return true end,
    InstallBookHooks = function() error("changed client method") end,
}
LibSets = { fullyLoaded = true }
dofile("KanaCraftedSetCollections/Main.lua")
handlers[EVENT_ADD_ON_LOADED](nil, "KanaCraftedSetCollections")
assert(handlers[EVENT_PLAYER_ACTIVATED], "failed hook must defer one diagnostic until activation")
handlers[EVENT_PLAYER_ACTIVATED]()
assert(#warnings == 2, "failed hook must report only once")
print("main_test: ok")
