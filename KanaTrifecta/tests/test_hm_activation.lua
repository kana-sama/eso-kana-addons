local F=dofile('KanaTrifecta/tests/fixtures.lua')
local function kill(run) F.Kill(run,'boss_5',8000,run.bosses.boss_5.pullId) end
local function setup()
 dofile('KanaTrifecta/profiles/catalog.lua')
 local p=KanaTrifecta.Profiles:Find(283,2);local handlers={};local boss=false;local hp=0
 local a={EVENT_PLAYER_COMBAT_STATE=1,EVENT_COMBAT_EVENT=2,EVENT_UNIT_DEATH_STATE_CHANGED=3,
  EVENT_CLIENT_INTERACT_RESULT=4,EVENT_RETICLE_TARGET_CHANGED=5,EVENT_EFFECT_CHANGED=6,
  EVENT_SHOW_BOOK=7,EVENT_CHATTER_BEGIN=8,CLIENT_INTERACT_RESULT_SUCCESS=1,EFFECT_RESULT_GAINED=1,
  REGISTER_FILTER_COMBAT_RESULT=1,REGISTER_FILTER_ABILITY_ID=2,REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE=3,
  COMBAT_UNIT_TYPE_PLAYER=1,COMBAT_UNIT_TYPE_GROUP=2,COMBAT_UNIT_TYPE_OTHER=3,
  ACTION_RESULT_EFFECT_GAINED=14,ACTION_RESULT_KILLING_BLOW=11,ACTION_RESULT_DIED=12,ACTION_RESULT_DIED_XP=13,
  COMBAT_MECHANIC_FLAGS_HEALTH=1,GetGameTimeMilliseconds=function() return 1000 end,GetTimeStamp=function() return 1000 end,
  GetGroupSize=function() return 1 end,GetGroupUnitTagByIndex=function() return 'group1' end,
  GetUnitDisplayName=function(tag) return tag=='player' and '@one' or '@two' end,
  GetRawUnitName=function(tag) return tag=='player' and 'One' or 'Two' end,
  IsGroupMemberInSameInstanceAsPlayer=function() return true end,IsUnitDead=function() return false end,
  IsUnitInCombat=function(tag) return boss and tag=='reticleover' end,
  DoesUnitExist=function(tag) return boss and tag=='reticleover' end,
  GetUnitName=function() return "Кра’гх Король Дреугов^M" end,
  GetUnitPower=function(_,power) assert(power==1);return hp,hp end,
  EVENT_MANAGER={RegisterForEvent=function(_,name,_,fn) handlers[name]=fn end,
   UnregisterForEvent=function(_,name) handlers[name]=nil end,AddFilterForEvent=function() end}}
 local b=KanaTrifecta.Bootstrap.New(a);b.generation=1;b.context={contextGeneration=1,language='ru',freshness='fresh'}
 b.run=KanaTrifecta.Run.New(p,b.context);b.observer:Activate(p,b.context)
 return b,a,handlers,function(value) boss=true;hp=value or 123;handlers.KanaTrifectaObserver_EVENT_RETICLE_TARGET_CHANGED(5) end
end
return {
 reticle_health_does_not_fabricate_a_death=function()
  local b,a,h,pull=setup();pull(4593053)
  a.IsUnitDead=function(tag) return tag=='reticleover' end
  h.KanaTrifectaObserver_EVENT_RETICLE_TARGET_CHANGED(5)
  assert(not b.run.bosses.boss_5.killed,'Reticle fallback reads health only')
 end,
 successful_scroll_read_is_carried_into_next_pull=function()
  for _,name in ipairs({'Свиток славной битвы^N','Scroll of Glorious Battle'}) do
   local b,a,h,pull=setup();local fn=h.KanaTrifectaObserver_EVENT_CLIENT_INTERACT_RESULT;assert(fn)
   fn(4,1,name);assert(not b.run.clock.startedAtMs and not b.run.bosses.boss_5.killed)
   pull();kill(b.run)
   assert(b.run:View(9000).bossRows[5].colorRole=='success')
  end
 end,
 book_dialog_failed_or_unrelated_interactions_do_not_confirm=function()
  local b,a,h,pull=setup();local fn=h.KanaTrifectaObserver_EVENT_CLIENT_INTERACT_RESULT;assert(fn)
  fn(4,2,'Scroll of Glorious Battle');fn(4,1,'Unrelated scroll')
  a.INTERACTION_CONVERSATION=1;a.GetInteractionType=function() return 1 end
  fn(4,1,'Scroll of Glorious Battle')
  if h.KanaTrifectaObserver_EVENT_SHOW_BOOK then h.KanaTrifectaObserver_EVENT_SHOW_BOOK(7,'Scroll of Glorious Battle') end
  if h.KanaTrifectaObserver_EVENT_CHATTER_BEGIN then h.KanaTrifectaObserver_EVENT_CHATTER_BEGIN(8,2) end
  pull();kill(b.run);assert(b.run.bosses.boss_5.mode=='unknown')
 end,
 group_scroll_effect_is_seen_after_timer_start=function()
  local b,a,h,pull=setup();h.KanaTrifectaObserver_EVENT_PLAYER_COMBAT_STATE(1,true)
  local fn=h.KanaTrifectaObserver_EVENT_COMBAT_EVENTHardMode70113;assert(fn,'HM subscription must survive timer start')
  fn(2,14,false,'',0,0,'',3,'Two^M',2,0,1,0,false,0,1,70113)
  pull();kill(b.run);assert(b.run.bosses.boss_5.state=='completed')
 end,
 aura_gain_requires_a_current_instance_member=function()
  local b,a,h,pull=setup();local fn=h.KanaTrifectaObserver_EVENT_EFFECT_CHANGEDHardMode70113;assert(fn)
  fn(6,1,0,'','reticleover',0,1,1,'','',0,0,0,'',0,70113,3)
  fn(6,2,0,'','player',0,1,1,'','',0,0,0,'',0,70113,3)
  pull();assert(b.run.bosses.boss_5.mode=='unknown')
  fn(6,1,0,'','group1',0,1,1,'','',0,0,0,'',0,70113,3)
  assert(b.run.bosses.boss_5.mode=='active')
 end,
 wipe_and_reload_discard_unconsumed_activation=function()
  local b,a,h,pull=setup();h.KanaTrifectaObserver_EVENT_CLIENT_INTERACT_RESULT(4,1,'Scroll of Glorious Battle')
  local saved=KanaTrifecta.State:Save(b.run,b:Clocks());local c=KanaTrifecta.Copy(b.context);c.freshness='same'
  local restored=KanaTrifecta.State:Restore(saved,b.run.profile,c,b:Clocks())
  F.Pull(restored,'boss_5','new');assert(restored.bosses.boss_5.mode=='unknown')
  b.observer:Handle({kind='wipe'});pull();assert(b.run.bosses.boss_5.mode=='unknown')
 end,
 reticle_health_is_an_independent_stronger_mode_signal=function()
  local b,a,h,pull=setup();h.KanaTrifectaObserver_EVENT_CLIENT_INTERACT_RESULT(4,1,'Scroll of Glorious Battle')
  pull(3993959);kill(b.run);assert(b.run.bosses.boss_5.state=='failed')
  local other,_,_,hmPull=setup();hmPull(4593053);kill(other.run)
  assert(other.run.bosses.boss_5.state=='completed')
 end,
}
