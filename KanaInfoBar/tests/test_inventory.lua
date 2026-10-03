KanaInfoBar={}
INVENTORY_BACKPACK=1; BAG_BACKPACK=1; SI_INVENTORY_MODE_ITEMS=10
ITEM_TYPE_DISPLAY_CATEGORY_ALL=20; TOP=1; BOTTOM=2
SCENE_HIDING=3; SCENE_HIDDEN=4; SCENE_SHOWN=5
local showing,sceneCallback,selected=true
SCENE_MANAGER={IsShowing=function(_,name) return showing and name=='inventory' end,
    GetScene=function() return {RegisterCallback=function(_,_,fn) sceneCallback=fn end} end}
local button={SetDimensions=function() end,SetAnchor=function() end,SetText=function() end,
    SetHidden=function(self,v) self.hidden=v end,SetHandler=function() end}
WINDOW_MANAGER={CreateControlFromVirtual=function() return button end}
ZO_PlayerInventory={}; ZO_PlayerInventoryTabs={}
function IsItemStolen(_,slot) return slot==1 or slot==2 end
function ZO_PostHook(object,method,fn)
    local original=object[method]
    object[method]=function(...) local result=original(...); fn(...); return result end
end
local title={text='Все',GetText=function(self) return self.text end,SetText=function(self,t) self.text=t end}
local bag={currentFilter=20,subFilter=20,activeTab=title,filterBar={},searchBox={SetText=function() end}}
PLAYER_INVENTORY={inventories={[1]=bag},UpdateList=function() end,
    ChangeFilter=function(_,tab) bag.currentFilter=tab.filterType; bag.subFilter=nil end,
    ShouldAddSlotToList=function(_,inventory,slot)
        if type(inventory.currentFilter)=='function' then return inventory.currentFilter(slot) end
        return not slot.isJunk
    end}
function ZO_MenuBar_SelectDescriptor() bag.currentFilter=20;bag.subFilter=20 end
INVENTORY_MENU_BAR={modeBar={SelectFragment=function(_,id) selected=id end}}
dofile('KanaInfoBar/Inventory.lua')
local A=KanaInfoBar
A:InitializeInventoryAction()
A:OpenInventory(true)
assert(selected==10,'open backpack even when craft bag was selected')
assert(PLAYER_INVENTORY:ShouldAddSlotToList(bag,{bagId=1,slotIndex=1,isJunk=false}))
assert(PLAYER_INVENTORY:ShouldAddSlotToList(bag,{bagId=1,slotIndex=2,isJunk=true}), 'stolen junk must remain visible')
assert(not PLAYER_INVENTORY:ShouldAddSlotToList(bag,{bagId=1,slotIndex=3,isJunk=false}), 'clean items hidden')
assert(button.hidden==false)
showing=false;sceneCallback(nil,SCENE_HIDING)
assert(bag.currentFilter==20 and bag.subFilter==20,'restore native category and subfilter')
assert(button.hidden==true)
showing=true;A:OpenInventory(true)
PLAYER_INVENTORY:ChangeFilter({inventoryType=1,filterType=999})
assert(not A.stolenFilter and bag.currentFilter==999,'category switch removes our filter, preserves new category')
A:OpenInventory(true);A:OpenInventory(false)
assert(not A.stolenFilter and bag.currentFilter==20)
print('PASS: stolen backpack, junk, filter cleanup and native tab changes')
