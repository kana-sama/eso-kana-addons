local Fake=dofile(ROOT..'/tests/support/fake_eso.lua')
return function()
 local k=Fake.Load({'Core.lua','Slots.lua','Inventory.lua','EquipmentPlan.lua','EquipmentRunner.lua','GearProbeCases.lua','GearProbeSuite.lua'})
 assert(k.GearProbeSuite and k.GearProbeCases,'combined equipment experiments are not installed')
 local a=Fake.New();local f={k=k,a=a,saved={},reports={},sent={},clock={now=0,timers={}},size=40}
 function f.clock:NowMs()return self.now end
 function f.clock:Schedule(delay,cb)self.serial=(self.serial or 0)+1;local h={at=self.now+delay,cb=cb,id=self.serial};self.timers[h]=true;return h end
 function f.clock:Cancel(h)self.timers[h]=nil end
 function f:Advance(ms)
  local finish=self.clock.now+ms;local count=0
  while true do
   local first
   for h in pairs(self.clock.timers)do if h.at<=finish and (not first or h.at<first.at or h.at==first.at and h.id<first.id)then first=h end end
   if not first then break end
   count=count+1;assert(count<20000,'unbounded diagnostic loop')
   self.clock.timers[first]=nil;self.clock.now=first.at;first.cb()
  end
  self.clock.now=finish
 end
 a.GetFrameTimeMilliseconds=function()return f.clock.now end
 a.GetAPIVersion=function()return 101051 end
 a.GetBagSize=function()return f.size end
 a.IsUnitDeadOrReincarnating=function()return false end
 a.ArePlayerWeaponsSheathed=function()return true end
 a.IsPlayerInWerewolfForm=function()return false end
 a.GetNumBagFreeSlots=function()local n=f.size;for _ in pairs(a.bags[1])do n=n-1 end;return n end
 a.GetString=function(id)return 'Native error '..tostring(id)end
 a.d=function()end
 f.events=k.Core.NewEvents();f.inventory=k.Inventory.New(a)
 local function free()for s=0,f.size-1 do if not a.bags[1][s]then return s end end end
 local function putBag(item)if not item then return true end;local s=free();if not s then return false end;a.bags[1][s]=item;return true end
 local function dispatch(method,bag,slot,destBag,destSlot)
  local item=a.bags[bag][slot];assert(item,'probe addressed a stale bag location')
  local request={method=method,uid=item.uid,bag=bag,slot=slot,destBag=destBag,destSlot=destSlot,time=f.clock.now}
  f.sent[#f.sent+1]=request
  if f.reject and f.reject(request)then return end
  f.clock:Schedule(100,function()
   if not a.bags[bag][slot] or a.bags[bag][slot].uid~=item.uid then return end
   local old=a.bags[destBag][destSlot]
   if method=='move' then
    if old then return end
    a.bags[bag][slot]=nil;a.bags[destBag][destSlot]=item
   else
    local d=a.descriptions[item.link]
    if d.quality==99 then
     for s,v in pairs(a.bags[0])do if s~=destSlot and a.descriptions[v.link].quality==99 then return end end
    end
    if destSlot==EQUIP_SLOT_OFF_HAND and a.bags[0][4] and a.descriptions[a.bags[0][4].link].equipType==6 then return end
    a.bags[bag][slot]=old;a.bags[destBag][destSlot]=item
    if d.equipType==6 and (destSlot==4 or destSlot==20)then
     local off=destSlot==4 and 5 or 21
     if putBag(a.bags[0][off])then a.bags[0][off]=nil end
    end
   end
   f.events:Emit('InventoryChanged',{})
  end)
 end
 a.CallSecureProtected=function(name,b,s,db,ds,count)assert(name=='RequestMoveItem' and count==1);dispatch('move',b,s,db,ds);return true end
 a.RequestEquipItem=function(b,s,db,ds)dispatch('equip',b,s,db,ds)end
 a.EquipItem=function(b,s,ds)dispatch('ww',b,s,0,ds)end
 a.RequestUnequipItem=function(b,s)local dest=free();assert(dest);dispatch('move',b,s,1,dest)end
 function f:Add(id,bag,slot,equipType,mythic)
  a.bags[bag][slot]={uid=id,link=id};a.descriptions[id]={equipType=equipType,quality=mythic and 99 or 1}
 end
 f:Add('head',0,0,1);f:Add('shoulders',0,3,4);f:Add('chest',0,2,3)
 f:Add('ringA',0,11,12);f:Add('ringB',0,12,12)
 f:Add('sword',0,4,5);f:Add('shield',0,5,7)
 f:Add('altHead',1,0,1);f:Add('altChest',1,1,3);f:Add('staff',1,2,6)
 f:Add('mythicNeck',1,3,2,true);f:Add('mythicHead',1,4,1,true)
 function f:New(saved)
  return k.GearProbeSuite.New({api=a,saved=saved or self.saved,clock=self.clock,inventory=self.inventory,events=self.events,
   canRun=function()return not self.busy end,report=function(text)self.reports[#self.reports+1]=text end})
 end
 f.suite=f:New();return f
end
