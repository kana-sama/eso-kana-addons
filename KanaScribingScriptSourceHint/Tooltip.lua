local A = KanaScribingScriptSourceHint
local T = {}
A.Tooltip = T
local View = {}
View.__index = View
local FONT, BODY_FONT = 'ZoFontGameBold', 'ZoFontGame'
local YELLOW, WHITE = {201/255, 195/255, 164/255, 1}, {1, 1, 1, 1}
local unpack = unpack or table.unpack

function T.New(api)
    return setmetatable({api = api, labels = {}, generation = 0}, View)
end

function View:Ensure()
    if self.body then return end
    local a, wm = self.api, self.api.WINDOW_MANAGER
    local name = 'KanaScribingScriptSourceHintTooltip'
    self.root = wm:CreateControlFromVirtual(name .. 'TopLevel', a.GuiRoot, 'TooltipTopLevel')
    self.tooltip = wm:CreateControlFromVirtual(name, self.root, 'ZO_BaseTooltip')
    self.tooltip:SetMouseEnabled(true)
    self.body = wm:CreateControl(name .. 'Body', self.tooltip, a.CT_CONTROL)
    self.body:SetMouseEnabled(true)
    self.measure = wm:CreateControl(nil, self.body, a.CT_LABEL)
    self.measure:SetHidden(true)
    self.scroll = wm:CreateControlFromVirtual(name .. 'Scroll', self.body, 'ZO_ScrollContainer')
    self.scroll:SetAnchor(a.TOPLEFT, self.body, a.TOPLEFT, 0, 0)
    self.scroll:SetAnchor(a.BOTTOMRIGHT, self.body, a.BOTTOMRIGHT, 0, 0)
    self.viewport = self.scroll:GetNamedChild('Scroll')
    self.child = self.viewport:GetNamedChild('Child')
    self.child:SetResizeToFitDescendents(false)
    self.body:SetHandler('OnMouseWheel', function(_, delta) a.ZO_Scroll_OnMouseWheel(self.scroll, delta) end)
    self.tooltip:SetHandler('OnMouseExit', function() self:Leave(self.owner) end)
end

function View:Measure(text, width, font)
    self.measure:SetFont(font or FONT)
    self.measure:SetDimensions(width or 0, 10000)
    self.measure:SetText(text)
    local w, h = self.measure:GetTextDimensions()
    return math.ceil(w), math.ceil(h)
end

function View:Label(text, x, y, width, font, align, color)
    local a = self.api
    self.used = self.used + 1
    local label = self.labels[self.used]
    if not label then
        label = a.WINDOW_MANAGER:CreateControl(nil, self.child, a.CT_LABEL)
        label:SetMouseEnabled(false)
        self.labels[self.used] = label
    end
    local _, height = self:Measure(text, width, font)
    label:SetHidden(false)
    label:ClearAnchors()
    label:SetFont(font or FONT)
    label:SetDimensions(width, height)
    label:SetText(text)
    label:SetColor(unpack(color or WHITE))
    label:SetHorizontalAlignment(align or a.TEXT_ALIGN_LEFT)
    label:SetAnchor(a.TOPLEFT, self.child, a.TOPLEFT, x, y)
    return label, height
end

function View:Hide()
    self.generation = self.generation + 1
    self.owner = nil
    if self.tooltip then self.api.ClearTooltipImmediately(self.tooltip); self.body:SetHidden(true) end
end

function View:Leave(owner)
    if not owner or owner ~= self.owner then return end
    local generation = self.generation
    local function check()
        if generation ~= self.generation or self.owner ~= owner then return end
        if self.api.MouseIsOver(owner) or self.api.MouseIsOver(self.tooltip) then
            self.api.zo_callLater(check, 120)
        else self:Hide() end
    end
    self.api.zo_callLater(check, 120)
end

function View:Show(owner, data)
    self:Hide()
    self:Ensure()
    local a = self.api
    self.owner = owner
    local anchor = owner.kanaTooltipAnchor or owner
    a.InitializeTooltip(self.tooltip, anchor, a.TOPRIGHT, -8, 0, a.TOPLEFT)
    self.body:SetHidden(false)
    for _, label in ipairs(self.labels) do label:SetHidden(true) end
    local padW, padH = self.tooltip:GetResizeToFitPadding()
    local maxW = math.max(1, math.min(420, a.GuiRoot:GetWidth() - 64 - padW, anchor:GetLeft() - 8 - padW))
    local maxH = math.max(1, a.GuiRoot:GetHeight() - 100 - padH)
    local y
    local function layout(overflow)
        local bar = overflow and a.ZO_SCROLL_BAR_WIDTH or 0
        local inset = overflow and 12 or 0
        self.viewport:ClearAnchors()
        self.viewport:SetAnchor(a.TOPLEFT, self.scroll, a.TOPLEFT, 0, 0)
        self.viewport:SetAnchor(a.BOTTOMRIGHT, self.scroll, a.BOTTOMRIGHT, -bar, 0)
        self.child:ClearAnchors()
        self.child:SetAnchor(a.TOPLEFT, self.viewport, a.TOPLEFT, 0, 0)
        self.child:SetAnchor(a.TOPRIGHT, self.viewport, a.TOPRIGHT, -inset, 0)
        local inner = math.max(1, maxW - bar - inset)
        self.used, y = 0, 0
        local function paragraph(text, font, color, gap)
            if text and text ~= '' then
                local _, height = self:Label(text, 0, y, inner, font, a.TEXT_ALIGN_LEFT, color)
                y = y + height + (gap or 8)
            end
        end
        paragraph(data.title, 'ZoFontHeader2', WHITE)
        paragraph(data.description, BODY_FONT, WHITE)
        if data.location then
            paragraph('Где взять', FONT, YELLOW, 2)
            paragraph(data.location, BODY_FONT, WHITE)
        end
        paragraph(data.context, FONT, YELLOW, 2)
        paragraph(data.status, BODY_FONT, WHITE)
        paragraph(data.account, BODY_FONT, YELLOW)
        paragraph(data.note, BODY_FONT, YELLOW, 0)
        return maxW
    end
    local width = layout(false)
    local overflow = y > maxH
    if overflow then width = layout(true) end
    self.scroll:GetNamedChild('ScrollBar'):SetHidden(not overflow)
    self.child:SetHeight(y)
    self.body:SetDimensions(width, math.min(y, maxH))
    local w, h = width + padW, math.min(y, maxH) + padH
    self.tooltip:SetDimensionConstraints(w, h, w, h)
    self.tooltip:SetDimensions(w, h)
    self.tooltip:AddControl(self.body)
    self.body:ClearAnchors()
    self.body:SetAnchor(a.CENTER)
    a.ZO_Scroll_ResetToTop(self.scroll)
end
