local Addon = KanaQuestMap

local blacklistInput = ""
local blacklistMessage = ""
local blacklistListControl

local function RefreshQuestMapPins()
  if QuestMap and QuestMap.RefreshPins then QuestMap:RefreshPins() end
end

local function RefreshBlacklistList()
  if blacklistListControl and blacklistListControl.UpdateValue then
    blacklistListControl:UpdateValue()
  end
end

local function CreateBlacklistRow(listControl, rowIndex)
  local row = WINDOW_MANAGER:CreateControl("KanaQuestMapBlacklistRow" .. rowIndex, listControl, CT_CONTROL)
  row:SetDimensions(listControl:GetWidth(), 28)

  row.name = WINDOW_MANAGER:CreateControl(nil, row, CT_LABEL)
  row.name:SetFont("ZoFontGame")
  row.name:SetWidth(400)
  row.name:SetAnchor(LEFT, row, LEFT)
  row.name:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
  row.name:SetMaxLineCount(1)

  row.delete = WINDOW_MANAGER:CreateControlFromVirtual("KanaQuestMapBlacklistDelete" .. rowIndex, row, "ZO_DefaultButton")
  row.delete:SetDimensions(90, 24)
  row.delete:SetAnchor(RIGHT, row, RIGHT)
  row.delete:SetText("Удалить")

  listControl.rows[rowIndex] = row
  return row
end

local function InitializeBlacklistList(listControl)
  listControl.rows = listControl.rows or {}
  if listControl.empty == nil then
    listControl.empty = WINDOW_MANAGER:CreateControl(nil, listControl, CT_LABEL)
    listControl.empty:SetFont("ZoFontGame")
    listControl.empty:SetAnchor(TOPLEFT, listControl, TOPLEFT)
    listControl.empty:SetText("Чёрный список пуст.")
  end
  listControl:SetDimensionConstraints(listControl:GetWidth(), 28, listControl:GetWidth(), 5000)
  blacklistListControl = listControl
end

