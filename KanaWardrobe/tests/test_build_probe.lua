local Fake=dofile(ROOT.."/tests/support/fake_eso.lua")
local function setup(storage)
    local k=Fake.Load({"Core.lua","BuildProbe.lua"})
    local a={ATTRIBUTE_HEALTH=1,ATTRIBUTE_MAGICKA=2,ATTRIBUTE_STAMINA=3,HOTBAR_CATEGORY_PRIMARY=0,HOTBAR_CATEGORY_BACKUP=1,ACTION_TYPE_ABILITY=1,MORPH_SLOT_BASE=0,SKILL_POINT_ALLOCATION_MODE_FULL=2,ATTRIBUTE_POINT_ALLOCATION_MODE_FULL=7,ATTRIBUTE_POINT_ALLOCATION_MODE_PURCHASE_ONLY=0,RESPEC_PAYMENT_TYPE_GOLD=0,RESPEC_RESULT_SUCCESS=0,EVENT_SKILL_RESPEC_RESULT=1,EVENT_ATTRIBUTE_RESPEC_RESULT=2,spent={12,22,30},slots={},sent={},callbacks={},timers={},morph=1}
    a.GetAttributeSpentPoints=function(i)return a.spent[i]end
    a.now=0;a.GetFrameTimeMilliseconds=function()return a.now end
    a.GetAPIVersion=function()return 101050 end
    a.GetSkillRespecCastTimeRemainingMs=function()return 0 end
    a.GetAttributeRespecCastTimeRemainingMs=function()return 0 end
    a.IsUnitInCombat=function()return false end;a.IsUnitDead=function()return false end
    a.scene="inventory";a.SCENE_MANAGER={GetCurrentSceneName=function()return a.scene end}
    a.EVENT_MANAGER={RegisterForEvent=function(_,_,event,fn)a.callbacks[event]=fn end,RegisterForUpdate=function(_,name,_,fn)a.timers[name]=fn end,UnregisterForUpdate=function(_,name)a.timers[name]=nil end}
    a.SKILLS_AND_ACTION_BAR_MANAGER={mode=0,HasAnyPendingChanges=function()return a.dirty end,GetSkillPointAllocationMode=function(s)return s.mode end,SetSkillPointAllocationMode=function(s,m)s.mode=m end}
    a.STATS={mode=0,attributeControls={},GetAttributePointAllocationMode=function(s)return s.mode end,SetAttributePointAllocationMode=function(s,m)s.mode=m end}
    for i=1,3 do a.STATS.attributeControls[i]={pointLimitedSpinner={GetAllocatedPoints=function()return a.statsDirty or 0 end}}end
    a.GetAssignableAbilityBarStartAndEndSlots=function()return 3,8 end
    for bar=0,1 do for slot=3,8 do a.slots[bar..":"..slot]={1,slot==3 and 100 or 200+slot}end end
    a.GetSlotType=function(slot,bar)return a.slots[bar..":"..slot][1]end
    a.GetSlotBoundId=function(slot,bar)return a.slots[bar..":"..slot][2]end
    local skill={IsCraftedAbility=function()return false end,IsPassive=function()return false end,IsUltimate=function()return false end,IsPurchased=function()return true end,GetProgressionId=function()return 10 end,GetCurrentMorphSlot=function()return a.morph end,GetSkillLineData=function()return {GetId=function()return 5 end,IsActive=function()return true end}end,GetMorphData=function(_,m)return {GetAbilityId=function()return m==0 and 90 or 100 end,GetName=function()return "Probe skill"end}end}
    a.SKILLS_DATA_MANAGER={GetProgressionDataByAbilityId=function(_,id)if id==100 or id==90 then return {GetSkillData=function()return skill end}end end,GetSkillDataByProgressionId=function()return skill end}
    a.PrepareSkillPointAllocationRequest=function(...)a.packet={...}end
    a.AddActiveChangeToAllocationRequest=function(...)a.active={...}end
    a.AddHotbarSlotChangeToAllocationRequest=function(...)a.packet[#a.packet+1]={...}end
    a.SendSkillPointAllocationRequest=function()a.sent[#a.sent+1]="skills"end
    a.SendAttributePointAllocationRequest=function(...)assert(storage.journal);a.sent[#a.sent+1]={...}end
    a.EVENT_START_SKILL_RESPEC=3
    a.SKILLS_AND_ACTION_BAR_MANAGER.GetSkillRespecPaymentType=function(s)return s.payment end
    a.enter=function(mode,payment)
        local m=a.SKILLS_AND_ACTION_BAR_MANAGER;m.mode=mode or 2;m.payment=payment or 0;a.scene="skills"
        a.callbacks[3](3,m.mode,m.payment)
    end
    a.StartSkillRespecFromUI=function()a.entries=(a.entries or 0)+1;assert(storage.journal);if not a.delayEntry then a.enter()end end
    storage=storage or {};local messages={};local p=k.BuildProbe.New(a,storage,function(t)messages[#messages+1]=t end)
    return p,a,storage,messages,k
end
local tests={}
function tests.entry_is_asynchronous_and_never_prepares_before_event()
 local p,a,s=setup({});a.delayEntry=true;assert(p:Run("skills"));assert(s.journal.phase=="entry" and #a.sent==0 and not a.packet and a.entries==1)
 for _,f in pairs(a.timers)do f()end;assert(#a.sent==0)
 a.enter();assert(#a.sent==0);for _,f in pairs(a.timers)do f()end;assert(#a.sent==1 and s.journal.sendScene=="skills")
end

function tests.idle_status_never_sends()local p,a=setup({});assert(p:Run("status"));assert(#a.sent==0)end
function tests.explicit_attribute_send_snapshots_before_mutation_and_sends_once()
 local p,a,s=setup({});assert(p:Run("attributes"));assert(s.journal.original[1]==12 and #a.sent==1);assert(a.sent[1][2]==-1 and a.sent[1][3]==1);assert(not p:Run("attributes"));assert(#a.sent==1 and s.journal.phase=="waiting")
end
function tests.success_requires_actual_and_restore_conflict_does_not_send()
 local p,a,s=setup({});p:Run("attributes");a.callbacks[2](2,0);p:Run("status");assert(not s.journal.verified);a.spent={11,23,30};p:Run("status");assert(s.journal.verified);a.spent[3]=31;assert(not p:Run("restore"));assert(#a.sent==1)
end
function tests.failed_or_wrong_or_late_results_do_not_confirm()
 local p,a,s=setup({});p:Run("attributes");a.spent={11,23,30};a.callbacks[1](1,0);assert(not s.journal.result);a.now=15000;for _,f in pairs(a.timers)do f()end;a.callbacks[2](2,0);p:Run("status");assert(not s.journal.verified and not p:Run("restore"));assert(#a.sent==1)
end
function tests.persistence_restores_original_and_clears_only_after_actual()
 local s={};local p,a=setup(s);p:Run("attributes");a.spent={11,23,30};a.callbacks[2](2,0);p:Run("status");local q,b=setup(s);b.spent={11,23,30};assert(q:Run("restore"));assert(#b.sent==1 and s.journal);b.spent={12,22,30};b.callbacks[2](2,0);q:Run("status");assert(not s.journal)
end
function tests.skills_packet_preserves_unrelated_slots_and_restore_checks_conflict()
 local p,a,s=setup({});assert(p:Run("skills"));for _,f in pairs(a.timers)do f()end;assert(a.active[1]==5 and a.active[2]==10 and a.active[3]==0 and a.active[4]==true);assert(#a.packet==4);a.morph=0;for bar=0,1 do a.slots[bar..":3"][2]=90 end;a.callbacks[1](1,0);p:Run("status");assert(s.journal.verified);a.slots['0:4'][2]=500;assert(not p:Run("restore"));assert(#a.sent==1)
end
function tests.batch_no_send_and_dirty_reset_refused()
 local p,a,s=setup({});assert(p:Run("batch"));assert(a.STATS.mode==a.ATTRIBUTE_POINT_ALLOCATION_MODE_FULL and a.SKILLS_AND_ACTION_BAR_MANAGER.mode==2 and #a.sent==0);a.statsDirty=1;assert(not p:Run("reset"));assert(a.STATS.mode==a.ATTRIBUTE_POINT_ALLOCATION_MODE_FULL);a.statsDirty=0;assert(p:Run("reset"));assert(a.STATS.mode==0 and not s.batch)
end
function tests.missing_api_and_combat_fail_without_partial_mutation()
 local p,a,s=setup({});a.SendAttributePointAllocationRequest=nil;assert(not p:Run("attributes"));assert(not s.journal and #a.sent==0);a.IsUnitInCombat=function()return true end;assert(not p:Run("batch"));assert(not s.batch)
end
function tests.failed_result_retains_snapshot_but_original_clears_without_resend()
 local p,a,s=setup({});p:Run("attributes");a.callbacks[2](2,79);assert(s.journal.phase=="result" and s.journal.result==79);assert(p:Run("restore"));assert(not s.journal and #a.sent==1)
end
function tests.restore_already_at_original_reports_note_without_error_or_send()
 local p,a,s,m=setup({});p:Run("attributes");a.spent={11,23,30};a.callbacks[2](2,0);a.spent={12,22,30};assert(#a.sent==1)
 assert(p:Run("restore"));assert(not s.journal and #a.sent==1 and #m==2)
 assert(s.latestReport:find("Note:\nOriginal actual state confirmed; snapshot cleared without sending.",1,true))
 assert(not s.latestReport:find("Error:",1,true))
end
function tests.reload_uncertain_target_refuses_restore()
 local s={};local p,a=setup(s);p:Run("attributes");local q,b=setup(s);b.spent={11,23,30};assert(s.journal.phase=="unknown");assert(q:Run("status"));assert(not q:Run("restore"));assert(#b.sent==0 and s.journal)
end
function tests.terminal_report_error_does_not_leave_busy()
 local p,a,s=setup({});p:Run("attributes");p.report=function()error("chat failed")end;a.callbacks[2](2,79);assert(s.journal.phase=="result")
end
function tests.skills_restore_sends_exact_original_assignments_once()
 local p,a,s=setup({});p:Run("skills");for _,f in pairs(a.timers)do f()end;a.morph=0;for bar=0,1 do a.slots[bar..":3"][2]=90 end;a.callbacks[1](1,0);assert(p:Run("restore"));for _,f in pairs(a.timers)do f()end;assert(#a.sent==2 and a.active[3]==1 and a.packet[3][4]==100 and a.packet[4][4]==100);a.morph=1;for bar=0,1 do a.slots[bar..":3"][2]=100 end;a.callbacks[1](1,0);p:Run("status");assert(not s.journal)
end
function tests.native_dirty_cast_and_session_guards_do_not_send()
 local p,a,s=setup({});a.dirty=true;assert(not p:Run("attributes"));a.dirty=false;a.GetSkillRespecCastTimeRemainingMs=function()return 5 end;assert(not p:Run("skills"));a.GetSkillRespecCastTimeRemainingMs=function()return 0 end;p.IsSessionIdle=function()return false end;assert(not p:Run("batch"));assert(#a.sent==0 and not s.journal and not s.batch)
end
function tests.missing_batch_reporting_api_does_not_change_modes()
 local p,a,s=setup({});a.SCENE_MANAGER=nil;assert(not p:Run("batch"));assert(a.STATS.mode==0 and a.SKILLS_AND_ACTION_BAR_MANAGER.mode==0 and not s.batch)
end
function tests.lazy_keyboard_stats_allows_explicit_probe_without_initialization()
 local p,a,s=setup({});a.STATS.attributeControls=nil;a.STATS.OnShowing=function()error("must not initialize keyboard UI")end
 assert(p:Run("attributes"));assert(#a.sent==1 and not a.STATS.initialized)
 a.callbacks[2](2,79);assert(p:Run("restore"));assert(not s.journal)
 assert(p:Run("batch"));assert(p:Run("reset"));assert(a.STATS.mode==0)
end
function tests.lazy_gamepad_stats_allows_keyboard_probe_without_initialization()
 local p,a,s=setup({});a.GAMEPAD_STATS={PerformDeferredInitializationRoot=function()error("must not initialize gamepad UI")end}
 assert(p:Run("skills"));for _,f in pairs(a.timers)do f()end;assert(#a.sent==1 and not a.GAMEPAD_STATS.deferredInitialized)
end
function tests.initialized_or_unknown_missing_attribute_state_refuses_mutation()
 for _,kind in ipairs({"keyboard", "gamepad", "unknown"})do
  local p,a,s=setup({})
  if kind=="keyboard"then a.STATS.attributeControls=nil;a.STATS.initialized=true;a.STATS.OnShowing=function()end
  elseif kind=="gamepad"then a.GAMEPAD_STATS={deferredInitialized=true,PerformDeferredInitializationRoot=function()end}
  else a.STATS.attributeControls=nil end
  assert(not p:Run("attributes"));assert(#a.sent==0 and not s.journal)
 end
end
function tests.initialized_gamepad_dirty_state_refuses_batch_and_reset()
 local p,a,s=setup({});a.GAMEPAD_STATS={deferredInitialized=true,attributeData={{addedPoints=0},{addedPoints=0},{addedPoints=0}}}
 assert(p:Run("batch"));a.GAMEPAD_STATS.attributeData[1].addedPoints=1;a.GAMEPAD_STATS.attributeData[2].addedPoints=-1
 assert(not p:Run("reset"));assert(a.STATS.mode==a.ATTRIBUTE_POINT_ALLOCATION_MODE_FULL and s.batch)
end

function tests.automatic_completion_waits_for_actual_then_reports_once_without_status()
 local p,a,s,m=setup({});assert(p:Run("attributes"));local before=#m
 a.callbacks[2](2,0);assert(s.journal.phase=="waiting" and #m==before)
 a.spent={11,23,30};for _,f in pairs(a.timers)do f()end
 assert(s.journal.verified and s.journal.phase=="result" and next(a.timers)==nil)
 assert(#m==before+1 and s.latestReport==m[#m] and s.latestReport:find("verified=true",1,true))
 a.callbacks[2](2,0);assert(#m==before+1 and #a.sent==1)
end
function tests.timeout_reports_once_retains_snapshot_and_stops_observation()
 local p,a,s,m=setup({});p:Run("attributes");local before=#m
 a.callbacks[2](2,0);a.now=15000;for _,f in pairs(a.timers)do f()end
 assert(s.journal.phase=="unknown" and not s.journal.verified and next(a.timers)==nil)
 assert(#m==before+1 and s.latestReport:find("timeout",1,true) and #a.sent==1)
 a.callbacks[2](2,0);assert(#m==before+1)
end
function tests.getter_exception_is_full_report_and_releases_wait()
 local p,a,s,m=setup({});p:Run("attributes")
 a.GetAttributeSpentPoints=function()error("getter exploded")end;a.callbacks[2](2,0)
 assert(s.journal.phase=="unknown" and next(a.timers)==nil)
 assert(s.latestReport:find("getter exploded",1,true) and s.latestReport:find("stack traceback",1,true))
 assert(m[#m]==s.latestReport and #a.sent==1)
end
function tests.refused_status_is_copyable_traceback_and_preserves_journal()
 local p,a,s,m=setup({});p:Run("attributes");a.GetAttributeSpentPoints=function()error("status exploded")end
 assert(not p:Run("status"));assert(s.journal and next(a.timers)==nil)
 assert(s.latestReport:find("status exploded",1,true) and s.latestReport:find("stack traceback",1,true) and m[#m]==s.latestReport)
end
function tests.recovered_snapshot_reports_without_sends_or_discarding_it()
 local s={};local p,a=setup(s);p:Run("attributes");local q,b,_,m=setup(s)
 assert(#m==0);q:Recover();assert(#b.sent==0 and s.journal.phase=="unknown")
 assert(#m==1 and s.latestReport:find("recovery",1,true) and not s.journal.verified)
 q:Recover();assert(#m==1)
end
function tests.actual_successful_restore_completes_automatically()
 local p,a,s=setup({});p:Run("attributes");a.spent={11,23,30};a.callbacks[2](2,0)
 assert(p:Run("restore"));a.callbacks[2](2,0);assert(s.journal)
 a.spent={12,22,30};for _,f in pairs(a.timers)do f()end
 assert(not s.journal and next(a.timers)==nil and #a.sent==2 and s.latestReport:find("verified=true",1,true))
end

function tests.persisted_success_recovery_verifies_actual_target_without_send()
 local s={journal={kind="attributes",phase="result",result=0,restoring=false,scene="hud",original={64,0,0},target={63,1,0}}}
 local p,a,_,m=setup(s);a.spent={63,1,0};p:Recover()
 assert(s.journal.verified and #a.sent==0 and #m==1 and s.latestReport:find("scene=hud",1,true))
end
function tests.status_matching_restore_stops_timer_before_clearing_snapshot()
 local p,a,s=setup({});p:Run("attributes");a.spent={11,23,30};a.callbacks[2](2,0);p:Run("restore")
 a.callbacks[2](2,0);a.spent={12,22,30};p:Run("status")
 assert(not s.journal and next(a.timers)==nil)
end
function tests.timer_getter_error_stops_wait_and_retains_full_traceback()
 local p,a,s,m=setup({});p:Run("attributes");a.GetAttributeSpentPoints=function()error("timer getter failed")end
 for _,f in pairs(a.timers)do f()end
 assert(s.journal.phase=="unknown" and next(a.timers)==nil and #a.sent==1)
 assert(s.latestReport:find("timer getter failed",1,true) and s.latestReport:find("stack traceback",1,true) and #m==1)
end
function tests.failed_status_does_not_reuse_stale_verified_flag()
 local p,a,s=setup({});p:Run("attributes");a.spent={11,23,30};a.callbacks[2](2,0);assert(s.journal.verified)
 a.GetAttributeSpentPoints=function()error("actual unavailable")end;assert(not p:Run("status"))
 assert(not s.journal.verified and s.latestReport:find("verified=false",1,true))
end
function tests.report_display_exception_is_persisted_and_stops_wait()
 local p,a,s=setup({});p:Run("attributes");p.report=function()error("dialog failed")end
 a.spent={11,23,30};a.callbacks[2](2,0)
 assert(next(a.timers)==nil and s.journal.phase=="result" and s.latestReport:find("dialog failed",1,true) and s.latestReport:find("stack traceback",1,true))
end
function tests.batch_status_reports_actual_modes_after_native_reset()
 local p,a,s=setup({});p:Run("batch");a.STATS.mode=0;a.SKILLS_AND_ACTION_BAR_MANAGER.mode=0;p:Run("status")
 assert(s.latestReport:find("actualSkillsMode=0",1,true) and s.latestReport:find("actualAttributesMode=0",1,true))
end
function tests.entry_conflicts_never_prepare_and_retain_unknown()
 for _,kind in ipairs({"event","mode","payment","dirty","actual","cast","session"})do
  local p,a,s=setup({});a.delayEntry=true;p:Run("skills");a.enter()
  if kind=="event"then a.callbacks[3](3,0,0)
  elseif kind=="mode"then a.SKILLS_AND_ACTION_BAR_MANAGER.mode=0
  elseif kind=="payment"then a.SKILLS_AND_ACTION_BAR_MANAGER.payment=1
  elseif kind=="dirty"then a.dirty=true
  elseif kind=="actual"then a.slots["0:4"][2]=999
  elseif kind=="cast"then a.GetSkillRespecCastTimeRemainingMs=function()return 1 end
  else p.IsSessionIdle=function()return false end end
  for _,f in pairs(a.timers)do f()end
  assert(#a.sent==0 and not a.packet and s.journal.phase=="unknown" and s.latestReport:find("Error:",1,true))
 end
end
function tests.entry_timeout_reload_and_second_operation_never_restart()
 local p,a,s=setup({});a.delayEntry=true;p:Run("skills");assert(not p:Run("restore"));assert(not p:Run("skills"));assert(a.entries==1)
 a.now=5000;a.enter();for _,f in pairs(a.timers)do f()end;assert(s.journal.phase=="unknown" and #a.sent==0 and s.latestReport:find("entry timeout",1,true))
 local p2,b,t=setup({});b.delayEntry=true;p2:Run("skills");local q,c=setup(t);assert(t.journal.phase=="unknown");q:Recover();assert(not c.entries and #c.sent==0)
end
function tests.entry_preflight_and_starter_errors_preserve_expected_journal()
 for _,name in ipairs({"StartSkillRespecFromUI","EVENT_START_SKILL_RESPEC"})do
  local p,a,s=setup({});a[name]=nil;assert(not p:Run("skills"));assert(not s.journal and not a.entries and #a.sent==0)
 end
 local p,a,s=setup({});a.StartSkillRespecFromUI=function()error("entry exploded")end
 assert(not p:Run("skills"));assert(s.journal.phase=="unknown" and #s.journal.original==12 and s.latestReport:find("entry exploded",1,true))
end
function tests.skill_failed14_full_snapshot_can_clear_original_without_another_entry()
 local p,a,s=setup({});p:Run("skills");for _,f in pairs(a.timers)do f()end;a.callbacks[1](1,14)
 assert(s.journal.result==14 and not s.journal.verified and #s.journal.original==12 and #s.journal.actual==12)
 assert(s.latestReport:find("result=14",1,true) and s.latestReport:find("entryScene=inventory",1,true) and s.latestReport:find("sendScene=skills",1,true))
 assert(p:Run("restore"));assert(not s.journal and a.entries==1 and #a.sent==1)
end
function tests.skill_forward_restore_each_enter_and_send_once_after_native_reset()
 local p,a,s=setup({});p:Run("skills");for _,f in pairs(a.timers)do f()end
 a.morph=0;for bar=0,1 do a.slots[bar..":3"][2]=90 end;a.callbacks[1](1,0);a.SKILLS_AND_ACTION_BAR_MANAGER.mode=0
 assert(p:Run("restore"));assert(a.entries==2 and #a.sent==1);for _,f in pairs(a.timers)do f()end;assert(#a.sent==2)
end
function tests.restore_scene_preflight_preserves_verified_journal_without_entry_or_send()
 for _,failure in ipairs({"missing","throws"})do
  local p,a,s,m,k=setup({});assert(p:Run("skills"));for _,f in pairs(a.timers)do f()end
  a.morph=0;for bar=0,1 do a.slots[bar..":3"][2]=90 end;a.callbacks[1](1,0)
  assert(s.journal.phase=="result" and s.journal.verified)
  local before=k.Copy(s.journal)
  if failure=="missing"then a.SCENE_MANAGER.GetCurrentSceneName=nil
  else a.SCENE_MANAGER.GetCurrentSceneName=function()error("scene unavailable")end end
  assert(not p:Run("restore"));assert(a.entries==1 and #a.sent==1 and not next(a.timers))
  for key,value in pairs(before)do
   if type(value)~="table"then assert(s.journal[key]==value,"journal mutated: "..key)end
  end
  assert(s.journal.original[1].id==before.original[1].id and s.journal.target[1].id==before.target[1].id)
  a.SCENE_MANAGER.GetCurrentSceneName=function()return a.scene end
  assert(p:Run("restore"));assert(a.entries==2 and #a.sent==1)
 end
end
function tests.fresh_skill_scene_preflight_never_creates_journal_or_entry()
 for _,failure in ipairs({"missing","throws"})do
  local p,a,s=setup({})
  if failure=="missing"then a.SCENE_MANAGER.GetCurrentSceneName=nil
  else a.SCENE_MANAGER.GetCurrentSceneName=function()error("scene unavailable")end end
  assert(not p:Run("skills"));assert(not s.journal and not a.entries and #a.sent==0 and not next(a.timers))
 end
end
function tests.batch_requires_actual_full_enum_before_snapshots_or_setters()
 local p,a,s=setup({});a.ATTRIBUTE_POINT_ALLOCATION_MODE_FULL=nil
 local calls=0
 a.STATS.SetAttributePointAllocationMode=function()calls=calls+1 end
 a.SKILLS_AND_ACTION_BAR_MANAGER.SetSkillPointAllocationMode=function()calls=calls+1 end
 assert(not p:Run("batch"));assert(calls==0 and not s.batch and not s.journal and #a.sent==0)
 assert(a.STATS.mode==0 and a.SKILLS_AND_ACTION_BAR_MANAGER.mode==0)
end
function tests.batch_uses_actual_attribute_enum_and_restores_zero_purchase_mode()
 local p,a,s=setup({});assert(a.ATTRIBUTE_POINT_ALLOCATION_MODE_PURCHASE_FULL==nil)
 assert(a.ATTRIBUTE_POINT_ALLOCATION_MODE_FULL~=a.SKILL_POINT_ALLOCATION_MODE_FULL)
 assert(p:Run("batch"));assert(s.batch.attributes==a.ATTRIBUTE_POINT_ALLOCATION_MODE_PURCHASE_ONLY)
 assert(a.STATS.mode==a.ATTRIBUTE_POINT_ALLOCATION_MODE_FULL and a.SKILLS_AND_ACTION_BAR_MANAGER.mode==a.SKILL_POINT_ALLOCATION_MODE_FULL)
 assert(p:Run("reset"));assert(a.STATS.mode==a.ATTRIBUTE_POINT_ALLOCATION_MODE_PURCHASE_ONLY and not s.batch and #a.sent==0)
end
function tests.skill_block_report_records_exact_managers_without_changing_native_state()
 local journal={phase='result',kind='attributes'};local batch={skills=0,attributes=0}
 local p,a,s,m,k=setup({journal=journal,batch=batch})
 a.SKILL_POINT_ALLOCATION_MODE_PURCHASE_ONLY=0
 a.SKILL_POINT_ALLOCATION_MANAGER={IsAnyChangePending=function()return false end}
 a.ACTION_BAR_ASSIGNMENT_MANAGER={IsAnyChangePending=function()return true end,hotbars={}}
 a.SKILL_LINE_ASSIGNMENT_MANAGER={IsAnyChangePending=function()return false end}
 local global=a.SKILLS_AND_ACTION_BAR_MANAGER
 global.managers={a.SKILL_POINT_ALLOCATION_MANAGER,a.ACTION_BAR_ASSIGNMENT_MANAGER,a.SKILL_LINE_ASSIGNMENT_MANAGER}
 global.HasAnyPendingChanges=function()return true end
 local problem=k.Problem('foreignSkillDraft')
 p:RecordSkillBlock(problem,'Apply')
 assert(problem.details.nativeReasons[1]=='bars' and #problem.details.nativeReasons==1)
 assert(#m==1 and s.skillBlockReport:find('bars.pending=true',1,true) and s.skillBlockReport:find('mode=0',1,true))
 assert(s.latestReport==s.skillBlockReport and s.skillBlockReport:find('action=Apply',1,true))
 assert(#a.sent==0 and not a.packet and s.journal==journal and s.batch==batch and global.mode==0)
 p:RecordSkillBlock(k.Problem('foreignSkillDraft'),'BeginEdit')
 assert(#m==1,'repeated identical block must not keep opening dialogs')
 -- Viewing the captured report after the native state has changed must not re-read it.
 global.HasAnyPendingChanges=function()error('old report must not read current state')end
 assert(p:Run('blocked'));assert(#m==2 and m[2]==s.skillBlockReport and s.journal==journal and #a.sent==0)
end
function tests.skill_block_report_includes_hidden_bar_actual_and_pending_ids()
 local p,a,s,m,k=setup({});a.SKILL_POINT_ALLOCATION_MODE_PURCHASE_ONLY=0
 local action={GetActionType=function()return 1 end,GetActionId=function()return 100 end,
  GetSlottableActionType=function()return 12 end,GetEffectiveAbilityId=function()return 101 end}
 local bar={SlotIterator=function()return pairs({[3]=action})end,DoesSlotHavePendingChanges=function()return true end}
 a.HOTBAR_CATEGORY_WEREWOLF=3;a.slots['3:3']={1,99}
 a.ACTION_BAR_ASSIGNMENT_MANAGER={hotbars={[3]=bar},IsAnyChangePending=function()return true end,ShouldSubmitChangesForHotbarCategory=function()return true end}
 a.SKILLS_AND_ACTION_BAR_MANAGER.HasAnyPendingChanges=function()return true end
 p:RecordSkillBlock(k.Problem('foreignSkillDraft'),'Apply')
 for _,line in ipairs({'bar.3.slot.3.actualId=99','bar.3.slot.3.pendingId=100','bar.3.slot.3.effectiveId=101'})do assert(s.skillBlockReport:find(line,1,true),line)end
 assert(#m==1 and #a.sent==0)
end
function tests.bar_block_report_preserves_refusal_snapshot_when_live_read_fails()
 local journal={phase='result',kind='attributes'}
 local p,a,s,m,k=setup({journal=journal})
 local reads=0
 a.GetSlotBoundId=function()reads=reads+1;error('slot getter failed')end
 a.ACTION_BAR_ASSIGNMENT_MANAGER={hotbars={},GetHotbar=function()error('must not create a hotbar')end}
 local problem=k.Problem('skillBarOverride',{slotContext={category=3,nativeSlot=8,mutable=true,
  runtimeOverride='10:active:51',explicit=false,before={kind='skill',skillKey='10:active:51',expectedMorph=1},target={kind='empty'}}})
 p:RecordSkillBlock(k.Problem('insufficientSkillPoints'),'Apply')
 assert(reads==0 and #m==0)
 p:RecordSkillBlock(problem,'Apply')
 assert(reads==1 and #m==1 and problem.code=='skillBarOverride' and problem.details.nativeReportSaved)
 for _,text in ipairs({'slotContext.category=3','slotContext.nativeSlot=8','slotContext.explicit=false',
  'slotContext.before.expectedMorph=1','slotContext.target.kind=empty','reason.runtimeOverride=true','slot getter failed'})do
  assert(m[1]:find(text,1,true),text)
 end
 assert(not m[1]:find('reason.immutable=true',1,true))
 assert(s.journal==journal and not s.batch and #a.sent==0 and not a.packet and not a.entries)
end
function tests.skill_block_report_distinguishes_mode_dirty_and_unreadable_managers()
 local p,a,s,m,k=setup({});a.SKILL_POINT_ALLOCATION_MODE_PURCHASE_ONLY=0
 local global=a.SKILLS_AND_ACTION_BAR_MANAGER;global.mode=2
 local problem=k.Problem('foreignSkillDraft');p:RecordSkillBlock(problem,'BeginEdit')
 assert(problem.details.nativeReasons[1]=='mode')
 global.mode=0;global.isDirty=true;problem=k.Problem('foreignSkillDraft');p:RecordSkillBlock(problem,'Apply')
 assert(problem.details.nativeReasons[1]=='dirty' and #m==2)
 global.isDirty=false;global.HasAnyPendingChanges=function()error('native getter failed')end
 problem=k.Problem('foreignSkillDraft');p:RecordSkillBlock(problem,'Apply')
 assert(problem.details.nativeReasons[1]=='unknown' and s.skillBlockReport:find('native getter failed',1,true) and #m==3)
 assert(#a.sent==0 and not a.packet)
end
return tests
