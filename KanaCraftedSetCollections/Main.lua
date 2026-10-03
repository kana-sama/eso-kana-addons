KanaCraftedSetCollections = KanaCraftedSetCollections or {}
local addon = KanaCraftedSetCollections
local ADDON_NAME = "KanaCraftedSetCollections"
local eventName = ADDON_NAME .. "_Initialization"
local warned = false

local function WarnOnce(reason)
    if warned then return end
    warned = true
    d("[" .. ADDON_NAME .. "] Не удалось подключить коллекцию крафтовых сетов: " .. tostring(reason))
end

local function Initialize()
    if addon.initialized then return true end
    if not LibSets or not LibSets.fullyLoaded then return false, "LibSets ещё не готова" end
    local book = ITEM_SET_COLLECTIONS_BOOK_KEYBOARD
    if not book then return false, "окно коллекции сетов недоступно" end
    if not ZO_ItemSetCollectionPieceTile_Keyboard then return false, "шаблон карточки сетов недоступен" end

    local ok, catalog, reason = pcall(addon.BuildCatalog, LibSets)
    if not ok then return false, catalog end
    if not catalog then return false, reason end
    local tileOk, tileResult = pcall(addon.InstallTileHooks)
    if not tileOk or not tileResult then return false, "не удалось защитить карточки от реконструкции" end
    local bookOk, bookResult = pcall(addon.InstallBookHooks, book, catalog)
    if not bookOk or not bookResult then return false, "точка подключения интерфейса изменилась" end

    addon.catalog = catalog
    addon.initialized = true
    EVENT_MANAGER:UnregisterForEvent(eventName .. "_PLAYER_ACTIVATED", EVENT_PLAYER_ACTIVATED)
    return true
end

local function OnPlayerActivated()
    local ok, reason = Initialize()
    if not ok then WarnOnce(reason) end
    EVENT_MANAGER:UnregisterForEvent(eventName .. "_PLAYER_ACTIVATED", EVENT_PLAYER_ACTIVATED)
end

local function OnAddonLoaded(_, loadedName)
    if loadedName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(eventName, EVENT_ADD_ON_LOADED)
    local ok = Initialize()
    if not ok then
        EVENT_MANAGER:RegisterForEvent(eventName .. "_PLAYER_ACTIVATED", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    end
end

EVENT_MANAGER:RegisterForEvent(eventName, EVENT_ADD_ON_LOADED, OnAddonLoaded)
