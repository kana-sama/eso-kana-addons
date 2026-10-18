local Addon = KanaBuffPanels
local NAME = "KanaBuffPanels"

local function Fail(reason)
    if Addon.native then Addon.native:Restore() end
    if Addon.panels then Addon.panels:Disable() end
    if not Addon.warned then
        Addon.warned = true
        d(Addon.displayName .. ": " .. Addon.Strings.unavailable .. tostring(reason))
    end
end

local function Redistribute()
    if Addon.native and Addon.native.active then
        local ok, err = pcall(Addon.native.Redistribute, Addon.native, Addon.rules, Addon.panels)
        if not ok then Fail(err) end
    end
end

function Addon.Refresh()
    if Addon.native and Addon.native.active then
        local ok, err = pcall(Addon.panels.Sync, Addon.panels)
        if ok then Redistribute() else Fail(err) end
    end
    if Addon.settings then Addon.settings:Refresh() end
end

function Addon.Initialize(addonName)
    if addonName ~= NAME or Addon.initialized then return end
    Addon.initialized = true
    EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED)
    local ok, err = pcall(function()
        for _, method in ipairs({"RegisterKeyboardElement", "RegisterGamepadElement", "RegisterCallback", "RebuildAllElements"}) do
            assert(HUD_MANAGER and type(HUD_MANAGER[method]) == "function", "HUD_MANAGER." .. method)
        end
        assert(ZO_HUD_EDITOR_OPTION_TYPES and ZO_HUD_EDITOR_OPTION_TYPES.ENUM, "HUD editor options")
        assert(LibAddonMenu2 and AddCustomMenuItem and AddCustomSubMenuItem, "LibAddonMenu / LibCustomMenu")
        Addon.saved = ZO_SavedVars:NewAccountWide("KanaBuffPanelsSV", 1, nil,
            {nextPanelId = 1, panels = {}, assignments = {}, hidden = {}})
        Addon.rules = Addon.Rules.New(Addon.saved, LocaleAwareToLower)
        local container = BUFF_DEBUFF and BUFF_DEBUFF.containerObjectsByUnitTag
            and BUFF_DEBUFF.containerObjectsByUnitTag.player
        local native, reason = Addon.Native.Bind(container, Redistribute, function(control)
            Addon.Menu.Bind(control, Addon.rules, Addon.Refresh)
        end)
        assert(native, reason)
        Addon.native = native
        Addon.panels = Addon.Panels.New(Addon.rules.saved.panels, native:GetPanelParent())
        Addon.panels:Sync()
        Addon.settings = Addon.Settings.Register(Addon.rules, Addon.Refresh)
    end)
    if not ok then Fail(err) end
end

EVENT_MANAGER:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, function(_, addonName) Addon.Initialize(addonName) end)
