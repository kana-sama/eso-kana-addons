local events, hooks = {}, {}
EVENT_MANAGER={RegisterForEvent=function(_,_,event,fn) events[event]=fn end,
    RegisterForUpdate=function() end,UnregisterForUpdate=function() end,
    AddFilterForEvent=function() end}
EVENT_INVENTORY_SINGLE_SLOT_UPDATE=1; EVENT_INVENTORY_FULL_UPDATE=2
EVENT_INVENTORY_BAG_CAPACITY_CHANGED=3; EVENT_PLAYER_ACTIVATED=4
EVENT_PLAYER_COMBAT_STATE=5; REGISTER_FILTER_BAG_ID=1
BAG_BACKPACK=1; BAG_WORN=2; ITEMTYPE_TREASURE=7
local combat=false
local grouped=true
function IsUnitInCombat() return combat end
function IsUnitGrouped(unit) assert(unit=='player'); return grouped end
function GetLatency() return 201 end
function GetFramerate() return 63.7 end
function GetNumBagUsedSlots() return 95 end
function GetBagUseableSize() return 100 end
function GetBagSize(bag) return bag==BAG_WORN and 3 or 4 end
function GetSlotStackSize(_,s) return s==0 and 3 or s==3 and 2 or 1 end
function IsItemStolen(_,s) return s~=2 end
function GetItemType(_,s) return s==1 and 9 or 7 end
function GetItemSellValueWithBonuses(_,s) return s==0 and 110 or s==3 and 275 or 900 end
local gear={55,20,80}
function DoesItemHaveDurability(bag,slot) assert(bag==BAG_WORN);return slot<3 end
function GetItemCondition(bag,slot) assert(bag==BAG_WORN);return gear[slot+1] end
function GetItemRepairCost(bag,slot) assert(bag==BAG_WORN);return ({100,150,50})[slot+1] end
local sellLimit,sellsUsed=4,2
function GetFenceSellTransactionInfo() return sellLimit,sellsUsed,3600 end
function ZO_PostHook(object,method,callback) hooks[method]=callback end
function zo_callLater(fn) fn() end
SCENE_MANAGER={IsShowing=function() return false end}
dofile('KanaInfoBar/Logic.lua')
KanaInfoBar.modules={}; KanaInfoBar.ids={}
function KanaInfoBar:RegisterWidget(module)
    self.modules[module.id]=module; table.insert(self.ids,module.id)
end
dofile('KanaInfoBar/Providers.lua')
local A=KanaInfoBar
A:InitializeProviders()
local function value(id) return A.modules[id].read() end
assert(value('messages').visible==false,'missing AC must hide messages')
AetherChat={Messenger={GetTotalUnreadCount=function() return 0 end}}
assert(value('messages').visible==false)
AetherChat.Messenger.GetTotalUnreadCount=function() return 42 end
assert(value('messages').text=='42')
assert(value('ping').color=='red')
assert(value('fps').text=='64')
assert(value('inventory').color=='red')
local durability=value('durability')
assert(durability.text=='20%' and durability.color=='orange')
assert(durability.detail:find('Средняя прочность: 52%',1,true))
assert(durability.detail:find('Починка надетых вещей: 300',1,true))
gear[2]=0
durability=value('durability')
assert(durability.text=='0%' and durability.color=='red','broken gear is red')
gear[2]=21
durability=value('durability')
assert(durability.text=='21%' and durability.color=='normal','above two-death threshold is neutral')
assert(value('treasure').text=='880g','panel shows only total treasure value')
assert(value('treasure').detail:find('Можно продать сегодня: 550g',1,true),
    'tooltip takes the two most valuable treasure units')
assert(value('treasure').detail:find('Осталось продаж: 2 из 4',1,true))
sellsUsed=4
assert(value('treasure').text=='880g','quota changes do not change panel total')
assert(value('treasure').detail:find('Можно продать сегодня: 0g',1,true),
    'tooltip quota refreshes without inventory change')
sellsUsed=0
assert(value('treasure').detail:find('Можно продать сегодня: 770g',1,true),
    'four remaining sales include two cheaper units')
sellLimit=100
assert(value('treasure').detail:find('Можно продать сегодня: 880g',1,true),
    'sale estimate cannot exceed owned treasure')
sellLimit=4
sellsUsed=2
assert(value('dps').text=='— / —')
CMX={currentdata={DPSOut=42000,groupDPSOut=126000,dpstime=8}}
local v=value('dps'); assert(v.text=='42k / 33%')
CMX.currentdata={DPSOut=0,groupDPSOut=0,dpstime=0}
assert(value('dps').text=='42k / 33%','retain final result after CM reset')
combat=true; events[EVENT_PLAYER_COMBAT_STATE](nil,true)
assert(value('dps').text=='— / —','new combat cannot reuse previous result')
CMX.currentdata={DPSOut=12000,groupDPSOut=0,dpstime=2}
assert(value('dps').text=='12k / —','missing denominator is unknown')
CMX.currentdata={DPSOut=0,groupDPSOut=40000,dpstime=4,hpstime=4}
assert(value('dps').text=='0 / 0%','valid recap without own damage must display zero')
grouped=false
for _,case in ipairs({{0,'0'},{842,'842'},{999,'999'},{1000,'1.0k'},
    {5600,'5.6k'},{9940,'9.9k'},{9999,'10.0k'},{10000,'10k'},{42600,'43k'},{1000000,'1000k'}}) do
    CMX.currentdata={DPSOut=case[1],groupDPSOut=case[1]*2,dpstime=4}
    assert(value('dps').text==case[2], 'DPS format: '..case[1])
    assert(not value('dps').detail:find('Доля группового DPS',1,true),'solo tooltip must omit group share')
end
CMX.currentdata={DPSOut=5600,groupDPSOut=11200,dpstime=4}
assert(value('dps').text=='5.6k')
CMX.currentdata={DPSOut=0,groupDPSOut=0,dpstime=0}
grouped=true
assert(value('dps').text=='5.6k / 50%','joining group updates cached result')
assert(value('dps').detail:find('Доля группового DPS: 50%',1,true))
grouped=false
assert(value('dps').text=='5.6k','leaving group removes share from cached result')
events[EVENT_PLAYER_COMBAT_STATE](nil,true)
assert(value('dps').text=='—','solo combat without recap has one placeholder')
CMX=nil
assert(value('dps').text=='—','missing CM solo has one placeholder')
print('PASS: providers, visibility, valuation and fight reset')
