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
local disabled = arg[1]
KanaQuestMap = { settings = { blacklistedQuests = { [1] = "Hidden" }, features = {
  blacklist = disabled ~= "blacklist" and disabled ~= "all",
  pinStates = disabled ~= "pinStates" and disabled ~= "all",
  invalidLocations = disabled ~= "invalidLocations" and disabled ~= "all",
} } }
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

local originalCreatePin = LibMapPins.CreatePin
local originalGetQuestList = LibQuestData.get_quest_list
dofile("Overlay.lua")
KanaQuestMap:InstallMapHooks()

LibMapPins:CreatePin("QuestMap_uncompleted", { id = 1 })
assert_equal(#created, (disabled == "blacklist" or disabled == "all") and 1 or 0,
  "blacklist switch controls suppression")

LibMapPins:CreatePin("QuestMap_uncompleted", { id = 2 })
assert_equal(created[#created].pinType,
  (disabled == "pinStates" or disabled == "all") and "QuestMap_uncompleted" or "QuestMap_started",
  "pin-state switch controls started quest")

LibMapPins:CreatePin("QuestMap_uncompleted", { id = 3 })
assert_equal(created[#created].pinType,
  (disabled == "pinStates" or disabled == "all") and "QuestMap_uncompleted" or "QuestMap_completed",
  "pin-state switch controls completed quest")

LibMapPins:CreatePin("OtherAddon_pin", { id = 1 })
assert_equal(created[#created].pinType, "OtherAddon_pin", "non-QuestMap pin passes through")

local falseLocation = LibQuestData:get_quest_list("stonefalls/stonefalls_base_0")
assert_equal(#falseLocation, (disabled == "invalidLocations" or disabled == "all") and 2 or 1,
  "false Stonefalls location follows its switch")
assert_equal(falseLocation[#falseLocation][1], 7000, "real Stonefalls quest remains")
assert_equal(#LibQuestData:get_quest_list("other/map"), 1, "other locations are unchanged")
if disabled == "all" then
  assert_equal(LibMapPins.CreatePin, originalCreatePin, "all-off leaves pin function untouched")
  assert_equal(LibQuestData.get_quest_list, originalGetQuestList, "all-off leaves quest list untouched")
end

print("PASS: overlay map hooks")
