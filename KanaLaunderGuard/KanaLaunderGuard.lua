local ADDON = "KanaLaunderGuard"
local DIALOG = "KANA_LAUNDER_GUARD_CONFIRM"
local pending, approved

local function IsStolenTreasure(bag, slot)
    return GetItemType(bag, slot) == ITEMTYPE_TREASURE and IsItemStolen(bag, slot)
end

local function UniqueId(bag, slot)
    local id = GetItemUniqueId(bag, slot)
    return id and Id64ToString(id)
end

local function Dismiss(dialog)
    if pending == dialog.data then
        pending = nil
    end
end

local function Confirm(dialog)
    local request = dialog.data
    if pending ~= request then return end
    pending = nil

    -- A dialog must never authorize a replacement item or a later visit.
    if not request.id
        or UniqueId(request.bag, request.slot) ~= request.id
        or not IsStolenTreasure(request.bag, request.slot)
        or GetSlotStackSize(request.bag, request.slot) ~= request.stackCount then
        return
    end

    -- Re-enter the public function so other addons' hooks still run.
    -- The prehook consumes this permission for exactly one matching call.
    approved = request
    local ok, err = pcall(LaunderItem, request.bag, request.slot, request.quantity)
    approved = nil
    if not ok then error(err) end
end

local function BeforeLaunder(bag, slot, quantity)
    if approved and approved.bag == bag and approved.slot == slot
        and approved.quantity == quantity then
        approved = nil
        return false
    end
    if not IsStolenTreasure(bag, slot) then return false end

    -- Repeated clicks/automatic batches cannot replace the pending request.
    if pending then return true end
    local stackCount = GetSlotStackSize(bag, slot)
    if type(quantity) ~= "number" or quantity <= 0 or quantity > stackCount then
        return true
    end
    local request = {
        bag = bag,
        slot = slot,
        quantity = quantity,
        stackCount = stackCount,
        id = UniqueId(bag, slot),
        link = GetItemLink(bag, slot),
    }
    pending = request
    -- Let the originating inventory action/dialog finish before showing ours.
    zo_callLater(function()
        if pending == request then
            ZO_Dialogs_ShowPlatformDialog(DIALOG, request)
        end
    end, 0)
    return true
end

local function Initialize(_, name)
    if name ~= ADDON then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_ADD_ON_LOADED)

    ZO_Dialogs_RegisterCustomDialog(DIALOG, {
        canQueue = true,
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.BASIC },
        title = { text = "Отмыть сокровище?" },
        mainText = {
            text = function(dialog)
                local request = dialog.data
                return string.format(
                    "Действительно отмыть это сокровище?\n\n%s\nКоличество: %d\n\nЭто отмывание, а не продажа: ты потратишь золото.",
                    request.link, request.quantity)
            end,
        },
        buttons = {
            { text = "Отмыть", callback = Confirm },
            { text = SI_DIALOG_CANCEL, callback = Dismiss },
        },
        noChoiceCallback = Dismiss,
        finishedCallback = Dismiss,
        removedFromQueueCallback = function(data)
            if pending == data then pending = nil end
        end,
    })
    ZO_PreHook("LaunderItem", BeforeLaunder)
    EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_CLOSE_STORE, function()
        pending, approved = nil, nil
        ZO_Dialogs_ReleaseAllDialogsOfName(DIALOG)
    end)
end

EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_ADD_ON_LOADED, Initialize)
