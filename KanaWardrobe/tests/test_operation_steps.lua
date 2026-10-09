local setup=dofile(ROOT..'/tests/support/operation_fixture.lua')
local function create(specs)
 local f=setup(specs);assert(f.k.OperationSteps,'native operation steps are not implemented')
 f.steps=f.k.OperationSteps.New(f.inventory,f.skills,f.attributes,f.events,f.clock,f.services)
 function f:Run(step)
  self.out=nil;self.problem=nil
  self.steps:Run(step,{intent={},target=step.target},function(p)step.pending=self.k.Copy(p)end,function(result,err)self.out=result;self.problem=err end)
 end
 return f
end
return {
 batch_dispatches_together_and_confirms_in_any_order=function()
  local f=create();local a=f:AddItem('a',2);local b=f:AddItem('b',3)
  local step=assert(f:Plan({equipment={[EQUIP_SLOT_RING1]=a,[EQUIP_SLOT_RING2]=b}})).steps[1]
  assert(step.kind=='equipBatch');f:Run(step)
  assert(#f.api.requests==2 and not f.out)
  f:AckGear(2);assert(not f.out);f:AckGear(1);assert(f.out and not f.problem)
  f:Run(step);assert(f.out and #f.api.requests==2)
 end,
 batch_partial_timeout_retries_only_missing_item_after_reload=function()
  local f=create();local a=f:AddItem('a',2);local b=f:AddItem('b',3)
  local step=assert(f:Plan({equipment={[EQUIP_SLOT_RING1]=a,[EQUIP_SLOT_RING2]=b}})).steps[1]
  f:Run(step);f:AckGear(1);f:Advance(6000)
  assert(f.problem.code=='requestTimeout' and #f.problem.details.items==1 and f.problem.details.items[1].uid=='b')
  step=f.k.OperationJournal.Plain(step)
  f.steps=f.k.OperationSteps.New(f.inventory,f.skills,f.attributes,f.events,f.clock,f.services)
  f:Run(step);assert(#f.api.requests==3 and f.api.requests[3][3]==3)
  f:AckGear(3);assert(f.out and not f.problem)
 end,
 batch_dispatch_checkpoint_includes_every_source_before_native_send=function()
  local f=create();local a=f:AddItem('a',2);local b=f:AddItem('b',3)
  local step=assert(f:Plan({equipment={[EQUIP_SLOT_RING1]=a,[EQUIP_SLOT_RING2]=b}})).steps[1]
  local send=f.inventory.Request;local calls=0
  f.inventory.Request=function(self,request)
   calls=calls+1
   local member=step.pending.batch.batch[calls]
   assert(member.uid==request.uid and member.source.slotIndex==calls+1)
   return send(self,request)
  end
  f:Run(step);assert(calls==2 and #f.api.requests==2 and not f.problem)
 end,
 batch_second_send_error_keeps_first_result_and_can_resume=function()
  local f=create();local a=f:AddItem('a',2);local b=f:AddItem('b',3)
  local step=assert(f:Plan({equipment={[EQUIP_SLOT_RING1]=a,[EQUIP_SLOT_RING2]=b}})).steps[1]
  local send=f.inventory.Request;local calls=0
  f.inventory.Request=function(self,request)
   calls=calls+1;if calls==2 then error('test native rejection')end
   return send(self,request)
  end
  f:Run(step);assert(f.problem and #f.api.requests==1 and #step.pending.batch.batch==2)
  assert(f.problem.details.error:find('test native rejection',1,true),'native refusal reason was lost')
  f:AckGear(1);f.inventory.Request=send;f:Run(step)
  assert(#f.api.requests==2);f:AckGear(2);assert(f.out and not f.problem)
 end,
 batch_retry_refuses_to_overwrite_new_manual_equipment=function()
  local f=create();local a=f:AddItem('a',2);local b=f:AddItem('b',3)
  local step=assert(f:Plan({equipment={[EQUIP_SLOT_RING1]=a,[EQUIP_SLOT_RING2]=b}})).steps[1]
  f:Run(step);f:AckGear(1);f:Advance(6000);f:AddItem('manual',EQUIP_SLOT_RING2,true)
  f:Run(step);assert(f.problem.code=='operationDependenciesChanged' and #f.api.requests==2)
 end,
 mastery_step_keeps_the_already_learned_selected_passive=function()
  local f=create({
   {lineId=352,kind='passive',id=10,name='Already learned',purchased=true,rank=1,mastery=true,masteryPoints=2,masterySpent=1},
   {lineId=352,kind='passive',id=11,name='To learn',purchased=false,rank=0,mastery=true},
   {lineId=352,kind='passive',id=12,name='Omitted',purchased=false,rank=0,mastery=true},
  })
  local wanted={abilities={skills={['352:passive:101']={kind='passive',rank=1},['352:passive:111']={kind='passive',rank=1}}}}
  local plan=assert(f:Plan(wanted));assert(plan.steps[1].kind=='skills')
  f:Run(plan.steps[1]);f:SkillEntryReady();f:Advance(2)
  local sent=f.requests.skills[1].skills
  assert(#sent==1 and sent[1].id==111 and not sent[1].removal,'delta was misread as a complete mastery selection')
  f.skillObjects[2].spec.purchased=true;f.skillObjects[2].spec.rank=1
  f.skillLines[352].spec.masterySpent=2
  f.events:Emit('NativeSkillRespecResult',{result=0});f:Advance(101)
  assert(f.out and not f.problem)
  f:Run(plan.steps[#plan.steps]);assert(f.out and not f.problem)
  local repeated=assert(f:Plan(wanted));assert(#repeated.steps==1 and repeated.steps[1].kind=='verify')
 end,
 verification_names_the_missing_mastery_passive_and_both_ranks=function()
  local f=create({{lineId=352,kind='passive',id=10,name='Boundless Potential',purchased=false,rank=0,mastery=true}})
  f:Run({kind='verify',target={abilities={skills={['352:passive:101']={kind='passive',rank=1}}}}})
  local d=f.problem.details.differences;assert(d and #d==1,'report needs the actual difference, not the whole catalogue')
  assert(d[1].name=='Boundless Potential' and d[1].expected.rank==1 and d[1].actual.rank==0)
  dofile(ROOT..'/Dialogs.lua')
  local message=f.k.Dialogs.Problem(f.problem)
  assert(message:find('Boundless Potential',1,true) and message:find('1',1,true) and message:find('0',1,true))
  assert(not message:find('352:passive:101',1,true))
  local report=f.k.OperationJournal.Report({operation={index=1,steps={{kind='verify',problem=f.problem}}}})
  assert(report:sub(1,3000):find('Boundless Potential',1,true))
 end,
 verification_bar_mismatch_names_both_morphs=function()
  local f=create();f.skillObjects[1].spec.names={[1]='Old Morph',[2]='New Morph'}
  f.actualBars[1][5]={type=1,id=511};f.api.ACTION_BAR_ASSIGNMENT_MANAGER:ResetPlayerHotbars()
  f:Run({kind='verify',target={abilities={bars={back={[3]={kind='skill',skillKey='10:active:51',expectedMorph=2}}}}}})
  local d=f.problem.details.differences;assert(d and #d==1)
  dofile(ROOT..'/Dialogs.lua');local message=f.k.Dialogs.Problem(f.problem)
  assert(message:find('Old Morph',1,true) and message:find('New Morph',1,true) and message:find('3',1,true))
 end,
 polling_exception_keeps_native_error_and_stack=function()
  local f=create();local checks=0
  f.steps:Wait({'InventoryChanged'},500,function()
   checks=checks+1;error('native polling failure')
  end,function(result,problem)f.problem=problem end)
  f:Advance(101)
  assert(f.problem.code=='operationError' and f.problem.details.error:find('native polling failure',1,true))
  assert(f.problem.details.traceback:find('stack traceback',1,true))
  f:Advance(1000);assert(checks==1,'failed poll must not keep running')
 end,
 gear_waits_for_source_release_and_displaced_item=function()
  local f=create();f:AddItem('old',EQUIP_SLOT_RING1,true);local ref=f:AddItem('ring',3)
  local step=assert(f:Plan({equipment={[EQUIP_SLOT_RING1]=ref}})).steps[1]
  f:Run(step);f.api.bags[BAG_WORN][EQUIP_SLOT_RING1]={uid='ring',link='ring'}
  f:Advance(101);assert(not f.out,'destination alone is not a complete swap')
  f.api.bags[BAG_BACKPACK][3]={uid='old',link='old'};f:Advance(101);assert(f.out)
 end,
 attribute_result_checkpoint_does_not_wait_for_next_frame=function()
  local f=create();local step={kind='attributes',target={health=0,magicka=0,stamina=64}}
  f:Run(step);f.events:Emit('NativeAttributeRespecResult',{result=74})
  assert(step.pending.descriptor.result==74,'native result must survive reload before polling')
 end,
 asynchronous_skill_send_is_checkpointed_before_dispatch=function()
  local f=create();local step={kind='skills',target={skills={['10:active:51']={kind='active',purchased=true,morph=2}}}}
  local send=f.api.SendSkillPointAllocationRequest
  f.api.SendSkillPointAllocationRequest=function(...)
   assert(step.pending.descriptor.phase=='dispatching','send must have durable dispatch checkpoint')
   return send(...)
  end
  f:Run(step);f:SkillEntryReady();f:Advance(2);assert(#f.requests.skills==1)
 end,
 gear_confirmation_and_already_done_retry=function()
  local f=create();local ref=f:AddItem('ring',3);local p=assert(f:Plan({equipment={[EQUIP_SLOT_RING1]=ref}}));local step=p.steps[1]
  f:Run(step);assert(#f.api.requests==1 and not f.out);f:AckGear();assert(f.out and not f.problem)
  f:Run(step);assert(f.out and #f.api.requests==1)
 end,
 timeout_keeps_facts_and_does_not_auto_retry=function()
  local f=create();local ref=f:AddItem('ring',3);local step=assert(f:Plan({equipment={[EQUIP_SLOT_RING1]=ref}})).steps[1]
  f:Run(step);f:Advance(6001);assert(f.problem.code=='requestTimeout' and step.pending.source.uid=='ring')
  assert(#f.problem.details.items==1 and f.problem.details.items[1].uid=='ring')
  f:Advance(10000);assert(#f.api.requests==1)
  f:AckGear();f:Run(step);assert(f.out and #f.api.requests==1)
 end,
 changed_slot_requires_fresh_diff_without_overwriting_manual_item=function()
  local f=create();local ref=f:AddItem('ring',3);local step=assert(f:Plan({equipment={[EQUIP_SLOT_RING1]=ref}})).steps[1]
  f:AddItem('manual',EQUIP_SLOT_RING1,true);f:Run(step)
  assert(f.problem.code=='operationDependenciesChanged' and #f.api.requests==0)
 end,
 attribute_response_and_actual_are_both_required=function()
  local f=create();local step={kind='attributes',target={health=0,magicka=0,stamina=64}}
  f:Run(step);assert(f.attributeSends==1 and not f.out)
  f.events:Emit('NativeAttributeRespecResult',{result=0});f:Advance(1);assert(not f.out)
  f.actualAttributes={0,0,64};f:Advance(101);assert(f.out and not f.problem)
 end,
 attribute_refusal_stops_and_retry_prepares_fresh_deltas=function()
  local f=create();local step={kind='attributes',target={health=0,magicka=0,stamina=64}}
  f:Run(step);f.events:Emit('NativeAttributeRespecResult',{result=74});f:Advance(1)
  assert(f.problem.code=='nativeRespecRefused');f:Advance(6000);assert(f.attributeSends==1)
  f:Run(step);assert(f.attributeSends==2)
 end,
 retry_during_cast_never_duplicates_request=function()
  local f=create();local step={kind='attributes',target={health=0,magicka=0,stamina=64}}
  f:Run(step);f.attributeCast=300;f:Advance(20001);assert(f.problem)
  f:Run(step);assert(f.problem and f.attributeSends==1)
 end,
 skills_are_confirmed_before_bar_can_resolve_new_morph=function()
  local f=create();local step={kind='skills',target={skills={['10:active:51']={kind='active',purchased=true,morph=2}}}}
  f:Run(step);f:SkillEntryReady();f:Advance(2);assert(#f.requests.skills==1 and not f.out)
  f.skillObjects[1].spec.morph=2;f.api.ACTION_BAR_ASSIGNMENT_MANAGER:ResetPlayerHotbars()
  f.events:Emit('NativeSkillRespecResult',{result=0});f:Advance(101);assert(f.out and not f.problem)
  f:Run({kind='bar',bar='front',target={[1]={kind='skill',skillKey='10:active:51',expectedMorph=2}}})
  assert(#f.requests.skills==2)
  local changes=f.requests.skills[2].bars;assert(changes[1].id==512)
 end,
 final_verification_reports_exact_difference=function()
  local f=create();f:Run({kind='verify',target={attributes={health=0,magicka=0,stamina=64}}})
  assert(f.problem.code=='operationMismatch' and f.problem.details.actual.attributes.health==10)
 end,
}
