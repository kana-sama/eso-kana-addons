local Fake=dofile(ROOT..'/tests/support/fake_eso.lua')
local function setup()
 local k=Fake.Load();local path=ROOT..'/BankTransfers.lua';local file=io.open(path)
 if file then file:close();dofile(path)end
 assert(k.BankTransfers,'BankTransfers is not implemented')
 local a=Fake.New();a.bankOpen=true;a.sizes={[0]=22,[1]=20,[2]=20,[6]=20}
 function a.GetBagSize(bag)return a.sizes[bag]or 0 end
 function a.IsESOPlusSubscriber()return a.subscriber==true end
 local parent=getmetatable(a).__index
 setmetatable(a,{__index=function(_,key)
  assert(key~='RequestMoveItem','private RequestMoveItem must not even be read')
  return parent[key]
 end})
 local clock
 function a.CallSecureProtected(name,fromBag,fromSlot,toBag,toSlot,quantity)
  assert(name=='RequestMoveItem' and quantity==1)
  a.requests[#a.requests+1]={fromBag,fromSlot,toBag,toSlot,at=clock and clock:NowMs()or 0,operation=a.operationId and a.operationId()}
  if a.onRequest then a.onRequest(#a.requests)end
  if a.reject then return false end
 end
 clock={now=0,next=0,timers={}}
 function clock:NowMs()return self.now end
 function clock:Schedule(delay,fn)self.next=self.next+1;self.timers[self.next]={at=self.now+delay,fn=fn};return self.next end
 function clock:Cancel(id)self.timers[id]=nil end
 function clock:Advance(ms)
  local limit=self.now+ms
  while true do
   local id,at
   for key,t in pairs(self.timers)do if t.at<=limit and (not at or t.at<at)then id=key;at=t.at end end
   if not id then break end
   local t=self.timers[id];self.timers[id]=nil;self.now=at;t.fn()
  end
  self.now=limit
 end
 local events=k.Core.NewEvents();local inv=k.Inventory.New(a,function(n,p)events:Emit(n,p)end)
 local repo=k.Presets.New({},'EU','@a','1','One');local active={};local saved={}
 local transfer=k.BankTransfers.New({repo=repo,inventory=inv,clock=clock,events=events,saved=saved,
  active=function()return active end,canRun=function()return not a.busy end})
 a.operationId=function()return transfer:GetView().id end
 local f={k=k,a=a,clock=clock,events=events,inv=inv,repo=repo,active=active,saved=saved,transfer=transfer}
 function f:Add(uid,bag,slot)
  a.bags[bag][slot]={uid=uid,link='item:'..uid};return {kind='item',uid=uid,link='item:'..uid}
 end
 function f:Preset(name,refs)
  local p=repo:NewDraft();p.name=name;p.slots={}
  for i,ref in ipairs(refs)do p.slots[k.Slots.Order[i]]=ref end
  return assert(repo:Save(p,0))
 end
 function f:Start(id)
  local ok,problem=transfer:Start(id)
  if not ok then return nil,problem end
  clock:Advance(32)
  local view=transfer:GetView()
  if view.status~='running' and view.status~='completed'then return nil,view.problem end
  return true
 end
 function f:Ack(index)
  if not index then
   for i,q in ipairs(a.requests)do if not q.done and q.operation==transfer:GetView().id then index=i;break end end
  end
  local q=a.requests[index];assert(q and not q.done,'no pending request');q.done=true
  assert(a.bags[q[1]][q[2]] and not a.bags[q[3]][q[4]],'move would overwrite an unrelated item')
  a.bags[q[3]][q[4]]=a.bags[q[1]][q[2]];a.bags[q[1]][q[2]]=nil
  inv:Refresh();clock:Advance(150)
 end
 function f:Finish()
  local n=0
  while transfer:IsBusy()do n=n+1;assert(n<30,'transfer stuck');self:Ack()end
  assert(transfer:GetView().status=='completed')
 end
 function f:Bag(uid)return assert(inv:Resolve(uid,false,false)).bagId end
 return f
end
return {
 sending_yields_before_the_first_request_and_between_small_batches_without_waiting_for_acknowledgements=function()
  local f=setup();local refs={}
  for i=1,8 do refs[i]=f:Add('Item'..i,BAG_BACKPACK,i-1)end
  local one=f:Preset('One',refs)
  assert(f.transfer:Start(one.id))
  assert(#f.a.requests==0 and f.transfer:IsBusy(),'return to the game so it can draw the progress bar before sending moves')
  f.clock:Advance(32);local first=#f.a.requests
  assert(first>1 and first<8,'send a small batch, then yield to the game')
  f.clock:Advance(32);assert(#f.a.requests>first and #f.a.requests<8,'the next frame must send more without waiting for acknowledgements')
  f.clock:Advance(32);assert(#f.a.requests==8 and f.transfer:GetView().completed==0)
  assert(f.a.requests[1].at<f.a.requests[8].at)
  f:Finish();assert(f.transfer:GetView().completed==8)
 end,
 closing_the_bank_before_the_first_frame_cancels_all_scheduled_moves=function()
  local f=setup();local one=f:Preset('One',{f:Add('A',BAG_BACKPACK,0)})
  assert(f.transfer:Start(one.id));f.a.bankOpen=false;f.events:Emit('BankClosed');f.clock:Advance(10000)
  assert(#f.a.requests==0 and not f.transfer:IsBusy())
 end,
 a_preset_becoming_active_between_batches_protects_its_unsent_items=function()
  local f=setup();local refs={}
  for i=1,4 do refs[i]=f:Add('Item'..i,BAG_BACKPACK,i-1)end
  local one=f:Preset('One',refs);assert(f:Start(one.id));local sent=#f.a.requests
  assert(sent>0 and sent<4)
  local other=f:Preset('Other',{refs[4]});f.active[other.id]=true;f.clock:Advance(32)
  assert(not f.transfer:IsBusy() and #f.a.requests==sent and f.transfer:GetView().problem.code=='bankActivePreset')
  f.clock:Advance(10000);assert(#f.a.requests==sent)
 end,
 independent_moves_are_dispatched_together_and_acknowledged_out_of_order=function()
  local f=setup();local one=f:Preset('One',{f:Add('A',BAG_BACKPACK,0),f:Add('B',BAG_BACKPACK,1),f:Add('C',BAG_BACKPACK,2)})
  assert(f:Start(one.id))
  assert(#f.a.requests==3,'all independent moves must be sent before waiting for any acknowledgement')
  assert(f.a.requests[1].at==f.a.requests[3].at and f.transfer:GetView().completed==0)
  f:Ack(3);assert(f.transfer:IsBusy() and f.transfer:GetView().completed==1)
  f:Ack(1);assert(f.transfer:IsBusy() and f.transfer:GetView().completed==2)
  f.clock:Advance(500);assert(#f.a.requests==3,'polling must never resend a pending move')
  f:Ack(2);assert(not f.transfer:IsBusy() and f.transfer:GetView().completed==3)
  assert(f.saved.bankTransferJournal.status=='completed')
 end,
 a_batch_waits_for_both_sides_of_each_inventory_update=function()
  local f=setup();local one=f:Preset('One',{f:Add('A',BAG_BACKPACK,0),f:Add('B',BAG_BACKPACK,1)})
  assert(f:Start(one.id));assert(#f.a.requests==2)
  local q=f.a.requests[1];local item=f.a.bags[q[1]][q[2]];f.a.bags[q[1]][q[2]]=nil;f.inv:Refresh()
  assert(f.transfer:GetView().completed==0 and f.transfer:IsBusy())
  f.a.bags[q[3]][q[4]]=item;q.done=true;f.inv:Refresh()
  assert(f.transfer:GetView().completed==1 and f.transfer:IsBusy())
  f:Ack(2);assert(f.transfer:GetView().status=='completed')
 end,
 shared_complete_presets_follow_the_first_user_example=function()
  local f=setup();local A=f:Add('A',BAG_BACKPACK,0);local B=f:Add('B',BAG_BACKPACK,1);local C=f:Add('C',BAG_BACKPACK,2)
  local one=f:Preset('One',{A,B});local two=f:Preset('Two',{B,C})
  assert(f:Start(one.id));f:Finish()
  assert(f:Bag('A')==BAG_BANK and f:Bag('B')==BAG_BACKPACK and f:Bag('C')==BAG_BACKPACK)
  assert(f:Start(two.id));f:Finish()
  assert(f:Bag('B')==BAG_BANK and f:Bag('C')==BAG_BANK)
  assert(f:Start(one.id));f:Finish()
  assert(f:Bag('A')==BAG_BACKPACK and f:Bag('B')==BAG_BACKPACK and f:Bag('C')==BAG_BANK)
 end,
 incomplete_other_preset_does_not_keep_shared_items_in_the_bag=function()
  local f=setup();local A=f:Add('A',BAG_BACKPACK,0);local B=f:Add('B',BAG_BACKPACK,1);local C=f:Add('C',BAG_BANK,0)
  local one=f:Preset('One',{A,B});local two=f:Preset('Two',{B,C})
  assert(f:Start(one.id));f:Finish()
  assert(f:Bag('A')==BAG_BANK and f:Bag('B')==BAG_BANK)
  assert(f:Start(two.id));f:Finish()
  assert(f:Bag('A')==BAG_BANK and f:Bag('B')==BAG_BACKPACK and f:Bag('C')==BAG_BACKPACK)
 end,
 worn_items_count_as_carried_but_active_presets_cannot_be_stored=function()
  local f=setup();local A=f:Add('A',BAG_WORN,EQUIP_SLOT_HEAD);local B=f:Add('B',BAG_BACKPACK,0)
  local one=f:Preset('One',{A,B});f.active[one.id]=true
  assert(f.k.BankTransfers.Presence(one,f.inv:Capture(false),f.a).inBag)
  local ok,p=f:Start(one.id);assert(not ok and p.code=='bankActivePreset' and #f.a.requests==0)
  f.active[one.id]=nil;assert(f:Start(one.id));f:Finish()
  assert(f:Bag('A')==BAG_BANK and f:Bag('B')==BAG_BANK)
 end,
 active_presets_keep_shared_items_and_are_rechecked_before_sending_the_batch=function()
  local f=setup();local A=f:Add('A',BAG_BACKPACK,0);local B=f:Add('B',BAG_WORN,EQUIP_SLOT_HEAD);local C=f:Add('C',BAG_BACKPACK,2)
  local one=f:Preset('One',{A,B});local two=f:Preset('Two',{B,C});f.active[two.id]=true
  assert(f:Start(one.id));f:Finish();assert(f:Bag('B')==BAG_WORN and #f.a.requests==1)
  f.active[two.id]=nil
  f.events:Subscribe('BankTransferChanged',function(view)if view.status=='running'then f.active[two.id]=true end end)
  local ok,p=f:Start(two.id)
  assert(not ok and not f.transfer:IsBusy() and #f.a.requests==1 and p.code=='bankActivePreset')
 end,
 missing_instances_and_full_destinations_fail_before_any_request=function()
  local f=setup();local A=f:Add('A',BAG_BANK,0);local one=f:Preset('One',{A,{kind='item',uid='missing',link='Missing'}})
  local ok,p=f:Start(one.id);assert(not ok and p.code=='bankItemsMissing' and p.details.items[1].uid=='missing' and #f.a.requests==0)
  assert(f.saved.bankTransferJournal.problem.details.items[1].uid=='missing','preflight failures must also survive reload')
  f:Add('missing',BAG_BANK,1);f.a.sizes[BAG_BACKPACK]=1
  ok,p=f:Start(one.id);assert(not ok and p.code=='bankDestinationFull' and #f.a.requests==0)
 end,
 subscriber_bank_and_exact_instance_identity_are_preserved=function()
  local f=setup();local A=f:Add('A',BAG_BACKPACK,0);local B=f:Add('B',BAG_BACKPACK,1)
  f.a.bags[BAG_BACKPACK][1].link='item:A';B.link='item:A'
  local one=f:Preset('One',{A,B});f.a.sizes[BAG_BANK]=1;f.a.subscriber=true
  assert(f:Start(one.id));f:Finish()
  assert(f:Bag('A')==BAG_BANK and f:Bag('B')==BAG_SUBSCRIBER_BANK)
  f.a.subscriber=false;assert(f:Start(one.id));f:Finish()
  assert(f:Bag('A')==BAG_BACKPACK and f:Bag('B')==BAG_BACKPACK)
 end,
 closed_bank_and_busy_sessions_never_dispatch_requests=function()
  local f=setup();local one=f:Preset('One',{f:Add('A',BAG_BACKPACK,0)})
  f.a.bankOpen=false;local ok,p=f:Start(one.id);assert(not ok and p.code=='bankClosed')
  f.a.bankOpen=true;f.a.busy=true;ok,p=f:Start(one.id);assert(not ok and p.code=='busy' and #f.a.requests==0)
 end,
 closing_bank_or_timing_out_stops_the_queue_and_does_not_wedge_future_clicks=function()
  local f=setup();local one=f:Preset('One',{f:Add('A',BAG_BACKPACK,0),f:Add('B',BAG_BACKPACK,1)})
  assert(f:Start(one.id));assert(#f.a.requests==2)
  f.a.bankOpen=false;f.events:Emit('BankClosed');f.clock:Advance(10000)
  assert(not f.transfer:IsBusy() and #f.a.requests==2 and f.saved.bankTransferJournal.status=='interrupted')
  f.a.bankOpen=true;assert(f:Start(one.id));f.clock:Advance(6000)
  assert(not f.transfer:IsBusy() and f.saved.bankTransferJournal.problem.code=='bankMoveTimeout')
  assert(f:Start(one.id));f:Finish()
 end,
 unrelated_slot_reuse_and_rejected_secure_dispatch_do_not_move_other_items=function()
  local f=setup();local one=f:Preset('One',{f:Add('A',BAG_BACKPACK,0),f:Add('B',BAG_BACKPACK,1)})
  f.a.onRequest=function(index)if index==1 then f:Add('Other',BAG_BANK,1)end end
  local ok,p=f:Start(one.id)
  assert(not ok and p.code=='bankSlotChanged' and not f.transfer:IsBusy() and #f.a.requests==1 and f:Bag('Other')==BAG_BANK)
  f:Ack(1);f.a.onRequest=nil;f.a.reject=true
  ok,p=f:Start(one.id);assert(not ok and not f.transfer:IsBusy() and p.code=='bankMoveRejected')
 end,
 destination_changes_are_checked_for_the_whole_batch_before_any_request=function()
  local f=setup();local one=f:Preset('One',{f:Add('A',BAG_BACKPACK,0),f:Add('B',BAG_BACKPACK,1)})
  f.events:Subscribe('BankTransferChanged',function(view)if view.status=='running'then f:Add('Other',BAG_BANK,1)end end)
  local ok,p=f:Start(one.id)
  assert(not ok and p.code=='bankSlotChanged' and #f.a.requests==0 and f:Bag('A')==BAG_BACKPACK)
 end,
 rejection_or_bank_close_during_dispatch_stops_unsent_requests=function()
  for _,close in ipairs({false,true})do
   local f=setup();local one=f:Preset('One',{f:Add('A',BAG_BACKPACK,0),f:Add('B',BAG_BACKPACK,1),f:Add('C',BAG_BACKPACK,2)})
   f.a.onRequest=function(index)
    if close then f.a.bankOpen=false;f.events:Emit('BankClosed')
    elseif index==2 then f.a.reject=true end
   end
   local ok,p=f:Start(one.id)
   assert(not ok and not f.transfer:IsBusy() and #f.a.requests==(close and 1 or 2))
   assert(p.code==(close and 'bankClosed'or 'bankMoveRejected'))
   f.clock:Advance(10000);assert(#f.a.requests==(close and 1 or 2))
   assert(f.saved.bankTransferJournal.plan.moves[1].uid=='A')
  end
 end,
 shared_only_and_empty_equipment_presets_do_not_create_meaningless_moves=function()
  local f=setup();local A=f:Add('A',BAG_BACKPACK,0);local B=f:Add('B',BAG_BACKPACK,1)
  local one=f:Preset('One',{A});f:Preset('Two',{A,B})
  local ok,p=f:Start(one.id);assert(not ok and p.code=='bankSharedOnly' and #f.a.requests==0)
  local empty=f:Preset('Empty',{{kind='empty'}})
  assert(f.k.BankTransfers.Presence(empty,f.inv:Capture(false),f.a).count==0)
  ok,p=f:Start(empty.id);assert(not ok and p.code=='bankNoEquipment')
 end,
 interrupted_journal_is_diagnostic_only_and_never_resumes_on_reload=function()
  local f=setup();local one=f:Preset('One',{f:Add('A',BAG_BACKPACK,0)})
  assert(f:Start(one.id));local before=#f.a.requests
  local copy=f.k.BankTransfers.New({repo=f.repo,inventory=f.inv,events=f.events,clock=f.clock,saved=f.saved,active=function()return {}end})
  assert(not copy:IsBusy() and copy:GetView().status=='interrupted' and #f.a.requests==before)
 end,
 transfer_failures_explain_the_item_and_missing_capacity=function()
  local f=setup();dofile(ROOT..'/Dialogs.lua')
  local text=f.k.Dialogs.Problem(f.k.Problem('bankItemsMissing',{items={{uid='A',link='Missing item A'}}}))
  assert(text:find('Missing item A',1,true))
  text=f.k.Dialogs.Problem(f.k.Problem('bankDestinationFull',{needed=12,available=3}))
  assert(text:find('12',1,true) and text:find('3',1,true))
  text=f.k.Dialogs.Problem(f.k.Problem('bankMoveTimeout',{link='Item B',direction='withdraw'}))
  assert(text:find('Item B',1,true) and text:find('backpack',1,true))
 end,
}
