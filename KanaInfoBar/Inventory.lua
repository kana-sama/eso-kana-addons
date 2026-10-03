local A=KanaInfoBar

function A:SetStolenFilter(enabled)
    local inventory=PLAYER_INVENTORY and PLAYER_INVENTORY.inventories[INVENTORY_BACKPACK]
    if not inventory then return end
    if enabled then
        if inventory.currentFilter~=self.stolenPredicate then
            self.savedInventoryFilter={filter=inventory.currentFilter,subFilter=inventory.subFilter,
                title=inventory.activeTab and inventory.activeTab:GetText()}
        end
        inventory.currentFilter=self.stolenPredicate
        inventory.subFilter=nil
        if inventory.activeTab then inventory.activeTab:SetText('Краденое') end
    elseif inventory.currentFilter==self.stolenPredicate and self.savedInventoryFilter then
        local saved=self.savedInventoryFilter
        inventory.currentFilter,inventory.subFilter=saved.filter,saved.subFilter
        if inventory.activeTab then inventory.activeTab:SetText(saved.title or '') end
    end
    self.stolenFilter=enabled==true
    if not enabled then self.savedInventoryFilter=nil end
    if self.stolenButton then self.stolenButton:SetHidden(not self.stolenFilter) end
    if PLAYER_INVENTORY then PLAYER_INVENTORY:UpdateList(INVENTORY_BACKPACK) end
end

function A:InitializeInventoryAction()
    if not PLAYER_INVENTORY then return end
    -- A native function category includes junk, unlike ITEM_TYPE_DISPLAY_CATEGORY_ALL.
    self.stolenPredicate=function(slot)
        return slot and slot.bagId==BAG_BACKPACK and IsItemStolen(slot.bagId,slot.slotIndex)
    end
    ZO_PostHook(PLAYER_INVENTORY,'ChangeFilter',function(manager,tab)
        if self.stolenFilter and tab.inventoryType==INVENTORY_BACKPACK
            and manager.inventories[INVENTORY_BACKPACK].currentFilter~=self.stolenPredicate then
            self:SetStolenFilter(false)
        end
    end)
    local button=WINDOW_MANAGER:CreateControlFromVirtual('KanaInfoBarStolenFilter',ZO_PlayerInventory,'ZO_DefaultButton')
    button:SetDimensions(300,28)
    button:SetAnchor(BOTTOM,ZO_PlayerInventory,TOP,0,-6)
    button:SetText('Краденое  ×  Показать все вещи')
    button:SetHidden(true)
    button:SetHandler('OnClicked',function() self:SetStolenFilter(false) end)
    self.stolenButton=button
    local scene=SCENE_MANAGER:GetScene('inventory')
    scene:RegisterCallback('StateChange',function(_,state)
        if state==SCENE_HIDING or state==SCENE_HIDDEN then self:SetStolenFilter(false) end
    end)
end

function A:OpenInventory(stolen)
    -- This panel targets the keyboard HUD and the keyboard inventory, including
    -- when a controller was the most recently used input device.
    if not PLAYER_INVENTORY then return end
    local function apply()
        if not SCENE_MANAGER:IsShowing('inventory') then return end
        if INVENTORY_MENU_BAR and INVENTORY_MENU_BAR.modeBar then
            INVENTORY_MENU_BAR.modeBar:SelectFragment(SI_INVENTORY_MODE_ITEMS)
        end
        local inventory=PLAYER_INVENTORY.inventories[INVENTORY_BACKPACK]
        -- Always show the backpack rather than a previously selected craft bag.
        if ZO_PlayerInventoryTabs then
            ZO_MenuBar_SelectDescriptor(inventory.filterBar,ITEM_TYPE_DISPLAY_CATEGORY_ALL,true,true)
        end
        if stolen and inventory.searchBox then inventory.searchBox:SetText('') end
        self:SetStolenFilter(stolen)
    end
    if SCENE_MANAGER:IsShowing('inventory') then apply()
    else SCENE_MANAGER:CallWhen('inventory',SCENE_SHOWN,apply); SCENE_MANAGER:Show('inventory') end
end
