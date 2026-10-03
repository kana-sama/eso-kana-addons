KanaCurrentlyEquipped = KanaCurrentlyEquipped or {}
local KCE = KanaCurrentlyEquipped

KCE.name = "KanaCurrentlyEquipped"
KCE.inventoryOpen = false

function KCE.ApplyVisibility()
    if not CurrentlyEquipped or not CEFrame then return end

    local visible = KCE.inventoryOpen and CurrentlyEquipped.show_UI ~= false
    CEFrame:SetHidden(not visible)
end

function KCE.OnInventorySceneStateChange(_, newState)
    KCE.inventoryOpen = newState == SCENE_SHOWING or newState == SCENE_SHOWN
    KCE.ApplyVisibility()
end

function KCE.HookCurrentlyEquipped()
    for _, method in ipairs({ "UpdateUI", "HideUICombat", "LayerChange", "SaveHideInMenu" }) do
        if type(CurrentlyEquipped[method]) == "function" then
            ZO_PostHook(CurrentlyEquipped, method, KCE.ApplyVisibility)
        end
    end

    local inventoryScene = SCENE_MANAGER:GetScene("inventory")
    if inventoryScene then
        inventoryScene:RegisterCallback("StateChange", KCE.OnInventorySceneStateChange)
    end

    KCE.ApplyVisibility()
end

function KCE.OnAddOnLoaded(_, addonName)
    if addonName ~= KCE.name then return end

    EVENT_MANAGER:UnregisterForEvent(KCE.name, EVENT_ADD_ON_LOADED)
    KCE.HookCurrentlyEquipped()
end

EVENT_MANAGER:RegisterForEvent(KCE.name, EVENT_ADD_ON_LOADED, KCE.OnAddOnLoaded)
