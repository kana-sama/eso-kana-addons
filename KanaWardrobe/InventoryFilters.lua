local KW = KanaWardrobe
local InventoryFilters = {}
KW.InventoryFilters = InventoryFilters
local Instance = {}; Instance.__index = Instance
local TAG = "KanaWardrobePresetItems"
-- Keyboard lists. ESO+ shares INVENTORY_BANK and its backingBags with the ordinary bank.
local definitions = {
    {key="backpack", lf="LF_INVENTORY", inventory="INVENTORY_BACKPACK", layout="BACKPACK_MENU_BAR_LAYOUT_FRAGMENT"},
    {key="bankWithdraw", lf="LF_BANK_WITHDRAW", inventory="INVENTORY_BANK"},
    {key="bankDeposit", lf="LF_BANK_DEPOSIT", inventory="INVENTORY_BACKPACK", layout="BACKPACK_BANK_LAYOUT_FRAGMENT"},
    {key="guildBankWithdraw", lf="LF_GUILDBANK_WITHDRAW", inventory="INVENTORY_GUILD_BANK"},
    {key="guildBankDeposit", lf="LF_GUILDBANK_DEPOSIT", inventory="INVENTORY_BACKPACK", layout="BACKPACK_GUILD_BANK_LAYOUT_FRAGMENT"},
    {key="houseBankWithdraw", lf="LF_HOUSE_BANK_WITHDRAW", inventory="INVENTORY_HOUSE_BANK"},
    {key="houseBankDeposit", lf="LF_HOUSE_BANK_DEPOSIT", inventory="INVENTORY_BACKPACK", layout="BACKPACK_HOUSE_BANK_LAYOUT_FRAGMENT"},
    {key="vendorSell", lf="LF_VENDOR_SELL", inventory="INVENTORY_BACKPACK", layout="BACKPACK_STORE_LAYOUT_FRAGMENT"},
    {key="vendorRepair", lf="LF_VENDOR_REPAIR"},
    {key="fenceSell", lf="LF_FENCE_SELL", inventory="INVENTORY_BACKPACK", layout="BACKPACK_FENCE_LAYOUT_FRAGMENT"},
    {key="fenceLaunder", lf="LF_FENCE_LAUNDER", inventory="INVENTORY_BACKPACK", layout="BACKPACK_LAUNDER_LAYOUT_FRAGMENT"},
    {key="guildStoreSell", lf="LF_GUILDSTORE_SELL", inventory="INVENTORY_BACKPACK", layout="BACKPACK_TRADING_HOUSE_LAYOUT_FRAGMENT"},
}
local supported = {}
for _, definition in ipairs(definitions) do supported[definition.key] = true end
local unpackValues = unpack or table.unpack
local function pack(...) return {n=select("#",...),...} end
local function isVisible(control)
    if control.IsControlHidden then return not control:IsControlHidden() end
    return not control:IsHidden()
end
function InventoryFilters.New(repo, inventory, session, savedCharacter)
    return setmetatable({repo=repo,inventory=inventory,session=session,saved=savedCharacter,
        counts={},countOnly=false}, Instance)
end
function Instance:IsEnabled() return self.saved.hidePresetItems == true end
function Instance:IsBypassed()
    if self.session.IsEditorActive then return self.session:IsEditorActive() end
    return self.session:GetView().isEditor == true
end
function Instance:SetEnabled(value)
    value = value == true
    if self:IsEnabled() == value then return end
    self.saved.hidePresetItems = value
    self:Refresh()
end
function Instance:ShouldShow(context, bagId, slotIndex)
    if not supported[context] or self.countOnly or not self:IsEnabled() or self:IsBypassed()
        or bagId == nil or slotIndex == nil then return true end
    local location = self.inventory:ReadSlot(bagId,slotIndex)
    return not location or #self.repo:Memberships(location.uid,"current") == 0
end
function Instance:HiddenCount(context)
    if not self:IsEnabled() or self:IsBypassed() then return 0 end
    return self.counts[context] or 0