local function RefreshBlacklistRows(listControl)
  InitializeBlacklistList(listControl)
  local questIds = Addon:GetBlacklistedQuestIds()
  for _, row in ipairs(listControl.rows) do row:SetHidden(true) end

  if #questIds == 0 then
    listControl.empty:SetHidden(false)
    listControl:SetHeight(28)
    return
  end

  listControl.empty:SetHidden(true)
  local previousRow
  for rowIndex, questId in ipairs(questIds) do
    local row = listControl.rows[rowIndex] or CreateBlacklistRow(listControl, rowIndex)
    row:ClearAnchors()
    row:SetAnchor(TOPLEFT, previousRow or listControl, previousRow and BOTTOMLEFT or TOPLEFT, 0, previousRow and 2 or 0)
    row:SetHidden(false)
    row.name:SetText(string.format("#%d — %s", questId, GetQuestName(questId)))
    row.delete:SetHandler("OnClicked", function()
      Addon:RemoveBlacklistedQuest(questId)
      RefreshQuestMapPins()
      RefreshBlacklistList()
    end)
    previousRow = row
  end
  listControl:SetHeight(#questIds * 30 - 2)
end

local function SubmitBlacklistInput(control)
  local added, reason = Addon:AddBlacklistedQuest(control.input:GetText())
  blacklistInput = ""
  control.input:SetText("")
  if reason == "empty" then
    blacklistMessage = "Введите название задания или его ID."
  elseif reason == "not-found" then
    blacklistMessage = "Задание не найдено. Для неоднозначного названия используйте #ID."
  elseif added == 0 then
    blacklistMessage = "Все найденные задания уже есть в чёрном списке."
  else
    blacklistMessage = string.format("Добавлено в чёрный список: %d.", added)
  end
  control.message:SetText(blacklistMessage)
  RefreshQuestMapPins()
  RefreshBlacklistList()
end

local function InitializeBlacklistInput(control)
  if control.input ~= nil then return end
  control:SetDimensionConstraints(control:GetWidth(), 76, control:GetWidth(), 76)
  control:SetHeight(76)

  control.title = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
  control.title:SetFont("ZoFontGame")
  control.title:SetAnchor(TOPLEFT, control, TOPLEFT)
  control.title:SetText("Название или #ID")

  control.backdrop = WINDOW_MANAGER:CreateControlFromVirtual("KanaQuestMapBlacklistInputBackdrop", control, "ZO_EditBackdrop")
  control.backdrop:SetDimensions(360, 24)
  control.backdrop:SetAnchor(TOPLEFT, control.title, BOTTOMLEFT, 0, 4)
  control.input = WINDOW_MANAGER:CreateControlFromVirtual("KanaQuestMapBlacklistInput", control.backdrop, "ZO_DefaultEditForBackdrop")
  control.input:SetAnchor(TOPLEFT, control.backdrop, TOPLEFT, 2, 2)
  control.input:SetAnchor(BOTTOMRIGHT, control.backdrop, BOTTOMRIGHT, -2, -2)
  control.input:SetHandler("OnFocusLost", function(input) blacklistInput = input:GetText() end)

  control.add = WINDOW_MANAGER:CreateControlFromVirtual("KanaQuestMapBlacklistAdd", control, "ZO_DefaultButton")
  control.add:SetDimensions(105, 24)
  control.add:SetAnchor(TOPRIGHT, control, TOPRIGHT)
  control.add:SetText("Скрыть")
  control.add:SetHandler("OnClicked", function() SubmitBlacklistInput(control) end)

  control.message = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
  control.message:SetFont("ZoFontGameSmall")
  control.message:SetAnchor(TOPLEFT, control.backdrop, BOTTOMLEFT, 0, 4)
end

local function RefreshBlacklistInput(control)
  InitializeBlacklistInput(control)
  if not control.input:HasFocus() then control.input:SetText(blacklistInput) end
  control.message:SetText(blacklistMessage)
end

local panelData = {
  type = "panel",
  name = "KanaQuestMap",
  displayName = "|c70C0DEKanaQuestMap|r",
  author = "Kana",
  version = "3.29-kana.2",
  registerForRefresh = true,
}

local optionsTable = {
  { type = "header", name = "Чёрный список заданий", width = "full" },
  {
    type = "description",
    text = "Введите точное название задания или его ID в формате #1234. Совпадающие задания не будут показываться на карте.",
    width = "full",
  },
  {
    type = "custom",
    reference = "KanaQuestMapBlacklistInputControl",
    minHeight = 76,
    maxHeight = 76,
    createFunc = RefreshBlacklistInput,
    refreshFunc = RefreshBlacklistInput,
    width = "full",
  },
  {
    type = "custom",
    reference = "KanaQuestMapBlacklistListControl",
    minHeight = 28,
    maxHeight = 5000,
    createFunc = function(control)
      InitializeBlacklistList(control)
      RefreshBlacklistRows(control)
    end,
    refreshFunc = RefreshBlacklistRows,
    width = "full",
  },
}

local function InitializeOldLamControls(panel)
  if panel ~= WINDOW_MANAGER:GetControlByName(Addon.name, "_Options") then return end
  if KanaQuestMapBlacklistInputControl then RefreshBlacklistInput(KanaQuestMapBlacklistInputControl) end
  if KanaQuestMapBlacklistListControl then RefreshBlacklistRows(KanaQuestMapBlacklistListControl) end
  CALLBACK_MANAGER:UnregisterCallback("LAM-PanelControlsCreated", InitializeOldLamControls)
end
CALLBACK_MANAGER:RegisterCallback("LAM-PanelControlsCreated", InitializeOldLamControls)

EVENT_MANAGER:RegisterForEvent("KanaQuestMapOverlaySettings", EVENT_PLAYER_ACTIVATED, function()
  local LAM = LibAddonMenu2
  if LAM then
    LAM:RegisterAddonPanel(Addon.name .. "_Options", panelData)
    LAM:RegisterOptionControls(Addon.name .. "_Options", optionsTable)
  end
  EVENT_MANAGER:UnregisterForEvent("KanaQuestMapOverlaySettings", EVENT_PLAYER_ACTIVATED)
end)
