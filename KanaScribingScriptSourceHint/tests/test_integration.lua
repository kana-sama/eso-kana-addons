local root = 'KanaScribingScriptSourceHint/'
dofile(root .. 'Sources.lua'); dofile(root .. 'Tracking.lua'); dofile(root .. 'Main.lua')
local A, passed = KanaScribingScriptSourceHint, 0
local function test(name, fn)
    local ok, err = pcall(fn)
    if not ok then error(name .. ': ' .. tostring(err), 0) end
    passed = passed + 1
end
local unpack = table.unpack or unpack
local LEFT, RIGHT = 4, 5
local Control = {}; Control.__index = Control
local function control(parent, width, height)
    local value = setmetatable({parent = parent, width = width or 0, height = height or 30,
        handlers = {}, alpha = 1, childList = {}, kind = 1}, Control)
    if parent then parent.childList[#parent.childList + 1] = value end
    return value
end
function Control:GetName() return self.controlName end
function Control:GetType() return self.kind end
function Control:GetNumChildren() return #self.childList end
function Control:GetChild(index)
    local child = self.childList[index]
    -- ESO counts unnamed children but may not expose them through GetChild.
    return child and child.controlName and child or nil
end
function Control:GetControlAlpha() return self.alpha end
function Control:SetColor(_, _, _, alpha) self.colorCalls = (self.colorCalls or 0) + 1; self.alpha = alpha end
function Control:SetDimensions(w, h) self.width, self.height = w, h end
function Control:SetWidth(w) self.width = w end
function Control:GetWidth() return self.width end
function Control:GetHeight() return self.height end
function Control:ClearAnchors() self.anchor = nil end
function Control:SetAnchor(...) self.anchor = {...} end
function Control:GetAnchor() return self.anchor ~= nil, unpack(self.anchor or {}) end
function Control:GetLeft()
    if not self.anchor then return self.left or 0 end
    local point, relative, relativePoint, x = unpack(self.anchor)
    relative = relative or self.parent
    local edge = relativePoint == RIGHT and relative:GetRight() or relative:GetLeft()
    return edge + (x or 0) - (point == RIGHT and self.width or 0)
end
function Control:GetRight() return self:GetLeft() + self.width end
function Control:SetTexture(value) self.texture = value end
function Control:SetHidden(value) self.hidden = value end
function Control:IsHidden() return self.hidden end
function Control:SetMouseEnabled(value) self.mouse = value end
function Control:SetHandler(name, callback) self.handlers[name] = callback end
function Control:SetAlpha(value) self.alpha = value end
function Control:SetDrawLayer(value) self.layer = value end
function Control:GetNamedChild(name) return assert(self.children[name], name) end
local rowId = 0
local function row(width)
    local r = control(nil, 900, 30); r.children = {}
    rowId = rowId + 1; r.controlName = 'CharacterKnowledgeTestRow' .. rowId
    for _, name in ipairs({'Icon', 'Name', 'NameSuffix', 'Extended'}) do
        local child = control(r); r.children[name] = child
        child.controlName = r.controlName .. name
        child.kind = (name == 'Name' or name == 'Extended') and 3 or 2
    end
    local c = r.children
    c.Icon:SetDimensions(26, 26)
    c.Name:SetDimensions(width or 380, 30); c.Name:SetAnchor(LEFT, c.Icon, RIGHT, 4, 0)
    c.NameSuffix:SetDimensions(26, 26); c.NameSuffix:SetAnchor(RIGHT, c.Name, RIGHT, 0, 0)
    c.Extended:SetDimensions(160, 30); c.Extended:SetAnchor(LEFT, c.Name, RIGHT, 0, 0)
    return r
end
local function fixture()
    local api = {TOPLEFT = 1, TOPRIGHT = 2, LEFT = LEFT, RIGHT = RIGHT, CT_CONTROL = 1, CT_TEXTURE = 2, CT_LABEL = 3,
        DL_OVERLAY = 3, MOUSE_BUTTON_INDEX_RIGHT = 2, SI_CRAFTED_ABILITY_SCRIPT_NAME_FORMATTER = 1,
        TIMED_ACTIVITY_TYPE_DAILY = 1, now = 100, callbacks = {}, menu = {}}
    api.GetTimeStamp = function() return api.now end
    api.GetTimedActivityTypeResetTimeS = function() return 200 end
    api.GetDisplayName = function() return '@one' end
    api.GetCurrentCharacterId = function() return 'alice' end
    api.LibCodesCommonCode = {GetServerName = function() return 'EU' end}
    api.LibCharacterKnowledge = {GetCharacterNameAndAccount = function(_, id) return id == 'alice' and 'Alice' or 'Bob', '@one' end}
    api.CharacterKnowledge = {list = {server = 'EU', account = '@one', charId = 'alice'}}
    local list = api.CharacterKnowledge.list
    list.automaticallyColorRows = true
    local color = {UnpackRGB = function() return 1, 1, 1 end}
    function list:GetRowColors() return color, color end
    -- Native ZO_SortFilterList:ColorRow, ESO API 101051, lines 288-304.
    -- Keep its unguarded child access: a nil entry must fail this regression.
    function list:ColorRow(c, data, mouseIsOver)
        if self.automaticallyColorRows then
            for i = 1, c:GetNumChildren() do
                local child = c:GetChild(i)
                if not child.nonRecolorable then
                    local childType = child:GetType()
                    local textColor, iconColor = self:GetRowColors(data, mouseIsOver, child)
                    if childType == api.CT_LABEL and textColor ~= nil then
                        local r, g, b = textColor:UnpackRGB()
                        child:SetColor(r, g, b, child:GetControlAlpha())
                    elseif childType == api.CT_TEXTURE and iconColor ~= nil then
                        local r, g, b = iconColor:UnpackRGB()
                        child:SetColor(r, g, b, child:GetControlAlpha())
                    end
                end
            end
        end
    end
    api.CharacterKnowledgeList = {SetupItemRow = function(_, r, data)
        r.originalCalls = (r.originalCalls or 0) + 1; r.name = data.name
        local suffix = r:GetNamedChild('NameSuffix')
        suffix.hidden, suffix.texture = data.nameSuffix == '', data.nameSuffix
        list:ColorRow(r, data, false)
    end}
    local namedControls = {}
    api.WINDOW_MANAGER = {CreateControl = function(_, name, parent, kind)
        local child = control(parent); child.controlName, child.kind = name, kind
        if name then assert(not namedControls[name], 'duplicate control name'); namedControls[name] = child end
        return child
    end}
    api.GetCraftedAbilityScriptScribingSlot = function(id) return id < 24 and 1 or id < 44 and 2 or 3 end
    api.GetCraftedAbilityScriptDisplayName = function(id) return 'Page ' .. id end
    api.GetCraftedAbilityScriptAcquireHint = function(id) return 'Native source for ' .. id end
    api.zo_strformat = function(_, text) return text end
    api.ZO_PostHook = function(object, method, callback)
        local old = object[method]; object[method] = function(...) old(...); callback(...) end
    end
    api.ZO_PostHookHandler = function(c, name, callback) c.handlers[name] = callback end
    function api.CharacterKnowledge.list:Row_OnMouseEnter(r)
        self:ColorRow(r, {}, true)
        self.mouseOverRow = r
        self.defaultAction = function() r.keyboardActions = (r.keyboardActions or 0) + 1 end
    end
    function api.CharacterKnowledge.list:Row_OnMouseExit(r)
        self:ColorRow(r, {}, false)
        self.mouseOverRow, self.defaultAction = nil, nil
    end
    api.CharacterKnowledgeListRow_OnMouseExit = function(r) api.CharacterKnowledge.list:Row_OnMouseExit(r); r.nativeTooltip = false end
    api.CharacterKnowledgeListRow_OnMouseUp = function(r) r.clicks = (r.clicks or 0) + 1 end
    api.EVENT_MANAGER = {RegisterForUpdate = function(_, name, _, fn) api.callbacks[name] = fn end,
        UnregisterForUpdate = function(_, name) api.callbacks[name] = nil end}
    api.ClearMenu = function() api.menu = {} end
    api.AddMenuItem = function(label, fn) api.menu[#api.menu + 1] = {label, fn} end
    api.ShowMenu = function() end
    api.ZO_SavedVars = {NewAccountWide = function(_, name, version, _, defaults)
        assert(name == 'KanaScribingScriptSourceHintSaved' and version == 1)
        assert(defaults.hideKnown == false)
        return {sourceHints = defaults.sourceHints, dailyTracking = defaults.dailyTracking, hideKnown = defaults.hideKnown}
    end}
    api.LibAddonMenu2 = {RegisterAddonPanel = function() end, RegisterOptionControls = function(_, _, options) api.options = options end}
    A.Events = {Install = function() end}
    A.Filter = {Install = function() api.filterInstalled = true end,
        SetHideKnown = function(_, value) A.settings.hideKnown = value end}
    A.Tooltip = {New = function() return {
        Show = function(self, owner, data) self.owner, self.data = owner, data end,
        Hide = function(self) self.owner = nil end, Leave = function() end,
    } end}
    A.Initialize(api); return api
end
local function setup(api, r, id, suffix)
    api.CharacterKnowledgeList:SetupItemRow(r, {name = 'Page', scriptId = id, nameSuffix = suffix or ''})
    return r.kanaSources and r.kanaSources.icons or {}
end
test('own settings and saved variable schema remain compatible', function()
    local api = fixture()
    assert(#api.options == 3 and api.options[1].getFunc() and api.options[2].getFunc())
    assert(api.filterInstalled and not api.options[3].getFunc() and not api.options[3].requiresReload)
    api.options[3].setFunc(true); assert(A.settings.hideKnown)
end)
test('native coloring survives refresh hover and recycling without changing source opacity', function()
    local api, r = fixture(), row()
    local icons = setup(api, r, 2)
    A.tracker:Record('mages'); api.callbacks[A.name .. 'SourcesRefresh']()
    setup(api, r, 2) -- The reported stack: native SetupRow runs before our post-hook.
    api.CharacterKnowledge.list:Row_OnMouseEnter(r)
    api.CharacterKnowledge.list:Row_OnMouseExit(r)
    assert(icons[2].alpha == 0.45 and not icons[2].colorCalls)
    assert(r.children.Name.colorCalls > 0, 'native row text must still be recolored')
    setup(api, r, nil, 'crown')
    setup(api, r, 26)
    local second = row(); setup(api, second, 2); setup(api, second, 2)
    for _, entry in ipairs({r, second}) do
        for i = 1, entry:GetNumChildren() do assert(entry:GetChild(i)) end
    end
end)
test('all daily pages get three distinct clickable source icons', function()
    local api = fixture()
    for _, id in ipairs({2, 26, 56}) do
        local r = row(); local data = {name = 'Page', scriptId = id, nameSuffix = ''}
        api.CharacterKnowledgeList:SetupItemRow(r, data)
        local icons = r.kanaSources and r.kanaSources.icons or {}
        assert(#icons == 3, 'expected three icons per daily page')
        local textures = {}
        for _, icon in ipairs(icons) do
            assert(icon.mouse and not icon.hidden and icon.kanaScriptId == id)
            assert(icon.kanaTooltipAnchor == icons[1])
            assert(not textures[icon.texture]); textures[icon.texture] = true
        end
        assert(data.nameSuffix == '' and r.name == 'Page' and r.originalCalls == 1)
    end
end)
test('icons reserve name space without shifting later columns at different widths', function()
    local api = fixture()
    for _, width in ipairs({380, 280}) do
        local r = row(width); local c, edge = r.children, r.children.Extended:GetLeft()
        local icons = setup(api, r, 2); assert(#icons == 3)
        assert(c.Extended:GetLeft() == edge, 'type column moved')
        assert(c.Name:GetRight() < icons[1]:GetLeft(), 'long name overlaps icons')
        assert(icons[1]:GetRight() < icons[2]:GetLeft() and icons[2]:GetRight() < icons[3]:GetLeft())
        assert(icons[3]:GetRight() <= edge and r.height == 30)
    end
end)
test('each tooltip contains only its task and pickup location', function()
    local api, r = fixture(), row()
    for _, icon in ipairs(setup(api, r, 2)) do
        icon.handlers.OnMouseEnter(icon)
        local data, info = A.tooltip.data, A.Sources.details[icon.kanaSource]
        assert(data.title == A.Sources.names[icon.kanaSource])
        assert(data.description == info.description and data.location == info.location)
        assert(not data.rows and not data.hint, 'combined sources leaked into a single-source tooltip')
    end
end)
test('receipt dims only its source and selected character without hover', function()
    local api, r = fixture(), row(); local icons = setup(api, r, 2)
    A.tracker:Record('mages'); api.callbacks[A.name .. 'SourcesRefresh']()
    assert(icons[1].alpha == 1 and icons[2].alpha == 0.45 and icons[3].alpha == 1)
    api.CharacterKnowledge.list.charId = 'bob'; api.callbacks[A.name .. 'SourcesRefresh']()
    assert(icons[2].alpha == 1)
    local data = A.BuildTooltip(api, 2, 'mages')
    assert(data.context:find('Bob', 1, true) and data.account:find('аккаунте', 1, true))
end)
test('daily reset restores opacity while the list stays open', function()
    local api, r = fixture(), row(); local icons = setup(api, r, 2)
    A.tracker:Record('mages'); api.callbacks[A.name .. 'SourcesRefresh'](); assert(icons[2].alpha < 1)
    api.now = 200; api.callbacks[A.name .. 'SourcesRefresh'](); assert(icons[2].alpha == 1)
end)
test('foreign account does not inherit local marks or correction', function()
    local api, r = fixture(), row(); A.tracker:Record('mages'); api.CharacterKnowledge.list.account = '@other'
    local icons = setup(api, r, 2); assert(icons[2].alpha == 1)
    icons[2].handlers.OnMouseUp(icons[2], 2, true); assert(#api.menu == 0 and r.clicks == 1)
end)
test('correction targets only clicked source and selected character and preserves left click', function()
    local api, r = fixture(), row(); api.CharacterKnowledge.list.charId = 'bob'
    local icons = setup(api, r, 2); icons[2].handlers.OnMouseUp(icons[2], 2, true)
    assert(#api.menu == 1); api.menu[1][2]()
    assert(A.tracker:Received('mages', 'EU', '@one', 'bob') and not A.tracker:Received('delve', 'EU', '@one', 'bob'))
    assert(icons[2].alpha == 0.45)
    icons[2].handlers.OnMouseUp(icons[2], 1, true); assert(r.clicks == 1)
end)
test('icon hover preserves native row highlight and keyboard action', function()
    local api, r = fixture(), row(); local icon = setup(api, r, 2)[1]; r.nativeTooltip = true
    icon.handlers.OnMouseEnter(icon); assert(not r.nativeTooltip and api.CharacterKnowledge.list.mouseOverRow == r)
    api.CharacterKnowledge.list.defaultAction(); assert(r.keyboardActions == 1)
    icon.handlers.OnMouseExit(icon); assert(not api.CharacterKnowledge.list.defaultAction)
end)
test('recycled nonscript row restores geometry marker and hides all source controls', function()
    local api, r = fixture(), row(); local icons = setup(api, r, 2); icons[1].handlers.OnMouseEnter(icons[1])
    api.CharacterKnowledgeList:SetupItemRow(r, {name = 'Motif', nameSuffix = 'crown'})
    assert(A.tooltip.owner == nil and r.children.Name.width == 380)
    assert(r.children.Extended.anchor[2] == r.children.Name)
    assert(r.children.NameSuffix.texture == 'crown' and not r.children.NameSuffix.hidden)
    for _, icon in ipairs(icons) do assert(icon.hidden and not icon.mouse and not icon.kanaSource) end
end)
test('reused daily row resets source texture and alpha', function()
    local api, r = fixture(), row(); A.tracker:Record('mages'); local icons = setup(api, r, 2)
    local oldTexture = icons[2].texture; setup(api, r, 26)
    assert(icons[2].kanaSource == 'fighters' and icons[2].texture ~= oldTexture and icons[2].alpha == 1)
    assert(#r.kanaSources.icons == 3 and r.children.Name.width > 0)
end)
test('special pages keep native markers without fake daily icons', function()
    local api = fixture()
    for _, entry in ipairs({{1, 'guild'}, {5, 'quest'}, {31, ''}, {999, ''}}) do
        local r = row(); assert(#setup(api, r, entry[1], entry[2]) == 0)
        assert(r.children.NameSuffix.texture == entry[2] and r.children.Name.width == 380)
    end
end)
test('tracking toggle keeps icons opaque and instructions available', function()
    local api, r = fixture(), row(); A.tracker:Record('mages'); A.settings.dailyTracking = false
    local icons = setup(api, r, 2); assert(icons[2].alpha == 1 and A.BuildTooltip(api, 2, 'mages').location)
end)
test('source toggle restores native geometry and markers', function()
    local api, r = fixture(), row(); local icons = setup(api, r, 2); A.settings.sourceHints = false
    setup(api, r, 1, 'guild')
    assert(r.children.Name.width == 380 and r.children.Extended.anchor[2] == r.children.Name)
    assert(r.children.NameSuffix.texture == 'guild' and not r.children.NameSuffix.hidden)
    for _, icon in ipairs(icons) do assert(icon.hidden and not icon.mouse) end
end)
print(string.format('%d tests passed', passed))
