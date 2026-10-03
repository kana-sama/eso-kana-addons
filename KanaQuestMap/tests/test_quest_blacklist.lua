local function assert_equal(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
  end
end

KanaQuestMap = { settings = { hiddenQuests = {}, blacklistedQuests = {} } }
EVENT_ADD_ON_LOADED = 1
EVENT_MANAGER = {
  RegisterForEvent = function() end,
  UnregisterForEvent = function() end,
}
LibQuestData = {
  get_questids_table = function(_, name)
    if name == "Одинаковое название" then return { 11, 12 } end
  end,
}

local questNames = {
  [11] = "Одинаковое название",
  [12] = "Одинаковое название",
  [99] = "Квест по ID",
}
GetQuestName = function(questId) return questNames[questId] or "" end

dofile("Overlay.lua")

local added, reason = KanaQuestMap:AddBlacklistedQuest("#99")
assert_equal(added, 1, "#ID adds exactly one quest")
assert_equal(reason, nil, "#ID has no error")
assert_equal(KanaQuestMap:IsQuestBlacklisted(99), true, "added ID is hidden")

added = KanaQuestMap:AddBlacklistedQuest("Одинаковое название")
assert_equal(added, 2, "an ambiguous title adds every exact ID")
assert_equal(KanaQuestMap:IsQuestBlacklisted(11), true, "first matching title is hidden")
assert_equal(KanaQuestMap:IsQuestBlacklisted(12), true, "second matching title is hidden")

assert_equal(KanaQuestMap:IsQuestBlacklisted(99), true, "blacklisted quest always remains hidden")
assert_equal(KanaQuestMap.SetBlacklistedQuestVisible, nil, "temporary visibility is not available")

KanaQuestMap.settings.hiddenQuests[77] = "Скрыто вручную"
assert_equal(KanaQuestMap:IsQuestBlacklisted(77), false, "manual hiding is not a blacklist entry")

KanaQuestMap:RemoveBlacklistedQuest(99)
assert_equal(KanaQuestMap:IsQuestBlacklisted(99), false, "removal clears blacklist")
assert_equal(KanaQuestMap.settings.hiddenQuests[77], "Скрыто вручную", "removal does not change manual hiding")

added, reason = KanaQuestMap:AddBlacklistedQuest("Несуществующий квест")
assert_equal(added, 0, "unknown title adds nothing")
assert_equal(reason, "not-found", "unknown title reports not-found")

print("PASS: quest blacklist")
