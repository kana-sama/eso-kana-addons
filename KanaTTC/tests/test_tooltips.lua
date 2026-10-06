-- Run from eso-kana-addons: lua KanaTTC/tests/test_tooltips.lua
local root = 'KanaTTC/'
local events, controls = {}, {}
local language = 'ru'
local originalCalls, nativeClears = 0, 0
local links, itemInfos = {}, {}
local nextLink = 0
CT_CONTROL, CT_LABEL = 1, 2
TOPLEFT, CENTER, TEXT_ALIGN_CENTER = 3, 4, 5
EVENT_ADD_ON_LOADED = 1
ITEMTYPE_POTION, ITEMTYPE_POISON, ITEMTYPE_MASTER_WRIT = 7, 30, 60
BAG_WORN = 1

local Control = {}
Control.__index = Control
function Control:SetFont(font) self.font = font end
function Control:SetColor(...) self.color = {...} end
function Control:SetText(text) self.text = text end
function Control:SetHidden(hidden) self.hidden = hidden end
function Control:SetHorizontalAlignment(alignment) self.alignment = alignment end
function Control:SetMouseEnabled(enabled) self.mouseEnabled = enabled end
function Control:SetScale(scale) self.scale = scale end
function Control:SetDimensions(width, height) self.width, self.height = width, height end
function Control:GetWidth() return self.width or 416 end
function Control:GetTextWidth()
    local text, icons = (self.text or ''):gsub('|t.-|t', '')
    local _, length = text:gsub('[^\128-\191]', '')
    return length * 8 + icons * 14
end
function Control:ClearAnchors() self.anchor = nil end
function Control:SetAnchor(...) self.anchor = {...} end
function Control:GetHandler(event) return self.handlers and self.handlers[event] end
function Control:SetHandler(event, callback)
    self.handlers = self.handlers or {}
    self.handlers[event] = callback
end
function Control:AddVerticalPadding(padding) self.padding = padding end
function Control:AddControl(control)
    self.insertions = (self.insertions or 0) + 1
    self.body = control
    -- Native AddControl reparents the custom control into a tooltip cell.
    control.parent = setmetatable({children = {}, name = 'TooltipCell'}, Control)
end
function Control:ClearLines()
    self.body = nil
    local handler = self:GetHandler('OnCleared')
    if handler then handler(self) end
end
function Control:SetLink(link)
    self.nativeLink = link
    if TamrielTradeCentre.Settings.EnableItemToolTipPricing then
        TamrielTradeCentrePrice:AppendPriceInfo(self, {priceInfo = links[link]})
    end
    return 'native-result', nil, 42
