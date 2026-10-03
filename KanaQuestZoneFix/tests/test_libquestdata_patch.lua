-- Run from eso-kana-addons: lua KanaQuestZoneFix/tests/test_libquestdata_patch.lua
dofile('LibQuestData/data/LibQuestData_QuestLocations.lua')
local locations = LibQuestData_QuestLocationData
local map = 'deshaan/mournhold_base_0'
local originalRows = {}
for zone, rows in pairs(locations) do
    originalRows[zone] = {}
    for _, row in ipairs(rows) do table.insert(originalRows[zone], row) end
end
local function patch()
    if not os.getenv('BASELINE') then dofile('KanaQuestZoneFix/LibQuestDataPatch.lua') end
end
patch()
for zone, rows in pairs(originalRows) do
    local index = 1
    for _, row in ipairs(rows) do
        if zone ~= map or row[5] ~= 7237 then
            assert(locations[zone][index] == row, 'unrelated pin changed: ' .. zone)
            index = index + 1
        end
    end
    assert(#locations[zone] == index - 1, 'misplaced pin remains: ' .. zone)
end
-- A later library's correct location must survive; repeated loading is harmless.
locations['future/leps eclusa'] = {{0.1, 0.2, 0.3, 0.4, 7237, 240047}}
patch()
assert(#locations['future/leps eclusa'] == 1)
LibQuestData_QuestLocationData = nil
patch()
print('PASS: misplaced 7237 removed; all other installed pins preserved; future location, repeat load, absent library')
