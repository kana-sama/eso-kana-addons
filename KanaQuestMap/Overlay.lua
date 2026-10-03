KanaQuestMap = KanaQuestMap or {}
local Addon = KanaQuestMap

Addon.name = "KanaQuestMap"
Addon.settingsDefaults = {
  blacklistedQuests = {},
  questMapSettingsMigrated = false,
}

local KANA_ONLY_SETTINGS = {
  blacklistedQuests = true,
  blacklistMigrated = true,
  questMapSettingsMigrated = true,
}

local function AccountWideValues(savedVariables)
  if savedVariables == nil then return nil end
  local defaults = savedVariables.Default
  if defaults == nil then return nil end
  local account = defaults[GetDisplayName()]
  return account and account["$AccountWide"]
end

local function CopyMissing(target, source)
  for key, value in pairs(source) do
    if not KANA_ONLY_SETTINGS[key] then
      if type(value) == "table" then
        local targetValue = rawget(target, key)
        if type(targetValue) ~= "table" then
          targetValue = {}
          rawset(target, key, targetValue)
        end
        CopyMissing(targetValue, value)
      elseif rawget(target, key) == nil then
        rawset(target, key, value)
      end
    end
  end
end

function Addon:MigrateForkSettings()
  if self.settings.questMapSettingsMigrated then return end

  local forkSettings = AccountWideValues(_G.KanaQuestMap_SavedVariables)
  local questMapSettings = AccountWideValues(_G.QuestMap_SavedVariables)
  if forkSettings ~= nil and questMapSettings ~= nil then
    CopyMissing(questMapSettings, forkSettings)
    if QuestMap and QuestMap.settings then
      CopyMissing(QuestMap.settings, forkSettings)
    end
  end
  self.settings.questMapSettingsMigrated = true
end

function Addon:Initialize()
  if self.initialized then return end
  self.initialized = true
  self.settings = ZO_SavedVars:NewAccountWide("KanaQuestMap_SavedVariables", 6, nil, self.settingsDefaults)
  self:MigrateForkSettings()
end

local function Trim(text)
  return string.match(text, "^%s*(.-)%s*$")
end

function Addon:IsQuestBlacklisted(questId)
  return self.settings.blacklistedQuests[questId] ~= nil
end

function Addon:BlacklistQuestId(questId)
  self.settings.blacklistedQuests[questId] = GetQuestName(questId)
end

function Addon:AddBlacklistedQuest(input)
  input = Trim(input or "")
  if input == "" then return 0, "empty" end

  local questIds
  local id = tonumber(string.match(input, "^#?(%d+)$"))
  if id ~= nil then
    if GetQuestName(id) == "" then return 0, "not-found" end
    questIds = { id }
  else
    questIds = LibQuestData:get_questids_table(input)
  end
  if questIds == nil then return 0, "not-found" end

  local added = 0
  for _, questId in ipairs(questIds) do
    if not self:IsQuestBlacklisted(questId) then
      self:BlacklistQuestId(questId)
      added = added + 1
    end
  end
  return added
end

function Addon:RemoveBlacklistedQuest(questId)
  self.settings.blacklistedQuests[questId] = nil
end

function Addon:GetBlacklistedQuestIds()
  local questIds = {}
  for questId in pairs(self.settings.blacklistedQuests) do
    table.insert(questIds, questId)
  end
  table.sort(questIds)
  return questIds
end

local InvalidQuestLocations = {
  ["stonefalls/davonswatch_base_0"] = { [4493] = true },
  ["stonefalls/stonefalls_base_0"] = { [4493] = true },
}

local function QuestPinTypes()
  local types = {}
  for key, pinType in pairs(QuestMap) do
    if string.match(key, "^PIN_TYPE_QUEST_") and type(pinType) == "string" then
      types[pinType] = true
    end
  end
  return types
end

function Addon:InstallMapHooks()
  if self.mapHooksInstalled or QuestMap == nil or LibMapPins == nil or LibQuestData == nil then return end
  self.mapHooksInstalled = true

  local LMP = LibMapPins
  local LQD = LibQuestData
  local questPinTypes = QuestPinTypes()
  local OriginalCreatePin = LMP.CreatePin
  LMP.CreatePin = function(lib, pinType, pinTag, ...)
    if questPinTypes[pinType] and type(pinTag) == "table" and type(pinTag.id) == "number" then
      if Addon:IsQuestBlacklisted(pinTag.id) then return end

      local questId = pinTag.id
      if LQD.started_quests[questId] then
        pinType = QuestMap.PIN_TYPE_QUEST_STARTED
      elseif LQD.completed_quests[questId] and LQD:get_quest_repeat(questId) > QUEST_REPEAT_NOT_REPEATABLE then
        pinType = QuestMap.PIN_TYPE_QUEST_COMPLETED
      end
    end
    return OriginalCreatePin(lib, pinType, pinTag, ...)
  end

  local OriginalGetQuestList = LQD.get_quest_list
  LQD.get_quest_list = function(lib, mapTexture)
    local quests = OriginalGetQuestList(lib, mapTexture)
    local invalidQuestIds = InvalidQuestLocations[mapTexture]
    if invalidQuestIds == nil or type(quests) ~= "table" then return quests end

    local filtered = {}
    for _, quest in ipairs(quests) do
      local questId = quest[lib.quest_map_pin_index.quest_id]
      if not invalidQuestIds[questId] then table.insert(filtered, quest) end
    end
    return filtered
  end
end

EVENT_MANAGER:RegisterForEvent(Addon.name, EVENT_ADD_ON_LOADED, function(_, addonName)
  if addonName ~= Addon.name then return end
  Addon:Initialize()
  EVENT_MANAGER:UnregisterForEvent(Addon.name, EVENT_ADD_ON_LOADED)
end)
