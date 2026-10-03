-- Run from this folder with: lua test_travel.lua
local addon = "KanaSeasonOneTravel"
local nodes = {}
local zoneIds = { [11] = 381, [22] = 41, [33] = 3, [44] = 999 }
local currentNode, inMode, interaction = 99, true, 1
local travelled = {}

POI_TYPE_WAYSHRINE = 1
MAP_MODE_FAST_TRAVEL = 4
INTERACTION_FAST_TRAVEL = 1

function GetNumFastTravelNodes() return #nodes end
function GetFastTravelNodeInfo(index)
    local node = nodes[index]
    return node.known, node.name, 0, 0, nil, nil, node.type
end
function GetFastTravelNodePOIIndicies(index) return nodes[index].zone end
function GetZoneId(index) return zoneIds[index] end
function ZO_ExplorationUtils_GetParentZoneIdByZoneIndex(index)
    if index == 44 then return 381 end
    return zoneIds[index]
end
function ZO_Map_GetFastTravelNode() return currentNode end
WORLD_MAP_MANAGER = { IsInMode = function(_, mode) return inMode and mode == MAP_MODE_FAST_TRAVEL end }
function GetInteractionType() return interaction end
function GetFastTravelNodeOutboundOnlyInfo(index) return nodes[index].outbound or false end
function FastTravelToNode(index) travelled[#travelled + 1] = index end

local function setNodes(first, second, third)
    nodes = {
        { known = true, name = "Other Wayshrine", type = 1, zone = 11 },
        { known = true, name = first, type = 1, zone = 11 },
        { known = true, name = second, type = 1, zone = 22 },
        { known = true, name = third, type = 1, zone = 33 },
    }
end

setNodes("Vulkhel Guard Wayshrine", "Hrogar's Hold Wayshrine", "North Hag Fen Wayshrine")
dofile("../Core.lua")
local core = _G[addon]

assert(core.Resolve("farm") == 2, "Farm must resolve to the official Auridon wayshrine")
assert(core.Resolve("bilsa") == 3, "Bilsa must resolve to the official Stonefalls wayshrine")
assert(core.Resolve("vampire") == 4, "Vampire hunt must resolve to the northern Hag Fen wayshrine")
nodes[2].zone = 44
assert(core.Resolve("farm") == 2, "A city wayshrine must resolve through its parent zone")
nodes[2].zone = 11

setNodes("Дорожное святилище Вулхельского Дозора", "Дорожное святилище владения Хрогара", "Дорожное святилище северной Ведьминой топи")
assert(core.Resolve("farm") == 2, "Russian client must resolve the farm destination")
assert(core.Resolve("bilsa") == 3, "Russian client must resolve the Bilsa destination")
assert(core.Resolve("vampire") == 4, "Russian client must resolve the vampire destination")
nodes[3].name = "Дорожное святилище Владения Хрогара"
assert(core.Resolve("bilsa") == 3, "Capitalized Russian shrine name must resolve")
nodes[3].name = "Дорожное святилище владения Хрогара"
nodes[1] = { known = true, name = "Дорожное святилище южной Ведьминой топи", type = 1, zone = 33 }
assert(core.Resolve("vampire") == 4, "Do not pick the southern Hag Fen shrine")

core.Travel("bilsa")
assert(#travelled == 1 and travelled[1] == 3, "Click must travel directly to the selected destination")

inMode = false
assert(core.Travel("farm") == false and #travelled == 1, "Ordinary map must not trigger travel")
inMode = true
currentNode = nil
assert(core.Travel("farm") == false and #travelled == 1, "No active source wayshrine must not trigger travel")
currentNode = 99
interaction = 0
assert(core.Travel("farm") == false and #travelled == 1, "Ended interaction must not trigger travel")
interaction = INTERACTION_FAST_TRAVEL

nodes[2].known = false
assert(core.Resolve("farm") == nil, "Undiscovered wayshrine must be unavailable")
assert(core.Travel("farm") == false and #travelled == 1, "Undiscovered wayshrine must not trigger travel")
nodes[2].known = true
nodes[2].outbound = true
assert(core.Travel("farm") == false and #travelled == 1, "Outbound-only destination must not trigger travel")

print("KanaSeasonOneTravel: all travel checks passed")

setNodes("Skywatch Wayshrine", "Ebonheart Wayshrine", "Aldcroft Wayshrine")
assert(core.Resolve("urcelmo") == 2)
assert(core.Resolve("holgunn") == 3)
assert(core.Resolve("arabelle") == 4)
setNodes("Дорожное святилище Скайвотча", "Дорожное святилище Эбонхарта", "Дорожное святилище Альдкрофта")
assert(core.Resolve("urcelmo") == 2)
assert(core.Resolve("holgunn") == 3)
assert(core.Resolve("arabelle") == 4)
print("KanaSeasonOneTravel: Freerunner travel checks passed")
