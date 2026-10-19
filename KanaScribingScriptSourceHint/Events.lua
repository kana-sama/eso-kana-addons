local A = KanaScribingScriptSourceHint
A.Events = {}

function A.Events.Install(api, tracker, enabled)
    local names = A.Sources.CofferNames(api)
    local pending, mails = nil, {}
    local namespace = 'KanaScribingScriptSourceHintTracking'
    local function register(event, callback)
        if event then api.EVENT_MANAGER:RegisterForEvent(namespace, event, callback) end
    end
    local function script(link)
        if not link or link == '' or api.GetItemLinkItemType(link) ~= api.ITEMTYPE_CRAFTED_ABILITY_SCRIPT then return end
        local id = api.GetItemLinkItemUseReferenceId(link)
        if id and id > 0 then return id, api.GetCraftedAbilityScriptScribingSlot(id) end
    end
    local function target()
        local name, kind = api.GetLootTargetInfo()
        if name and name ~= '' and kind == api.INTERACT_TARGET_TYPE_ITEM then
            return names[name] or names[api.zo_strformat(api.SI_TOOLTIP_ITEM_NAME, name)], name
        end
        return nil, name
    end
    local function observe()
        if not enabled() then pending = nil; return end
        local group, name = target()
        if not group then
            if name and name ~= '' then pending = nil end
            return
        end
        if not pending or pending.name ~= name then pending = {group = group, name = name, items = {}} end
        pending.expires = api.GetTimeStamp() + 60
        for i = 1, api.GetNumLootItems() do
            local lootId = api.GetLootItemInfo(i)
            local link = api.GetLootItemLink(lootId, api.LINK_STYLE_DEFAULT)
            if script(link) then pending.items[api.GetItemLinkItemId(link)] = true end
        end
    end
    register(api.EVENT_LOOT_UPDATED, observe)
    register(api.EVENT_LOOT_RECEIVED, function(_, _, item, quantity, _, _, personal, pickpocket, _, itemId)
        if not enabled() or not personal or pickpocket or quantity <= 0 then return end
        local link = item
        if not link or not link:find('|H', 1, true) then link = itemId and A.Sources.ItemLink(itemId) end
        local id, slot = script(link)
        if not id then return end
        local group, name = target()
        if name and name ~= '' then
            -- A new or non-item target must not inherit the previous coffer.
            if not group then pending = nil; return end
        elseif pending and pending.expires > api.GetTimeStamp()
            and pending.items[api.GetItemLinkItemId(link)] then
            group = pending.group
        end
        if group then tracker:Loot(group, id, slot, true, quantity) end
        if pending then pending.items[api.GetItemLinkItemId(link)] = nil end
    end)
    register(api.EVENT_LOOT_CLOSED, function() pending = nil end)

    local subjects = {}
    -- These are ESO's localized reward names, also used as the mail subjects.
    for i = 1, 2 do
        local name = api.GetString('SI_LFGITEMREWARDTYPE', i)
        if name and name ~= '' then subjects[name] = true end
    end
    local function mailKey(id) return api.Id64ToString and api.Id64ToString(id) or tostring(id) end
    register(api.EVENT_MAIL_READABLE, function(_, mailId)
        local key = mailKey(mailId)
        mails[key] = nil
        if not enabled() then return end
        local _, _, subject, _, _, system, _, _, count = api.GetMailItemInfo(mailId)
        if not system or not subjects[subject] then return end
        local pages = {}
        for i = 1, count do
            local id, slot = script(api.GetAttachedItemLink(mailId, i, api.LINK_STYLE_DEFAULT))
            if id and A.Sources.SourceForLoot('dungeon', id, slot) then pages[#pages + 1] = {id, slot} end
        end
        mails[key] = pages
    end)
    register(api.EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS, function(_, mailId)
        local key = mailKey(mailId)
        local pages = mails[key]
        mails[key] = nil
        if enabled() then
            for _, page in ipairs(pages or {}) do tracker:Loot('dungeon', page[1], page[2], true, 1) end
        end
    end)
    -- Do not discard on MAIL_REMOVED: delete-on-claim may remove the header
    -- before TAKE_ATTACHED_ITEM_SUCCESS. IDs cannot cross the login boundary.
    register(api.EVENT_PLAYER_DEACTIVATED, function() pending = nil; mails = {} end)
    register(api.EVENT_PLAYER_ACTIVATED, function() pending = nil; names = A.Sources.CofferNames(api) end)
end
