local ADDON_NAME = "KanaWritRecipes"
local addon = KanaWritRecipes
local hooked = setmetatable({}, { __mode = "k" })
local marker

local function BagLink(data)
    if data.bagId ~= nil and data.slotIndex ~= nil then
        return GetItemLink(data.bagId, data.slotIndex, LINK_STYLE_DEFAULT)
    end
end

local function StoreLink(data)
    if data.slotIndex ~= nil then
        return GetStoreItemLink(data.slotIndex, LINK_STYLE_DEFAULT)
    end
end

local function BuybackLink(data)
    if data.slotIndex ~= nil then
        return GetBuybackItemLink(data.slotIndex, LINK_STYLE_DEFAULT)
    end
end

local function MarkRow(row, data, getLink)
    local name = row:GetNamedChild("Name")
    if not name or not data then return end
    -- Always consume the text produced by the original row callback. Do not
    -- modify item names/data: sorting, searching and other addons keep originals.
    local text = name:GetText() or ""
    if text:sub(1, #marker) == marker then
        text = text:sub(#marker + 1)
        name:SetText(text)
    end
    local itemLink = data.itemLink
    if not itemLink or itemLink == "" then
        itemLink = getLink and getLink(data)
    end
    if itemLink and itemLink ~= "" and addon.recipeIds[GetItemLinkItemId(itemLink)] then
        name:SetText(marker .. text)
    end
end

local function HookList(list, getLink)
    if not list or not list.dataTypes then return end
    for _, dataType in pairs(list.dataTypes) do
        if type(dataType.setupCallback) == "function" and not hooked[dataType] then
            hooked[dataType] = true
            SecurePostHook(dataType, "setupCallback", function(row, data)
                MarkRow(row, data, getLink)
            end)
        end
    end
end

local function InstallHooks()
    if PLAYER_INVENTORY then
        for _, inventory in pairs(PLAYER_INVENTORY.inventories) do
            HookList(inventory.listView, BagLink)
        end
    end
    HookList(STORE_WINDOW and STORE_WINDOW.list, StoreLink)
    HookList(BUY_BACK_WINDOW and BUY_BACK_WINDOW.list, BuybackLink)
    if TRADING_HOUSE then
        HookList(TRADING_HOUSE.searchResultsList)
        HookList(TRADING_HOUSE.postedItemsList)
    end
end

local function OnLoaded(_, name)
    if name ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    marker = "|cE8C45A[" .. (GetCVar("language.2") == "ru" and "Дейлик" or "Writ") .. "]|r "
    InstallHooks()
    -- Retry when lazy-created lists become available; hook each data type once.
    for _, event in ipairs({EVENT_PLAYER_ACTIVATED, EVENT_OPEN_STORE, EVENT_OPEN_BANK,
            EVENT_OPEN_GUILD_BANK, EVENT_TRADING_HOUSE_RESPONSE_RECEIVED}) do
        EVENT_MANAGER:RegisterForEvent(ADDON_NAME, event, InstallHooks)
    end
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnLoaded)
