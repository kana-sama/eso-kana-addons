KanaScribingScriptSourceHint = {}
dofile('KanaScribingScriptSourceHint/Filter.lua')
local A, passed = KanaScribingScriptSourceHint, 0
local function test(name, fn)
    local ok, err = pcall(fn)
    if not ok then error(name .. ': ' .. tostring(err), 0) end
    passed = passed + 1
end
local unpack = table.unpack or unpack
local Control = {}; Control.__index = Control
local function control(name, width, left)
    return setmetatable({name = name, width = width, left = left or 0, centerY = 0, children = {}, height = 20}, Control)
end
function Control:GetName() return self.name end
function Control:GetNamedChild(name) return self.children[name] end
function Control:GetWidth() return self.width end
function Control:GetHeight() return self.height end
function Control:GetLeft() return self.left end
function Control:GetRight() return self.left + self.width end
function Control:IsHidden() return self.hidden == true end
function Control:SetWidth(value) self.width = value end
function Control:SetMaxLineCount(value) self.maxLines = value end
function Control:ClearAnchors() self.anchor = nil end
function Control:SetAnchor(point, relative, relativePoint, x, y)
    assert(point == 1 and relativePoint == 1)
    self.anchor = relative
    self.left = relative.left + x
    self.centerY = relative.centerY + (y or 0)
