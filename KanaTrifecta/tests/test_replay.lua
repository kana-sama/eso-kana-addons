local F=dofile('KanaTrifecta/tests/fixtures.lua')
local function setup(fresh)
 local now=0;local api={GetGameTimeMilliseconds=function() return now end,GetTimeStamp=function() return 1000+now/1000 end}
 local b=KanaTrifecta.Bootstrap.New(api);b.generation=1
 local p=F.NewRun().profile;p.startRule=0;p.Observe=KanaTrifecta.Profiles.ObserveEncounters
 for _,def in ipairs(p.bosses) do def.terminalDeath=true;def.healthModes={[10]='inactive',[20]='active'} end
 local c={profileKey=p.key,contextGeneration=1,runKey='replay',freshness=fresh or 'fresh',language='en'}
 b.run=KanaTrifecta.Run.New(p,c);b.context=c;b.observer.context=c;b.observer.profile=p
 return b,function(value) now=value end
end
local function unit(b,name,hp,dead,at)
 b.observer:Handle({kind='bossSnapshot',atMs=at,units={{name=name,maxHealth=hp,inCombat=not dead,isDead=dead,tag='boss1'}}})
end
return {
 full_run_reload_failed_hm=function()
  local b,setTime=setup();b.observer:Handle({kind='combatState',inCombat=true,atMs=0})
  F.Member(b.run,'one',false);b.observer:Emit('MemberDied',{memberKey='one',inInstance=true,human=true},100)
  unit(b,'a',20,false,1000);b.observer:Handle({kind='wipe',atMs=2000});unit(b,'a',10,false,3000);unit(b,'a',10,true,400000)
  unit(b,'b',20,false,500000);unit(b,'b',20,true,800000);unit(b,'c',20,false,900000);unit(b,'c',20,true,1260000)
  assert(b.run:View(1800000).timer.text=='04:00');assert(b.run.bosses.a.state=='failed');assert(b.run.deathCount==1)
  setTime(1800000);local saved=KanaTrifecta.State:Save(b.run,b:Clocks());local context=KanaTrifecta.Copy(b.context)
  context.freshness='same';context.contextGeneration=2
  local restored=KanaTrifecta.State:Restore(saved,b.run.profile,context,{nowMs=10,nowWallSec=3000})
  local view=restored:View(500000);assert(view.timer.stopped);assert(view.timer.text=='04:00');assert(view.deaths.colorRole=='error');assert(view.bossRows[1].colorRole=='error')
  assert(view.assessment=='failed');assert(restored.bosses.a.modeEvidence.source=='bossMaxHealth')
 end,
 late_join_does_not_invent_history=function()
  local b=setup('unknown');b.observer:Handle({kind='combatState',inCombat=true,atMs=0})
  assert(b.run.clock.localObservation and b.run.clock.unboundedStart)
  unit(b,'a',10,true,1000);assert(b.run:View(5000).timer.text=='24:55');assert(b.run:View(5000).deaths.text=='0')
  b.observer:Emit('AchievementAwarded',{id=1,historical=true},2000);assert(not next(b.run.serverConfirmations))
 end,
}
