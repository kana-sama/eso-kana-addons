local Addon = KanaQuestMap

local function DecorateTooltipCreators()
  if Addon.tooltipCreatorsDecorated or QuestMap == nil or ZO_MapPin == nil then return end
  local tooltipCreators = ZO_MapPin.TOOLTIP_CREATORS
  if tooltipCreators == nil then return end

  for key, pinType in pairs(QuestMap) do
    if string.match(key, "^PIN_TYPE_QUEST_") and type(pinType) == "string" then
      local tooltipCreator = ZO_MapPin.TOOLTIP_CREATORS[_G[pinType]]
      if type(tooltipCreator) == "table" and type(tooltipCreator.creator) == "function" then
        tooltipCreator.creator = function(pin)
          local pinTag = select(2, pin:GetPinTypeAndTag())
          local chronology = Addon.Chronology:Format(pinTag.id)
          if IsInGamepadPreferredMode() then
            local InformationTooltip = ZO_MapLocationTooltip_Gamepad
            local baseSection = InformationTooltip.tooltip
            InformationTooltip:LayoutIconStringLine(baseSection, nil, QuestMap.idName, baseSection:GetStyle("mapLocationTooltipContentHeader"))
            InformationTooltip:LayoutIconStringLine(baseSection, nil, pinTag.pinName, baseSection:GetStyle("mapLocationTooltipContentName"))
            if chronology then
              InformationTooltip:LayoutIconStringLine(baseSection, nil, chronology, baseSection:GetStyle("mapLocationTooltipContentName"))
            end
          elseif chronology then
            SetTooltipText(InformationTooltip, pinTag.pinName .. "\n" .. chronology)
          else
            SetTooltipText(InformationTooltip, pinTag.pinName)
          end
        end
      end
    end
  end
  Addon.tooltipCreatorsDecorated = true
end

local function InitializeJournalCompletionIndicator()
  local journal = ZO_QUEST_JOURNAL_QUESTS_KEYBOARD
  if journal == nil or journal.kanaQuestMapCompletionIndicator then return end
  local scrollChild = journal.questInfoContainer:GetNamedChild("ScrollChild")
  local repeatableText = scrollChild:GetNamedChild("RepeatableText")
  local icon = WINDOW_MANAGER:CreateControl("KanaQuestMapJournalCompletionIcon", scrollChild, CT_TEXTURE)
  icon:SetTexture("EsoUI/Art/Cadwell/check.dds")
  icon:SetDimensions(20, 20)
  icon:SetAnchor(LEFT, repeatableText, RIGHT, 10, 0)
  icon:SetHidden(true)
  icon:SetMouseEnabled(false)

  SecurePostHook(journal, "RefreshDetails", function()
    local questData = journal:GetSelectedQuestData()
    if questData == nil then icon:SetHidden(true) return end
    local questId = GetJournalQuestId(questData.questIndex)
    local repeatable = GetJournalQuestRepeatType(questData.questIndex) ~= QUEST_REPEAT_NOT_REPEATABLE
    icon:SetHidden(not (repeatable and questId and LibQuestData.completed_quests[questId]))
  end)
  journal.kanaQuestMapCompletionIndicator = true
end

EVENT_MANAGER:RegisterForEvent("KanaQuestMapPCOverlay", EVENT_PLAYER_ACTIVATED, function()
  Addon:InstallMapHooks()
  if QuestMap and QuestMap.RefreshPins then QuestMap:RefreshPins() end
  DecorateTooltipCreators()
  InitializeJournalCompletionIndicator()
  EVENT_MANAGER:UnregisterForEvent("KanaQuestMapPCOverlay", EVENT_PLAYER_ACTIVATED)
end)
