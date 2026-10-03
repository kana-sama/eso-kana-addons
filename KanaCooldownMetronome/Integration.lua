local A, CM = KanaCooldownMetronome, CombatMetronome
local defaults = A.DEFAULT_SAVED_VARS.Progressbar

function A:LoadSettings()
    KanaCooldownMetronomeSavedVars = KanaCooldownMetronomeSavedVars or {version = 1, profiles = {}}
    local saved = KanaCooldownMetronomeSavedVars
    saved.profiles = saved.profiles or {}
    -- Import every old profile once, so switching characters does not lose the
    -- old geometry. Never overwrite settings already owned by this extension.
    local legacy = CombatMetronomeSavedVars and CombatMetronomeSavedVars.Default or {}
    for account, profiles in pairs(legacy) do
        if type(profiles) == "table" then
            saved.profiles[account] = saved.profiles[account] or {}
            for id, profile in pairs(profiles) do
                if type(profile) == "table" and profile.Progressbar and not saved.profiles[account][id] then
                    local imported = {}
                    for key in pairs(defaults) do imported[key] = profile.Progressbar[key] end
                    saved.profiles[account][id] = imported
                end
            end
        end
    end
    local account = GetDisplayName()
    local id = CM.SV.global and "$AccountWide" or GetCurrentCharacterId()
    saved.profiles[account] = saved.profiles[account] or {}
    local settings = saved.profiles[account][id]
    if not settings then
        settings = {}
        for key in pairs(defaults) do settings[key] = CM.SV.Progressbar[key] end
        saved.profiles[account][id] = settings
    end
    for key, value in pairs(defaults) do
        if settings[key] == nil then settings[key] = value end
    end
    self.settings = settings
    -- Geometry belongs to this addon; colors, visibility and timing settings
    -- continue to come from the current Combat Metronome profile.
    self.SV = {Progressbar = setmetatable({}, {
        __index = function(_, key)
            if defaults[key] ~= nil then return A.settings[key] end
            return CM.SV.Progressbar[key]
        end,
        __newindex = function(_, key, value)
            if defaults[key] ~= nil then A.settings[key] = value
            else CM.SV.Progressbar[key] = value end
        end,
    })}
end

function A:PositionRing()
    if not self.settings.radialCooldown then return end
    local frame = self.Progressbar.frame
    frame:ClearAnchors()
    frame:SetAnchor(CENTER, GuiRoot, TOPLEFT, self.settings.radialCenterX, self.settings.radialCenterY)
end

function A:HideFancy(value)
    CM:HideFancy(value)
end

function A:ExtendMenu()
    local options = CM.menu and CM.menu.options and CM.menu.options.Progressbar
    if not options then return end
    for _, option in ipairs(options) do
        if option.kanaCooldownMetronome then return end
    end
    local option = self:RadialOptions()
    option.kanaCooldownMetronome = true
    local position = 1
    for i, entry in ipairs(options) do
        if entry.name == "Position / Size" then position = i; break end
    end
    -- LAM keeps this options table by reference and builds controls lazily.
    table.insert(options, position, option)
end

function A:AttachUI(ui)
    self.Progressbar = CM.Progressbar
    local pb = self.Progressbar
    if pb.kanaCooldownAttached then return end
    pb.kanaCooldownAttached = true
    self:LoadSettings()
    local hidden = pb.bar.background:IsHidden()
    self:AttachRadialBar()
    local function After(name, callback)
        local original = ui[name]
        ui[name] = function(...)
            original(...)
            callback()
        end
    end
    After("Position", function() A:PositionRing() end)
    After("Anchors", function() A:RadialLayout() end)
    After("HiddenStates", function() A:UpdateRadialBar() end)
    After("BarColors", function() A:UpdateRadialBar() end)
    local size = ui.Size
    ui.Size = function(...)
        pb.frame:SetDimensionConstraints(50, 10, GuiRoot:GetWidth(), 100)
        size(...)
        A:RadialLayout()
    end
    local move, resize = pb.frame:GetHandler("OnMoveStop"), pb.frame:GetHandler("OnResizeStop")
    pb.frame:SetHandler("OnMoveStop", function(...)
        if A.settings.radialCooldown then
            A.settings.radialCenterX = pb.frame:GetLeft() + pb.frame:GetWidth() / 2
            A.settings.radialCenterY = pb.frame:GetTop() + pb.frame:GetHeight() / 2
            ui.Anchors()
        elseif move then move(...) end
    end)
    pb.frame:SetHandler("OnResizeStop", function(...)
        if A.settings.radialCooldown then
            A.settings.radialOuterRadius = math.floor(math.min(pb.frame:GetWidth(), pb.frame:GetHeight()) / 2)
            A:RefreshRadialSettings()
        elseif resize then resize(...) end
    end)
    pb.bar:SetHidden(hidden)
    self:RadialLayout()
    self:PositionRing()
end

function A:Initialize()
    if self.initialized then return end
    if not CM or not CM.Progressbar or not CM.Progressbar.UI or not CM.menu or not CM.menu.options then
        d("KanaCooldownMetronome: Combat Metronome is not initialized; radial extension was not loaded.")
        return
    end
    self.initialized = true
    self:AttachUI(CM.Progressbar.UI)
    self:ExtendMenu()
    local buildUI = CM.BuildUI
    CM.BuildUI = function(owner, ...)
        local ui = buildUI(owner, ...)
        owner.Progressbar.kanaCooldownAttached = nil
        A:AttachUI(ui)
        return ui
    end
    local buildMenu = CM.BuildMenu
    CM.BuildMenu = function(owner, ...)
        buildMenu(owner, ...)
        A:ExtendMenu()
    end
    local hideFancy = CM.HideFancy
    CM.HideFancy = function(owner, hidden)
        return hideFancy(owner, hidden or A.settings.radialCooldown)
    end
    local reset = CM.ResetBarValues
    CM.ResetBarValues = function(owner, ...)
        reset(owner, ...)
        A:UpdateRadialBar()
    end
    local update = CM.Update
    CM.Update = function(owner, ...)
        update(owner, ...)
        if A.settings.radialCooldown then
            -- Original dynamic icon anchoring is local to CMProgressbar.lua.
            -- Restore the radial anchor after the original update has finished.
            local pb = owner.Progressbar
            pb.spellIcon:ClearAnchors()
            pb.spellIcon:SetAnchor(BOTTOM, pb.frame, TOP, 0, -4)
            pb.spellIconAnchoredDynamically = false
        end
    end
    SCENE_MANAGER:RegisterCallback("SceneStateChanged", function()
        -- The base scene callback uses its local Position function.
        A:PositionRing()
        A:UpdateRadialBar()
    end)
end

EVENT_MANAGER:RegisterForEvent(A.name, EVENT_ADD_ON_LOADED, function(_, name)
    if name ~= A.name then return end
    EVENT_MANAGER:UnregisterForEvent(A.name, EVENT_ADD_ON_LOADED)
    A:Initialize()
end)
