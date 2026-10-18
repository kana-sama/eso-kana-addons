KanaCurrentlyEquipped = KanaCurrentlyEquipped or {}
local KCE = KanaCurrentlyEquipped

KCE.name = "KanaCurrentlyEquipped"
KCE.inventoryOpen = false

function KCE.InitializeSettings()
    KCE.settings = ZO_SavedVars:NewAccountWide('KanaCurrentlyEquippedSV', 1, nil, {
        inventoryOnly = true,
    })
    local panelId = 'KanaCurrentlyEquipped_Panel'
    LibAddonMenu2:RegisterAddonPanel(panelId, {
        type = 'panel',
        name = 'Kana CurrentlyEquipped: visibility fix',
        displayName = '|cFF0000Kana|r |c4488FFCurrentlyEquipped|r: |cFFFFFFvisibility fix|r',
        author = 'Kana',
        version = '1.0.0',
        registerForRefresh = true,
        registerForDefaults = true,
    })
    LibAddonMenu2:RegisterOptionControls(panelId, {{
        type = 'checkbox',
        name = 'Показывать панель только в инвентаре',
        getFunc = function() return KCE.settings.inventoryOnly ~= false end,
        setFunc = function(value) KCE.settings.inventoryOnly = value end,
        default = true,
        requiresReload = true,
        width = 'full',
    }})
end

function KCE.ApplyVisibility()
    if KCE.settings and KCE.settings.inventoryOnly == false then return end
    if not CurrentlyEquipped or not CEFrame then return end

    local visible = KCE.inventoryOpen and CurrentlyEquipped.show_UI ~= false
    CEFrame:SetHidden(not visible)
end

function KCE.OnInventorySceneStateChange(_, newState)
    KCE.inventoryOpen = newState == SCENE_SHOWING or newState == SCENE_SHOWN
    KCE.ApplyVisibility()
end

function KCE.HookCurrentlyEquipped()
    if KCE.settings and KCE.settings.inventoryOnly == false then return end
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
    KCE.InitializeSettings()
    KCE.HookCurrentlyEquipped()
end

EVENT_MANAGER:RegisterForEvent(KCE.name, EVENT_ADD_ON_LOADED, KCE.OnAddOnLoaded)
