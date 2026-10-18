KanaLazySetCrafterAutoHide = KanaLazySetCrafterAutoHide or {}
local addon = KanaLazySetCrafterAutoHide
local NAME = 'KanaLazySetCrafterAutoHide'

function addon.Initialize(a)
    if addon.initialized then return end
    local crafter, window = a.DolgubonSetCrafter, a.DolgubonSetCrafterWindow
    if not crafter or not crafter.savedvars or type(crafter.savedvars.queue) ~= 'table'
        or type(crafter.close) ~= 'function' or type(crafter.GetSettings) ~= 'function'
        or type(crafter.GetAutocraft) ~= 'function' or type(crafter.toggleCraftButton) ~= 'function'
        or not crafter.name or not window or not a.CraftingQueueScroll
        or not a.DolgubonSetCrafterToggle or not a.KEYBIND_STRIP or not a.SCENE_MANAGER then return end

    local supported = {
        [a.CRAFTING_TYPE_BLACKSMITHING] = true,
        [a.CRAFTING_TYPE_CLOTHIER] = true,
        [a.CRAFTING_TYPE_ENCHANTING] = true,
        [a.CRAFTING_TYPE_WOODWORKING] = true,
        [a.CRAFTING_TYPE_JEWELRYCRAFTING] = true,
    }
    local ru = a.GetCVar('language.2') == 'ru'
    local activeStation, activeScene, added
    local keybinds = {
        alignment = a.KEYBIND_STRIP_ALIGN_RIGHT,
        {
            name = function()
                if window:IsHidden() then return ru and 'Показать Set Crafter' or 'Show Set Crafter' end
                return ru and 'Скрыть Set Crafter' or 'Hide Set Crafter'
            end,
            -- Reuse the user's existing binding; do not take a crafting shortcut.
            keybind = 'SET_CRAFTER_OPEN',
            callback = function()
                if supported[a.GetCraftingInteractionType()] then crafter.close() end
            end,
        },
    }
    local function RefreshKeybind()
        if added then a.KEYBIND_STRIP:UpdateKeybindButtonGroup(keybinds) end
    end
    local function RemoveKeybind()
        if added then
            a.KEYBIND_STRIP:RemoveKeybindButtonGroup(keybinds)
            added = false
        end
        activeScene = nil
    end
    local function OnSceneState(scene, state)
        if state == a.SCENE_SHOWING or state == a.SCENE_SHOWN then
            if not supported[a.GetCraftingInteractionType()] then return end
            activeScene = scene
            if not added then
                a.KEYBIND_STRIP:AddKeybindButtonGroup(keybinds)
                added = true
            else
                RefreshKeybind()
            end
        elseif (state == a.SCENE_HIDING or state == a.SCENE_HIDDEN) and activeScene == scene then
            RemoveKeybind()
        end
    end
    for _, name in ipairs({
        'smithing', 'enchanting',
        'gamepad_smithing_root', 'gamepad_smithing_refine', 'gamepad_smithing_creation',
        'gamepad_smithing_deconstruct', 'gamepad_smithing_improvement', 'gamepad_smithing_research',
        'gamepad_smithing_consolidatedSetSelection', 'gamepad_enchanting_mode',
        'gamepad_enchanting_creation', 'gamepad_enchanting_extraction',
        'gamepad_provisioner_root', 'gamepad_provisioner_options', -- furnishings at these stations
    }) do
        local scene = a.SCENE_MANAGER:GetScene(name)
        if scene then
            scene:RegisterCallback('StateChange', function(_, state) OnSceneState(scene, state) end)
            OnSceneState(scene, scene:GetState())
        end
    end
    -- Also catches the original slash command, which captures a local closeWindow
    -- and would bypass a hook on the exported crafter.close function.
    a.ZO_PostHookHandler(window, 'OnShow', RefreshKeybind)
    a.ZO_PostHookHandler(window, 'OnHide', RefreshKeybind)

    -- Set Crafter 3.0.8.0 opens from a private local closeWindow inside this
    -- event. Replace only its entry policy, retaining its manual-craft setup.
    -- Its exit handler, crafting library callbacks and saved settings stay intact.
    a.EVENT_MANAGER:UnregisterForEvent(crafter.name, a.EVENT_CRAFTING_STATION_INTERACT)
    a.EVENT_MANAGER:RegisterForEvent(NAME, a.EVENT_CRAFTING_STATION_INTERACT, function(_, station, sameStation)
        if not supported[station] or a.GetCraftingInteractionType() ~= station then return end
        if not crafter:GetAutocraft() then crafter.toggleCraftButton(true) end
        if activeStation ~= station or not sameStation then
            activeStation = station
            crafter.close(next(crafter.savedvars.queue) == nil)
        end
        a.DolgubonSetCrafterToggle:SetHidden(not crafter:GetSettings().showToggle)
    end)
    a.EVENT_MANAGER:RegisterForEvent(NAME, a.EVENT_END_CRAFTING_STATION_INTERACT, function()
        activeStation = nil
        RemoveKeybind()
    end)
    addon.initialized = true
end

EVENT_MANAGER:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, function(_, name)
    if name ~= NAME then return end
    EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED)
    addon.Initialize(_G)
end)
