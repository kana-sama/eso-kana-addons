dofile('KanaScribingScriptSourceHint/Sources.lua')
dofile('KanaScribingScriptSourceHint/Tracking.lua')
local f = loadfile('KanaScribingScriptSourceHint/Tooltip.lua')
if f then f() end
local A = KanaScribingScriptSourceHint
local passed = 0
local function test(name, fn)
    local ok, err = pcall(fn)
    if not ok then error(name .. ': ' .. tostring(err), 0) end
    passed = passed + 1
end
local Control = {}; Control.__index = Control
function Control.new(parent) return setmetatable({parent = parent, children = {}, handlers = {}, width = 0, height = 0}, Control) end
function Control:GetNamedChild(name)
    if not self.children[name] then self.children[name] = Control.new(self) end
    return self.children[name]
end
function Control:SetHandler(name, callback) self.handlers[name] = callback end
function Control:SetHidden(value) self.hidden = value end
function Control:IsHidden() return self.hidden end
function Control:SetMouseEnabled(value) self.mouse = value end
function Control:SetResizeToFitDescendents(value) self.resize = value end
function Control:ClearAnchors() self.anchors = {} end
function Control:SetAnchor(...) self.anchors = self.anchors or {}; table.insert(self.anchors, {...}) end
function Control:SetFont(font) self.font = font end
function Control:SetText(text) self.text = text end
function Control:SetDimensions(w, h) self.width = w; self.height = h end
function Control:SetHeight(h) self.height = h end
function Control:GetWidth() return self.width end
function Control:GetHeight() return self.height end
function Control:GetLeft() return self.left or 800 end
function Control:SetColor(...) self.color = {...} end
function Control:SetHorizontalAlignment(value) self.align = value end
function Control:SetDimensionConstraints(...) self.constraints = {...} end
function Control:GetResizeToFitPadding() return 32, 24 end
function Control:AddControl(control) self.content = control end
function Control:GetTextDimensions()
    local plain = (self.text or ''):gsub('|c%x%x%x%x%x%x', ''):gsub('|r', '')
    local width = #plain * 6
    local lines = self.width > 0 and math.max(1, math.ceil(width / self.width)) or 1
    return self.width > 0 and math.min(width, self.width) or width, 18 * lines
end
local function fixture()
    local api = {CT_CONTROL = 1, CT_LABEL = 2, TOPLEFT = 1, BOTTOMRIGHT = 2,
        TOPRIGHT = 3, CENTER = 4, TEXT_ALIGN_LEFT = 1, TEXT_ALIGN_RIGHT = 2, ZO_SCROLL_BAR_WIDTH = 16}
    api.GuiRoot = Control.new(); api.GuiRoot:SetDimensions(1200, 900)
    api.InformationTooltip = setmetatable({}, {__newindex = function() error('shared tooltip mutated') end})
    api.WINDOW_MANAGER = {CreateControl = function(_, _, parent) return Control.new(parent) end,
        CreateControlFromVirtual = function(_, _, parent, template)
            local c = Control.new(parent); c.template = template; return c
        end}
    function api.InitializeTooltip(tooltip, owner, point, offsetX, _, relativePoint)
        tooltip.owner = owner; tooltip.hidden = false
        function tooltip:GetRight()
            local anchor = (owner.left or 0) + (relativePoint == api.TOPRIGHT and owner.width or 0)
            local left = anchor + offsetX - (point == api.TOPRIGHT and self.width or 0)
            -- Model the native screen clamp that exposed the overlap.
            return math.max(0, math.min(left, api.GuiRoot.width - self.width)) + self.width
        end
    end
    function api.ClearTooltipImmediately(tooltip) tooltip.hidden = true end
    function api.ZO_Scroll_ResetToTop(scroll) scroll.reset = true end
    function api.ZO_Scroll_OnMouseWheel(scroll, delta) scroll.scrolled = delta end
    function api.MouseIsOver(control) return control.over end
    function api.zo_callLater(callback) api.later = callback end
    assert(A.Tooltip, 'tooltip layout is not implemented')
    return A.Tooltip.New(api), api
end
local function view(description, location)
    return {title = 'Гильдия магов', description = description or 'Найдите реликвию Шеогората.',
        location = location or 'Альвур Барен в Гильдии магов Элден-Рута, Вэйреста или Морнхолда.',
        context = 'Alice · EU', status = 'Получение страницы сегодня не зафиксировано.',
        note = 'ПКМ — исправить отметку.'}
