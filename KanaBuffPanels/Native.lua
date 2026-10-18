local Addon = KanaBuffPanels
local Native = {}
Native.__index = Native
Addon.Native = Native

local function StockLayout(pool, controls)
    local previous, width = nil, 0
    for _, control in ipairs(controls) do
        Addon.TimerLayout.Restore(control)
        control:SetParent(pool.container)
        control:SetExcludeFromResizeToFitExtents(false)
        control:ClearAnchors()
        if previous then
            control:SetAnchor(LEFT, previous, RIGHT, 5, 0)
            width = width + 5
        else
            control:SetAnchor(LEFT, pool.container, LEFT, 0, 0)
        end
        width = width + control:GetWidth()
        previous = control
    end
    pool.container:SetWidth(width)
end

function Native.Bind(container, onUpdated, onAcquire)
    if container and container.kbpAdapter and container.kbpAdapter.active then
        return container.kbpAdapter
    end
    if not container or type(container.GetPools) ~= "function"
        or type(container.GetControl) ~= "function" or type(container.Update) ~= "function"
        or type(container.RefreshContainerVisibility) ~= "function" then
        return nil, "player effect container"
    end
    local buffPool, debuffPool = container:GetPools()
    for _, pool in pairs({buff = buffPool or false, debuff = debuffPool or false}) do
        if not pool or not pool.container or type(pool.SetCustomAcquireBehavior) ~= "function"
            or type(pool.SetCustomResetBehavior) ~= "function"
            or type(pool.customAcquireBehavior) ~= "function" or type(pool.customResetBehavior) ~= "function" then
            return nil, "player effect pools"
        end
    end
    local self = setmetatable({container = container, pools = {buffPool, debuffPool},
        icons = {{}, {}}, active = true}, Native)
    self.hidden = WINDOW_MANAGER:CreateControl(nil, container:GetControl(), CT_CONTROL)
    self.hidden:SetExcludeFromResizeToFitExtents(true)
    self.hidden:SetHidden(true)
    self.visible = WINDOW_MANAGER:CreateControl(nil, container:GetControl(), CT_CONTROL)
    self.visible:SetExcludeFromResizeToFitExtents(true)
    for index, pool in ipairs(self.pools) do
        local acquire, reset = pool.customAcquireBehavior, pool.customResetBehavior
        pool:SetCustomAcquireBehavior(function(control)
            acquire(control)
            if self.active then
                control.kbpOwner = self
                local ordered = self.icons[index]
                ordered[#ordered + 1] = control
                if onAcquire then onAcquire(control) end
            end
        end)
        pool:SetCustomResetBehavior(function(control)
            if control.kbpOwner == self then
                Addon.TimerLayout.Restore(control)
                control.kbpOwner = nil
                control:SetExcludeFromResizeToFitExtents(false)
            end
            reset(control)
        end)
    end
    local update = container.Update
    container.Update = function(object, ...)
        if self.active then self.icons = {{}, {}} end
        update(object, ...)
        if self.active and onUpdated then onUpdated() end
    end
    -- Mirror the native group's contextual visibility (including quickslot wheels).
    -- This runs in ESO's existing visibility pass and never traverses the panels.
    local refreshVisibility = container.RefreshContainerVisibility
    container.RefreshContainerVisibility = function(object, ...)
        refreshVisibility(object, ...)
        if self.active then
            local hidden = buffPool.container:IsHidden() and debuffPool.container:IsHidden()
            if self.visible:IsHidden() ~= hidden then self.visible:SetHidden(hidden) end
        end
    end
    container.kbpAdapter = self
    container.isDirty = true
    return self
end

function Native:GetIcons()
    return self.icons[1], self.icons[2]
end

function Native:GetPanelParent()
    return self.visible
end

function Native:Redistribute(rules, panels)
    if not self.active then return end
    local groups = {}
    for index, ordered in ipairs(self.icons) do
        local stock = {}
        for _, control in ipairs(ordered) do
            if control.kbpOwner == self then
                local destination = rules:Destination(Addon.Rules.EffectKey(control.data))
                if destination == "hidden" then
                    Addon.TimerLayout.Restore(control)
                    control:SetParent(self.hidden)
                    control:SetExcludeFromResizeToFitExtents(true)
                elseif destination == "default" then
                    stock[#stock + 1] = control
                else
                    local group = groups[destination] or {}
                    groups[destination] = group
                    group[#group + 1] = control
                end
            end
        end
        StockLayout(self.pools[index], stock)
    end
    panels:Render(groups)
end

function Native:Restore()
    if not self.active then return end
    self.active = false
    for index, ordered in ipairs(self.icons) do
        local stock = {}
        for _, control in ipairs(ordered) do
            if control.kbpOwner == self then
                control.kbpOwner = nil
                stock[#stock + 1] = control
            end
        end
        StockLayout(self.pools[index], stock)
    end
    self.container.isDirty = true
end
