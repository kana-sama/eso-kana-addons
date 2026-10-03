local Fake=dofile(ROOT..'/tests/support/fake_eso.lua')
local BuildFake=dofile(ROOT..'/tests/support/build_fixture.lua')
local AttributeFake=dofile(ROOT..'/tests/support/attribute_fixture.lua')
local function setup()
 local kw=Fake.Load({'Core.lua','SkillState.lua','AttributeAdapter.lua'});local f=AttributeFake.Attach(BuildFake.New())
 return kw,f,kw.AttributeAdapter.New(f.api,kw.Core.NewEvents())
end
return {
 cleanup_refreshes_native_spinner_limits_and_keybinds_after_leaving_full_mode=function()
  local _,f,a=setup();local stats=f.api.STATS
  local update=stats.UpdateSpendablePoints
  stats.UpdateSpendablePoints=function(self)update(self);self.displayedMode=self.mode end
  local updates=0;stats.keybindButtons={}
  f.api.KEYBIND_STRIP={UpdateKeybindButtonGroup=function(_,buttons)assert(buttons==stats.keybindButtons and stats.mode==0);updates=updates+1 end}
  assert(a:MountDraft({health=0,magicka=0,stamina=64}));assert(stats.displayedMode==1)
  assert(a:DiscardDraft());assert(stats.displayedMode==0,'spinners still display the full draft mode')
  assert(updates==1 and f.attributeSends==0)
 end,
 invalid_native_result_never_releases_attribute_submission=function()
  for _,result in ipairs({math.huge,-math.huge,0/0,0.5})do
   local _,f,a=setup();local current,budget=a:Capture()
   local request=assert(a:Prepare(current,{health=0,magicka=0,stamina=64},budget));assert(a:Submit(request))
   local token=a:GetSubmissionState().token
   assert(not a:ResolveSubmission(result,token),'invalid result must not confirm native refusal')
   local state=a:GetSubmissionState();assert(state.phase=='unknown' and state.token==token and state.result==nil)
   assert(not a:Submit(a:Prepare(current,{health=1,magicka=19,stamina=34},budget)) and f.attributeSends==1)
   assert(a:ResolveSubmission(14,token) and a:GetSubmissionState().phase=='failed')
  end
 end,
 absolute_targets_produce_signed_deltas=function()
  local _,f,a=setup();local current,budget=a:Capture();assert(budget==66 and current.unspentAtCapture==2)
  local q=assert(a:Prepare(current,{health=0,magicka=0,stamina=64},budget));assert(q.deltas.health==-10 and q.deltas.magicka==-20 and q.deltas.stamina==30 and q.remaining==2)
  assert(#f.requests.attributes==0)
 end,
 zero_triple_returns_points_and_invalid_targets_refused=function()
  local _,_,a=setup();local current,budget=a:Capture()
  assert(a:Prepare(current,{health=0,magicka=0,stamina=0},budget).remaining==66)
  assert(not a:Prepare(current,{health=0,magicka=0,stamina=65},64))
  for _,target in ipairs({{health=-1,magicka=0,stamina=0},{health=0.5,magicka=0,stamina=0},{health=0,magicka=0,stamina=67},{health=0,stamina=0}})do assert(not a:Prepare(current,target,budget))end
 end,
 stats_mount_refunds_before_increases_and_never_purchases=function()
  local _,f,a=setup();assert(a:MountDraft({health=0,magicka=0,stamina=64}));local draft=a:CaptureDraft()
  assert(draft.stamina==64 and draft.health==0 and f.attributeSends==0)
  local setters={};for _,row in ipairs(f.attributeLog)do if row[1]=='set'then setters[#setters+1]=row[2]end end
  assert(setters[1]==1 and setters[2]==2 and setters[3]==3)
  assert(a:DiscardDraft());assert(f.api.STATS.mode==0 and f.api.STATS.payment==9 and f.attributeSends==0)
 end,
 draft_native_changes_observed_and_unmount_discards_current_only=function()
  local _,f,a=setup();local changed=0;assert(a:MountDraft({health=10,magicka=20,stamina=34},function()changed=changed+1 end))
  f.api.STATS.attributeControls[1].pointLimitedSpinner.pointsSpinner:Change(11)
  assert(a:CaptureDraft().health==11 and changed==1 and a:Capture().health==10)
  assert(a:UnmountDraft());assert(f.api.STATS.attributeControls[1].pointLimitedSpinner:GetAllocatedPoints()==0 and f.attributeSends==0);assert(not next(f.api.STATS.attributeControls[1].pointLimitedSpinner.pointsSpinner.callbacks))
 end,
 foreign_offsetting_pending_and_uninitialized_controls_refuse_before_mode=function()
  local _,f,a=setup();f.api.STATS.attributeControls[1].pointLimitedSpinner.addedPoints=1;f.api.STATS.attributeControls[2].pointLimitedSpinner.addedPoints=-1
  assert(not a:MountDraft({health=10,magicka=20,stamina=34}));assert(f.api.STATS.mode==0 and #f.attributeLog==0)
  f.api.STATS.attributeControls=nil;assert(not a:MountDraft({health=10,magicka=20,stamina=34}));assert(f.attributeSends==0)
 end,
 submit_revalidates_actual_budget_and_sends_direct_once=function()
  local _,f,a=setup();local current,budget=a:Capture();local q=assert(a:Prepare(current,{health=0,magicka=0,stamina=64},budget))
  assert(a:Submit(q));assert(f.attributeSends==1 and f.requests.attributes[1].payload.health==-10 and f.requests.attributes[1].payload.stamina==30)
  assert(not a:Submit(q));assert(f.attributeSends==1 and not a:Matches(q.target))
  f.actualAttributes={0,0,64};assert(a:Matches(q.target))
 end,
 stale_submit_and_foreign_pending_never_send=function()
  local _,f,a=setup();local current,budget=a:Capture();local q=a:Prepare(current,{health=0,magicka=0,stamina=64},budget)
  f.actualAttributes[1]=11;assert(not a:Submit(q));assert(f.attributeSends==0)
 end,
 new_level_points_remain_free_and_skill_budget_is_irrelevant=function()
  local _,f,a=setup();f.attributeUnspent=5;f.api.GetAvailableSkillPoints=function()error('wrong budget')end
  local current,budget=a:Capture();assert(budget==69);assert(a:Prepare(current,{health=0,magicka=0,stamina=64,unspentAtCapture=99},budget).remaining==5)
 end,
 owned_submission_accepts_full_current_draft_without_reverse_on_cancel=function()
  local _,f,a=setup();assert(a:MountDraft({health=0,magicka=0,stamina=64}));local current,budget=a:Capture();local q=a:Prepare(current,a:CaptureDraft(),budget)
  assert(a:Submit(q));assert(f.attributeSends==1);assert(not a:DiscardDraft());assert(f.attributeSends==1)
 end,
 native_reset_then_discard_and_remount_never_sends=function()
  local _,f,a=setup();assert(a:MountDraft({health=0,magicka=0,stamina=64}));f:ResetAttributesNative()
  assert(a:DiscardDraft());assert(f.attributeSends==0);assert(a:MountDraft({health=0,magicka=0,stamina=64}));assert(a:CaptureDraft().stamina==64)
 end,
 userdata_managers_spinners_and_zero_enums_work=function()
  local _,f,a=setup()
  local function proxy(value)
   local handle=assert(io.tmpfile());handle:close()
   debug.setmetatable(handle,{__index=value,__newindex=function(_,key,v)value[key]=v end})
   return handle
  end
  for _,control in ipairs(f.api.STATS.attributeControls)do control.pointLimitedSpinner=proxy(control.pointLimitedSpinner)end
  f.api.STATS=proxy(f.api.STATS)
  assert(a:MountDraft({health=0,magicka=0,stamina=64}));assert(a:DiscardDraft());assert(f.api.STATS.mode==0)
 end,
 missing_methods_fail_preflight_and_cleanup_failure_is_honest=function()
  local _,f,a=setup();f.api.STATS.attributeControls[2].pointLimitedSpinner.ResetAddedPoints=nil
  assert(not a:MountDraft({health=0,magicka=0,stamina=64}));assert(f.api.STATS.mode==0 and #f.attributeLog==0)
  local _,g,b=setup();assert(b:MountDraft({health=0,magicka=0,stamina=64}))
  g.api.STATS.attributeControls[2].pointLimitedSpinner.ResetAddedPoints=function()error('reset failed')end
  local ok,err=b:DiscardDraft();assert(not ok and err.details.reason:find('reset failed',1,true));assert(g.api.STATS.mode==1 and g.attributeSends==0)
 end,
 submit_rejects_offsetting_foreign_edits_cast_and_lower_budget=function()
  local _,f,a=setup();local current,budget=a:Capture();local q=a:Prepare(current,{health=0,magicka=0,stamina=66},budget)
  f.api.STATS.attributeControls[1].pointLimitedSpinner.addedPoints=1;f.api.STATS.attributeControls[2].pointLimitedSpinner.addedPoints=-1
  assert(not a:Submit(q));f.api.STATS.attributeControls[1].pointLimitedSpinner.addedPoints=0;f.api.STATS.attributeControls[2].pointLimitedSpinner.addedPoints=0
  f.attributeCast=10;assert(not a:Submit(q));f.attributeCast=0;f.attributeUnspent=0;assert(not a:Submit(q));assert(f.attributeSends==0)
 end,
 foreign_skills_and_unknown_initialized_stats_refuse_before_send=function()
  local _,f,a=setup();f.api.SKILLS_AND_ACTION_BAR_MANAGER={HasAnyPendingChanges=function()return true end}
  assert(not a:MountDraft({health=0,magicka=0,stamina=64}));assert(f.api.STATS.mode==0)
  f.api.SKILLS_AND_ACTION_BAR_MANAGER=nil;local current,budget=a:Capture();local q=a:Prepare(current,{health=0,magicka=0,stamina=64},budget)
  f.api.STATS.attributeControls=nil;assert(not a:Submit(q));assert(f.attributeSends==0)
 end,

 lazy_stats_direct_submit_does_not_initialize_or_enter_native_scene=function()
  local _,f,a=setup();f.api.STATS={OnShowing=function()error('must not initialize')end}
  f.api.StartAttributeRespecFromUI=function()error('must not enter scene')end
  local current,budget=a:Capture();assert(a:Submit(a:Prepare(current,{health=0,magicka=0,stamina=64},budget)));assert(f.attributeSends==1)
 end,
 gamepad_pending_unknown_and_lazy_state_are_distinguished=function()
  local _,f,a=setup();f.api.GAMEPAD_STATS={attributeData={{addedPoints=1},{addedPoints=-1},{addedPoints=0}}}
  assert(not a:MountDraft({health=0,magicka=0,stamina=64}));assert(f.api.STATS.mode==0)
  f.api.GAMEPAD_STATS={};assert(not a:MountDraft({health=0,magicka=0,stamina=64}))
  f.api.GAMEPAD_STATS={PerformDeferredInitializationRoot=function()error('must not initialize')end}
  assert(a:MountDraft({health=0,magicka=0,stamina=64}))
 end,

 owned_request_rejects_mode_conflict_and_other_native_cast=function()
  local _,f,a=setup();assert(a:MountDraft({health=0,magicka=0,stamina=64}));local current,budget=a:Capture();local q=a:Prepare(current,a:CaptureDraft(),budget)
  f.api.STATS.mode=0;assert(not a:Submit(q));f.api.STATS.mode=1
  f.api.GetSkillRespecCastTimeRemainingMs=function()return 1 end;assert(not a:Submit(q));assert(f.attributeSends==0)
 end,

 trusted_result_and_actual_required_before_next_request=function()
  local _,f,a=setup();local current,budget=a:Capture();local q=a:Prepare(current,{health=0,magicka=0,stamina=64},budget);assert(a:Submit(q))
  local state=a:GetSubmissionState();assert(state.sent and state.phase=='waiting' and state.token)
  assert(not a:ResolveSubmission(0,state.token));assert(not a:Submit(q) and f.attributeSends==1)
  f.actualAttributes={0,0,64};f.attributeCast=1;assert(not a:ResolveSubmission(0,state.token));f.attributeCast=0
  assert(not a:ResolveSubmission(0,state.token+1));assert(a:ResolveSubmission(0,state.token));assert(a:GetSubmissionState().phase=='confirmed')
  current,budget=a:Capture();assert(a:Submit(a:Prepare(current,{health=1,magicka=0,stamina=63},budget)));assert(f.attributeSends==2)
 end,
 failed_submission_actual_original_unlocks_but_does_not_discard_editor=function()
  local _,f,a=setup();assert(a:MountDraft({health=0,magicka=0,stamina=64}));local current,budget=a:Capture();assert(a:Submit(a:Prepare(current,a:CaptureDraft(),budget)))
  local token=a:GetSubmissionState().token;assert(a:ResolveSubmission(14,token));assert(a:GetSubmissionState().phase=='failed' and f.api.STATS.mode==1)
  assert(a:GetSubmissionState().resolved,'a confirmed server refusal is a known result')
  assert(a:DiscardDraft());assert(f.attributeSends==1 and f.api.STATS.mode==0)
  current,budget=a:Capture();assert(a:Submit(a:Prepare(current,{health=11,magicka=19,stamina=34},budget)));assert(f.attributeSends==2)
 end,
 cancel_sent_partial_or_missing_result_retains_unknown_and_block=function()
  local _,f,a=setup();local current,budget=a:Capture();assert(a:Submit(a:Prepare(current,{health=0,magicka=0,stamina=64},budget)))
  local token=a:GetSubmissionState().token;assert(not a:CancelSubmission('timeout'));assert(a:GetSubmissionState().phase=='unknown')
  assert(not a:ResolveSubmission(nil,token));f.actualAttributes={0,20,34};assert(not a:ResolveSubmission(14,token))
  assert(not a:Submit(a:Prepare({health=0,magicka=20,stamina=34},{health=1,magicka=19,stamina=34},66)));assert(f.attributeSends==1)
 end,
 resolved_owned_success_can_cleanup_without_paid_reverse=function()
  local _,f,a=setup();assert(a:MountDraft({health=0,magicka=0,stamina=64}));local current,budget=a:Capture();assert(a:Submit(a:Prepare(current,a:CaptureDraft(),budget)))
  f.actualAttributes={0,0,64};assert(a:ResolveSubmission(0,a:GetSubmissionState().token));assert(a:UnmountDraft());assert(f.actualAttributes[3]==64 and f.attributeSends==1)
 end,
 submission_descriptor_is_detached_and_thrown_send_remains_uncertain=function()
  local _,f,a=setup();local current,budget=a:Capture();local q=a:Prepare(current,{health=0,magicka=0,stamina=64},budget)
  f.api.SendAttributePointAllocationRequest=function()error('send crashed')end;assert(not a:Submit(q));q.target.stamina=1
  local state=a:GetSubmissionState();assert(state.sent and state.phase=='unknown' and state.target.stamina==64)
  state.target.stamina=2;assert(a:GetSubmissionState().target.stamina==64);assert(not a:ResolveSubmission(0,state.token))
 end,

}