end
local function label(t, text)
    for _, value in ipairs(t.labels) do if value.text == text and not value.hidden then return value end end
end
test('single-source tooltip has separate title description and pickup group', function()
    local t, api = fixture()
    local data = view()
    t:Show(Control.new(), data)
    local title, description = label(t, data.title), label(t, data.description)
    local where, location = label(t, 'Где взять'), label(t, data.location)
    assert(title and description and where and location)
    assert(title.font == 'ZoFontHeader2' and where.font == 'ZoFontGameBold')
    assert(description.anchors[1][5] > title.anchors[1][5] + title.height)
    assert(location.anchors[1][5] > where.anchors[1][5])
    assert(t.tooltip.template == 'ZO_BaseTooltip' and t.root.template == 'TooltipTopLevel')
    assert(t.tooltip.width <= 460, 'single activity tooltip is unnecessarily wide')
end)
test('tooltip stays left of the icon near the right screen edge', function()
    local t, api = fixture()
    local owner = Control.new(); owner.left = 1000; owner:SetDimensions(26, 26)
    t:Show(owner, view())
    assert(t.tooltip:GetRight() <= owner.left - 8, 'tooltip overlaps the source icon')
end)
test('hovering the last source leaves all three source icons uncovered', function()
    local t = fixture()
    local first, last = Control.new(), Control.new()
    first.left = 920; first:SetDimensions(26, 26)
    last.left = 976; last:SetDimensions(26, 26); last.kanaTooltipAnchor = first
    t:Show(last, view())
    assert(t.owner == last and t.tooltip:GetRight() <= first.left - 8)
end)
test('narrow screen limits tooltip to actual space left of the source group', function()
    for _, screenWidth in ipairs({1000, 900}) do
        local t, api = fixture(); api.GuiRoot:SetDimensions(screenWidth, 700)
        local first, last = Control.new(), Control.new()
        first.left = screenWidth - 572; first:SetDimensions(26, 26)
        last.left = first.left + 56; last:SetDimensions(26, 26); last.kanaTooltipAnchor = first
        t:Show(last, view())
        assert(t.tooltip:GetRight() <= first.left - 8, 'screen clamp covered the source group')
        assert(t.tooltip:GetRight() - t.tooltip.width >= 0)
    end
end)
test('short screen keeps scrolling and the final paragraph accessible', function()
    local t, api = fixture(); api.GuiRoot:SetDimensions(500, 260)
    local data = view(string.rep('Длинное описание занятия. ', 30), string.rep('Длинное название города. ', 12))
    t:Show(Control.new(), data)
    assert(t.scroll.template == 'ZO_ScrollContainer')
    assert(t.child.height > t.body.height and not t.scroll:GetNamedChild('ScrollBar').hidden)
    local last = label(t, data.note); assert(last and last.anchors[1][5] + last.height <= t.child.height)
    t.body.handlers.OnMouseWheel(t.body, -1); assert(t.scroll.scrolled == -1)
    assert(t.tooltip.width <= 500 and t.tooltip.height <= 260)
end)
test('small tooltip after large clears old paragraphs and scrollbar space', function()
    local t, api = fixture(); api.GuiRoot:SetDimensions(700, 300)
    local large = view(string.rep('Long description ', 40)); large.account = 'Another character received a script.'
    t:Show(Control.new(), large)
    local old = t.labels[t.used]
    api.GuiRoot:SetDimensions(1200, 1200)
    local small = view('Small', 'Here'); small.context = nil; small.status = nil; small.note = nil
    t:Show(Control.new(), small)
    assert(old.hidden and t.scroll:GetNamedChild('ScrollBar').hidden)
    assert(t.viewport.anchors[2][4] == 0, 'hidden bar must not reserve right padding')
    assert(t.child.height == t.body.height)
end)
test('pointer can move from icon into tooltip', function()
    local t, api = fixture(); local owner = Control.new()
    t:Show(owner, view())
    t:Leave(owner); t.tooltip.over = true; api.later(); assert(not t.tooltip.hidden)
    t.tooltip.over = false; api.later(); assert(t.tooltip.hidden)
end)
print(string.format('%d tests passed', passed))
