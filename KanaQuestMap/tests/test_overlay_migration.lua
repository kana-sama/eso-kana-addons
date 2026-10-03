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
GetDisplayName = function() return "@Kana" end

KanaQuestMap = {}
QuestMap = {}
local upstreamRaw = {}
setmetatable(upstreamRaw, { __index = { pinSize = 25, pinFilters = {} } })
QuestMap.settings = upstreamRaw

KanaQuestMap_SavedVariables = {
  Default = {
    ["@Kana"] = {
      ["$AccountWide"] = {
        pinSize = 42,
        pinFilters = { custom = true },
        blacklistedQuests = { [99] = "Kana-only" },
      },
    },
  },
}
QuestMap_SavedVariables = {
  Default = { ["@Kana"] = { ["$AccountWide"] = upstreamRaw } },
}

dofile("Overlay.lua")
KanaQuestMap.settings = { questMapSettingsMigrated = false, blacklistedQuests = {} }
KanaQuestMap:MigrateForkSettings()

assert_equal(rawget(upstreamRaw, "pinSize"), 42, "fork value fills an upstream default-only field")
assert_equal(rawget(upstreamRaw, "pinFilters").custom, true, "nested fork values are migrated")
assert_equal(rawget(upstreamRaw, "blacklistedQuests"), nil, "Kana-only blacklist does not enter QuestMap")

print("PASS: overlay migration")
