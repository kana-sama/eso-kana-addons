-- Report by Antis3n1l (2026-09-02):
-- https://forums.elderscrollsonline.com/en/discussion/698890/getquestzoneid-returns-wrong-zoneid-for-some-quests
-- questId = {reported wrong zoneId, dungeon zoneId}
local corrections = {
    [4303] = {283, 934},
    [4555] = {144, 936},
    [4813] = {146, 933},
    [5403] = {117, 843},
    [5702] = {117, 848},
    [5891] = {888, 974},
    [6064] = {92, 1009},
    [6186] = {382, 1052},
    [6249] = {101, 1080},
    [6251] = {823, 1081},
    [6349] = {1086, 1122},
    [6351] = {383, 1123},
    [6414] = {684, 1152},
    [7105] = {1207, 1470},
    [7155] = {684, 1471},
    [7235] = {1443, 1496},
    [7237] = {816, 1497},
    [7320] = {1502, 1551},
    [7323] = {1502, 1552},
}

-- Install during file loading, before addon initialization events build caches.
-- Keep the previous implementation so other wrappers and future fixes survive.
local originalGetQuestZoneId = GetQuestZoneId
function GetQuestZoneId(questId)
    local zoneId = originalGetQuestZoneId(questId)
    local correction = corrections[questId]
    if correction and zoneId == correction[1] then
        return correction[2]
    end
    return zoneId
end
