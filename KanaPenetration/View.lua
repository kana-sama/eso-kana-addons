local K = KanaPenetration
local View = {}
View.__index = View
K.View = View

local ART = 'EsoUI/Art/UnitAttributeVisualizer/targetBar_dynamic_'
-- Target HP's 14 x 17 leading edge defines the diagonal, including its frame.
local SLOPE = 14 / 17
local GAP = 3
local BAR_TINT = 0.55
local COORDS = {
    Left={0.2890625,0.453125,0.328125,0.6875},
    Center={0.453125,0.5546875,0.328125,0.6875},
    Right={0.5546875,0.71875,0.328125,0.6875},
}

local function Control(name, parent, kind, layer, level)
    local c = WINDOW_MANAGER:CreateControl(name, parent, kind)
    c:SetMouseEnabled(false)
    c:SetDrawLayer(layer)
    c:SetDrawLevel(level)
    return c
end

function View.New(settings, russian)
    local self = setmetatable({settings=settings, russian=russian, rows={}}, View)
    self.root = WINDOW_MANAGER:CreateTopLevelWindow('KanaPenetrationWindow')
    self.root:SetDrawTier(DT_LOW)
    self.root:SetClampedToScreen(false)
    self.root:SetMouseEnabled(false)
    self.root:SetMovable(false)
    self.root:SetHidden(true)
    self.onUpdate = function() self:SyncTargetFade() end
    self.content = Control('KanaPenetrationContent', self.root, CT_CONTROL, DL_CONTROLS, 0)
    self.content:SetAnchorFill(self.root)
    for index = 1, 2 do
        local prefix = 'KanaPenetrationRow' .. index
        local row = {root=Control(prefix, self.content, CT_CONTROL, DL_CONTROLS, 0),
            background={}, frame={}, bars={}, gloss={}}
        for _, side in ipairs({'Left','Center','Right'}) do
            row.background[side] = Control(prefix .. 'Bg' .. side, row.root, CT_TEXTURE, DL_BACKGROUND, 0)
            row.frame[side] = Control(prefix .. 'Frame' .. side, row.root, CT_TEXTURE, DL_CONTROLS, 30)
        end
        for half = 1, 2 do
            local bar = WINDOW_MANAGER:CreateControlFromVirtual(prefix .. 'Bar' .. half,
                row.root, 'ZO_TargetAttributeStatusBar_Keyboard_Template')
            local gloss = WINDOW_MANAGER:CreateControlFromVirtual(prefix .. 'Gloss' .. half,
                bar, 'ZO_TargetAttributeStatusBarGloss_Keyboard_Template')
            bar:SetMouseEnabled(false)
            gloss:SetMouseEnabled(false)
            bar:SetDrawLevel(10)
            gloss:SetDrawLevel(20)
            gloss:SetAnchorFill(bar)
            if half == 1 then
                bar:SetBarAlignment(BAR_ALIGNMENT_REVERSE)
                gloss:SetBarAlignment(BAR_ALIGNMENT_REVERSE)
            end
            bar:SetMinMax(0, 1)
            gloss:SetMinMax(0, 1)
            row.bars[half], row.gloss[half] = bar, gloss
        end
        row.text = Control(prefix .. 'Text', row.root, CT_LABEL, DL_TEXT, 40)
        row.text:SetColor(1, 1, 1, 1)
        row.text:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        row.text:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        self.rows[index] = row
    end
    self:Render(nil)
    return self
end

function View:TrackFade(active)
    if active == self.trackingFade then return end
    self.trackingFade = active
    self.root:SetHandler('OnUpdate', active and self.onUpdate or nil)
end

function View:Hide()
    self.visible, self.fading = false, false
    self.content:SetHidden(true)
    self:TrackFade(false)
    self:RestoreName()
end

function View:SyncTargetFade()
    local frame = ZO_TargetUnitFramereticleover
    local hidden = not frame or frame:IsControlHidden()
    if self.fading and hidden then self:Hide(); return end
    -- Only native visibility/alpha are read per frame: no snapshots, string
    -- formatting, layout, timers, allocations or new controls during a fade.
    local alpha = self.trackingFade and (hidden and 0 or frame:GetAlpha()) or 1
    if alpha ~= self.alpha then
        self.alpha = alpha
        self.content:SetAlpha(alpha)
    end
end

function View:TargetAnchor()
    local frame = ZO_TargetUnitFramereticleover
    return frame and (frame:GetNamedChild('BgContainer') or frame)
end

