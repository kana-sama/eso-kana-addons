local ADDON_NAME = 'KanaTTC'
local ttc, prices = TamrielTradeCentre, TamrielTradeCentrePrice
local states = {}
local GOLD_ICON = ' |t14:14:EsoUI/Art/currency/currency_gold.dds|t'
local HEADER_FONT = '$(MEDIUM_FONT)|14|soft-shadow-thin'
local VALUE_FONT = '$(BOLD_FONT)|16|soft-shadow-thin'
local GAP, HEIGHT = 10, 36
local HEADERS = {
    ru = {'Рек. цена', 'Средняя', 'Продажи', 'Предложения'},
    en = {'Sugg. low', 'Sale avg', 'Sales', 'Listings'},
}

local function FormatValue(value, isPrice, decimals)
    if type(value) ~= 'number' then return '—' end
    local text
    if isPrice and value >= 100000 then
        text = string.format('%.0fk', math.floor(value / 1000 + 0.5))
    elseif isPrice and value >= 10000 then
        text = string.format('%.1fk', math.floor(value / 100 + 0.5) / 10)
    else
        text = ttc:FormatNumber(value, decimals):gsub('%.0+$', '')
    end
    return text .. (isPrice and GOLD_ICON or '')
end

local function CreateLabel(parent, font, r, g, b)
    local label = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
    label:SetFont(font)
    label:SetColor(r, g, b, 1)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    return label
end

local function CreateTable(tooltip)
    local state = {headers = {}, values = {}}
    state.control = WINDOW_MANAGER:CreateControl(nil, tooltip, CT_CONTROL)
    state.control:SetMouseEnabled(false)
    state.control:SetHidden(true)
    state.content = WINDOW_MANAGER:CreateControl(nil, state.control, CT_CONTROL)
    state.content:SetAnchor(CENTER, state.control, CENTER)
    for index = 1, 4 do
        state.headers[index] = CreateLabel(state.content, HEADER_FONT, 0.65, 0.65, 0.65)
        state.values[index] = CreateLabel(state.content, VALUE_FONT, 0.9, 0.9, 0.9)
        if index <= 2 then state.values[index]:SetColor(0.95, 0.8, 0.4, 1) end
    end
    states[tooltip] = state
    ZO_PostHookHandler(tooltip, 'OnCleared', function()
        state.inserted = false
        state.control:SetHidden(true)
    end)
    return state
end

local function LayoutTable(tooltip, state, info)
    local headings = HEADERS[GetCVar('language.2')] or HEADERS.en
    local values = {
        FormatValue(info.SuggestedPrice, true, 0),
        FormatValue(info.SaleAvg, true, 2),
        FormatValue(info.SaleEntryCount, false, 0),
        FormatValue(info.EntryCount, false, 0),
    }
    local widths = {}
    -- Measure unconstrained labels: previous values must not constrain reuse.
    for index = 1, 4 do
        local header, value = state.headers[index], state.values[index]
        header:SetDimensions(0, 17)
        value:SetDimensions(0, 19)
        header:SetText(headings[index])
        value:SetText(values[index])
        widths[index] = math.ceil(math.max(header:GetTextWidth(), value:GetTextWidth()))
    end
    local x = 0
    for index = 1, 4 do
        local header, value = state.headers[index], state.values[index]
        header:ClearAnchors()
        value:ClearAnchors()
        header:SetDimensions(widths[index], 17)
        value:SetDimensions(widths[index], 19)
        header:SetAnchor(TOPLEFT, state.content, TOPLEFT, x, 0)
        value:SetAnchor(TOPLEFT, state.content, TOPLEFT, x, 17)
        x = x + widths[index] + GAP
    end
    local width = x - GAP
    local tooltipWidth = tooltip:GetWidth()
    local available = math.max(1, (tooltipWidth > 0 and tooltipWidth or 416) - 32)
    state.content:SetDimensions(width, HEIGHT)
    state.content:SetScale(math.min(1, available / width))
    state.control:SetDimensions(available, HEIGHT)
end

local function AppendTable(tooltip, itemLink)
    local state = states[tooltip]
    local info
    if itemLink and itemLink ~= '' then info = prices:GetPriceInfo(itemLink) end
    if not info then
        if state then state.control:SetHidden(true) end
        return
    end
    state = state or CreateTable(tooltip)
    LayoutTable(tooltip, state, info)
    state.control:SetHidden(false)
    if not state.inserted then
        tooltip:AddVerticalPadding(3)
        tooltip:AddControl(state.control)
        -- AddControl supplies a new parent cell; anchor to that cell each time.
        state.control:ClearAnchors()
        state.control:SetAnchor(CENTER)
        state.inserted = true
    end
end

local function HookTooltip(tooltip, method, getItemLink)
    if not tooltip or type(tooltip[method]) ~= 'function' then return end
    ZO_PostHook(tooltip, method, function(control, ...)
        AppendTable(control, getItemLink(...))
    end)
end

local function HookCrafting(object, tooltip, method, getItemLink)
    if not object or not tooltip or type(object[method]) ~= 'function' then return end
    ZO_PostHook(object, method, function(...)
        AppendTable(tooltip, getItemLink(...))
    end)
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, function(_, addonName)
    if addonName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    -- Own tooltip hooks: TTC's settings and price-output hooks are independent.
    for _, entry in ipairs({
        {'SetAttachedMailItem', GetAttachedItemLink},
        {'SetBagItem', GetItemLink},
        {'SetBuybackItem', GetBuybackItemLink},
        {'SetLootItem', GetLootItemLink},
        {'SetTradeItem', GetTradeItemLink},
        {'SetStoreItem', GetStoreItemLink},
        {'SetTradingHouseListing', GetTradingHouseListingItemLink},
        {'SetTradingHouseItem', GetTradingHouseSearchResultItemLink},
        {'SetQuestReward', GetQuestRewardItemLink},
    }) do
        HookTooltip(ItemTooltip, entry[1], entry[2])
    end
    HookTooltip(ItemTooltip, 'SetWornItem', function(slot)
        return GetItemLink(BAG_WORN, slot)
    end)
    local function Link(link) return link end
    HookTooltip(ItemTooltip, 'SetLink', Link)
    HookTooltip(PopupTooltip, 'SetLink', Link)

    HookCrafting(ZO_SmithingImprovement, ZO_SmithingTopLevelImprovementPanelResultTooltip,
        'SetupResultTooltip', function(_, bag, slot)
            return GetSmithingImprovedItemLink(bag, slot, GetCraftingInteractionType())
        end)
    HookCrafting(ZO_SmithingCreation, ZO_SmithingTopLevelCreationPanelResultTooltip,
        'SetupResultTooltip', function(_, pattern, material, quantity, style, trait)
            return GetSmithingPatternResultLink(pattern, material, quantity, style, trait)
        end)
    HookCrafting(ZO_Provisioner, ZO_ProvisionerTopLevelTooltip, 'RefreshRecipeDetails', function(control)
        if control:GetRecipeData() then
            return GetRecipeResultItemLink(control:GetSelectedRecipeListIndex(), control:GetSelectedRecipeIndex())
        end
    end)
    HookCrafting(ZO_Enchanting, ZO_EnchantingTopLevelTooltip, 'UpdateTooltip', function()
        return ENCHANTING:GetResultItemLink()
    end)
    HookCrafting(ZO_Alchemy, ZO_AlchemyTopLevelTooltip, 'UpdateTooltip', function()
        return ALCHEMY:GetResultItemLink()
    end)
end)
