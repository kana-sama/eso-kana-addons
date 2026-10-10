local F=dofile('KanaTrifecta/tests/fixtures.lua')
local function setup(maxHealth)
 dofile('KanaTrifecta/profiles/catalog.lua')
 local p=KanaTrifecta.Copy(KanaTrifecta.Profiles:Find(283,2))
 local now,exists=0,true;local handlers={}
 local a={EVENT_PLAYER_COMBAT_STATE=1,EVENT_COMBAT_EVENT=2,EVENT_UNIT_DEATH_STATE_CHANGED=3,
  REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE=1,REGISTER_FILTER_COMBAT_RESULT=2,REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE=3,
  COMBAT_UNIT_TYPE_PLAYER=1,COMBAT_UNIT_TYPE_GROUP=2,COMBAT_UNIT_TYPE_OTHER=3,
  ACTION_RESULT_DAMAGE=10,ACTION_RESULT_KILLING_BLOW=11,ACTION_RESULT_DIED=12,ACTION_RESULT_DIED_XP=13,
  GetGameTimeMilliseconds=function() return now end,GetTimeStamp=function() return 1000 end,
  GetGroupSize=function() return 0 end,GetUnitDisplayName=function() return '@one' end,GetRawUnitName=function() return 'Char' end,
  IsUnitDead=function() return false end,IsUnitInCombat=function(tag) return tag=='boss1' end,
  DoesUnitExist=function(tag) return exists and tag=='boss1' end,
  GetUnitName=function() return "Кра'гх Король Дреугов^M" end,GetUnitPower=function() return 100,maxHealth or 123 end,POWERTYPE_HEALTH=1,
  EVENT_MANAGER={RegisterForEvent=function(_,name,id,fn) handlers[name]=fn end,AddFilterForEvent=function() end,
   UnregisterForEvent=function(_,name) handlers[name]=nil end}}
 local b=KanaTrifecta.Bootstrap.New(a);b.generation=1;b.context={contextGeneration=1,language='ru',freshness='fresh'}
 b.run=KanaTrifecta.Run.New(p,b.context);b.observer:Activate(p,b.context)
 return b,a,handlers,function(t,e) now=t;exists=e end
end
return {
 normal_kragh_kill_fails_hm_and_freezes_finish=function()
  local b,a,h,set=setup(3993959)
  h.KanaTrifectaObserver_EVENT_PLAYER_COMBAT_STATE(1,true)
  for i=1,4 do F.Kill(b.run,'boss_'..i,i*1000) end
  set(73000,false)
  h.KanaTrifectaObserver_EVENT_COMBAT_EVENTDeath12(2,a.ACTION_RESULT_DIED,false,'',0,0,'',3,"Кра'гх Король Дреугов^M",3,0,0,0,false,0,99,0)
  local view=b.run:View(90000);local row=view.bossRows[5]
  assert(row.colorRole=='error','Normal veteran Kra gh must fail the HM requirement')
  assert(row.killTimeText=='01:13' and b.run.clock.stoppedElapsedMs==73000)
 end,
 hardmode_kragh_kill_completes_boss=function()
  local b,a,h,set=setup(4593053)
  h.KanaTrifectaObserver_EVENT_PLAYER_COMBAT_STATE(1,true)
  set(73000,false);h.KanaTrifectaObserver_EVENT_UNIT_DEATH_STATE_CHANGED(3,'boss1',true)
  assert(b.run:View(90000).bossRows[5].colorRole=='success','HM health must complete the boss')
 end,
 unrecognized_kragh_health_does_not_prove_normal_mode=function()
  for _,hp in ipairs({0,1347189,3993958,4593054,6000000}) do
   local b,a,h,set=setup(hp)
   h.KanaTrifectaObserver_EVENT_PLAYER_COMBAT_STATE(1,true)
   set(73000,false);h.KanaTrifectaObserver_EVENT_UNIT_DEATH_STATE_CHANGED(3,'boss1',true)
   assert(b.run.bosses.boss_5.mode=='unknown','Unrecognized health must remain unknown')
  end
 end,
 apostrophe_variants_match_the_same_boss=function()
  local b=setup();assert(b.run.bosses.boss_5.pullId,'Straight apostrophe must match localized boss name')
 end,
 death_subscription_survives_timer_start_and_stops_at_last_kill=function()
  for _,result in ipairs({11,12,13}) do
   local b,a,h,set=setup()
   h.KanaTrifectaObserver_EVENT_PLAYER_COMBAT_STATE(1,true)
   for i=1,4 do F.Kill(b.run,'boss_'..i,i*1000) end
   local fn=h['KanaTrifectaObserver_EVENT_COMBAT_EVENTDeath'..result]
   assert(fn,'Death observation must remain subscribed after RunStarted')
   set(73000,false)
   fn(2,result,false,'',0,0,'',a.COMBAT_UNIT_TYPE_OTHER,"Кра'гх Король Дреугов^M",a.COMBAT_UNIT_TYPE_OTHER,0,0,0,false,0,99,0)
   assert(b.run.bosses.boss_5.killed and b.run.clock.stopped)
   assert(b.run:View(90000).bossRows[5].killTimeText=='01:13')
   assert(b.run.clock.stoppedElapsedMs==73000)
   set(90000,false);fn(2,result,false,'',0,0,'',3,"Кра'гх Король Дреугов^M",3,0,0,0,false,0,99,0)
   assert(b.run.bosses.boss_5.killedAtMs==73000,'Duplicate death must not change finish time')
  end
 end,
 vanished_dead_tag_uses_last_observed_boss_identity=function()
  local b,a,h,set=setup();h.KanaTrifectaObserver_EVENT_PLAYER_COMBAT_STATE(1,true)
  set(73000,false);h.KanaTrifectaObserver_EVENT_UNIT_DEATH_STATE_CHANGED(3,'boss1',true)
  assert(b.run.bosses.boss_5.killed,'Explicit death must not require tag to remain readable')
 end,
 disappearance_damage_or_player_death_does_not_kill_boss=function()
  local b,a,h,set=setup();h.KanaTrifectaObserver_EVENT_PLAYER_COMBAT_STATE(1,true)
  set(1000,false);b.observer:ScanBosses('bossesChanged');assert(not b.run.bosses.boss_5.killed)
  local fn=h.KanaTrifectaObserver_EVENT_COMBAT_EVENTDeath12;assert(fn)
  fn(2,a.ACTION_RESULT_DAMAGE,false,'',0,0,'',3,"Кра'гх Король Дреугов^M",3,0,0,0,false,0,99,0)
  fn(2,a.ACTION_RESULT_DIED,false,'',0,0,'',3,"Кра'гх Король Дреугов^M",1,0,0,0,false,0,99,0)
  assert(not b.run.bosses.boss_5.killed)
 end,
}
