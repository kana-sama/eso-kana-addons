local Addon = KanaBuffPanels
local Panels = {}
Panels.__index = Panels
Addon.Panels = Panels

function Panels.New(savedPanels, parent)
    local self = setmetatable({saved = savedPanels, parent = parent, records = {}, groups = {}, metrics = {}}, Panels)
    self.measure = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
    self.measure:SetHidden(true)
    self.measure:SetExcludeFromResizeToFitExtents(true)
    self.measure:SetMaxLineCount(2)
    HUD_MANAGER:RegisterCallback("SavedVarsReady", function() self:RefreshOptions(true) end)
    HUD_MANAGER:RegisterCallback("PropagateSettings", function() self:RefreshOptions() end)
    return self
end

function Panels:Create(id)
    local root = WINDOW_MANAGER:CreateControl("KanaBuffPanelsPanel" .. id, self.parent, CT_CONTROL)
    root:SetDimensions(1, 1)
    root:SetAnchor(CENTER, GuiRoot, CENTER, 0, -100 - ((id - 1) % 5) * 70)
    root:SetExcludeFromResizeToFitExtents(true)
    local bounds = WINDOW_MANAGER:CreateControl(nil, root, CT_CONTROL)
    bounds:SetExcludeFromResizeToFitExtents(true)
    root.hudElementRef = bounds
    local record = {root = root, bounds = bounds}
    self.records[id] = record
    local function options()
        return {
            {type = ZO_HUD_EDITOR_OPTION_TYPES.ENUM, key = "orientation", name = Addon.Strings.orientation,
                values = {1, 2}, valueStringPrefix = "SI_KBP_ORIENTATION", defaultValue = 1,
                callback = function()
                    self:RefreshOptions()
                    HUD_MANAGER:RebuildAllElements()
                end},
            {type = ZO_HUD_EDITOR_OPTION_TYPES.ENUM, key = "growth", name = Addon.Strings.growth,
                values = {1, 2, 3}, valueStringPrefix = "SI_KBP_HORIZONTAL", defaultValue = 1,
                callback = function() self:Render(self.groups) end},
            {type = ZO_HUD_EDITOR_OPTION_TYPES.ENUM, key = "timerPosition", name = Addon.Strings.timerPosition,
                values = {1, 2, 3, 4}, valueStringPrefix = "SI_KBP_TIMER_POSITION", defaultValue = 1,
                callback = function() self:Render(self.groups) end},
        }
    end
    local function name() return self.saved[id] and self.saved[id].name or "" end
    local config = {isValid = function() return self.saved[id] ~= nil and not self.disabled end}
    record.keyboard = HUD_MANAGER:RegisterKeyboardElement(root, name, config, options())
    record.gamepad = HUD_MANAGER:RegisterGamepadElement(root, name, config, options())
    local active = IsInGamepadPreferredMode() and record.gamepad or record.keyboard
    active:RevertOffsetModifications()
end

function Panels:Sync()
    if self.disabled then return end
    local changed = false
    for id in pairs(self.saved) do
        if not self.records[id] then self:Create(id);changed = true end
    end
    for id, record in pairs(self.records) do
        local name = self.saved[id] and self.saved[id].name
        if record.name ~= name then record.name = name;changed = true end
        if not name then record.root:SetHidden(true) end
    end
    if changed then
        self:RefreshOptions()
        HUD_MANAGER:RebuildAllElements()
    end
end

function Panels:RefreshOptions(restoreOffsets)
    if self.disabled then return end
    self.metrics = {}
    for _, record in pairs(self.records) do
        for _, element in ipairs({record.keyboard, record.gamepad}) do
            element:GetCustomOptions()[2].valueStringPrefix = element:GetCustomOptionValue("orientation") == 2
                and "SI_KBP_VERTICAL" or "SI_KBP_HORIZONTAL"
        end
        if restoreOffsets then
            local active = IsInGamepadPreferredMode() and record.gamepad or record.keyboard
            active:RevertOffsetModifications()
        end
    end
    self:Render(self.groups)
end

function Panels:Measure(controls, timerPosition)
    local icon = controls[1]
    local gamepad = IsInGamepadPreferredMode()
    local size = gamepad and (ZO_BUFF_DEBUFF_FRAME_DIMENSIONS_GAMEPAD or 46)
        or (ZO_BUFF_DEBUFF_FRAME_DIMENSIONS_KEYBOARD or 40)
    local width, height = size, size
    local font = gamepad and "ZoFontGamepadBold20" or "ZoFontWinT2"
    if icon then
        width, height = icon:GetDimensions()
        font = icon.duration:GetFont()
    end
    local key = tostring(font) .. ":" .. width .. ":" .. height
    if not self.metrics[key] then
        self.measure:SetFont(font)
        self.measure:SetWidth(width)
        self.measure:SetText("0\n0")
        self.metrics[key] = {width = width, height = height, labelHeight = self.measure:GetTextHeight()}
    end
    local hasDuration = {}
    for index, control in ipairs(controls) do hasDuration[index] = Addon.TimerLayout.HasDuration(control) end
    return {width = width, height = height, labelWidth = width, labelHeight = self.metrics[key].labelHeight,
        gap = 5, timerPosition = timerPosition, hasDuration = hasDuration}
end

function Panels:Render(groups)
    if self.disabled then return end
    self.groups = groups
    for id in pairs(self.saved) do
        local record = self.records[id]
        if record then
            local controls = groups[id] or {}
            local element = IsInGamepadPreferredMode() and record.gamepad or record.keyboard
            local timerPosition = element:GetCustomOptionValue("timerPosition")
            local metrics = self:Measure(controls, timerPosition)
            local layout = Addon.Layout.Place(#controls, element:GetCustomOptionValue("orientation"),
                element:GetCustomOptionValue("growth"), metrics)
            for index, control in ipairs(controls) do
                control:SetParent(record.root)
                control:SetExcludeFromResizeToFitExtents(true)
                control:ClearAnchors()
                local center = layout.centers[index]
                control:SetAnchor(CENTER, record.root, CENTER, center.x, center.y)
                Addon.TimerLayout.Apply(control, timerPosition, metrics)
            end
            local bounds = layout.bounds
            record.bounds:ClearAnchors()
            record.bounds:SetAnchor(TOPLEFT, record.root, CENTER, bounds.x, bounds.y)
            record.bounds:SetDimensions(bounds.width, bounds.height)
            -- HUD editor observes the root's OnRectChanged, not hudElementRef.
            -- Resizing a CENTER-anchored root leaves the layout origin fixed.
            record.root:SetDimensions(bounds.width, bounds.height)
            record.root:SetHidden(#controls == 0)
        end
    end
end

function Panels:Disable()
    self.disabled = true
    for _, record in pairs(self.records) do record.root:SetHidden(true) end
    HUD_MANAGER:RebuildAllElements()
end
