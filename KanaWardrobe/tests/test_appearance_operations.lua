local setup=dofile(ROOT..'/tests/support/operation_fixture.lua')
local function create(categories)
 local f=setup();local k=f.k;dofile(ROOT..'/AppearanceAdapter.lua')
 f.appearanceState={[1]=101,[2]=201};f.appearanceCalls={}
 f.api.COLLECTIBLE_CATEGORY_TYPE_COSTUME=1;f.api.COLLECTIBLE_CATEGORY_TYPE_HAT=2
 if categories then
  for i=3,categories do f.api['COLLECTIBLE_CATEGORY_TYPE_'..k.AppearanceAdapter.Order[i]]=i;f.appearanceState[i]=i*100+1 end
 end
 f.api.GetActiveCollectibleByType=function(c)return f.appearanceState[c]end
 f.api.GetCollectibleCategoryType=function(id)return math.floor(id/100) end
 f.api.GetCollectibleName=function(id)return 'Collectible '..id end
 f.api.GetCollectibleIcon=function(id)return 'icon'..id end
 f.api.IsCollectibleUnlocked=function(id)return id~=199 end
 f.api.IsCollectibleUsable=function()return true end
 f.api.UseCollectible=function(id)
  f.appearanceCalls[#f.appearanceCalls+1]=id
  if not f.stall then local c=f.api.GetCollectibleCategoryType(id);f.appearanceState[c]=f.appearanceState[c]==id and 0 or id end
 end
 f.services.appearance=k.AppearanceAdapter.New(f.api)
 local capture=f.services.capture
 f.services.capture=function(scope)
  local s,c=capture(scope)
  if scope==nil or scope=='appearance' or type(scope)=='table' and scope.appearance then s.appearance=f.services.appearance:Capture()end
  return s,c
 end
 f.services.buildPlanner=k.BuildPlanner.New(f.services)
 f.services.operations=true;f.services.checkDrafts=function()return true end
 f.saved=f.repo.character
 function f:Reload()
  self.session=k.Session.New(self.repo,self.inventory,k.EquipmentPlan,nil,self.protection,self.saved,{},nil,self.services)
  self.x=self.session.operations
 end
 f:Reload()
 function f:Tick(n)for _=1,n or 15 do self:Advance(2)end end
 function f:Preset(value)return assert(self.repo:PatchComponents(nil,{appearance={op='replace',value=value}},'Appearance'))end
 return f
end
local function sharedCooldown(f,duration,initial)
 local untilTime=f.clock:NowMs()+(initial or 0)
 f.appearanceTimes={};f.cooldownReads={}
 f.api.GetCollectibleCooldownAndDuration=function(id)
  f.cooldownReads[#f.cooldownReads+1]=id
  return math.max(0,untilTime-f.clock:NowMs()),duration
 end
 local use=f.api.UseCollectible
 f.api.UseCollectible=function(id)
  assert(f.clock:NowMs()>=untilTime,'collectible sent during shared cooldown')
  f.appearanceTimes[#f.appearanceTimes+1]=f.clock:NowMs();untilTime=f.clock:NowMs()+duration;use(id)
 end
end
-- Mirrors the recorded result=9 failure: the item's local cooldown can be
-- zero and IsCollectibleUsable true while the server's shared cooldown rejects.
local function serverCooldown(f,duration,initial)
 local untilTime=f.clock:NowMs()+(initial or 0);local use=f.api.UseCollectible
 f.api.COLLECTIBLE_USAGE_BLOCK_REASON_ON_COOLDOWN=9;f.api.COLLECTIBLE_USAGE_BLOCK_REASON_NOT_BLOCKED=0
 f.api.GetCollectibleCooldownAndDuration=function()return 0,0 end
 f.api.GetCollectibleBlockReason=function()return 0 end
 f.serverCalls={}
 f.api.UseCollectible=function(id)
  local now=f.clock:NowMs();f.serverCalls[#f.serverCalls+1]={id=id,time=now}
  if now<untilTime then
   f.clock:Schedule(1,function()f.events:Emit('AppearanceUseResult',{result=9,isAttemptingActivation=f.appearanceState[math.floor(id/100)]~=id})end)
  else untilTime=now+duration;use(id)end
 end
end
return {
 appearance_server_shared_cooldown_shows_retry_timer_and_recovers_automatically=function()
  local f=create();serverCooldown(f,3200);local p=f:Preset({[1]=0,[2]=0})
  assert(f.session:Apply(p.id));f:Tick()
  local op=f.x:GetView();local pending=op.steps[op.index].pending
  assert(op.status=='running' and pending.phase=='cooldown' and pending.countdownKind=='retry' and pending.remainingMs>0,'server rejection must enter a timed retry')
  dofile(ROOT..'/Dialogs.lua');dofile(ROOT..'/OperationWindow.lua')
  assert(f.k.OperationWindow.StepBody(op.steps[op.index]):find('retry',1,true),'timer must describe a retry, not claim an exact server cooldown')
  for _=1,90 do f:Advance(100)end;f:Tick()
  assert(not f.x:GetView() and f.appearanceState[1]==0 and f.appearanceState[2]==0)
  assert(#f.appearanceCalls==2,'completed toggles must never be sent again')
  assert(#f.serverCalls<=6,'cooldown retries must be paced')
 end,
 appearance_server_cooldown_retry_can_be_paused_without_sending=function()
  local f=create();serverCooldown(f,3200,1800);local p=f:Preset({[1]=0})
  assert(f.session:Apply(p.id));f:Tick();assert(f.x:GetView().steps[2].pending.phase=='cooldown')
  local calls=#f.serverCalls;assert(f.session:Pause());f:Advance(100)
  assert(f.x:GetView().status=='paused');f:Advance(3000);assert(#f.serverCalls==calls)
  assert(f.session:Resume());f:Tick();assert(not f.x:GetView() and f.appearanceState[1]==0)
 end,
 appearance_block_reason_is_checked_even_when_collectible_is_usable=function()
  local f=create();local p=f:Preset({[1]=0})
  f.api.COLLECTIBLE_USAGE_BLOCK_REASON_ON_COOLDOWN=9;f.api.COLLECTIBLE_USAGE_BLOCK_REASON_NOT_BLOCKED=0
  f.api.GetCollectibleCooldownAndDuration=function()return 0,0 end
  f.api.GetCollectibleBlockReason=function()return f.clock:NowMs()<1600 and 9 or 0 end
  assert(f.session:Apply(p.id));f:Tick()
  assert(f.x:GetView() and f.x:GetView().status=='running' and #f.appearanceCalls==0,'usable does not mean unblocked')
  f:Advance(1700);f:Tick();assert(not f.x:GetView() and f.appearanceState[1]==0)
 end,
 appearance_unknown_result_never_triggers_automatic_toggle_retry=function()
  local f=create();local p=f:Preset({[1]=0});f.stall=true
  assert(f.session:Apply(p.id));f:Tick();f:Advance(5100)
  assert(f.x:GetView().status=='failed' and #f.appearanceCalls==1)
 end,
 appearance_server_cooldown_countdown_updates_and_refusals_are_saved=function()
  local f=create();serverCooldown(f,3200,10000);local p=f:Preset({[1]=0})
  assert(f.session:Apply(p.id));f:Tick()
  f:Advance(1100);f:Tick()
  local op=f.x:GetView();local step=op.steps[op.index]
  assert(step.pending.countdownKind=='retry' and math.ceil(step.pending.remainingMs/1000)==2)
  f:Advance(1100)
  step=f.x:GetView().steps[op.index]
  assert(math.ceil(step.pending.remainingMs/1000)==1,'visible countdown must decrease while waiting')
  local saved=f.x.operation.steps[op.index].attempts[1].pending
  assert(#saved.refusals==2 and saved.refusals[2].result==9 and saved.refusals[2].useId==101)
  assert(#f.serverCalls==2)
 end,
 appearance_server_cooldown_has_a_bounded_retry_budget=function()
  local f=create();serverCooldown(f,3200,100000);local p=f:Preset({[1]=0})
  assert(f.session:Apply(p.id));f:Tick()
  for _=1,380 do f:Advance(100)end
  local op=f.x:GetView();local step=op.steps[op.index]
  assert(op.status=='failed' and step.problem.code=='appearanceCooldownTimeout')
  assert(#f.serverCalls<=11 and #f.appearanceCalls==0)
  local calls=#f.serverCalls;f:Advance(10000);assert(#f.serverCalls==calls)
 end,
 appearance_target_reached_during_server_retry_is_not_toggled_again=function()
  local f=create();serverCooldown(f,3200,10000);local p=f:Preset({[1]=0})
  assert(f.session:Apply(p.id));f:Tick()
  f.appearanceState[1]=0;f.events:Emit('AppearanceChanged',{});f:Tick()
  assert(not f.x:GetView() and #f.serverCalls==1)
  f:Advance(10000);assert(#f.serverCalls==1)
 end,
 appearance_synchronous_server_rejection_is_not_lost=function()
  local f=create();local p=f:Preset({[1]=0})
  f.api.COLLECTIBLE_USAGE_BLOCK_REASON_ON_COOLDOWN=9
  f.api.UseCollectible=function()f.events:Emit('AppearanceUseResult',{result=9,isAttemptingActivation=false})end
  assert(f.session:Apply(p.id));f:Tick()
  local step=f.x:GetView().steps[2];assert(step.pending.phase=='cooldown' and #step.pending.refusals==1)
 end,
 appearance_other_server_refusal_does_not_retry_and_keeps_its_reason=function()
  local f=create();local p=f:Preset({[1]=0});f.stall=true
  f.api.COLLECTIBLE_USAGE_BLOCK_REASON_ON_COOLDOWN=9
  f.api.GetString=function(_,result)return 'Reason '..result end
  assert(f.session:Apply(p.id));f:Tick()
  f.events:Emit('AppearanceUseResult',{result=12,isAttemptingActivation=false});f:Advance(5100)
  local op=f.x:GetView();local problem=op.steps[op.index].problem
  assert(op.status=='failed' and problem.details.reasonText=='Reason 12' and #f.appearanceCalls==1)
 end,
 appearance_other_block_reason_prevents_a_usable_collectible_from_being_sent=function()
  local f=create();local p=f:Preset({[1]=0})
  f.api.COLLECTIBLE_USAGE_BLOCK_REASON_NOT_BLOCKED=0
  f.api.COLLECTIBLE_USAGE_BLOCK_REASON_ON_COOLDOWN=9
  f.api.GetCollectibleBlockReason=function()return 12 end
  assert(f.session:Apply(p.id));f:Tick()
  local op=f.x:GetView();assert(op.status=='failed' and op.steps[2].problem.code=='appearanceBlocked' and #f.appearanceCalls==0)
 end,
 appearance_steps_surround_whole_gear_attributes_and_skill_segments=function()
  local f=create(4);local ring=f:AddItem('ring',EQUIP_SLOT_RING1,true)
  f:AddItem('oldMythic',EQUIP_SLOT_HEAD,true,EQUIP_TYPE_HEAD);f.api.descriptions.oldMythic.quality=99
  local new=f:AddItem('new',2,false,EQUIP_TYPE_NECK);f.api.descriptions.new.quality=99
  local p=assert(f:Plan({appearance={[1]=102,[2]=202,[3]=302,[4]=402},
   equipment={[EQUIP_SLOT_RING2]=ring,[EQUIP_SLOT_NECK]=new},attributes={health=0,magicka=0,stamina=64},
   abilities={skills={['10:active:51']={kind='active',purchased=true,morph=2}},bars={front={[1]={kind='skill',skillKey='10:active:51',expectedMorph=2}}}}}))
  local kinds={};local seen={}
  for _,s in ipairs(p.steps)do kinds[#kinds+1]=s.kind;assert(not seen[s.id],'duplicate step id');seen[s.id]=true end
  assert(table.concat(kinds,',')=='appearance,unequip,equip,unequip,equip,appearance,attributes,appearance,skills,bar,appearance,verify',table.concat(kinds,','))
  assert(#f.appearanceCalls==0,'planning changed appearance')
 end,
 appearance_two_changes_use_start_and_end_and_omit_unchanged_categories=function()
  local f=create(3);local wanted={appearance={[1]=102,[2]=201,[3]=302},attributes={health=0,magicka=0,stamina=64}}
  local p=assert(f:Plan(wanted))
  assert(#p.steps==4 and p.steps[1].category==1 and p.steps[2].kind=='attributes' and p.steps[3].category==3 and p.steps[4].kind=='verify')
 end,
 appearance_shared_cooldown_waits_and_then_completes_without_rejection=function()
  local f=create();sharedCooldown(f,2400);local p=f:Preset({[1]=102,[2]=0})
  assert(f.session:Apply(p.id));f:Tick()
  local op=f.x:GetView();assert(op.status=='running' and op.steps[op.index].pending.phase=='cooldown')
  assert(#f.appearanceCalls==1 and f.appearanceState[2]==201)
  for _=1,30 do f:Advance(100)end;f:Tick()
  assert(not f.x:GetView() and f.appearanceState[1]==102 and f.appearanceState[2]==0)
  assert(#f.appearanceCalls==2 and f.appearanceTimes[2]-f.appearanceTimes[1]>=2400)
  assert(f.cooldownReads[#f.cooldownReads]==201,'clearing must query the currently active collectible')
 end,
 appearance_initial_cooldown_is_waited_and_pause_prevents_unsent_action=function()
  local f=create();sharedCooldown(f,2400,1800);local p=f:Preset({[1]=102})
  assert(f.session:Apply(p.id));f:Tick();assert(f.x:GetView().status=='running' and #f.appearanceCalls==0)
  assert(f.session:Pause());f:Advance(100)
  assert(f.x:GetView().status=='paused' and f.x:GetView().steps[f.x:GetView().index].status=='pending')
  f:Advance(2000);assert(#f.appearanceCalls==0)
  assert(f.session:Resume());f:Tick()
  assert(not f.x:GetView() and f.appearanceState[1]==102 and #f.appearanceCalls==1)
 end,
 appearance_completed_target_is_not_delayed_by_other_collectible_cooldown=function()
  local f=create();sharedCooldown(f,2400,9000);local p=f:Preset({[1]=101})
  assert(f.session:Apply(p.id));f:Tick()
  assert(not f.x:GetView() and #f.appearanceCalls==0)
 end,
 appearance_long_cooldown_does_not_consume_the_server_response_timeout=function()
  local f=create();sharedCooldown(f,9000,8000);local p=f:Preset({[1]=102})
  assert(f.session:Apply(p.id));f:Tick();f:Advance(5100)
  assert(f.x:GetView().status=='running' and #f.appearanceCalls==0)
  f:Advance(3100);f:Tick()
  assert(not f.x:GetView() and f.appearanceState[1]==102 and #f.appearanceCalls==1)
 end,
 appearance_cooldown_block_reason_without_timer_recovers_without_sending_early=function()
  local f=create();local p=f:Preset({[1]=102})
  f.api.COLLECTIBLE_USAGE_BLOCK_REASON_ON_COOLDOWN=8
  f.api.IsCollectibleUsable=function()return f.clock:NowMs()>=1600 end
  f.api.GetCollectibleBlockReason=function()return f.clock:NowMs()<1600 and 8 or 0 end
  assert(f.session:Apply(p.id));f:Tick()
  assert(f.x:GetView().status=='running' and #f.appearanceCalls==0)
  f:Advance(1700);f:Tick()
  assert(not f.x:GetView() and f.appearanceState[1]==102 and #f.appearanceCalls==1)
 end,
 appearance_stuck_cooldown_has_bounded_wait_and_diagnostic_remaining_time=function()
  local f=create();local p=f:Preset({[1]=102})
  f.api.GetCollectibleCooldownAndDuration=function()return 2000,2000 end
  assert(f.session:Apply(p.id));f:Tick();f:Advance(7100)
  local op=f.x:GetView();local step=op.steps[op.index]
  assert(op.status=='failed' and step.problem.code=='appearanceCooldownTimeout' and step.problem.details.remainingMs==2000)
  assert(#f.appearanceCalls==0)
  f.api.GetCollectibleCooldownAndDuration=function()return 0,2000 end
  assert(f.session:Resume());f:Tick();assert(not f.x:GetView() and f.appearanceState[1]==102)
 end,
 appearance_excess_changes_keep_each_build_segment_contiguous=function()
  local f=create(7);local appearance={};for i=1,7 do appearance[i]=i*100+2 end
  local p=assert(f:Plan({appearance=appearance,attributes={health=0,magicka=0,stamina=64},
   abilities={skills={['10:active:51']={kind='active',purchased=true,morph=2}},bars={front={[1]={kind='skill',skillKey='10:active:51',expectedMorph=2}}}}}))
  local kinds={};local categories={}
  for _,step in ipairs(p.steps)do kinds[#kinds+1]=step.kind;if step.kind=='appearance'then categories[#categories+1]=step.category end end
  assert(table.concat(kinds,',')=='appearance,attributes,appearance,appearance,appearance,appearance,appearance,skills,bar,appearance,verify')
  assert(table.concat(categories,',')=='1,2,3,4,5,6,7')
 end,
 appearance_apply_changes_only_selected_categories=function()
  local f=create();local p=f:Preset({[1]=102})
  f.skills.Catalogue=function()error('appearance must not scan skills')end
  f.attributes.Capture=function()error('appearance must not capture attributes')end
  assert(f.session:Apply(p.id));f:Tick()
  local op=f.x:GetView();assert(not op,op and op.steps[op.index].problem and (op.steps[op.index].problem.code.." "..tostring(op.steps[op.index].problem.details and op.steps[op.index].problem.details.error)))
  assert(f.appearanceState[1]==102 and f.appearanceState[2]==201 and #f.appearanceCalls==1)
  assert(#f.api.requests==0)
 end,
 appearance_edit_save_cancel_and_apply_have_equipment_semantics=function()
  for _,finish in ipairs({'Save','Cancel','SaveAndApply'})do
   local f=create();local p=f:Preset({[1]=102})
   assert(f.session:BeginEdit(p.id,false,'collectionsBook'));f:Tick()
   assert(f.session:IsEditorActive() and f.appearanceState[1]==102)
   assert(f.session:GetSelected('appearance',1) and not f.session:GetSelected('appearance',2))
   f.appearanceState[1]=103;f.appearanceState[2]=0
   assert(f.session:SetSelected('appearance',2,true))
   assert(f.session[finish](f.session));f:Tick()
   local v=f.x:GetView();assert(not v,v and v.steps[v.index].problem.code)
   assert(f.session:GetView().state=='idle')
   if finish=='SaveAndApply'then assert(f.appearanceState[1]==103 and f.appearanceState[2]==0)
   else assert(f.appearanceState[1]==101 and f.appearanceState[2]==201)end
   local saved=f.repo:Get(p.id).appearance
   if finish=='Cancel'then assert(saved[1]==102 and saved[2]==nil)
   else assert(saved[1]==103 and saved[2]==0)end
  end
 end,
 appearance_reload_restores_original_after_continue=function()
  local f=create();local p=f:Preset({[1]=102})
  assert(f.session:BeginEdit(p.id,false,'collectionsBook'));f:Tick();assert(f.appearanceState[1]==102)
  f.appearanceState[2]=0;f:Reload()
  assert(f.x:GetView().status=='paused');assert(f.appearanceState[1]==102)
  assert(f.session:Resume());f:Tick()
  assert(not f.x:GetView() and f.appearanceState[1]==101 and f.appearanceState[2]==201)
 end,
 appearance_retry_after_late_success_does_not_send_toggle_again=function()
  local f=create();local p=f:Preset({[1]=102});f.stall=true
  assert(f.session:Apply(p.id));f:Tick();f:Advance(5100)
  local op=f.x:GetView();assert(op.status=='failed' and op.steps[op.index].problem.code=='appearanceUnconfirmed',op.status..' '..tostring(op.steps[op.index].problem and op.steps[op.index].problem.code))
  assert(#f.appearanceCalls==1);f.appearanceState[1]=102
  f.api.GetCollectibleCooldownAndDuration=function()return 9000,9000 end
  assert(f.session:Resume());f:Tick()
  assert(not f.x:GetView() and #f.appearanceCalls==1)
 end,
 appearance_unavailable_item_fails_diff_without_changing_character=function()
  local f=create();local p=f:Preset({[1]=199,[2]=0})
  assert(f.session:Apply(p.id));f:Tick()
  local op=f.x:GetView();assert(op.index==1 and op.steps[1].problem.code=='appearanceLocked')
  assert(#f.appearanceCalls==0 and f.appearanceState[2]==201)
 end,
 appearance_quicksave_includes_empty_categories=function()
  local f=create();f.appearanceState[2]=0
  assert(f.session:QuickSave());local p=f.repo:Get(f.k.Presets.QUICK_ID)
  assert(p.appearance[1]==101 and p.appearance[2]==0)
 end,
}