function View:RestoreName()
    local name = self.shiftedName
    if not name then return end
    local valid, _, relativeTo = name:GetAnchor(0)
    -- A different addon may have replaced our anchor: do not undo its change.
    if valid and relativeTo == self.root then
        name:ClearAnchors()
        for _, anchor in ipairs(self.nameAnchors) do name:SetAnchor(unpack(anchor)) end
    end
    self.shiftedName, self.nameAnchors = nil, nil
end

function View:PlaceName()
    local frame = ZO_TargetUnitFramereticleover
    local name = frame and frame:GetNamedChild('TextArea')
    if not self.visible or not name then
        self:RestoreName()
        return
    end
    if self.shiftedName ~= name then self:RestoreName() end
    local valid, _, relativeTo = name:GetAnchor(0)
    if valid and relativeTo == self.root then return end
    local anchors = {}
    for index = 0, name:GetNumAnchors() - 1 do
        local a = {name:GetAnchor(index)}
        table.remove(a, 1)
        anchors[#anchors + 1] = a
    end
    if not anchors[1] then return end
    self.shiftedName, self.nameAnchors = name, anchors
    name:ClearAnchors()
    name:SetAnchor(TOP, self.root, BOTTOM, anchors[1][4] or 0, anchors[1][5] or 7)
end

local function Font(frame)
    if frame then
        local native = frame:GetNamedChild('ResourceNumbers')
        local extender = frame:GetNamedChild('LUIEExtenderLabel')
        local function Displayed(label)
            return label and not label:IsControlHidden() and label:GetAlpha() > 0 and label:GetText() ~= ''
        end
        -- The extender can exist without drawing the HP text currently on screen.
        local label = Displayed(native) and native or Displayed(extender) and extender or native or extender
        if label then
            -- GetFont is a font descriptor/token, not the resolved typeface.
            -- Appending size/style to it can produce an invalid descriptor and
            -- make ESO fall back to a different (regular-weight) font.
            local descriptor = string.format('%s|%s', label:GetFontFaceName(), label:GetFontSize())
            local style = label:GetFontStyle()
            if style and style ~= '' then descriptor = descriptor .. '|' .. style end
            return descriptor
        end
    end
    return 'ZoFontWinH5'
end

local function Skin(texture, source, file, side)
    texture:SetTexture(source and source:GetTextureFileName() or ART .. file .. '.dds')
    if source then texture:SetTextureCoords(source:GetTextureCoords())
    else texture:SetTextureCoords(unpack(COORDS[side])) end
end

function View:Layout()
    local s = self.settings
    local frame, hp = ZO_TargetUnitFramereticleover, self:TargetAnchor()
    local nativeScale = frame and frame:GetScale() or 1
    local edge = frame and frame:GetNamedChild('FrameLeft')
    local rowHeight = edge and edge:GetHeight() / nativeScale or 23
    local capWidth = edge and edge:GetWidth() / nativeScale or 21
    local slope = SLOPE * (capWidth / 21) / (rowHeight / 23)
    local count = self.split and 2 or 1
    local height = rowHeight * count + GAP * (count - 1)
    local scale = nativeScale
    local width = (hp:GetWidth() - 2 * slope * (hp:GetHeight() + GAP * scale)) / scale
    local font = Font(frame)
    local skin = edge and edge:GetTextureFileName()
    local previous = self.layout
    if previous and previous.width == width and previous.height == height and previous.scale == scale
        and previous.guiScale == GuiRoot:GetScale() and previous.capWidth == capWidth
        and previous.rowHeight == rowHeight and previous.slope == slope
        and previous.hp == hp and previous.skin == skin
        and previous.font == font and previous.numbers == s.showNumbers then
        self:PlaceName()
        return
    end
    self.layout = {width=width, height=height, scale=scale, capWidth=capWidth, rowHeight=rowHeight, slope=slope,
        guiScale=GuiRoot:GetScale(), hp=hp, skin=skin, font=font, numbers=s.showNumbers}
    self.root:SetScale(scale / GuiRoot:GetScale())
    self.root:SetDimensions(width, height)
    self.root:ClearAnchors()
    self.root:SetAnchor(TOP, hp, BOTTOM, 0, GAP)
    for index, row in ipairs(self.rows) do
        local inset = (index - 1) * (rowHeight + GAP) * slope
        local rowWidth = math.max(2 * capWidth + 1, width - 2 * inset)
        row.width = rowWidth
        row.root:SetDimensions(rowWidth, rowHeight)
        row.root:ClearAnchors()
        row.root:SetAnchor(TOP, self.content, TOP, 0, (index - 1) * (rowHeight + GAP))
        for _, side in ipairs({'Left','Center','Right'}) do
            Skin(row.frame[side], frame and frame:GetNamedChild('Frame' .. side), 'frame', side)
            Skin(row.background[side], hp and hp:GetNamedChild('Bg' .. side), 'bg', side)
            for _, part in ipairs({row.frame[side], row.background[side]}) do
                part:ClearAnchors()
                if side == 'Center' then
                    part:SetDimensions(rowWidth - 2 * capWidth, rowHeight)
                    part:SetAnchor(TOP, row.root, TOP, 0, 0)
                else
                    part:SetDimensions(capWidth, rowHeight)
                    local point = side == 'Left' and TOPLEFT or TOPRIGHT
                    part:SetAnchor(point, row.root, point, 0, 0)
                end
            end
        end
        local padding, fillHeight = 7 * capWidth / 21, 17 * rowHeight / 23
        for half = 1, 2 do
            local point = half == 1 and TOPLEFT or TOPRIGHT
            row.bars[half]:ClearAnchors()
            row.bars[half]:SetDimensions((rowWidth - 2 * padding) / 2, fillHeight)
            row.bars[half]:SetAnchor(point, row.root, point, half == 1 and padding or -padding,
                (rowHeight - fillHeight) / 2)
        end
        row.text:SetFont(font)
        row.text:SetDimensions(rowWidth - 2 * capWidth, rowHeight)
        row.text:ClearAnchors()
        row.text:SetAnchor(CENTER, row.root, CENTER, 0, 0)
        row.text:SetHidden(not s.showNumbers)
    end
    self:PlaceName()
end

local function Number(value)
    return value and ZO_AbbreviateAndLocalizeNumber(math.floor(value + 0.5),
        NUMBER_ABBREVIATION_PRECISION_TENTHS, false) or '?'
end

local function Percent(value)
    -- Use the same localized precision and rounding as the native HP numbers.
    return tostring(ZO_FormatResourceBarCurrentAndMax(value, 100, RESOURCE_NUMBERS_SETTING_PERCENT_ONLY))
end

function View:Row(row, result)
    local previous = row.result
    if previous and previous.penetration == result.penetration and previous.upperPenetration == result.upperPenetration
        and previous.percent == result.percent and previous.upperPercent == result.upperPercent
        and previous.stripped == result.stripped and previous.fill == result.fill then return end
    row.result = result
    local percent, color
    if result.stripped then
        percent, color = '—', {0.35, 0.95, 0.55}
    elseif result.percent then
        if result.upperPercent and result.upperPercent > result.percent then
            percent = '≈' .. Percent(result.percent) .. '–' .. Percent(result.upperPercent) .. '%'
        else
            percent = '≈' .. Percent(result.percent) .. '%'
        end
        color = result.percent > 100 and {1, 0.6, 0.25}
            or result.percent == 100 and {0.35, 0.95, 0.55} or {0.95, 0.75, 0.3}
    else
        percent, color = '?', {0.65, 0.65, 0.65}
    end
    local numerator = Number(result.penetration)
    if result.upperPenetration and result.penetration and result.upperPenetration > result.penetration then
        numerator = numerator .. '–' .. Number(result.upperPenetration)
    end
    row.text:SetText(numerator .. ' ' .. percent)
    local red, green, blue = color[1] * BAR_TINT, color[2] * BAR_TINT, color[3] * BAR_TINT
    for half = 1, 2 do
        row.bars[half]:SetColor(red, green, blue, 1)
        row.bars[half]:SetValue(result.fill)
        row.gloss[half]:SetColor(red, green, blue, 1)
        row.gloss[half]:SetValue(result.fill)
    end
end

function View:Render(snapshot, fading)
    local frame = ZO_TargetUnitFramereticleover
    if not snapshot and fading and self.visible
        and frame and not frame:IsControlHidden() then
        self.fading = true
        self:SyncTargetFade()
        return
    end
    if not snapshot or not self:TargetAnchor() then self:Hide(); return end
    self.fading = false
    self.visible = snapshot ~= nil
    self.content:SetHidden(not self.visible)
    self.split = false
    if snapshot then
        local p, s = snapshot.physical, snapshot.spell
        self.split = p.penetration ~= s.penetration or p.remaining ~= s.remaining
            or p.upperPenetration ~= s.upperPenetration
        self:Row(self.rows[1], p)
        self:Row(self.rows[2], s)
    end
    self.rows[2].root:SetHidden(not self.split)
    self:Layout()
    self:TrackFade(frame ~= nil)
    self:SyncTargetFade()
end
