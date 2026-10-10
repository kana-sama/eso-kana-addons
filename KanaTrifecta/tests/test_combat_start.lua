local F=dofile('KanaTrifecta/tests/fixtures.lua')
local function setup(options)
 options=options or {};dofile('KanaTrifecta/profiles/catalog.lua')
 local p=KanaTrifecta.Copy(KanaTrifecta.Profiles:Find(options.zone or 283,2))
 if options.rule then p.startRule=options.rule end
 local c={contextGeneration=1,freshness=options.freshness or 'unknown',language='en'}
 local now=options.now or 1000;local handlers={}
 local a={GetGameTimeMilliseconds=function() return now end,GetTimeStamp=function() return 1000+now/1000 end,
  GetGroupSize=function() return 0 end,GetUnitDisplayName=function() return '@one' end,GetRawUnitName=function() return 'Char' end,
  IsUnitDead=function() return false end,IsUnitInCombat=function() return options.inCombat or false end,
  EVENT_PLAYER_COMBAT_STATE=1,EVENT_COMBAT_EVENT=2,EVENT_ZONE_CHANGED=3,
  COMBAT_UNIT_TYPE_PLAYER=1,COMBAT_UNIT_TYPE_GROUP=2,COMBAT_UNIT_TYPE_OTHER=3,
  ACTION_RESULT_DAMAGE=10,ACTION_RESULT_EFFECT_GAINED=12,REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE=1,
  REGISTER_FILTER_ABILITY_ID=2,REGISTER_FILTER_COMBAT_RESULT=3,
  EVENT_MANAGER={RegisterForEvent=function(_,name,id,fn) handlers[name]=fn end,AddFilterForEvent=function() end,
   UnregisterForEvent=function(_,name) handlers[name]=nil end}}
 local b=KanaTrifecta.Bootstrap.New(a);b.generation=1;b.context=c;b.run=KanaTrifecta.Run.New(p,c)
 if options.prepare then options.prepare(b.run) end
 b.observer:Activate(p,c)
 return b.run,b.observer,a,handlers,function(t) now=t end
end
local function hit(h,a,source,ability,result)
 local fn=h['KanaTrifectaObserver_EVENT_COMBAT_EVENT'..tostring(source)]
 assert(fn,'Missing combat start subscription')
 fn(2,result or a.ACTION_RESULT_DAMAGE,false,'',0,0,'Char',source,'Enemy',3,10,0,0,false,1,2,ability or 1)
end
return {
 first_combat_after_reload_starts_once_and_releases_start_events=function()
  local r,o,a,h,set=setup();assert(r:View(1000).timer.text=='15:00')
  local state=h.KanaTrifectaObserver_EVENT_PLAYER_COMBAT_STATE
  state(1,true);assert(r.clock.startedAtMs==1000)
  assert(r.clock.quality=='estimated' and r.clock.localObservation)
  assert(r:View(2000).timer.text=='14:59');assert(r:View(2000).deaths.text=='0')
  assert(not h.KanaTrifectaObserver_EVENT_COMBAT_EVENT1)
  assert(not h.KanaTrifectaObserver_EVENT_COMBAT_EVENT2)
  set(5000);state(1,false);state(1,true);assert(r.clock.startedAtMs==1000)
 end,
 damage_starts_when_combat_state_transition_was_missed=function()
  for _,source in ipairs({1,2}) do
   local r,o,a,h=setup();hit(h,a,source);assert(r.clock.startedAtMs==1000)
  end
 end,
 combat_already_active_at_ui_load_starts_without_transition=function()
  local r=setup({inCombat=true});assert(r.clock.startedAtMs==1000)
  assert(r:View(2000).timer.text=='14:59')
 end,
 fresh_known_threshold_waits_for_its_subzone=function()
  local r,o,a,h,set=setup({rule=123,freshness='fresh'})
  h.KanaTrifectaObserver_EVENT_PLAYER_COMBAT_STATE(1,true);assert(not r.clock.startedAtMs)
  local zone=h.KanaTrifectaObserver_EVENT_ZONE_CHANGED
  zone(3,nil,nil,nil,nil,999);assert(not r.clock.startedAtMs)
  set(2000);zone(3,nil,nil,nil,nil,123);assert(r.clock.startedAtMs==2000)
  assert(r.clock.quality=='observed');set(5000);zone(3,nil,nil,nil,nil,123);assert(r.clock.startedAtMs==2000)
 end,
 unknown_history_can_start_before_known_threshold=function()
  local r,o,a,h=setup({rule=123});hit(h,a,1)
  assert(r.clock.startedAtMs==1000 and r.clock.localObservation and r.clock.unboundedStart)
 end,
 boss_combat_is_fallback_for_missed_fresh_threshold=function()
  local r,o=setup({rule=123,freshness='fresh'})
  o:Handle({kind='bossSnapshot',units={{name='unknown',inCombat=true}}})
  assert(r.clock.startedAtMs==1000 and r.clock.localObservation)
 end,
 existing_running_and_finished_clocks_never_restart=function()
  for _,stop in ipairs({false,true}) do
   local r,o,a,h=setup({freshness='fresh',inCombat=true,prepare=function(run)
    F.Start(run,0)
    if stop then for _,def in ipairs(run.profile.bosses) do F.Kill(run,def.key,500) end end
   end})
   assert(r.clock.startedAtMs==0);assert(r.clock.stopped==stop)
   h.KanaTrifectaObserver_EVENT_PLAYER_COMBAT_STATE(1,true);assert(r.clock.startedAtMs==0)
   if stop then assert(r.clock.stoppedElapsedMs==500) end
  end
 end,
 special_start_uses_sourced_ability_effect=function()
  local r,o,a,h=setup({zone=1153,freshness='fresh'})
  assert(r.profile.startAbilityId==131774)
  h.KanaTrifectaObserver_EVENT_PLAYER_COMBAT_STATE(1,true);assert(not r.clock.startedAtMs)
  local fn=h.KanaTrifectaObserver_EVENT_COMBAT_EVENTStartAbility;assert(fn)
  fn(2,a.ACTION_RESULT_DAMAGE,false,'',0,0,'',3,'',3,0,0,0,false,1,2,131774);assert(not r.clock.startedAtMs)
  fn(2,a.ACTION_RESULT_EFFECT_GAINED,false,'',0,0,'',3,'',3,0,0,0,false,1,2,131774)
  assert(r.clock.startedAtMs==1000 and r.clock.quality=='observed')
  assert(not h.KanaTrifectaObserver_EVENT_COMBAT_EVENTStartAbility)
 end,
}
