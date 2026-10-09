KanaSeasonOneTravel = {}
local addon = KanaSeasonOneTravel

-- Season One encounter starts and their nearest wayshrines are named in the
-- official Update 50 patch notes. Match live node names rather than storing
-- node indexes, which can change when the fast travel network is updated.
local destinations = {
    farm = {
        zoneId = 381, -- Auridon
        names = { "Vulkhel Guard", "Вулхельского Дозора" },
    },
    bilsa = {
        zoneId = 41, -- Stonefalls
        names = { "Hrogar's Hold", "Хрогара" },
    },
    vampire = {
        zoneId = 3, -- Glenumbra
        names = { "North Hag Fen", "северной Ведьминой топи", "Северной Ведьминой топи" },
    },
    urcelmo = {
        zoneId = 381,
        names = { "Skywatch", "Скайвотч", "Небесного Дозора" },
    },
    holgunn = {
        zoneId = 41,
        names = { "Ebonheart", "Эбонхарт" },
    },
    arabelle = {
        zoneId = 3,
        names = { "Aldcroft", "Альдкрофт" },
    },
    nowhere = {
        zoneId = 3, -- The Nowhere Vault entrance is in Daggerfall's Thieves Den.
        names = { "Daggerfall", "Даггерфолла", "Даггерфолл" },
    },
    highseas = {
        zoneId = 823, -- Gold Coast: event ship west of Anvil
        names = { "Anvil", "Анвила", "Анвиль" },
    },
}
addon.destinations = destinations

-- The announced 2026 event runs September 30–October 14. ESO events normally
-- turn over at 10:00 EDT (14:00 UTC); the published dates omit an exact hour.
local HIGH_SEAS_START = 1790776800
local HIGH_SEAS_END = 1791986400

function addon.IsHighSeasActive()
    local now = GetTimeStamp()
    return now >= HIGH_SEAS_START and now < HIGH_SEAS_END
end

function addon.Resolve(key)
    local destination = destinations[key]
    if not destination then return nil end

    for nodeIndex = 1, GetNumFastTravelNodes() do
        local known, name, _, _, _, _, poiType = GetFastTravelNodeInfo(nodeIndex)
        if known and poiType == POI_TYPE_WAYSHRINE and type(name) == "string" then
            local zoneIndex = GetFastTravelNodePOIIndicies(nodeIndex)
            if zoneIndex and (GetZoneId(zoneIndex) == destination.zoneId
                or ZO_ExplorationUtils_GetParentZoneIdByZoneIndex(zoneIndex) == destination.zoneId) then
                for _, expectedName in ipairs(destination.names) do
                    if name:find(expectedName, 1, true) then
                        return nodeIndex
                    end
                end
            end
        end
    end
end

function addon.CanTravel()
    return ZO_Map_GetFastTravelNode() ~= nil
        and WORLD_MAP_MANAGER:IsInMode(MAP_MODE_FAST_TRAVEL)
        and GetInteractionType() == INTERACTION_FAST_TRAVEL
end

function addon.Travel(key)
    if not addon.CanTravel() then return false end
    if key == "highseas" and not addon.IsHighSeasActive() then return false end
    local nodeIndex = addon.Resolve(key)
    if not nodeIndex or GetFastTravelNodeOutboundOnlyInfo(nodeIndex) then return false end
    FastTravelToNode(nodeIndex)
    return true
end
