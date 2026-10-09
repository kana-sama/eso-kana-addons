local setup=dofile(ROOT..'/tests/support/gear_suite_fixture.lua')
local function caseById(suite,id)for _,c in ipairs(suite.cases)do if c.id==id then return c end end;error(id)end
local tests={}
function tests.gear_suite_runs_all_available_experiments_and_restores_after_native_refusal()
 local f=setup();local initial=f.inventory:Capture(false).worn
 assert(f.suite:Run('gearsuite'));f:Advance(120000)
 local run=f.saved.suite
 assert(not f.suite.active and run.status=='completed',run.error)
 assert(run.matchesOriginal and f.k.Slots.Equal(initial,f.inventory:Capture(false).worn))
 assert(caseById(run,'armor_batch').status=='passed')
 assert(caseById(run,'armor_batch_ww').status=='passed')
 assert(caseById(run,'all_equipment').status=='passed')
 assert(caseById(run,'replacements').status=='passed')
 assert(caseById(run,'mixed_empty').status=='passed')
 assert(caseById(run,'mixed_replacement').status=='passed')
 assert(caseById(run,'ring_move').status=='passed')
 assert(caseById(run,'ring_swap').status=='passed')
 assert(caseById(run,'ring_swap_bag').status=='passed')
 assert(caseById(run,'mythic_direct').status=='failed','refusal is an experiment outcome, not an aborted suite')
 assert(caseById(run,'mythic_staged').status=='passed')
 assert(caseById(run,'twohand_clear').status=='passed')
 assert(caseById(run,'twohand_pair').status=='passed')
 assert(caseById(run,'weapon_transfer').status=='passed')
 assert(caseById(run,'full_bag').status=='skipped')
 assert(#f.reports==1,'one report at the end, no per-experiment prompts')
 local moves=caseById(run,'all_equipment').phases[1].requests
 assert(#moves==7 and moves[1].sentAt==moves[7].sentAt,'all removals must be dispatched together')
 local cells={};for _,r in ipairs(moves)do assert(not cells[r.destSlot]);cells[r.destSlot]=true end
end
function tests.gear_suite_timeout_records_partial_state_restores_and_runs_later_cases()
 local f=setup();local rejected=false
 f.reject=function(r)
  local run=f.saved.suite;local c=run and run.cases[run.index]
  if c and c.id=='armor_batch' and r.method=='move' and r.uid=='head' and not rejected then rejected=true;return true end
 end
 assert(f.suite:Run('gearsuite'));f:Advance(120000)
 local run=f.saved.suite;local c=caseById(run,'armor_batch')
 assert(c.status=='failed' and c.phases[1].actual[0].uid=='head')
 assert(c.phases[1].actual[3].kind=='empty' and c.restored)
 assert(caseById(run,'armor_batch_ww').status=='passed' and run.matchesOriginal)
end
function tests.gear_suite_skips_ineligible_cases_without_binding_or_filling_the_bag()
 local f=setup()
 for slot in pairs(f.a.bags[1])do f.a.bags[1][slot].willBind=true end
 local cases=f.k.GearProbeCases.Build(f.inventory:Capture('equipment'),f.a)
 assert(caseById({cases=cases},'replacements').skip)
 assert(caseById({cases=cases},'mythic_staged').skip)
 assert(caseById({cases=cases},'full_bag').skip)
 assert(#f.sent==0 and f.a.GetNumBagFreeSlots()==35)
end
function tests.gear_suite_full_bag_probe_does_not_manufacture_full_inventory()
 local f=setup();f.size=5
 assert(f.suite:Run('gearsuite'));f:Advance(120000)
 local run=f.saved.suite
 assert(caseById(run,'full_bag').status=='passed' and run.matchesOriginal,run.error)
 assert(f.a.GetNumBagFreeSlots()==0)
end
function tests.gear_suite_reload_is_read_only_and_explicit_restore_uses_persisted_baseline()
 local f=setup();local original=f.inventory:Capture(false).worn
 assert(f.suite:Run('gearsuite'));f:Advance(125)
 -- Simulate reload: timers vanish, only plain SavedVariables survive.
 f.clock.timers={};local saved=f.k.Copy(f.saved);local count=#f.sent
 local reloaded=f:New(saved)
 assert(not reloaded.active and #f.sent==count and saved.suite.status=='interrupted')
 assert(reloaded:Run('gearsuiterestore'));f:Advance(20000)
 assert(saved.suite.matchesOriginal and f.k.Slots.Equal(original,f.inventory:Capture(false).worn))
end
function tests.gear_suite_report_storage_has_no_oversized_strings_and_reopens_after_reload()
 local f=setup();assert(f.suite:Run('gearsuite'));f:Advance(120000)
 local function verify(value)
  if type(value)=='string'then assert(#value<=1800,'ESO drops oversized SavedVariables strings')
  elseif type(value)=='table'then for _,v in pairs(value)do verify(v)end end
 end
 verify(f.saved)
 local saved=f.k.Copy(f.saved);local p=f:New(saved);local n=#f.sent
 assert(p:Run('gearsuitereport') and #f.sent==n)
 assert(f.reports[2]:find('mythic_direct',1,true) and f.reports[2]:find('matchesOriginal=true',1,true))
end
function tests.gear_suite_busy_and_combat_do_not_overwrite_an_existing_journal()
 local f=setup();f.saved.suite={status='completed',marker='keep'};f.busy=true
 assert(not f.suite:Run('gearsuite'));assert(#f.sent==0 and f.saved.suite.marker=='keep')
 f.busy=false;f.a.combat=true;assert(not f.suite:Run('gearsuite'));assert(#f.sent==0)
end
function tests.gear_suite_native_error_is_attached_to_the_phase_and_stop_waits_before_restoring()
 local f=setup();assert(f.suite:Run('gearsuite'));f:Advance(125)
 f.suite:NativeError('EVENT_UI_ERROR',123,'Предмет нельзя надеть')
 assert(f.suite:Run('gearsuitestop'));f:Advance(15000)
 local run=f.saved.suite
 assert(run.status=='stopped' and run.matchesOriginal and not f.suite.active)
 assert(run.cases[1].phases[1].errors[1].code=='123')
 assert(run.cases[2].status=='pending','stop must not launch another experiment')
end
function tests.gear_suite_does_not_continue_testing_after_failed_restoration()
 local f=setup()
 f.reject=function(r)return f.suite.mode=='restore' and r.method=='equip'end
 assert(f.suite:Run('gearsuite'));f:Advance(120000)
 local run=f.saved.suite
 assert(run.status=='interrupted' and not f.suite.active and not run.matchesOriginal)
 local failed=caseById(run,'replacements')
 assert(failed.restore.result.status~='success' and caseById(run,'mixed_empty').status=='pending')
 f.reject=nil;assert(f.suite:Run('gearsuiterestore'));f:Advance(20000)
 assert(run.matchesOriginal and run.status=='restored')
end
function tests.gear_suite_reload_during_preparation_keeps_original_snapshot_for_restore()
 local f=setup();local original=f.inventory:Capture(false).worn
 assert(f.suite:Run('gearsuite'))
 for _=1,400 do
  f:Advance(25)
  local c=f.saved.suite.cases[f.saved.suite.index]
  if c and c.id=='ring_move' and f.suite.mode=='setup' and f.a.bags[0][12]==nil then break end
 end
 assert(f.saved.suite.cases[f.saved.suite.index].id=='ring_move' and f.suite.mode=='setup')
 f.clock.timers={};local saved=f.k.Copy(f.saved);local reloaded=f:New(saved)
 local count=#f.sent
 assert(not reloaded:Run('gearsuite') and #f.sent==count,'interrupted setup must not become a new baseline')
 assert(reloaded:Run('gearsuiterestore'));f:Advance(20000)
 assert(f.k.Slots.Equal(original,f.inventory:Capture(false).worn))
end
return tests