end
function Instance:Notify()
    self:UpdateCapacity()
    if self.onChanged then self.onChanged(self) end
end
-- Presentation only: the native slot totals still govern item moves and the
-- full-bag warning. Use the same count as the checkbox, after other filters.
function Instance:UpdateCapacity()
    local api=self.api
    local manager=api and api.PLAYER_INVENTORY
    local inventory=manager and manager.inventories[api.INVENTORY_BACKPACK]
    if not inventory or not inventory.freeSlotsLabel or not manager.GetNumSlots then return end
    local kind=inventory.freeSlotType
    if type(kind)=="function" then kind=kind()end
    if kind~=api.INVENTORY_BACKPACK then return end
    local context=self:ContextForInventory(inventory)
    local hidden=context and self:HiddenCount(context) or 0
    if hidden==0 and not self.capacityApplied then return end
    local used,total=manager:GetNumSlots(kind)
    hidden=math.max(0,math.min(hidden,used,total))
    local format=used<total and inventory.freeSlotsStringId or inventory.freeSlotsFullStringId
    local value=api.zo_strformat(format,used-hidden,total-hidden)
    if hidden>0 then value=value.." "..string.format(KW.Text("CAPACITY_HIDDEN"),hidden)end
    inventory.freeSlotsLabel:SetText(value)
    self.capacityApplied=hidden>0
end
function Instance:ContextForInventory(inventory)
    local api, manager = self.api, self.api.PLAYER_INVENTORY
    for _, d in ipairs(definitions) do
        if d.inventory and manager.inventories[api[d.inventory]] == inventory then
            if d.layout then
                if manager.appliedLayout == api[d.layout].layoutData then return d.key end
            else return d.key end
        end
    end
    if inventory == manager.inventories[api.INVENTORY_BACKPACK]
        and manager.appliedLayout == api.BACKPACK_DEFAULT_LAYOUT_FRAGMENT.layoutData then return "backpack" end
end
-- A local, exception-safe bypass applies only to this instance's callbacks. Foreign filters stay active.
function Instance:WithoutOwnFilter(callback)
    local previous = self.countOnly
    self.countOnly = true
    local result = pack(pcall(callback))
    self.countOnly = previous
    if not result[1] then error(result[2],0) end
    return unpackValues(result,2,result.n)
end
function Instance:CountCandidates(context, candidates, accepts)
    local seen, count = {}, 0
    if self:IsEnabled() and not self:IsBypassed() then
        for _, row in ipairs(candidates) do
            local location = self.inventory:ReadSlot(row.bagId,row.slotIndex)
            if location and not seen[location.uid] and #self.repo:Memberships(location.uid,"current") > 0 then
                if self:WithoutOwnFilter(function() return accepts(row) end) then
                    seen[location.uid] = true; count = count + 1
                end
            end
        end
    end
    self.counts[context] = count
