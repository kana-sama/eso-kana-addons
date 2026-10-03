-- Annular cooldown: 0 is twelve o'clock, increasing clockwise.
-- The centre stays transparent; all visible pieces use ordinary bar backdrops.
local CM = KanaCooldownMetronome
local TAU = 2 * math.pi

local function Clamp(value, low, high)
    return math.max(low, math.min(high, value))
end

-- Match the normal bar's foreground-over-background alpha composition in each strip.
local function CompositeColor(foreground, background)
    local foregroundAlpha = foreground[4] or 1
    local backgroundWeight = (background[4] or 1) * (1 - foregroundAlpha)
    local alpha = foregroundAlpha + backgroundWeight
    if alpha == 0 then return {0, 0, 0, 0} end
    return {
        (foreground[1] * foregroundAlpha + background[1] * backgroundWeight) / alpha,
        (foreground[2] * foregroundAlpha + background[2] * backgroundWeight) / alpha,
        (foreground[3] * foregroundAlpha + background[3] * backgroundWeight) / alpha,
        alpha,
    }
end

-- Render with the same CT_BACKDROP primitive as the linear bar. Native Polygon
-- controls fail the standalone ring test on the user's ESO client.
local function DrawRing(radial, inner, outer, progress, ping, colors)
    if radial.inner ~= inner or radial.outer ~= outer then
        radial.inner, radial.outer = inner, outer
        radial.rows = {}
        -- Half a UI unit per row at normal sizes; bound cost for very large rings.
        local count = math.min(512, math.ceil(outer * 2) * 2)
        local height = 2 * outer / count
        for i = 1, count do
            local y = -outer + (i - .5) * height
            local outside = math.sqrt(math.max(0, outer * outer - y * y))
            local inside = math.sqrt(math.max(0, inner * inner - y * y))
            radial.rows[i] = {y = y, height = height, outside = outside, inside = inside}
        end
    end
    local used = 0
    local function Rectangle(left, right, row, color)
        if right - left < 1e-8 then return end
        used = used + 1
        local rect = radial.rectangles[used]
        if not rect then
            rect = WINDOW_MANAGER:CreateControl(radial.root:GetName().."Strip"..used, radial.root, CT_BACKDROP)
            rect:SetMouseEnabled(false)
            rect:SetDrawLayer(DL_OVERLAY)
            rect:SetEdgeColor(0, 0, 0, 0)
            rect:SetEdgeTexture(nil, 1, 1, 0, 0)
            rect:SetDrawLevel(1)
            radial.rectangles[used] = rect
        end
        local x, width = (left + right) / 2, right - left
        if rect.cmX ~= x or rect.cmY ~= row.y then
            rect:ClearAnchors()
            rect:SetAnchor(CENTER, radial.root, CENTER, x, row.y)
            rect.cmX, rect.cmY = x, row.y
        end
        if rect.cmWidth ~= width or rect.cmHeight ~= row.height then
            rect:SetDimensions(width, row.height)
            rect.cmWidth, rect.cmHeight = width, row.height
        end
        rect:SetCenterColor(unpack(color))
        rect:SetHidden(false)
    end
    local rays = {}
    for _, fraction in ipairs({ping, progress}) do
        if fraction > 0 and fraction < 1 then
            rays[#rays + 1] = {math.sin(fraction * TAU), -math.cos(fraction * TAU)}
        end
    end
    local function Interval(left, right, row)
        local cuts = {left, right}
        -- The seam at twelve o'clock separates the last background interval
        -- from ping/progress, even when neither moving ray crosses this row.
        if row.y < 0 and left < 0 and right > 0 then cuts[#cuts + 1] = 0 end
        for _, ray in ipairs(rays) do
            if math.abs(ray[2]) > 1e-10 and row.y / ray[2] >= 0 then
                local x = row.y * ray[1] / ray[2]
                if x > left and x < right then cuts[#cuts + 1] = x end
            end
        end
        table.sort(cuts)
        for i = 1, #cuts - 1 do
            local angle = (math.atan2((cuts[i] + cuts[i + 1]) / 2, -row.y) / TAU) % 1
            local color = angle < ping and colors[1] or angle < progress and colors[2] or colors[3]
            Rectangle(cuts[i], cuts[i + 1], row, color)
        end
    end
    for _, row in ipairs(radial.rows) do
        if row.inside > 0 then
            Interval(-row.outside, -row.inside, row)
            Interval(row.inside, row.outside, row)
        else
            Interval(-row.outside, row.outside, row)
        end
    end
    for i = used + 1, #radial.rectangles do radial.rectangles[i]:SetHidden(true) end
end

function CM:NormalizeRadialSettings()
    local sv = self.SV.Progressbar
    for _, key in ipairs({"radialCooldown", "radialCenterX", "radialCenterY", "radialOuterRadius", "radialInnerRadius"}) do
        if sv[key] == nil then sv[key] = self.DEFAULT_SAVED_VARS.Progressbar[key] end
    end
    sv.radialOuterRadius = Clamp(sv.radialOuterRadius, 2, 500)
    sv.radialInnerRadius = Clamp(sv.radialInnerRadius, 0, sv.radialOuterRadius - 1)
end

function CM:UpdateRadialBar()
    local pb, sv = self.Progressbar, self.SV.Progressbar
    local radial, bar = pb.radial, pb.bar
    if not radial then return end
    radial.root:SetHidden(not sv.radialCooldown or radial.hidden)
    if not sv.radialCooldown then return end
    bar.background:SetHidden(true)
    bar.backgroundTexture:SetHidden(true)
    bar.borderL:SetHidden(true)
    bar.borderR:SetHidden(true)
    if radial.hidden then return end
    local outer, inner = sv.radialOuterRadius, sv.radialInnerRadius
    radial.root:SetDimensions(2 * outer, 2 * outer)
    local progress = Clamp(bar.segments[2] and bar.segments[2].progress or 0, 0, 1)
    local ping = Clamp(bar.segments[1] and bar.segments[1].progress or 0, 0, progress)
    local pingColor = bar.segments[1] and bar.segments[1].color or sv.backgroundColor
    local progressColor = bar.segments[2] and bar.segments[2].color or sv.backgroundColor
    DrawRing(radial, inner, outer, progress, ping, {
        CompositeColor(pingColor, sv.backgroundColor),
        CompositeColor(progressColor, sv.backgroundColor),
        sv.backgroundColor,
    })
end

function CM:AttachRadialBar()
    self:NormalizeRadialSettings()
    local pb = self.Progressbar
    if pb.radial then return end
    local root = WINDOW_MANAGER:CreateControl(self.name.."RadialCooldown", pb.frame, CT_CONTROL)
    root:SetAnchor(CENTER, pb.frame, CENTER, 0, 0)
    root:SetMouseEnabled(false)
    root:SetHidden(true)
    pb.radial = {root = root, rectangles = {}, hidden = true}
    -- Override this bar instance only; the shared DariansUtilities library is untouched.
    local bar, owner = pb.bar, self
    local linearUpdate, linearSetHidden = bar.Update, bar.SetHidden
    bar.Update = function(instance)
        if owner.SV.Progressbar.radialCooldown then owner:UpdateRadialBar()
        else
            pb.radial.root:SetHidden(true)
            linearUpdate(instance)
        end
    end
    bar.SetHidden = function(instance, hidden)
        pb.radial.hidden = hidden
        linearSetHidden(instance, hidden or owner.SV.Progressbar.radialCooldown)
        owner:UpdateRadialBar()
    end
end

function CM:RadialLayout()
    local pb, sv = self.Progressbar, self.SV.Progressbar
    self:NormalizeRadialSettings()
    if sv.radialCooldown then
        local diameter = 2 * sv.radialOuterRadius
        pb.frame:SetClampedToScreen(false)
        pb.frame:SetDimensionConstraints(4, 4, 1000, 1000)
        pb.frame:SetDimensions(diameter, diameter)
        pb.timeLabel:ClearAnchors()
        pb.timeLabel:SetAnchor(CENTER, pb.frame, CENTER, 0, 0)
        pb.spellLabel:ClearAnchors()
        pb.spellLabel:SetAnchor(TOP, pb.frame, BOTTOM, 0, 4)
        pb.spellIcon:ClearAnchors()
        pb.spellIcon:SetAnchor(BOTTOM, pb.frame, TOP, 0, -4)
        pb.spellIconAnchoredDynamically = false
    else
        pb.frame:SetClampedToScreen(true)
        pb.frame:SetDimensionConstraints(50, 10, GuiRoot:GetWidth(), 100)
    end
    self:UpdateRadialBar()
end

function CM:RefreshRadialSettings()
    self:NormalizeRadialSettings()
    local pb = self.Progressbar
    pb.UI.Size()
    pb.UI.Position(pb.showSample and "Sample" or "UI")
    pb.bar:SetHidden(pb.radial.hidden)
    self:HideFancy(pb.radial.hidden or not self.SV.Progressbar.makeItFancy)
    pb.bar:Update()
end

function CM:RadialOptions()
    local owner = self
    local function Disabled() return not owner.SV.Progressbar.radialCooldown end
    local function Slider(name, key, max, min)
        return {
            type = "slider", name = name, min = min or 0, max = max,
            step = 1, decimals = 0, width = "half", disabled = Disabled,
            getFunc = function() return owner.SV.Progressbar[key] end,
            setFunc = function(value)
                owner.SV.Progressbar[key] = value
                owner:RefreshRadialSettings()
            end,
        }
    end
    local function CenterButton(name, key, dimension)
        return {
            type = "button", name = name, width = "half", disabled = Disabled,
            func = function()
                owner.SV.Progressbar[key] = math.floor(dimension(GuiRoot) / 2)
                owner:RefreshRadialSettings()
            end,
        }
    end
    return {
        type = "submenu", name = "Радиальный кулдаун",
        disabled = function() return owner.SV.Progressbar.hide end,
        controls = {
            {
                type = "checkbox", name = "Радиальный кулдаун",
                tooltip = "Кольцо вместо полосы. X/Y — координаты центра от левого верхнего угла экрана, радиусы — в единицах интерфейса.",
                getFunc = function() return owner.SV.Progressbar.radialCooldown end,
                setFunc = function(value)
                    owner.SV.Progressbar.radialCooldown = value
                    owner:RefreshRadialSettings()
                end,
            },
            Slider("Центр X", "radialCenterX", math.floor(GuiRoot:GetWidth())),
            CenterButton("Center Horiz", "radialCenterX", GuiRoot.GetWidth),
            Slider("Центр Y", "radialCenterY", math.floor(GuiRoot:GetHeight())),
            CenterButton("Center Vert", "radialCenterY", GuiRoot.GetHeight),
            Slider("Внешний радиус", "radialOuterRadius", 500, 2),
            Slider("Внутренний радиус", "radialInnerRadius", 499),
        },
    }
end