end
function Control:SetHidden(value) self.hidden = value end
local function fixture(settings, existing, layout)
    layout = layout or {}
    A.settings = settings or {hideKnown = false, receipts = {old = true}}
    local frame = control('CharacterKnowledgeFrame', 930)
    local search = control('Search', 380, layout.searchLeft or 280)
    search.centerY = 29
    search.children.Label = control('SearchLabel', 120, search.left)
    search.children.Label.centerY = search.centerY
    frame.children.Search = search
    local singleAccount = control('SingleAccount', 20, 30)
    singleAccount.label = control('SingleAccountLabel', 160, 55)
    singleAccount.hidden = not layout.accountVisible
    local headers = control('CharacterKnowledgeHeaders', 900)
    headers.centerY = 67
    headers.children.Name = control('Name', 200)
    headers.children.Quality = control('Quality', 210, 200)
    headers.children.NameSuffix = control('NameSuffix', 16, 389)
    local list = {frame = frame, singleAccount = singleAccount, headers = headers,
        filterId = 9, charId = 'alice', entries = {}, masterList = {}, search = '',
        scroll = {height = 140, marker = 'native scroll'}, refreshes = 0}
    list.list = list.scroll
    local api = {LEFT = 1, CharacterKnowledge = {}, LibCharacterKnowledge = {ITEM_CATEGORY_SCRIBING = 9}}
    api.CharacterKnowledgeList = {}
    function api.CharacterKnowledgeList:FilterScrollList()
        self.entries = {}; local known = 0
        for _, data in ipairs(self.masterList) do
            if data.category == self.filterId and data.name:find(self.search, 1, true) then
                self.entries[#self.entries + 1] = {data = data}
                if data.ratioKnown == 1 then known = known + 1 end
            end
        end
        self.nativeCount = {known, #self.entries}
    end
    function api.CharacterKnowledgeList:UpdateState()
        self.researchModeIsSelected = self.filterId == 99
        if not self.researchModeIsSelected then self:RefreshFilters() end
    end
    function list:RefreshFilters()
        self.refreshes = self.refreshes + 1
        self:FilterScrollList()
        table.sort(self.entries, function(a, b) return a.data.name < b.data.name end)
    end
    function list:SelectCharacter(id)
        self.charId = id
        for _, data in ipairs(self.masterList) do data.ratioKnown = data.knownBy[id] and 1 or 0 end
        self:UpdateState()
    end
    setmetatable(list, {__index = api.CharacterKnowledgeList})
    api.ZO_PostHook = function(object, method, after)
        local old = object[method]; object[method] = function(...) old(...); after(...) end
    end
    api.WINDOW_MANAGER = {CreateControlFromVirtual = function(_, name, parent, template)
        assert(name and name ~= '' and template == 'ZO_CheckButton')
        local check = control(name, 20); check.parent = parent
        parent.created = (parent.created or 0) + 1; return check
    end}
    api.ZO_CheckButton_SetLabelText = function(c, text)
        -- Native ESO creates and exposes button.label here; there is no GetLabel API.
        c.label = c.label or control(c.name .. 'Label', 0)
        c.label.text = text
    end
    api.ZO_CheckButton_SetCheckState = function(c, value) c.checked = value end
    api.ZO_CheckButton_SetToggleFunction = function(c, fn) c.toggle = fn end
    api.ZO_CheckButton_IsChecked = function(c) return c.checked end
    api.ZO_ScrollList_GetDataList = function() return list.entries end
    for i, name in ipairs({'Zeta known', 'Alpha missing', 'Beta known', 'Gamma grimoire'}) do
        list.masterList[i] = {name = name, category = 9, scriptId = i < 4 and i or nil,
            grimoireId = i == 4 and 1 or nil, knownBy = {alice = i == 1 or i == 3, bob = i == 2 or i == 4}}
    end
    list.masterList[5] = {name = 'Known motif', category = 2, knownBy = {alice = true}}
    for _, data in ipairs(list.masterList) do data.ratioKnown = data.knownBy.alice and 1 or 0 end
    if existing then api.CharacterKnowledge.list = list end
    A.Filter.Install(api)
    if not existing then list:UpdateState(); api.CharacterKnowledge.list = list end
    return api, list
end
local function names(list)
    local values = {}; for _, entry in ipairs(list.entries) do values[#values + 1] = entry.data.name end
    return table.concat(values, ',')
end
test('checkbox starts unchecked on search row without moving native controls', function()
    local api, list = fixture()
    local check = list.kanaHideKnown
    assert(check and check.label.text == 'Скрывать известные' and not check.checked and not check.hidden)
    local search = list.frame.children.Search
    assert(check.parent == list.frame and check.centerY == search.centerY)
    assert(check.centerY < list.headers.centerY and check.left == list.singleAccount.left)
    assert(check.left + check.width + 5 + check.label.width < search.children.Label.left)
    assert(list.frame.created == 1 and not list.headers.created and #list.entries == 4)
    assert(search.left == 280 and search.width == 380 and list.headers.centerY == 67)
end)
test('checkbox follows search geometry and leaves visible account filter accessible', function()
    local api, list = fixture(nil, nil, {searchLeft = 240})
    local check, search = list.kanaHideKnown, list.frame.children.Search
    assert(check.centerY == search.centerY)
    assert(check.left + check.width + 5 + check.label.width < search.children.Label.left)
    search.left, search.children.Label.left, search.children.Label.centerY = 440, 440, 35
    list.singleAccount.hidden = false
    list:UpdateState()
    assert(check.centerY == 35 and check.left > list.singleAccount.label:GetRight())
    assert(check.left + check.width + 5 + check.label.width < search.children.Label.left)
    assert(list.singleAccount.left == 30 and list.singleAccount.label.width == 160)
    assert(search.width == 380 and list.frame.created == 1)
end)
test('toggle hides all known pages for selected character but keeps native search sorting and counts', function()
    local api, list = fixture()
    list.kanaHideKnown.checked = true; list.kanaHideKnown.toggle(list.kanaHideKnown, true)
    assert(A.settings.hideKnown and names(list) == 'Alpha missing,Gamma grimoire')
    assert(list.nativeCount[1] == 2 and list.nativeCount[2] == 4)
    list.search = 'Alpha'; list:RefreshFilters(); assert(names(list) == 'Alpha missing')
    assert(#list.masterList == 5 and A.settings.receipts.old)
end)
test('changing selected character refilters using personal knowledge', function()
    local api, list = fixture({hideKnown = true})
    list:SelectCharacter('bob')
    assert(names(list) == 'Beta known,Zeta known')
    list:SelectCharacter('alice'); assert(names(list) == 'Alpha missing,Gamma grimoire')
end)
test('turning filter off restores known pages without reload', function()
    local api, list = fixture({hideKnown = true})
    A.Filter.SetHideKnown(api, false)
    assert(#list.entries == 4 and not list.kanaHideKnown.checked)
end)
test('other categories and research preserve native content and hide checkbox', function()
    local api, list = fixture({hideKnown = true})
    list.filterId = 2; list:UpdateState()
    assert(names(list) == 'Known motif' and list.kanaHideKnown.hidden)
    list.filterId = 99; list:UpdateState(); assert(list.kanaHideKnown.hidden)
    list.filterId = 9; list:UpdateState()
    assert(#list.entries == 2 and not list.kanaHideKnown.hidden and list.frame.created == 1)
end)
test('existing browser and saved enabled flag apply on install', function()
    local api, list = fixture({hideKnown = true}, true)
    assert(list.kanaHideKnown.checked and #list.entries == 2)
end)
test('unknown knowledge stays visible and all-known result can be empty', function()
    local api, list = fixture({hideKnown = true})
    for _, data in ipairs(list.masterList) do data.ratioKnown = 1 end
    list:RefreshFilters(); assert(#list.entries == 0)
    list.masterList[2].ratioKnown = nil; list:RefreshFilters(); assert(names(list) == 'Alpha missing')
end)
test('filter preserves native scroll container and access to last result at small height', function()
    local api, list = fixture({hideKnown = true})
    local nativeScroll = list.scroll
    for i = 1, 30 do list.masterList[#list.masterList + 1] = {name = 'Page ' .. i, category = 9, ratioKnown = 0} end
    list.scroll.height = 60; list:RefreshFilters()
    assert(list.list == nativeScroll and list.scroll.height == 60 and #list.entries == 32)
    assert(list.entries[#list.entries].data.name == 'Page 9')
end)
print(string.format('%d tests passed', passed))