end
function Instance:RecountInventory(inventoryType)
    local manager = self.api.PLAYER_INVENTORY
    local inventory = manager.inventories[inventoryType]
    local context = inventory and self:ContextForInventory(inventory)
    if not context or not inventory.listView or not isVisible(inventory.listView) then return end
    local candidates = {}
    -- House-bank storage exists only while its scene is open. Match the native
    -- UpdateList lifecycle and count zero after the backing storage is cleared.
    if inventory.backingBags and inventory.slots and manager:ShouldAddEntries(inventoryType) then
        for _, bag in ipairs(inventory.backingBags) do
            for _, row in pairs(inventory.slots[bag] or {}) do candidates[#candidates+1] = row end
        end
    end
    self:CountCandidates(context,candidates,function(row) return manager:ShouldAddSlotToList(inventory,row) end)
    self:Notify()
end
-- Mirrors the native repair builder's candidates and metadata, including its search and cost rules.
-- LibFilters' verified keyboard helper uses REPAIR_WINDOW.additionalFilter on these same rows.
function Instance:RecountRepair()
    local api, repair = self.api, self.api.REPAIR_WINDOW
    if not isVisible(repair.control) then return end
    local candidates = {}
    for _, bag in ipairs({api.BAG_WORN,api.BAG_BACKPACK}) do
        for slot in api.ZO_IterateBagSlots(bag) do
            if api.TEXT_SEARCH_MANAGER:IsDataInSearchTextResults("storeTextSearch",api.BACKGROUND_LIST_FILTER_TARGET_BAG_SLOT,bag,slot) then
                local condition = api.GetItemCondition(bag,slot)
                if condition < 100 and not api.IsItemStolen(bag,slot) then
                    local icon,stackCount,_,_,_,_,_,functionalQuality,displayQuality = api.GetItemInfo(bag,slot)
                    local cost = stackCount > 0 and api.GetItemRepairCost(bag,slot) or 0
                    if cost > 0 then
                        candidates[#candidates+1] = {bagId=bag,slotIndex=slot,condition=condition,repairCost=cost,
                            name=api.zo_strformat(api.SI_TOOLTIP_ITEM_NAME,api.GetItemName(bag,slot)),icon=icon,
                            stackCount=stackCount,functionalQuality=functionalQuality,displayQuality=displayQuality,quality=displayQuality}
                    end
                end
            end
        end
    end
    self:CountCandidates("vendorRepair",candidates,function(row)
        return not repair.additionalFilter or repair.additionalFilter(row)
    end)
    self:Notify()
end
function Instance:GetContexts()
    local result = {}
    if not self.api then return result end
    local api, manager = self.api,self.api.PLAYER_INVENTORY
    for _, d in ipairs(definitions) do
        local inventory = d.inventory and manager.inventories[api[d.inventory]]
        local control = inventory and inventory.listView or api.REPAIR_WINDOW.control
        local list = inventory and inventory.listView or api.REPAIR_WINDOW.list
        result[#result+1] = {context=d.key,filterType=api[d.lf],inventoryType=d.inventory and api[d.inventory],
            list=list,parent=inventory and (list.GetParent and list:GetParent() or list) or api.REPAIR_WINDOW.control,
            active=isVisible(control) and (not inventory or self:ContextForInventory(inventory)==d.key)}
    end
    return result
end
-- Native list builders explicitly support this row predicate. Keep their
-- methods intact: UpdateList also binds slot controls used by private actions.
function Instance:AttachRowFilter(owner,context)
    local previous=owner.additionalFilter
    owner.additionalFilter=function(row)
        if type(previous)=="function" and not previous(row)then return false end
        if type(previous)=="number" and not self.api.ZO_ItemFilterUtils.IsSlotInItemTypeDisplayCategoryAndSubcategory(row,self.api.currentFilter,previous)then return false end
        return self:ShouldShow(context,row.bagId,row.slotIndex)
    end
end
function Instance:FilterRepairAfterUpdate()
    local api,repair=self.api,self.api.REPAIR_WINDOW
    if not isVisible(repair.control)then return end
    -- Repair has no native additionalFilter without LibFilters. Work on its
    -- finished data after native update/sort; do not wrap either method or
    -- replay sort callbacks. Header sorts retain the already filtered list.
    local data=api.ZO_ScrollList_GetDataList(repair.list)
    local candidates={}
    for _,entry in ipairs(data)do candidates[#candidates+1]=entry.data end
    self:CountCandidates("vendorRepair",candidates,function()return true end)
    local removed=false
    for index=#data,1,-1 do
        local row=data[index].data
        if not self:ShouldShow("vendorRepair",row.bagId,row.slotIndex)then
            table.remove(data,index);removed=true
        end
    end
    if removed then api.ZO_ScrollList_Commit(repair.list)end
    self:Notify()
end
-- Caller invokes after native keyboard lists and the optional library are initialized.
-- Observation must use the VM hook, never a Lua wrapper calling saved methods.
function Instance:Attach(api, events, onChanged)
    if self.attached then return end
    self.api = api or _G
    api = self.api
    self.onChanged = onChanged
    local manager, repair = assert(api.PLAYER_INVENTORY),assert(api.REPAIR_WINDOW)
    assert(manager.ShouldAddSlotToList and manager.UpdateList and manager.RefreshInventorySlot)
    assert(repair.ApplySort and repair.UpdateList)
    for _, d in ipairs(definitions) do
        if d.inventory then assert(manager.inventories[assert(api[d.inventory])],d.inventory) end
        if d.layout then assert(api[d.layout] and api[d.layout].layoutData,d.layout) end
    end
    assert(api.BACKPACK_DEFAULT_LAYOUT_FRAGMENT)
    -- A second Attach on the same native manager must not stack callbacks or wrappers.
    assert(not manager.KanaWardrobeFilters or manager.KanaWardrobeFilters==self,"KanaWardrobe filters already attached")
    manager.KanaWardrobeFilters = self
    self.lib = api.LibFilters3
    if self.lib then
        for _, d in ipairs(definitions) do
            local context, filterType = d.key, assert(api[d.lf],d.lf)
            local signature = self.lib:GetFilterTypeFunctionType(filterType)
            assert(signature==1 or signature==2,"Unsupported LibFilters callback signature")
            assert(self.lib:RegisterFilter(TAG,filterType,function(first,second)
                if signature==2 then return self:ShouldShow(context,first,second) end
                if type(first)~="table" then return true end
                return self:ShouldShow(context,first.bagId,first.slotIndex)
            end),"Unable to register "..d.lf)
        end
    else
        local attached={}
        for _,d in ipairs(definitions)do
            local owner=d.layout and api[d.layout].layoutData or d.inventory and manager.inventories[api[d.inventory]]
            if owner and not attached[owner]then
                self:AttachRowFilter(owner,d.key);attached[owner]=true
            end
        end
        local default=api.BACKPACK_DEFAULT_LAYOUT_FRAGMENT.layoutData
        if not attached[default]then self:AttachRowFilter(default,"backpack")end
    end
    -- SecurePostHook runs AFTER the original without moving its execution
    -- under an addon-owned function. ZO_PostHook is a Lua wrapper, not this API.
    api.SecurePostHook(manager,"UpdateList",function(_,kind)self:RecountInventory(kind)end)
    if manager.UpdateFreeSlots then
        api.SecurePostHook(manager,"UpdateFreeSlots",function(_,kind)
            if kind==api.INVENTORY_BACKPACK then self:UpdateCapacity()end
        end)
    end
    api.SecurePostHook(repair,"UpdateList",function()
        if self.lib then self:RecountRepair()else self:FilterRepairAfterUpdate()end
    end)
    self.lastBypassed = self:IsBypassed()
    if events then
        events:Subscribe("PresetsChanged",function() self:Refresh() end)
        -- Native inventory events already rebuild the affected list through our
        -- UpdateList hook. Only changes to our filter rules require an extra pass.
        events:Subscribe("SessionChanged",function()
            local bypassed=self:IsBypassed()
            if bypassed~=self.lastBypassed then
                self.lastBypassed=bypassed; self:Refresh()
            end
        end)
    end
    self.attached = true
    self:Refresh()
end
function Instance:Refresh()
    if not self.attached or self.pending then return end
    self.pending = true
    self.api.zo_callLater(function()
        self.pending = false
        if self.lib then
            for _, d in ipairs(definitions) do self.lib:RequestUpdate(self.api[d.lf]) end
        else
            local seen,manager = {},self.api.PLAYER_INVENTORY
            for _,d in ipairs(definitions) do
                local kind = d.inventory and self.api[d.inventory]
                if kind and not seen[kind] then seen[kind]=true; manager:UpdateList(kind) end
            end
            self.api.REPAIR_WINDOW:UpdateList()
        end
        self:Notify()
    end,0)
end
