EVENT_MANAGER:RegisterForEvent(KanaAudibleFishBite.ADDON_NAME, EVENT_ADD_ON_LOADED, function (eventCode, name)
  if name ~= KanaAudibleFishBite.ADDON_NAME then return end
  KanaAudibleFishBite:Initialize()
  EVENT_MANAGER:UnregisterForEvent(KanaAudibleFishBite.ADDON_NAME, EVENT_ADD_ON_LOADED)
end)

function KanaAudibleFishBite:Initialize()
  KanaAudibleFishBite:InitializeSettings()
  KanaAudibleFishBite:InitializeBiteAlert()
  KanaAudibleFishBite:InitializeStateMachine()
  KanaAudibleFishBite.settingsMenu = KanaAudibleFishBiteSettingsMenu:New()
end

function KanaAudibleFishBite:InitializeBiteAlert()
  local root = WINDOW_MANAGER:CreateTopLevelWindow("KanaAudibleFishBiteAlert")
  root:SetAnchor(CENTER, GuiRoot, CENTER, 0, -100)
  root:SetDimensions(600, 120)
  root:SetMouseEnabled(false)
  root:SetHidden(true)

  -- Scenes control the root; bite visibility belongs to the child label.
  local label = WINDOW_MANAGER:CreateControl("KanaAudibleFishBiteAlertText", root, CT_LABEL)
  label:SetAnchorFill(root)
  label:SetFont("$(BOLD_FONT)|80|thick-outline")
  label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
  label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
  label:SetColor(1, 0.85, 0.1, 1)
  label:SetMouseEnabled(false)
  label:SetText("тяни!")
  label:SetHidden(true)
  self.biteAlert = label

  local fragment = ZO_SimpleSceneFragment:New(root)
  HUD_SCENE:AddFragment(fragment)
  HUD_UI_SCENE:AddFragment(fragment)
end

local states = {
    none = 0,
    fishing = 1,
    bite = 2,
}
function KanaAudibleFishBite:InitializeStateMachine()
  local state = states.none

  EVENT_MANAGER:RegisterForEvent(KanaAudibleFishBite.ADDON_NAME .. "EVENT_INVENTORY_SINGLE_SLOT_UPDATE", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function()
    if state == states.fishing then
      state = states.bite
      KanaAudibleFishBite.biteAlert:SetHidden(false)
      PlaySound(KanaAudibleFishBite.soundVars.SoundFile)
      EVENT_MANAGER:RegisterForUpdate(KanaAudibleFishBite.ADDON_NAME .. "TIMEOUT", 3000, function()
        EVENT_MANAGER:UnregisterForUpdate(KanaAudibleFishBite.ADDON_NAME .. "TIMEOUT")
        KanaAudibleFishBite.biteAlert:SetHidden(true)
        if state == states.bite then
          state = states.none
        end
      end)
    elseif state == states.bite then
      EVENT_MANAGER:UnregisterForUpdate(KanaAudibleFishBite.ADDON_NAME .. "TIMEOUT")
      KanaAudibleFishBite.biteAlert:SetHidden(true)
      state = states.none
    end
  end)

  local mostRecentFishingNode
  local function OnShowOrHide()
    local action, interactableName, _, _, additionalInfo = GetGameCameraInteractableActionInfo()
    if action then
      if additionalInfo == ADDITIONAL_INTERACT_INFO_FISHING_NODE then
        mostRecentFishingNode = interactableName
        state = states.none
        KanaAudibleFishBite.biteAlert:SetHidden(true)
      elseif interactableName == mostRecentFishingNode and state == states.none then
        state = states.fishing
      end
    else
        state = states.none
        KanaAudibleFishBite.biteAlert:SetHidden(true)
    end
  end

  ZO_PreHookHandler(RETICLE.interact, "OnEffectivelyShown", OnShowOrHide)
  ZO_PreHookHandler(RETICLE.interact, "OnHide", OnShowOrHide)
end
