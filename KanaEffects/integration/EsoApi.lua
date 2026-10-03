-- Native ESO boundary. Exact signatures and provenance: docs/api-probe.md.
local EsoApi = {}
KanaEffects.EsoApi = EsoApi
local function method(object, name) return object and type(object[name]) == "function" end
function EsoApi.Build()
    local native = _G
    local api = { constants = {}, controls = {}, capabilities = {} }
    for _, name in ipairs({
        "GetAPIVersion", "GetNumBuffs", "GetUnitBuffInfo", "GetAbilityName", "GetAbilityIcon",
        "DoesAbilityExist", "GetAbilityBuffType", "GetAbilityDuration", "IsAbilityPermanent", "IsAbilityDurationToggled",
        "GetAbilityDescription", "GetAbilityEffectDescription", "GetFrameTimeSeconds", "GetTimeStamp", "GetDateStringFromTimestamp", "GetGameTimeSeconds", "GetGameTimeMilliseconds",
        "DoesUnitExist", "GetUnitName", "AreUnitsEqual", "GetUnitReaction", "GetUIGlobalScale",
        "GetUICustomScale", "GetUIMousePosition", "GetSetting", "GetCVar", "IsInGamepadPreferredMode",
        "LocaleAwareToLower", "zo_strformat", "CreateFont", "GetStringWidthScaled", "GetInterfaceColor",
        "GetWorldName", "GetCurrentCharacterId", "GetDisplayName",
        "PushActionLayerByName", "RemoveActionLayerByName",
        "InitializeTooltip", "SetTooltipText", "ClearTooltipImmediately",
        "GetNextActiveArtificialEffectId", "GetArtificialEffectInfo", "GetArtificialEffectTooltipText",
        "StartScriptProfiler", "StopScriptProfiler", "IsScriptProfilerEnabled", "GetScriptProfilerNumFrames",
        "GetScriptProfilerFrameNumRecords", "GetScriptProfilerRecordInfo", "GetScriptProfilerClosureInfo",
        "GetTotalUserAddOnMemoryPoolUsageMB", "GetTotalUserAddOnMemoryPoolCapacityMB",
    }) do
        if type(native[name]) == "function" then api[name] = native[name] end
    end
    for _, name in ipairs({
        "BOSS_RANK_ITERATION_BEGIN", "BOSS_RANK_ITERATION_END",
        "SCRIPT_PROFILER_RECORD_DATA_TYPE_CLOSURE",
        "EVENT_ADD_ON_LOADED", "EVENT_ADD_ONS_LOADED", "EVENT_PLAYER_ACTIVATED", "EVENT_PLAYER_DEACTIVATED",
        "EVENT_EFFECT_CHANGED", "EVENT_EFFECTS_FULL_UPDATE", "EVENT_RETICLE_TARGET_CHANGED", "EVENT_BOSSES_CHANGED",
        "EVENT_ARTIFICIAL_EFFECT_ADDED", "EVENT_ARTIFICIAL_EFFECT_REMOVED", "MOUSE_BUTTON_INDEX_RIGHT",
        "EVENT_SCREEN_RESIZED", "EVENT_GAMEPAD_PREFERRED_MODE_CHANGED", "EVENT_INTERFACE_SETTING_CHANGED",
        "REGISTER_FILTER_UNIT_TAG", "REGISTER_FILTER_UNIT_TAG_PREFIX", "REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE",
        "BUFF_EFFECT_TYPE_BUFF", "BUFF_EFFECT_TYPE_DEBUFF", "COMBAT_UNIT_TYPE_PLAYER",
        "EFFECT_RESULT_FADED", "EFFECT_RESULT_FULL_REFRESH", "EFFECT_RESULT_GAINED", "EFFECT_RESULT_TRANSFER", "EFFECT_RESULT_UPDATED",
        "SETTING_TYPE_UI", "UI_SETTING_CUSTOM_SCALE", "UI_SETTING_USE_CUSTOM_SCALE",
        "UI_SETTING_GAMEPAD_CUSTOM_SCALE", "UI_SETTING_USE_GAMEPAD_CUSTOM_SCALE",
        "CT_CONTROL", "CT_TEXTURE", "CT_LABEL", "CT_BACKDROP", "CT_BUTTON",
        "EVENT_GLOBAL_MOUSE_UP", "EVENT_GAME_FOCUS_CHANGED", "EVENT_PLAYER_COMBAT_STATE",
        "DT_LOW", "DT_HIGH", "KEY_DOWNARROW", "KEY_UPARROW", "SCENE_SHOWING", "SCENE_SHOWN", "SCENE_HIDDEN", "ZO_COMBOBOX_SUPPRESS_UPDATE",
        "SPACE_INTERFACE", "TEXT_WRAP_MODE_ELLIPSIS", "DL_BACKGROUND", "DL_CONTROLS", "DL_OVERLAY", "DL_TEXT",
        "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT",
        "TEXT_ALIGN_LEFT", "TEXT_ALIGN_CENTER", "TEXT_ALIGN_RIGHT", "TEXT_ALIGN_TOP", "TEXT_ALIGN_BOTTOM",
        "BSTATE_NORMAL", "BSTATE_PRESSED", "BSTATE_DISABLED", "INTERFACE_COLOR_TYPE_TEXT_COLORS",
        "INTERFACE_TEXT_COLOR_NORMAL", "INTERFACE_TEXT_COLOR_SELECTED", "INTERFACE_TEXT_COLOR_HIGHLIGHT",
        "INTERFACE_TEXT_COLOR_DISABLED", "INTERFACE_TEXT_COLOR_FAILED",
    }) do
        api.constants[name] = native[name]
        api[name] = native[name]
    end
    -- Source-defined names only; numeric values come from this client.
    for _, name in ipairs({
        "BUFF_TYPE_DEPRECATED_0", "BUFF_TYPE_DEPRECATED_INCREASE_ULT_COST", "BUFF_TYPE_EMPOWER",
        "BUFF_TYPE_GALLOP", "BUFF_TYPE_MAJOR_AEGIS", "BUFF_TYPE_MAJOR_BERSERK",
        "BUFF_TYPE_MAJOR_BREACH", "BUFF_TYPE_MAJOR_BRITTLE", "BUFF_TYPE_MAJOR_BRUTALITY",
        "BUFF_TYPE_MAJOR_COURAGE", "BUFF_TYPE_MAJOR_COWARDICE", "BUFF_TYPE_MAJOR_DEFILE",
        "BUFF_TYPE_MAJOR_ENDURANCE", "BUFF_TYPE_MAJOR_EVASION", "BUFF_TYPE_MAJOR_EXPEDITION",
        "BUFF_TYPE_MAJOR_FORCE", "BUFF_TYPE_MAJOR_FORTITUDE", "BUFF_TYPE_MAJOR_HEROISM",
        "BUFF_TYPE_MAJOR_INTELLECT", "BUFF_TYPE_MAJOR_MAIM", "BUFF_TYPE_MAJOR_MANGLE",
        "BUFF_TYPE_MAJOR_MENDING", "BUFF_TYPE_MAJOR_PROPHECY_DEPRECATED", "BUFF_TYPE_MAJOR_PROTECTION",
        "BUFF_TYPE_MAJOR_RESOLVE", "BUFF_TYPE_MAJOR_SAVAGERY", "BUFF_TYPE_MAJOR_SLAYER",
        "BUFF_TYPE_MAJOR_SORCERY_DEPRECATED", "BUFF_TYPE_MAJOR_TIMIDITY", "BUFF_TYPE_MAJOR_VEXATION",
        "BUFF_TYPE_MAJOR_VITALITY", "BUFF_TYPE_MAJOR_VULNERABILITY", "BUFF_TYPE_MINOR_AEGIS",
        "BUFF_TYPE_MINOR_BERSERK", "BUFF_TYPE_MINOR_BREACH", "BUFF_TYPE_MINOR_BRITTLE",
        "BUFF_TYPE_MINOR_BRUTALITY", "BUFF_TYPE_MINOR_COURAGE", "BUFF_TYPE_MINOR_COWARDICE",
        "BUFF_TYPE_MINOR_DEFILE", "BUFF_TYPE_MINOR_ENDURANCE", "BUFF_TYPE_MINOR_ENERVATION",
        "BUFF_TYPE_MINOR_EVASION", "BUFF_TYPE_MINOR_EXPEDITION", "BUFF_TYPE_MINOR_FORCE",
        "BUFF_TYPE_MINOR_FORTITUDE", "BUFF_TYPE_MINOR_HEROISM", "BUFF_TYPE_MINOR_INTELLECT",
        "BUFF_TYPE_MINOR_LIFESTEAL", "BUFF_TYPE_MINOR_MAGICKASTEAL", "BUFF_TYPE_MINOR_MAIM",
        "BUFF_TYPE_MINOR_MANGLE", "BUFF_TYPE_MINOR_MENDING", "BUFF_TYPE_MINOR_PROPHECY_DEPRECATED",
        "BUFF_TYPE_MINOR_PROTECTION", "BUFF_TYPE_MINOR_RESOLVE", "BUFF_TYPE_MINOR_SAVAGERY",
        "BUFF_TYPE_MINOR_SLAYER", "BUFF_TYPE_MINOR_SORCERY_DEPRECATED", "BUFF_TYPE_MINOR_TIMIDITY",
        "BUFF_TYPE_MINOR_TOUGHNESS", "BUFF_TYPE_MINOR_UNCERTAINTY", "BUFF_TYPE_MINOR_VEXATION",
        "BUFF_TYPE_MINOR_VITALITY", "BUFF_TYPE_MINOR_VULNERABILITY", "BUFF_TYPE_NONE",
    }) do
        api.constants[name] = native[name]
        api[name] = native[name]
    end
    api.capabilities.scriptProfiler=api.constants.SCRIPT_PROFILER_RECORD_DATA_TYPE_CLOSURE~=nil
    for _,name in ipairs({'StartScriptProfiler','StopScriptProfiler','IsScriptProfilerEnabled','GetScriptProfilerNumFrames','GetScriptProfilerFrameNumRecords','GetScriptProfilerRecordInfo','GetScriptProfilerClosureInfo'}) do
        if type(api[name])~='function' then api.capabilities.scriptProfiler=false end
    end
    -- Stock context-menu API (contextmenu.lua:111,184,266). Capture callable
    -- functions once; never replace native globals or submit chat messages.
    local clearMenu,addMenuItem,showMenu=native.ClearMenu,native.AddMenuItem,native.ShowMenu
    if type(clearMenu)=='function' and type(addMenuItem)=='function' and type(showMenu)=='function' then
        api.ContextMenu=function(control,items)
            clearMenu()
            for _,item in ipairs(items or {}) do addMenuItem(item.label,item.callback) end
            showMenu(control); return true
        end
    end
    api.ScrollList = {}
    for _,name in ipairs({"AddDataType", "Clear", "GetDataList", "CreateDataEntry", "Commit", "RefreshVisible", "ScrollDataIntoView"}) do
        api.ScrollList[name] = native["ZO_ScrollList_" .. name]
    end
    if not api.ScrollList.AddDataType or not api.ScrollList.Commit then api.ScrollList = nil end
    api.ComboBox = native.ZO_ComboBox_ObjectFromContainer
    api.CheckButton = {}
    for _, name in ipairs({"SetLabelText", "SetCheckState", "SetToggleFunction", "IsChecked"}) do
        api.CheckButton[name] = native["ZO_CheckButton_" .. name]
    end
    api.Scroll = {UpdateScrollBar=native.ZO_Scroll_UpdateScrollBar}
    -- Use the stock scene-manager recipe: raw camera toggling alone would not
    -- switch HUD/HUDUI or perform native focus/scene-lock checks.
    local sceneManager=native.SCENE_MANAGER
    if method(sceneManager,"IsInUIMode") and method(sceneManager,"SetInUIMode") then
        api.EditorUIMode={
            IsActive=function() return sceneManager:IsInUIMode() end,
            SetActive=function(active) return sceneManager:SetInUIMode(active) end,
            CanRestore=function()
                if not method(sceneManager,"GetCurrentSceneName") or not method(sceneManager,"GetNextScene") then return false end
                local current=sceneManager:GetCurrentSceneName(); local pending=sceneManager:GetNextScene()
                local nextName=pending and pending:GetName()
                return (current=="hud" or current=="hudui") and (nextName==nil or nextName=="hud" or nextName=="hudui")
            end,
        }
    end
    api.eventManager = native.EVENT_MANAGER
    api.hudManager = native.HUD_MANAGER
    api.callbackManager = native.CALLBACK_MANAGER
    api.windowManager = native.WINDOW_MANAGER
    api.fonts = { game = native.ZoFontGame, gameBold = native.ZoFontGameBold }
    api.informationTooltip = native.InformationTooltip
    api.sceneFragmentClass = native.ZO_SimpleSceneFragment
    api.scenes = {hud=native.HUD_SCENE, hudui=native.HUD_UI_SCENE}
    api.slashCommands = native.SLASH_COMMANDS
    local chatRouter = native.CHAT_ROUTER
    api.LocalMessage = function(text)
        if method(chatRouter, "AddSystemMessage") then chatRouter:AddSystemMessage(text) end
    end
    api.savedVars = native.ZO_SavedVars
    -- Raw preservation must precede the native helper's destructive version check.
    api.GetSettingsTable = function() return native.KanaEffectsSettings end
    api.SetSettingsTable = function(value) native.KanaEffectsSettings = value end
    api.anchorClass = native.ZO_Anchor
    api.hudOptionTypes = native.ZO_HUD_EDITOR_OPTION_TYPES
    api.hudEditorScene = native.HUD_EDITOR_SCENE_KEYBOARD
    api.NativeHUDEditorPending=function()
        return api.hudEditorScene~=nil and method(sceneManager,'GetNextScene') and sceneManager:GetNextScene()==api.hudEditorScene
    end
    for _, name in ipairs({ "GuiRoot", "ZO_TargetUnitFramereticleover", "ZO_ActionBar1", "ZO_PlayerAttributeHealth", "ZO_PlayerAttributeMagicka", "ZO_PlayerAttributeStamina" }) do
        api.controls[name] = native[name]
    end
    -- The template name is not a control. Native creation appends unitTag,
    -- and may happen after Build, so retain a dynamic boundary lookup.
    api.GetTargetFrameControl=function() return native.ZO_TargetUnitFramereticleover end
    local wm = api.windowManager
    -- WindowManager returns GuiRoot UI units; no Retina/global-scale multiplier.
    if method(wm, "GetUIMousePosition") then
        api.GetUIMousePosition=function() return wm:GetUIMousePosition() end
    end
    if method(wm, "CreateControl") then
        api.controls.CreateControl = function(name, parent, controlType) return wm:CreateControl(name, parent, controlType) end
    end
    if method(wm, "CreateTopLevelWindow") then
        api.controls.CreateTopLevelWindow = function(name) return wm:CreateTopLevelWindow(name) end
    end
    if method(wm, "CreateControlFromVirtual") then
        api.controls.CreateControlFromVirtual = function(name, parent, template, suffix)
            return wm:CreateControlFromVirtual(name, parent, template, suffix)
        end
    end
    local now = api.GetFrameTimeSeconds
    api.Now = function()
        assert(now, "GetFrameTimeSeconds unavailable; seconds clock cannot be inferred")
        return now()
    end
    local lower = api.LocaleAwareToLower or string.lower
    api.NormalizeName = function(text)
        assert(type(text) == "string", "NormalizeName expects text")
        -- ESO grammatical suffix is metadata; trim it before case folding.
        text = string.gsub(text, "%^.*$", "")
        text = string.gsub(string.gsub(text, "^%s+", ""), "%s+$", "")
        return lower(text)
    end
    local capabilities = api.capabilities
    capabilities.clock = now ~= nil
    capabilities.historyTimestamp = api.GetTimeStamp ~= nil
    capabilities.localizedNormalization = api.LocaleAwareToLower ~= nil
    capabilities.buffs = api.GetNumBuffs ~= nil and api.GetUnitBuffInfo ~= nil
    capabilities.unitExistence = api.DoesUnitExist ~= nil
    capabilities.bossTags = api.DoesUnitExist ~= nil -- Tag support is sampled live by the probe.
    capabilities.events = method(api.eventManager, "RegisterForEvent") and method(api.eventManager, "UnregisterForEvent") or false
    capabilities.controls = api.controls.CreateControl ~= nil and api.controls.GuiRoot ~= nil
    capabilities.nativeHudRegistration = method(api.hudManager, "RegisterKeyboardElement") or false
    capabilities.nativeHudRebuild = method(api.hudManager, "RebuildAllElements") or false
    capabilities.nativeHudCallbacks = method(api.hudManager, "RegisterCallback") and method(api.hudManager, "UnregisterCallback") or false
    -- No public removal signature exists in the checked API/source. Never infer it
    -- from a similarly named live/private method or mutate manager tables.
    capabilities.nativeHudRemoval = false
    capabilities.nativeHudOptions = api.hudOptionTypes ~= nil
    return api
end
