local Addon = KanaQuestMap

local function DecorateTooltipCreators()
  if Addon.consoleTooltipCreatorsDecorated or QuestMap == nil or ZO_MapPin == nil then return end
  local tooltipCreators = ZO_MapPin.TOOLTIP_CREATORS
  if tooltipCreators == nil then return end

  for key, pinType in pairs(QuestMap) do
    if string.match(key, "^PIN_TYPE_QUEST_") and type(pinType) == "string" then
      local tooltipCreator = ZO_MapPin.TOOLTIP_CREATORS[_G[pinType]]
      if type(tooltipCreator) == "table" and type(tooltipCreator.creator) == "function" then
        tooltipCreator.creator = function(pin)
          local pinTag = select(2, pin:GetPinTypeAndTag())
          local chronology = Addon.Chronology:Format(pinTag.id)
          local InformationTooltip = ZO_MapLocationTooltip_Gamepad
          local baseSection = InformationTooltip.tooltip
          InformationTooltip:LayoutIconStringLine(baseSection, nil, QuestMap.idName, baseSection:GetStyle("mapLocationTooltipContentHeader"))
          InformationTooltip:LayoutIconStringLine(baseSection, nil, pinTag.pinName, baseSection:GetStyle("mapLocationTooltipContentName"))
          if chronology then
            InformationTooltip:LayoutIconStringLine(baseSection, nil, chronology, baseSection:GetStyle("mapLocationTooltipContentName"))
          end
        end
      end
    end
  end
  Addon.consoleTooltipCreatorsDecorated = true
end

EVENT_MANAGER:RegisterForEvent("KanaQuestMapConsoleOverlay", EVENT_PLAYER_ACTIVATED, function()
  Addon:InstallMapHooks()
  if QuestMap and QuestMap.RefreshPins then QuestMap:RefreshPins() end
  DecorateTooltipCreators()
  EVENT_MANAGER:UnregisterForEvent("KanaQuestMapConsoleOverlay", EVENT_PLAYER_ACTIVATED)
end)
