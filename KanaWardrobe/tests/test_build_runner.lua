local Fake=dofile(ROOT..'/tests/support/fake_eso.lua')
local BF=dofile(ROOT..'/tests/support/build_fixture.lua')
local AF=dofile(ROOT..'/tests/support/attribute_fixture.lua')
local function setup()
 local k=Fake.Load({'Core.lua','Slots.lua','lang/en.lua','BuildModel.lua','Inventory.lua','EquipmentPlan.lua','EquipmentRunner.lua','SkillState.lua','SkillAdapter.lua','AttributeAdapter.lua','BuildPlanner.lua'})
 local file=io.open(ROOT..'/BuildRunner.lua');if file then file:close();dofile(ROOT..'/BuildRunner.lua')end
 assert(k.BuildRunner,'Missing BuildRunner')
 local f=AF.Attach(BF.InstallSkills(BF.New(),{{lineId=10,kind='active',id=51,purchased=true,morph=1}}));BF.InstallSkillDrafts(f)
 f.api.IsUnitDeadOrReincarnating=function()return f.api.dead or false end
 local clock={now=0,next=0,timers={}}
 function clock:NowMs()return self.now end
 function clock:Schedule(delay,fn)self.next=self.next+1;self.timers[self.next]={at=self.now+delay,fn=fn};return self.next end
 function clock:Cancel(id)self.timers[id]=nil end
 function clock:Advance(delta)
  local limit=self.now+delta
  while true do
   local id,at;for n,t in pairs(self.timers)do if t.at<=limit and(not at or t.at<at or t.at==at and n<id)then id,at=n,t.at end end
   if not id then break end;local t=self.timers[id];self.timers[id]=nil;self.now=at;t.fn()
  end
  self.now=limit
 end
 f.clock=clock;f.events=k.Core.NewEvents();f.k=k;f.done={};f.progress={}
 f.skills=k.SkillAdapter.New(f.api,f.events,clock);f.attributes=k.AttributeAdapter.New(f.api,f.events)
 f.inventory=k.Inventory.New(f.api,function(n,p)f.events:Emit(n,p)end)
 f.gear=k.EquipmentRunner.New(f.inventory,f.events,clock)
 f.planner=k.BuildPlanner.New({skills=f.skills,attributes=f.attributes})
 function f:Capture()
  local c=self.skills:Catalogue();local attrs,budget=self.attributes:Capture();local eq=self.inventory:Capture('equipment')
  return {equipment=k.Copy(eq.worn),abilities=k.Copy(c.abilities),attributes=attrs,equipmentState=eq,budgets={skills=c.budgets.skills,mastery=k.Copy(c.budgets.mastery),attributes=budget},catalogueRevision=c.revision},c
 end
 f.runner=k.BuildRunner.New(f.skills,f.attributes,f.gear,f.events,clock,{capture=function()return f:Capture()end,revalidateRemaining=f.planner.RevalidateRemaining})
 function f:Plan(intent)local s,c=self:Capture();return assert(self.planner.Build(s,intent,c,{}))end
 function f:Start(plan,progress)return self.runner:Start(plan,function(p)self.progress[#self.progress+1]=p;if progress then progress(p)end end,function(r)self.done[#self.done+1]=r end)end
 function f:Ready()self:SkillEntryReady();clock:Advance(2)end
 function f:ConfirmSkills()
  self.skillObjects[1].spec.morph=2;self.api.SKILLS_AND_ACTION_BAR_MANAGER:ResetRespecState();self.events:Emit('NativeSkillRespecResult',{result=0});clock:Advance(101)
 end
 function f:ConfirmAttributes()
  self.actualAttributes={0,0,64};self.attributeUnspent=2;self:ResetAttributesNative();self.events:Emit('NativeAttributeRespecResult',{result=0});clock:Advance(101)
 end
 function f:AddGear()
  self.api.bags[BAG_BACKPACK][3]={uid='hat',link='hat'};self.api.descriptions.hat={equipType=EQUIP_TYPE_HEAD}
  return {[EQUIP_SLOT_HEAD]={kind='item',uid='hat',link='hat'}}
 end
 function f:ApplyGear()
  local q=self.api.requests[1];assert(q and q[1]=='equip');self.api.bags[BAG_WORN][q[5]]=self.api.bags[q[2]][q[3]];self.api.bags[q[2]][q[3]]=nil;self.inventory:Refresh();clock:Advance(101)
 end
 return f
end
local skillTarget={skills={['10:active:51']={kind='active',purchased=true,morph=2}}}
local attributeTarget={health=0,magicka=0,stamina=64}
return {
 attribute_cooldown_waits_then_retries_only_the_refused_phase=function()
  local f=setup();f.api.RESPEC_RESULT_ON_COOLDOWN_ATTRIBUTES=75
  assert(f:Start(f:Plan({abilities=skillTarget,attributes=attributeTarget,equipment=f:AddGear()})))
  f:Ready();f:ConfirmSkills()
  f.events:Emit('NativeAttributeRespecResult',{result=75});f.clock:Advance(101)
  assert(f.runner:IsBusy() and not f.done[1] and f.progress[#f.progress].stage=='cooldown')
  assert(f.attributes:GetSubmissionState().resolved and #f.requests.attributes==1 and #f.api.requests==0)
  f.clock:Advance(4000);assert(#f.requests.attributes==1,'must not spam retry requests')
  f.clock:Advance(1000);assert(#f.requests.attributes==2 and #f.requests.skills==1)
  f:ConfirmAttributes();f:ApplyGear()
  assert(f.done[1].status=='applied' and not f.runner:IsBusy() and next(f.clock.timers)==nil)
 end,
 cancelled_cooldown_never_sends_late_retry=function()
  local f=setup();f.api.RESPEC_RESULT_ON_COOLDOWN_ATTRIBUTES=75
  assert(f:Start(f:Plan({attributes=attributeTarget})))
  f.events:Emit('NativeAttributeRespecResult',{result=75});f.clock:Advance(101)
  f.runner:Stop('cancelled');f.clock:Advance(10000)
  assert(#f.requests.attributes==1 and next(f.clock.timers)==nil and f.done[1].pending.resolved)
 end,
 skill_cooldown_releases_native_ownership_before_retrying=function()
  local f=setup();f.api.RESPEC_RESULT_ON_COOLDOWN_SKILLS=74
  assert(f:Start(f:Plan({abilities=skillTarget})));f:Ready()
  f.api.SKILLS_AND_ACTION_BAR_MANAGER:ResetRespecState()
  f.events:Emit('NativeSkillRespecResult',{result=74});f.clock:Advance(101)
  assert(f.runner:IsBusy() and f.progress[#f.progress].stage=='cooldown')
  assert(f.skills:GetSubmissionState().resolved and not f.skills:GetNativeOwnership())
  f.clock:Advance(5000);f:Ready();assert(#f.requests.skills==2)
  f:ConfirmSkills();assert(f.done[1].status=='applied' and next(f.clock.timers)==nil)
 end,
 cooldown_retry_rechecks_actual_state_and_has_a_finite_wait=function()
  for _,mutate in ipairs({false,true})do
   local f=setup();f.api.RESPEC_RESULT_ON_COOLDOWN_ATTRIBUTES=75
   assert(f:Start(f:Plan({attributes=attributeTarget})))
   f.events:Emit('NativeAttributeRespecResult',{result=75});f.clock:Advance(101)
   if mutate then f.actualAttributes={11,19,34}end
   for _=1,14 do
    if not f.runner:IsBusy()then break end
    f.clock:Advance(5000)
    if f.runner:IsBusy()then f.events:Emit('NativeAttributeRespecResult',{result=75});f.clock:Advance(101)end
   end
   assert(not f.runner:IsBusy() and f.done[1].status~='applied' and next(f.clock.timers)==nil)
   if mutate then assert(#f.requests.attributes==1)else assert(f.done[1].pending.resolved)end
  end
 end,
 progress_includes_attributes_and_skills_before_equipment=function()
  local f=setup();assert(f:Start(f:Plan({abilities=skillTarget,attributes=attributeTarget,equipment=f:AddGear()})))
  local function current(phase,completed)
   local p=f.progress[#f.progress]
   assert(p.phase==phase and p.total==3 and p.completed==completed,'progress must cover all requested operations')
  end
  current('skills',0);f:Ready();f:ConfirmSkills();current('attributes',1)
  f:ConfirmAttributes();current('equipment',2);f:ApplyGear()
  local p=f.progress[#f.progress];assert(p.completed==3 and p.ratio==1 and f.done[1].status=='applied')
 end,
 attributes_only_progress_tracks_cast_but_waits_for_verified_result=function()
  local f=setup();assert(f:Start(f:Plan({attributes=attributeTarget})))
  local p=f.progress[#f.progress];assert(p.phase=='attributes' and p.total==1 and p.completed==0 and p.ratio==0)
  f.attributeCast=2000;f.clock:Advance(101)
  f.attributeCast=1000;f.clock:Advance(100)
  p=f.progress[#f.progress];assert(p.completed==0 and p.ratio>.4 and p.ratio<.6,'native cast should show gradual attribute progress')
  f.attributeCast=0;f.clock:Advance(100)
  p=f.progress[#f.progress];assert(p.ratio<1 and f.runner:IsBusy(),'elapsed cast cannot confirm the attribute request')
  f:ConfirmAttributes();p=f.progress[#f.progress];assert(p.completed==1 and p.ratio==1 and not f.runner:IsBusy())
 end,
 noops_do_not_inflate_progress_for_gear_only_work=function()
  local f=setup();local s=f:Capture()
  assert(f:Start(f:Plan({abilities=s.abilities,attributes=s.attributes,equipment=f:AddGear()})))
  local p=f.progress[#f.progress];assert(p.phase=='equipment' and p.completed==0 and p.total==1)
  f:ApplyGear();p=f.progress[#f.progress];assert(p.completed==1 and p.total==1)
 end,
 dispatching_adapter_blocks_reentrant_new_operation_before_gear_request=function()
  local f=setup();local plan=f:Plan({equipment=f:AddGear()});local accepted,problem,observed
  f.events:Subscribe('SkillSubmissionChanged',function(state)
   if state.phase=='dispatching'then
    observed=true;accepted,problem=f:Start(plan)
   end
  end)
  local request=assert(f.skills:Prepare(f.skills:Capture(),{bars={front={[1]={kind='skill',skillKey='10:active:51',expectedMorph=1}}}}))
  assert(f.skills:Submit(request));assert(observed)
  assert(not accepted and problem.code=='buildSubmissionUnresolved','dispatching must refuse before creating a second operation')
  assert(#f.api.requests==0 and #f.requests.skills==1 and not f.runner:IsBusy() and next(f.clock.timers)==nil)
 end,
 dispatching_progress_persists_token_before_async_or_bar_only_packet=function()
  for _,full in ipairs({true,false})do
   local f=setup();local dispatched
   local target=full and skillTarget or {bars={front={[1]={kind='skill',skillKey='10:active:51',expectedMorph=1}}}}
   assert(f:Start(f:Plan({abilities=target}),function(p)
    if p.stage=='dispatching'then
     assert(p.pending.token and not p.pending.sent and p.pending.original and p.pending.target and not f.packetPrepareCalls)
     dispatched=p.pending
    end
   end));if full then f:Ready()end
   assert(dispatched and #f.requests.skills==1 and f.packetPrepareCalls==1)
  end
 end,
 dispatching_observer_stop_throw_or_equipment_edit_prevents_packet=function()
  for _,full in ipairs({true,false})do for _,action in ipairs({'stop','throw','gear'})do
   local f=setup();local target=full and skillTarget or {bars={front={[1]={kind='skill',skillKey='10:active:51',expectedMorph=1}}}}
   assert(f:Start(f:Plan({abilities=target}),function(p)
    if p.stage=='dispatching'then
     if action=='stop'then f.runner:Stop('closed')elseif action=='throw'then error('journal failure')
     else f.api.bags[BAG_BACKPACK][3]={uid='external',link='external'};f.api.descriptions.external={equipType=EQUIP_TYPE_HEAD}end
    end
   end));if full then f:Ready()end
   assert(#f.requests.skills==0 and not f.packetPrepareCalls and not f.runner:IsBusy() and #f.done==1)
   assert(f.api.SKILLS_AND_ACTION_BAR_MANAGER.mode==0)
  end end
 end,
 confirmed_flags_in_returned_plan_guard_future_gear_progress=function()
  local f=setup();f.actualBars[2][3]={type=1,id=511};f.api.ACTION_BAR_ASSIGNMENT_MANAGER:ResetPlayerHotbars()
  local plan=f:Plan({abilities=skillTarget,equipment=f:AddGear()})
  f.skillObjects[1].spec.morph=2;f.actualBars[2][3]={type=1,id=512};f.api.ACTION_BAR_ASSIGNMENT_MANAGER:ResetPlayerHotbars()
  local snapshot,catalogue=f:Capture();local remaining=assert(f.planner.RevalidateRemaining(plan,snapshot,catalogue,{skills=true}))
  assert(f:Start(remaining,function(p)
   if p.phase=='equipment' and p.stage=='requesting' and p.pending and p.pending.uid then f.actualBars[2][3]={type=1,id=511}end
  end))
  assert(#f.api.requests==0 and f.done[1].status=='paused' and f.done[1].confirmed.skills)
 end,
 native_reset_in_either_result_order_never_echoes_coordinator_send=function()
  for _,result in ipairs({0,14})do for _,bridgeFirst in ipairs({true,false})do
   local f=setup();assert(f:Start(f:Plan({abilities=skillTarget})));f:Ready()
   local global=f.api.SKILLS_AND_ACTION_BAR_MANAGER
   global:RegisterCallback('SkillPointAllocationModeChanged',function(mode)if mode==0 then global.isDirty=true end end)
   if bridgeFirst then f.events:Emit('NativeSkillRespecResult',{result=result})end
   global:ResetInterface();global:OnUpdate()
   if not bridgeFirst then f.events:Emit('NativeSkillRespecResult',{result=result})end
   if result==0 then f.skillObjects[1].spec.morph=2 end
   f.clock:Advance(101);global:OnUpdate()
   assert(#f.requests.skills==1 and f.done[1].status==(result==0 and 'applied' or 'failed'))
   assert(next(f.events.listeners)==nil and next(f.clock.timers)==nil)
  end end
 end,
 journal_requesting_facts_precede_each_native_submission=function()
  local f=setup();local persisted={}
  assert(f:Start(f:Plan({abilities=skillTarget,attributes=attributeTarget}),function(p)
   if p.stage=='requesting'then
    persisted[p.phase]=p.pending
    assert(not p.pending.sent and p.pending.original and p.pending.target and p.operationId)
    assert(p.phase=='skills' and #f.requests.skills==0 or p.phase=='attributes' and #f.requests.attributes==0)
    p.pending.target={};p.confirmed.skills=false -- observers receive detached facts
   end
  end));f:Ready();f:ConfirmSkills();f:ConfirmAttributes()
  assert(persisted.skills and persisted.attributes and f.done[1].status=='applied')
 end,
 unknown_native_request_blocks_new_coordinator_start=function()
  local f=setup();local plan=f:Plan({attributes=attributeTarget});assert(f:Start(plan));f.runner:Stop()
  local ok,problem=f:Start(plan);assert(not ok and problem.code=='buildSubmissionUnresolved' and #f.requests.attributes==1)
 end,
 stale_budget_at_start_refuses_every_domain_before_native_entry=function()
  local f=setup();local plan=f:Plan({abilities=skillTarget,attributes=attributeTarget,equipment=f:AddGear()})
  f.skillPoints=0;assert(f:Start(plan))
  assert(#f.requests.skills==0 and #f.requests.attributes==0 and #f.api.requests==0 and not f.nativeEntryCalls)
  assert(f.done[1].status=='paused')
 end,
 gear_progress_observer_cannot_change_confirmed_attributes_and_still_send=function()
  local f=setup();assert(f:Start(f:Plan({attributes=attributeTarget,equipment=f:AddGear()}),function(p)
   if p.phase=='equipment' and p.stage=='requesting' and p.pending and p.pending.uid then f.actualAttributes[1]=1 end
  end));f:ConfirmAttributes()
  assert(#f.api.requests==0 and f.done[1].status=='paused' and f.done[1].problem.code=='confirmedBuildMismatch')
 end,
 result_with_no_actual_change_and_partial_attribute_update_times_out=function()
  local f=setup();assert(f:Start(f:Plan({attributes=attributeTarget})))
  f.events:Emit('NativeAttributeRespecResult',{result=0});f.actualAttributes={0,20,34};f.clock:Advance(15001)
  assert(f.done[1].status=='paused' and #f.requests.attributes==1 and f.done[1].pending.sent)
 end,
 actual_target_during_active_attribute_cast_waits_without_poisoning_lock=function()
  local f=setup();assert(f:Start(f:Plan({attributes=attributeTarget})))
  f.actualAttributes={0,0,64};f.attributeCast=5;f.events:Emit('NativeAttributeRespecResult',{result=0});f.clock:Advance(101)
  assert(f.runner:IsBusy() and f.attributes:GetSubmissionState().phase=='waiting' and #f.done==0)
  f.attributeCast=0;f.clock:Advance(101);assert(f.done[1].status=='applied' and #f.requests.attributes==1)
 end,
 synchronous_attribute_result_is_observed_after_one_send=function()
  local f=setup();local send=f.api.SendAttributePointAllocationRequest
  f.api.SendAttributePointAllocationRequest=function(...)
   send(...);f.actualAttributes={0,0,64};f.events:Emit('NativeAttributeRespecResult',{result=0})
  end
  assert(f:Start(f:Plan({attributes=attributeTarget})));f.clock:Advance(2)
  assert(#f.requests.attributes==1 and f.done[1].status=='applied' and not f.runner:IsBusy())
 end,
 entry_failure_and_combat_between_phases_never_start_next_domain=function()
  local f=setup();assert(f:Start(f:Plan({abilities=skillTarget})));f.clock:Advance(5001)
  assert(f.done[1].status=='failed' and #f.requests.skills==0 and not f.runner:IsBusy())
  f=setup();assert(f:Start(f:Plan({abilities=skillTarget,attributes=attributeTarget}),function(p)
   if p.phase=='skills' and p.stage=='confirmed'then f.api.combat=true end
  end));f:Ready();f:ConfirmSkills()
  assert(#f.requests.attributes==0 and f.done[1].status=='failed' and f.done[1].confirmed.skills)
 end,
 auxiliary_actual_barrier_prevents_attribute_send=function()
  local f=setup();f.actualBars[2][3]={type=1,id=511};f.api.ACTION_BAR_ASSIGNMENT_MANAGER:ResetPlayerHotbars()
  assert(f:Start(f:Plan({abilities=skillTarget,attributes=attributeTarget})));f:Ready();f:ConfirmSkills()
  assert(#f.requests.attributes==0 and f.runner:IsBusy())
  f.actualBars[2][3]={type=1,id=512};f.api.ACTION_BAR_ASSIGNMENT_MANAGER:ResetPlayerHotbars();f.clock:Advance(101)
  assert(#f.requests.attributes==1 and #f.requests.skills==1)
 end,
 absent_result_waiting_never_recaptures_unrelated_snapshot=function()
  local f=setup();local captures=0;local capture=f.Capture
  function f:Capture()captures=captures+1;return capture(self)end
  assert(f:Start(f:Plan({attributes=attributeTarget})));local before=captures
  f.clock:Advance(1000);assert(captures==before and f.runner:IsBusy())
  f.runner:Stop();assert(next(f.clock.timers)==nil)
 end,
 observer_item_movement_and_budget_change_refuse_before_send=function()
  local f=setup();assert(f:Start(f:Plan({equipment=f:AddGear()}),function(p)
   if p.stage=='requesting'then f.api.bags[BAG_BACKPACK][4]=f.api.bags[BAG_BACKPACK][3];f.api.bags[BAG_BACKPACK][3]=nil end
  end));assert(#f.api.requests==0 and f.done[1].status=='paused')
  f=setup();assert(f:Start(f:Plan({attributes=attributeTarget}),function(p)
   if p.stage=='requesting'then f.attributeUnspent=3 end
  end));assert(#f.requests.attributes==0 and f.done[1].status=='paused')
 end,
 synchronous_equipment_done_does_not_leave_phantom_operation=function()
  local f=setup();local gear=f:AddGear();local starts=0
  function f.gear:Start(plan,progress,done)
   starts=starts+1;f.api.bags[BAG_WORN][EQUIP_SLOT_HEAD]=f.api.bags[BAG_BACKPACK][3];f.api.bags[BAG_BACKPACK][3]=nil
   done({status='success',actual=plan.target});return 7
  end
  assert(f:Start(f:Plan({equipment=gear})));assert(starts==1 and f.done[1].status=='applied' and not f.runner:IsBusy())
  assert(next(f.clock.timers)==nil)
 end,
 sent_stop_retains_unknown_descriptor_and_removes_coordinator_listeners=function()
  local f=setup();assert(f:Start(f:Plan({attributes=attributeTarget})));f.runner:Stop('closed')
  assert(f.done[1].status=='paused' and f.done[1].pending.sent and f.done[1].pending.phase=='unknown')
  assert(next(f.events.listeners)==nil and next(f.clock.timers)==nil)
  f:ConfirmAttributes();assert(#f.requests.attributes==1 and #f.done==1)
 end,
 attributes_start_only_after_verified_skills=function()
  local f=setup();assert(f:Start(f:Plan({abilities=skillTarget,attributes=attributeTarget})))
  assert(#f.requests.skills==0 and #f.requests.attributes==0)
  f:Ready();assert(#f.requests.skills==1 and #f.requests.attributes==0)
  f.events:Emit('NativeSkillRespecResult',{result=0});f.clock:Advance(101);assert(#f.requests.attributes==0)
  f:ConfirmSkills();assert(#f.requests.attributes==1 and f.done[1]==nil)
  f:ConfirmAttributes();assert(f.done[1].status=='applied' and f.done[1].confirmed.skills and f.done[1].confirmed.attributes)
 end,
 gear_starts_only_after_verified_attributes=function()
  local f=setup();local gear=f:AddGear();assert(f:Start(f:Plan({attributes=attributeTarget,equipment=gear})))
  assert(#f.requests.attributes==1 and #f.api.requests==0)
  f.events:Emit('NativeAttributeRespecResult',{result=0});f.clock:Advance(101);assert(#f.api.requests==0)
  f:ConfirmAttributes();assert(#f.api.requests==1,f.done[1] and f.done[1].problem and (f.done[1].problem.code..':'..tostring(f.done[1].problem.details.error)) or 'gear not issued');f:ApplyGear();assert(f.done[1].status=='applied',tostring(f.done[1].status)..':'..tostring(f.done[1].problem and f.done[1].problem.code))
 end,
 noop_has_no_respec_and_no_phantom_busy=function()
  local f=setup();local s=f:Capture();assert(f:Start(f:Plan({abilities=s.abilities,attributes=s.attributes,equipment={}})))
  assert(#f.requests.skills==0 and #f.requests.attributes==0 and #f.api.requests==0 and not f.runner:IsBusy())
  assert(f.done[1].status=='applied' and next(f.clock.timers)==nil)
 end,
 sent_timeout_retains_pending_and_late_success_never_resends=function()
  local f=setup();assert(f:Start(f:Plan({abilities=skillTarget})));f:Ready();f.clock:Advance(15001)
  assert(f.done[1].status=='paused' and f.done[1].pending.sent and not f.runner:IsBusy())
  f:ConfirmSkills();assert(#f.requests.skills==1 and #f.done==1 and next(f.clock.timers)==nil)
 end,
 stop_unsent_entry_cancels_late_send=function()
  local f=setup();assert(f:Start(f:Plan({abilities=skillTarget})));f.runner:Stop('closed');f:Ready();f.clock:Advance(6000)
  assert(#f.requests.skills==0 and f.done[1].status=='paused' and next(f.clock.timers)==nil)
 end,
 attribute_refusal_after_skills_stops_before_gear=function()
  local f=setup();assert(f:Start(f:Plan({abilities=skillTarget,attributes=attributeTarget,equipment=f:AddGear()})));f:Ready();f:ConfirmSkills()
  f.events:Emit('NativeAttributeRespecResult',{result=14});f.clock:Advance(101)
  assert(f.done[1].status=='failed' and f.done[1].confirmed.skills and #f.api.requests==0)
  assert(f.attributes:GetSubmissionState().phase=='failed')
 end,
 requesting_observer_stop_or_error_never_sends=function()
  for _,throw in ipairs({false,true})do
   local f=setup();assert(f:Start(f:Plan({attributes=attributeTarget}),function(p)
    if p.stage=='requesting'then if throw then error('persist failure')else f.runner:Stop('closed')end end
   end))
   assert(#f.requests.attributes==0 and not f.runner:IsBusy() and #f.done==1)
  end
 end,
 deadline_starts_at_actual_send_not_entry_acceptance=function()
  local f=setup();assert(f:Start(f:Plan({abilities=skillTarget})));f.clock:Advance(4500);f:Ready();f.clock:Advance(11000)
  assert(f.runner:IsBusy() and #f.done==0);f.clock:Advance(4001);assert(f.done[1].status=='paused' and #f.requests.skills==1)
 end,
}
