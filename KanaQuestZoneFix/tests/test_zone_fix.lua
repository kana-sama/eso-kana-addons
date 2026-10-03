-- Run from eso-kana-addons: lua KanaQuestZoneFix/tests/test_zone_fix.lua
-- Regression fixtures from the linked ESO bug report, independent of patch data.
local cases = {
    {4303, 283, 934}, {4555, 144, 936}, {4813, 146, 933},
    {5403, 117, 843}, {5702, 117, 848}, {5891, 888, 974},
    {6064, 92, 1009}, {6186, 382, 1052}, {6249, 101, 1080},
    {6251, 823, 1081}, {6349, 1086, 1122}, {6351, 383, 1123},
    {6414, 684, 1152}, {7105, 1207, 1470}, {7155, 684, 1471},
    {7235, 1443, 1496}, {7237, 816, 1497}, {7320, 1502, 1551},
    {7323, 1502, 1552},
}
local zones = {[99999] = 117, [0] = 0}
for _, case in ipairs(cases) do zones[case[1]] = case[2] end
GetQuestZoneId = function(id) return zones[id] end

-- BASELINE reproduces the bug with the original API result.
if not os.getenv('BASELINE') then
    dofile('KanaQuestZoneFix/KanaQuestZoneFix.lua')
end
for _, case in ipairs(cases) do
    assert(GetQuestZoneId(case[1]) == case[3], 'wrong dungeon for quest ' .. case[1])
end
assert(GetQuestZoneId(99999) == 117, 'unlisted quest must keep its zone')
assert(GetQuestZoneId(0) == 0, 'unknown quest zero must pass through')
assert(GetQuestZoneId(-1) == nil, 'nil result must pass through')
for _, case in ipairs(cases) do
    zones[case[1]] = case[3]
    assert(GetQuestZoneId(case[1]) == case[3], 'preserve upstream fix')
    zones[case[1]] = 9999
    assert(GetQuestZoneId(case[1]) == 9999, 'preserve unexpected future zone')
    zones[case[1]] = case[2]
end

-- Exercise the installed library rather than reimplementing its lookup.
EVENT_MANAGER = {RegisterForEvent = function() end}
dofile('LibUespQuestData/LibUespQuestData/LibUespQuestData.lua')
dofile('LibUespQuestData/LibUespQuestData/Data2.lua')
for _, row in ipairs(uespQuestData2) do
    LibUespQuestData.quests[tonumber(row.internalId)] = row
end
GetZoneNameById = function(id) return 'zone:' .. id end
GetZoneIndex = function(id) return id + 10000 end
GetQuestName = function(id) return 'quest:' .. id end
GetPOIInfo = function() return '', 0, '', '' end
for _, case in ipairs(cases) do
    local name, _, _, index = LibUespQuestData:GetUespQuestLocationInfo(case[1])
    assert(name == 'zone:' .. case[3], 'library location name ' .. case[1])
    assert(index == case[3] + 10000, 'library location index ' .. case[1])
    local _, _, infoZone = LibUespQuestData:GetUespQuestInfo(case[1])
    assert(infoZone == name, 'library quest info ' .. case[1])
end
print('PASS: 19 corrections, passthrough, upstream changes, installed LibUespQuestData integration')
