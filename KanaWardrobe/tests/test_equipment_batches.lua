local setup=dofile(ROOT..'/tests/support/gear_suite_fixture.lua')
local function plan(f,intent)
 return assert(f.k.EquipmentPlan.Build(f.inventory:Capture('equipment'),intent,'apply',{}))
end
local function item(id)return {kind='item',uid=id}end
local empty={kind='empty'}
local function run(f,p)
 f.runner=f.k.EquipmentRunner.New(f.inventory,f.events,f.clock)
 assert(f.runner:Start(p,nil,function(r)f.result=r end))
end
local function forbidPrivateMoveLookup(api)
 local previous=getmetatable(api).__index
 setmetatable(api,{__index=function(t,key)
  if key=='RequestMoveItem' then error('private RequestMoveItem must not be read from addon code') end
  if type(previous)=='function' then return previous(t,key) end
  return previous and previous[key]
 end})
end
return {
 private_move_function_is_never_read_when_removing_a_batch=function()
  local f=setup();forbidPrivateMoveLookup(f.a)
  run(f,plan(f,{[0]=empty,[3]=empty}));assert(#f.sent==2)
  assert(f.sent[1].destSlot~=f.sent[2].destSlot)
  f:Advance(150);assert(f.result.status=='success')
 end,
 private_move_function_is_never_read_when_equipping_a_batch=function()
  local f=setup();forbidPrivateMoveLookup(f.a)
  run(f,plan(f,{[0]=item('altHead'),[2]=item('altChest')}));assert(#f.sent==2)
  f:Advance(150);assert(f.result.status=='success')
 end,
 missing_secure_wrapper_never_falls_back_to_a_private_move=function()
  local f=setup();f.a.CallSecureProtected=false;forbidPrivateMoveLookup(f.a)
  local ok,problem=f.inventory:Request({kind='unequip',uid='head',equipSlot=0,bagSlot=10})
  assert(not ok and problem.code=='invalidStep' and #f.sent==0)
 end,
 missing_secure_wrapper_keeps_removals_serial_without_private_lookup=function()
  local f=setup();f.a.CallSecureProtected=false;forbidPrivateMoveLookup(f.a)
  run(f,plan(f,{[0]=empty,[3]=empty}));assert(#f.sent==1)
  f:Advance(250);assert(f.result.status=='success' and #f.sent==2)
 end,
 operation_single_item_preserves_the_native_refusal_reason=function()
  local f=dofile(ROOT..'/tests/support/operation_fixture.lua')()
  local ref=f:AddItem('a',2);local step=assert(f:Plan({equipment={[EQUIP_SLOT_RING1]=ref}})).steps[1]
  local services=f.k.OperationSteps.New(f.inventory,f.skills,f.attributes,f.events,f.clock,f.services)
  local err
  services:Run(step,{intent={}},function(p)step.pending=f.k.Copy(p)end,function(_,problem)err=problem end)
  f.events:Emit('NativeEquipmentError',{event='EVENT_UI_ERROR',code=42,text='Native refusal reason'})
  f:Advance(6000);assert(err and err.details.reasonText=='Native refusal reason')
 end,
 legacy_equip_evidence_without_a_source_is_not_silently_confirmed=function()
  local f=setup();local before=f.inventory:Capture(false).worn
  local p={before=before,expected=f.k.Copy(before),batch={{kind='equip',uid='head',equipSlot=0}}}
  assert(not f.k.EquipmentRunner.IsPendingConfirmed(f.inventory,p,f.inventory:Capture(false)))
 end,

 two_implicit_offhand_releases_do_not_compete_for_one_unreserved_cell=function()
  local f=setup();f:Add('backSword',0,20,EQUIP_TYPE_ONE_HAND);f:Add('backShield',0,21,EQUIP_TYPE_OFF_HAND)
  f:Add('backStaff',1,8,EQUIP_TYPE_TWO_HAND)
  local p=plan(f,{[4]=item('staff'),[20]=item('backStaff')})
  assert(p.steps[1].batchId~=p.steps[2].batchId,'two implicit removals can choose the same cell')
  run(f,p);assert(#f.sent==1);f:Advance(250);assert(f.result.status=='success' and #f.sent==2)
 end,
 partial_twohand_result_reports_the_offhand_that_failed_to_clear=function()
  local f=setup();local p=plan(f,{[4]=item('staff')})
  f.reject=function()return true end;run(f,p)
  f.a.bags[1][2]=f.a.bags[0][4];f.a.bags[0][4]={uid='staff',link='staff'}
  f:Advance(5100);local d=f.result.problem.details
  assert(d.items[1].equipSlot==5 and d.items[1].actual.uid=='shield' and d.items[1].expected.kind=='empty')
 end,
 native_refusal_is_preserved_with_the_failed_batch=function()
  local f=setup();f.reject=function()return true end
  run(f,plan(f,{[0]=item('altHead')}))
  f.events:Emit('NativeEquipmentError',{event='EVENT_UI_ERROR',code=42,text='Native refusal reason'})
  f:Advance(5100)
  assert(f.result.diagnostics.nativeErrors[1].text=='Native refusal reason')
  assert(f.result.problem.details.reasonText=='Native refusal reason')
 end,

 removals_share_one_batch_and_unique_reserved_destinations=function()
  local f=setup();local p=plan(f,{[0]=empty,[3]=empty,[2]=empty})
  assert(#p.steps==3 and p.steps[1].batchId==p.steps[3].batchId,'independent removals were split')
  run(f,p);assert(#f.sent==3,'removals must dispatch together')
  assert(f.sent[1].destSlot~=f.sent[2].destSlot and f.sent[2].destSlot~=f.sent[3].destSlot)
  f:Advance(150);assert(f.result.status=='success' and not f.a.bags[0][0] and not f.a.bags[0][3])
 end,
 explicit_removal_and_replacement_share_one_operation_step=function()
  local f=setup();local p=plan(f,{[3]=empty,[0]=item('altHead')})
  assert(#p.steps==2 and p.steps[1].batchId==p.steps[2].batchId,'mixed independent moves were split')
  run(f,p);assert(#f.sent==2);f:Advance(150)
  assert(f.result.status=='success' and f.a.bags[0][0].uid=='altHead' and not f.a.bags[0][3])
 end,
 ring_swap_is_one_request_and_both_slots_are_verified=function()
  local f=setup();local p=plan(f,{[11]=item('ringB'),[12]=item('ringA')})
  assert(#p.steps==1,'ring swap used a backpack detour')
  run(f,p);assert(#f.sent==1 and f.sent[1].bag==0)
  f:Advance(150);assert(f.result.status=='success' and f.a.bags[0][11].uid=='ringB' and f.a.bags[0][12].uid=='ringA')
 end,
 worn_weapon_transfer_uses_no_bag_cell=function()
  local f=setup();local p=plan(f,{[20]=item('sword')})
  assert(#p.steps==1 and p.requiredFree==0,'empty-bar transfer must be direct')
  run(f,p);assert(f.sent[1].bag==0 and f.sent[1].slot==4 and f.sent[1].destSlot==20)
  f:Advance(150);assert(f.result.status=='success' and not f.a.bags[0][4] and f.a.bags[0][20].uid=='sword')
 end,
 same_slot_mythic_replacement_is_direct=function()
  local f=setup();f.a.bags[0][1]=f.a.bags[1][3];f.a.bags[1][3]=nil
  f:Add('mythicNeck2',1,6,EQUIP_TYPE_NECK,true)
  local p=plan(f,{[1]=item('mythicNeck2')});assert(#p.steps==1 and p.steps[1].kind=='equip')
  run(f,p);f:Advance(150);assert(f.result.status=='success')
 end,
 different_slot_mythic_waits_for_release_without_extra_armor_removal=function()
  local f=setup();f.a.bags[0][1]=f.a.bags[1][3];f.a.bags[1][3]=nil
  local p=plan(f,{[0]=item('mythicHead'),[2]=item('altChest')})
  assert(#p.steps==3)
  local removes=0;for _,s in ipairs(p.steps)do if s.kind=='unequip'then removes=removes+1;assert(s.uid=='mythicNeck')end end
  assert(removes==1)
  run(f,p);assert(#f.sent==2,'ordinary replacement should accompany the required release')
  f:Advance(50);assert(#f.sent==2);f:Advance(250);assert(f.result.status=='success' and #f.sent==3)
 end,
 twohand_equip_clears_offhand_in_one_request=function()
  local f=setup();local p=plan(f,{[4]=item('staff')})
  assert(#p.steps==1,'native twohand clearing was expanded into a removal')
  run(f,p);assert(#f.sent==1);f:Advance(150)
  assert(f.result.status=='success' and f.a.bags[0][4].uid=='staff' and not f.a.bags[0][5])
 end,
 onehand_and_shield_replace_twohand_in_one_ordered_batch=function()
  local f=setup();f.a.bags[0][4]=f.a.bags[1][2];f.a.bags[1][2]={uid='sword',link='sword'}
  f.a.bags[1][7]=f.a.bags[0][5];f.a.bags[0][5]=nil
  f.a.IsEquipable=function(b,s)
   local v=f.a.bags[b][s];return v and (v.uid~='shield' or f.a.bags[0][4].uid~='staff') or false
  end
  local p=plan(f,{[4]=item('sword'),[5]=item('shield')})
  assert(#p.steps==2 and p.steps[1].batchId==p.steps[2].batchId,'weapon pair unnecessarily fenced')
  run(f,p);assert(#f.sent==2 and f.sent[1].destSlot==4 and f.sent[2].destSlot==5)
  f:Advance(150);assert(f.result.status=='success' and f.a.bags[0][5].uid=='shield')
 end,
 operation_groups_mixed_moves_and_retries_only_missing_removal=function()
  local f=dofile(ROOT..'/tests/support/operation_fixture.lua')()
  f:AddItem('old',EQUIP_SLOT_RING1,true);local a=f:AddItem('a',2)
  local p=assert(f:Plan({equipment={[EQUIP_SLOT_RING1]={kind='empty'},[EQUIP_SLOT_RING2]=a}}))
  assert(#p.steps==2 and p.steps[1].kind=='equipBatch','operation must contain one gear step plus verification')
  local step=p.steps[1];local services=f.k.OperationSteps.New(f.inventory,f.skills,f.attributes,f.events,f.clock,f.services)
  local result,err
  local function execute()result=nil;err=nil;services:Run(step,{intent={}},function(v)step.pending=f.k.Copy(v)end,function(r,e)result=r;err=e end)end
  execute();assert(#f.api.requests==2);f:AckGear(1);f:Advance(6000)
  assert(err and #err.details.items==1)
  execute();assert(#f.api.requests==3);f:AckGear(3);assert(result and not err)
 end,
 operation_preserves_both_ring_swap_effects=function()
  local f=dofile(ROOT..'/tests/support/operation_fixture.lua')()
  local a=f:AddItem('a',EQUIP_SLOT_RING1,true);local b=f:AddItem('b',EQUIP_SLOT_RING2,true)
  local p=assert(f:Plan({equipment={[EQUIP_SLOT_RING1]=b,[EQUIP_SLOT_RING2]=a}}))
  assert(#p.steps==2 and p.steps[1].kind=='equipBatch')
  assert(p.steps[1].target[EQUIP_SLOT_RING1].uid=='b' and p.steps[1].target[EQUIP_SLOT_RING2].uid=='a')
 end,
}
