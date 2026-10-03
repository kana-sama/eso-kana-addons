local function assert_equal(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
  end
end

EVENT_ADD_ON_LOADED = 1
EVENT_MANAGER = {
  RegisterForEvent = function() end,
  UnregisterForEvent = function() end,
}
QUEST_REPEAT_NOT_REPEATABLE = 0
KanaQuestMap = { settings = { blacklistedQuests = { [1] = "Hidden" } } }
QuestMap = {
  PIN_TYPE_QUEST_UNCOMPLETED = "QuestMap_uncompleted",
  PIN_TYPE_QUEST_COMPLETED = "QuestMap_completed",
  PIN_TYPE_QUEST_STARTED = "QuestMap_started",
}

local created = {}
LibMapPins = {
  CreatePin = function(_, pinType, pinTag)
    table.insert(created, { pinType = pinType, questId = pinTag.id })
  end,
}
LibQuestData = {
  started_quests = { [2] = true },
  completed_quests = { [3] = true },
  quest_map_pin_index = { quest_id = 1 },
  get_quest_repeat = function(_, questId) return questId == 3 and 1 or 0 end,
  get_quest_list = function(_, mapTexture)
    if mapTexture == "stonefalls/stonefalls_base_0" then return { { 4493 }, { 7000 } } end
    return { { 4493 } }
  end,
}
GetQuestName = function() return "Quest" end

dofile("Overlay.lua")
KanaQuestMap:InstallMapHooks()

LibMapPins:CreatePin("QuestMap_uncompleted", { id = 1 })
assert_equal(#created, 0, "blacklisted QuestMap quest is suppressed")

LibMapPins:CreatePin("QuestMap_uncompleted", { id = 2 })
assert_equal(created[1].pinType, "QuestMap_started", "started quest is rerouted")

LibMapPins:CreatePin("QuestMap_uncompleted", { id = 3 })
assert_equal(created[2].pinType, "QuestMap_completed", "completed repeatable quest is rerouted")

LibMapPins:CreatePin("OtherAddon_pin", { id = 1 })
assert_equal(created[3].pinType, "OtherAddon_pin", "non-QuestMap pin passes through")

local falseLocation = LibQuestData:get_quest_list("stonefalls/stonefalls_base_0")
assert_equal(#falseLocation, 1, "false Stonefalls location is filtered")
assert_equal(falseLocation[1][1], 7000, "real Stonefalls quest remains")
assert_equal(#LibQuestData:get_quest_list("other/map"), 1, "other locations are unchanged")

print("PASS: overlay map hooks")