end
WINDOW_MANAGER = {}
function WINDOW_MANAGER:CreateControl(name, parent, kind)
    local control = setmetatable({name = name, parent = parent, kind = kind, children = {}, scale = 1}, Control)
    controls[#controls + 1] = control
    parent.children[#parent.children + 1] = control
    return control
end
GuiRoot = setmetatable({children = {}}, Control)
EVENT_MANAGER = {}
function EVENT_MANAGER:RegisterForEvent(name, _, callback) events[name] = callback end
function EVENT_MANAGER:UnregisterForEvent(name) events[name] = nil end
function GetCVar() return language end
function ZO_PreHook(object, method, callback)
    local original = object[method]
    object[method] = function(...)
        if callback(...) then return end
        return original(...)
    end
end
function ZO_PostHook(object, method, callback)
    local original = object[method]
    local function pack(...) return {n = select('#', ...), ...} end
    object[method] = function(...)
        local result = pack(original(...))
        callback(...)
        return (unpack or table.unpack)(result, 1, result.n)
    end
end
function ZO_PostHookHandler(control, event, callback)
    local original = control:GetHandler(event)
    control:SetHandler(event, function(...)
        if original then original(...) end
        callback(...)
    end)
end

TamrielTradeCentre = {Settings = {EnableItemToolTipPricing = false}}
-- Execute the installed TTC formatter, including its rounding/grouping rules.
local initFile = assert(io.open('../TamrielTradeCentre/TamrielTradeCentreInit.lua'))
local initSource = initFile:read('*a'):gsub('\r\n', '\n')
initFile:close()
local formatter = assert(initSource:match('(function TamrielTradeCentre:FormatNumber.-\nend)'))
assert((loadstring or load)(formatter))()
TamrielTradeCentrePrice = {
    GetPriceInfo = function(_, link) return links[link] end,
    AppendPriceInfo = function() originalCalls = originalCalls + 1 end,
}
local originalAppend = TamrielTradeCentrePrice.AppendPriceInfo
TamrielTradeCentre_ItemInfo = {New = function(_, link) return itemInfos[link] end}
ItemTooltip = setmetatable({children = {}}, Control)
PopupTooltip = setmetatable({children = {}}, Control)

local function itemLink(kind, ...)
    local args = {...}
    for index = 1, #args do args[index] = tostring(args[index]) end
    return kind .. ':' .. table.concat(args, ':')
end
function GetItemLink(...) return itemLink('bag', ...) end
function GetAttachedItemLink(...) return itemLink('mail', ...) end
function GetBuybackItemLink(...) return itemLink('buyback', ...) end
function GetLootItemLink(...) return itemLink('loot', ...) end
function GetTradeItemLink(...) return itemLink('trade', ...) end
function GetStoreItemLink(...) return itemLink('store', ...) end
function GetTradingHouseListingItemLink(...) return itemLink('listing', ...) end
function GetTradingHouseSearchResultItemLink(...) return itemLink('search', ...) end
function GetQuestRewardItemLink(...) return itemLink('reward', ...) end
for _, method in ipairs({'SetAttachedMailItem', 'SetBagItem', 'SetBuybackItem',
    'SetLootItem', 'SetTradeItem', 'SetStoreItem', 'SetTradingHouseListing',
    'SetTradingHouseItem', 'SetWornItem', 'SetQuestReward'}) do
    ItemTooltip[method] = function(self) self.nativeCalls = (self.nativeCalls or 0) + 1 end
end
local function crafting(method)
    return {[method] = function(self) self.nativeCalls = (self.nativeCalls or 0) + 1 end}
end
ZO_SmithingImprovement = crafting('SetupResultTooltip')
ZO_SmithingCreation = crafting('SetupResultTooltip')
ZO_Provisioner = crafting('RefreshRecipeDetails')
ZO_Enchanting = crafting('UpdateTooltip')
ZO_Alchemy = crafting('UpdateTooltip')
ZO_SmithingTopLevelImprovementPanelResultTooltip = setmetatable({children = {}}, Control)
ZO_SmithingTopLevelCreationPanelResultTooltip = setmetatable({children = {}}, Control)
ZO_ProvisionerTopLevelTooltip = setmetatable({children = {}}, Control)
ZO_EnchantingTopLevelTooltip = setmetatable({children = {}}, Control)
ZO_AlchemyTopLevelTooltip = setmetatable({children = {}}, Control)
function GetCraftingInteractionType() return 2 end
function GetSmithingImprovedItemLink(...) return itemLink('improved', ...) end
function GetSmithingPatternResultLink(...) return itemLink('crafted', ...) end
function GetRecipeResultItemLink(...) return itemLink('recipe', ...) end
function ZO_Provisioner:GetRecipeData() return self.recipeData end
function ZO_Provisioner:GetSelectedRecipeListIndex() return 3 end
function ZO_Provisioner:GetSelectedRecipeIndex() return 4 end
ENCHANTING = {GetResultItemLink = function() return 'enchanting:result' end}
ALCHEMY = {GetResultItemLink = function() return 'alchemy:result' end}

local addonFile = io.open(root .. 'KanaTTC.lua')
if addonFile then addonFile:close(); dofile(root .. 'KanaTTC.lua') end
assert(events.KanaTTC, 'KanaTTC must register its addon initialization')
events.KanaTTC(EVENT_ADD_ON_LOADED, 'OtherAddon')
assert(events.KanaTTC, 'ignore unrelated addon events')
events.KanaTTC(EVENT_ADD_ON_LOADED, 'KanaTTC')
assert(not events.KanaTTC, 'unregister initialization after loading')
assert(TamrielTradeCentrePrice.AppendPriceInfo == originalAppend,
    'KanaTTC must leave the original TTC price output unchanged')

local function tooltip(width)
    local control = setmetatable({width = width or 416, children = {}}, Control)
    control:SetHandler('OnCleared', function() nativeClears = nativeClears + 1 end)
    return control
end
local function priceInfo(suggested, average, sales, items)
    return {SuggestedPrice = suggested, SaleAvg = average,
        SaleEntryCount = sales, SaleAmountCount = items,
        Avg = 999, Min = 1, Max = 9999, EntryCount = 888, AmountCount = 777}
end
local function append(tip, info)
    nextLink = nextLink + 1
    local link = 'fixture:' .. nextLink
    links[link] = info
    return PopupTooltip.SetLink(tip, link)
end
local function labels(tip)
    local result = {}
    local function visit(control)
        if control.kind == CT_LABEL and not control.hidden then result[#result + 1] = control.text end
        for _, child in ipairs(control.children) do visit(child) end
    end
    assert(tip.body and not tip.body.hidden, 'compact TTC table is visible')
    visit(tip.body)
    return result
end
local passed = 0
local function expect(condition, message)
    assert(condition, message)
    passed = passed + 1
end
local function expectValues(tip, low, average, sales, items)
    local texts = labels(tip)
    expect(#texts == 8, 'four header/value pairs, without extra labels')
    expect(texts[2]:gsub('%s*|t.-|t', '') == low, 'suggested low: ' .. texts[2])
    expect(texts[4]:gsub('%s*|t.-|t', '') == average, 'sale average: ' .. texts[4])
    expect(texts[6] == sales, 'sales counter must come from sale entries')
    expect(texts[8] == items, 'items counter must come from sold quantities')
    expect(not texts[6]:find('|t', 1, true) and not texts[8]:find('|t', 1, true), 'counters have no currency icon')
end

local tip = tooltip()
append(tip, priceInfo(950, 1560, 42, 126))
expectValues(tip, '950', '1,560', '42', '126')
expect(labels(tip)[1] == 'Рек. мин.' and labels(tip)[3] == 'Ср. продаж', 'Russian price labels distinguish both prices')
expect(labels(tip)[5] == 'Продаж' and labels(tip)[7] == 'Предметов', 'Russian counters distinguish sales and items')
expect(originalCalls == 0, 'compact table works when original TTC output is disabled')
expect(tip.body.anchor[1] == CENTER and tip.body.anchor[2] == nil, 'anchor inside the cell supplied by native AddControl')
expect(tip.body.width <= tip.width - 32 and tip.body.height <= 40, 'compact table fits the native tooltip')

local firstBody, created = tip.body, #controls
append(tip, priceInfo(12500, 9999, 13, 13))
expectValues(tip, '12.5k', '9,999', '13', '13')
expect(tip.body == firstBody and #controls == created and tip.insertions == 1, 'repeated updates reuse one table without duplicate insertions')
tip:ClearLines()
expect(firstBody.hidden and nativeClears == 1, 'native clearing hides the table and preserves the original handler')
append(tip, priceInfo(1000, 10000, 0, 0))
expectValues(tip, '1,000', '10.0k', '0', '0')
expect(tip.body == firstBody and tip.insertions == 2, 'table is reattached after native clearing')

tip:ClearLines()
append(tip, priceInfo(nil, 999.25, nil, 1000000))
expectValues(tip, '—', '999.25', '—', '1,000,000')
tip:ClearLines()
append(tip, nil)
expect(tip.body == nil and firstBody.hidden, 'no price info produces no empty TTC block or stale values')

local narrow = tooltip(260)
append(narrow, priceInfo(99999999, 10500, 1000000, 123456789))
expectValues(narrow, '100000k', '10.5k', '1,000,000', '123,456,789')
expect(narrow.body.width <= 228, 'large exact counters fit a narrow tooltip')
expect(tip.body == nil and firstBody.hidden, 'independent tooltip controls do not share visible state')

language = 'en'
local english = tooltip()
append(english, priceInfo(0, 0, 1, 200))
expectValues(english, '0', '0', '1', '200')
expect(labels(english)[1] == 'Sugg. low' and labels(english)[3] == 'Sale avg', 'English labels preserve TTC terms')
expect(labels(english)[5] == 'Sales' and labels(english)[7] == 'Items', 'English counters have distinct labels')

english:ClearLines()
append(english, priceInfo(23400, 99999, 4, 400))
expectValues(english, '23.4k', '100.0k', '4', '400')
english:ClearLines()
append(english, priceInfo(100000, 125500, 5, 500))
expectValues(english, '100k', '126k', '5', '500')

TamrielTradeCentre.Settings.EnableItemToolTipPricing = false
local disabled = tooltip()
append(disabled, priceInfo(1, 2, 3, 4))
expectValues(disabled, '1', '2', '3', '4')
expect(originalCalls == 0, 'TTC master switch does not disable KanaTTC')
TamrielTradeCentre.Settings = {EnableItemToolTipPricing = true}
append(disabled, priceInfo(1, 2, 3, 4))
expectValues(disabled, '1', '2', '3', '4')
expect(originalCalls == 1, 'original TTC price output remains functional alongside KanaTTC')
local x, y, z = append(disabled, priceInfo(1, 2, 3, 4))
expect(x == 'native-result' and y == nil and z == 42, 'preserve native setter return values')

TamrielTradeCentre.Settings = {EnableItemToolTipPricing = false,
    EnableToolTipSuggested = false, EnableToolTipAggregate = false,
    EnableToolTipStat = false, EnableToolTipSalePrice = false,
    EnableToolTipLastUpdate = false}
append(disabled, priceInfo(23400, 125500, 42, 126))
expectValues(disabled, '23.4k', '126k', '42', '126')

local setterCases = {
    {'SetBagItem', 'bag:2:9', {2, 9}},
    {'SetAttachedMailItem', 'mail:3:4', {3, 4}},
    {'SetBuybackItem', 'buyback:5', {5}},
    {'SetLootItem', 'loot:6', {6}},
    {'SetTradeItem', 'trade:7:8', {7, 8}},
    {'SetStoreItem', 'store:9', {9}},
    {'SetTradingHouseListing', 'listing:10', {10}},
    {'SetTradingHouseItem', 'search:11', {11}},
    {'SetWornItem', 'bag:1:12', {12}},
    {'SetQuestReward', 'reward:13:14', {13, 14}},
}
for index, case in ipairs(setterCases) do
    ItemTooltip:ClearLines()
    links[case[2]] = priceInfo(index, index + 20, index + 30, index + 40)
    ItemTooltip[case[1]](ItemTooltip, (unpack or table.unpack)(case[3]))
    expectValues(ItemTooltip, tostring(index), tostring(index + 20), tostring(index + 30), tostring(index + 40))
end
expect(ItemTooltip.nativeCalls == #setterCases, 'independent hooks preserve every original setter')

local savedSettings = TamrielTradeCentre.Settings
TamrielTradeCentre.Settings = setmetatable({}, {__index = function()
    error('KanaTTC must not read TTC settings')
end})
ItemTooltip:ClearLines()
ItemTooltip:SetBagItem(2, 9)
expectValues(ItemTooltip, '1', '21', '31', '41')
TamrielTradeCentre.Settings = savedSettings

links['improved:2:9:2'] = priceInfo(23, 24, 25, 26)
ZO_SmithingImprovement:SetupResultTooltip(2, 9)
expectValues(ZO_SmithingTopLevelImprovementPanelResultTooltip, '23', '24', '25', '26')
links['crafted:1:2:3:4:5'] = priceInfo(33, 34, 35, 36)
ZO_SmithingCreation:SetupResultTooltip(1, 2, 3, 4, 5)
expectValues(ZO_SmithingTopLevelCreationPanelResultTooltip, '33', '34', '35', '36')
links['recipe:3:4'] = priceInfo(43, 44, 45, 46)
ZO_Provisioner.recipeData = {}
ZO_Provisioner:RefreshRecipeDetails()
expectValues(ZO_ProvisionerTopLevelTooltip, '43', '44', '45', '46')
links['enchanting:result'] = priceInfo(53, 54, 55, 56)
ZO_Enchanting:UpdateTooltip()
expectValues(ZO_EnchantingTopLevelTooltip, '53', '54', '55', '56')
links['alchemy:result'] = priceInfo(63, 64, 65, 66)
ZO_Alchemy:UpdateTooltip()
expectValues(ZO_AlchemyTopLevelTooltip, '63', '64', '65', '66')

-- Exercise the installed TTC lookup against its real compact price-table keys.
local currentAppend = TamrielTradeCentrePrice.AppendPriceInfo
dofile('../TamrielTradeCentre/TamrielTradeCentrePrice.lua')
TamrielTradeCentrePrice.AppendPriceInfo = currentAppend
TamrielTradeCentre_PriceInfo = {}
local constructor = assert(initSource:match('(function TamrielTradeCentre_PriceInfo:New.-\nend)'))
assert((loadstring or load)(constructor))()
TamrielTradeCentrePrice.PriceTable = {Data = {
    [17] = {[1] = {[1] = {[-1] = {
        A = 999, N = 1, X = 9999, EC = 888, AC = 777,
        S = 23400, SA = 19500, SE = 42, SAC = 126,
    }}}},
}}
local actual = tooltip()
itemInfos['actual:17'] = {ID = 17, QualityID = 1, Level = 1, ItemType = 1}
PopupTooltip.SetLink(actual, 'actual:17')
expectValues(actual, '23.4k', '19.5k', '42', '126')
actual:ClearLines()
TamrielTradeCentrePrice.PriceTable = nil
PopupTooltip.SetLink(actual, 'actual:17')
expect(actual.body == nil, 'missing installed TTC price table produces no price block')
print('PASS: ' .. passed .. ' compact TTC tooltip checks')
