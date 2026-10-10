local F=dofile('KanaTrifecta/tests/fixtures.lua')
local S=dofile('KanaTrifecta/tests/ui_stubs.lua')
return {
 kill_event_expands_previously_empty_time_label_immediately=function()
  local a=S.api();local b=KanaTrifecta.Bootstrap.New(a)
  local now=0;a.GetGameTimeMilliseconds=function() return now end
  b.generation=1;b.context={contextGeneration=1};b.run=F.NewRun();F.Start(b.run,0)
  b.hud=KanaTrifecta.Hud.New(a,function() end);b.hud.root:SetHidden(false);b:UpdateView()
  local label=b.hud.rows[1].killTime
  -- Native GetTextWidth measures laid-out text within the existing label width.
  label.GetTextWidth=function(c) return math.min(#(c.text or '')*10,c:GetWidth()) end
  assert(label.hidden and label:GetWidth()==1)
  F.Pull(b.run,'a','first');now=73000
  b:Apply({kind='BossKilled',contextGeneration=1,atMs=now,
   payload={bossKey='a',pullId='first',terminal=true}})
  assert(label.text=='01:13' and not label.hidden)
  assert(label:GetWidth()>=50,'Time must fit all five characters without reload')
  now=80000;b:UpdateView();assert(label:GetWidth()>=50)
 end,

 disabled_preference_survives_initialization_without_menu_library=function()
  local a=S.api();local b=KanaTrifecta.Bootstrap.New(a)
  b.saved={settings={showBossKillTimes=false}};KanaTrifecta.Settings.Initialize(b)
  b.hud=KanaTrifecta.Hud.New(a,function() end,b.settings)
  local r=F.NewRun();F.Start(r,0);F.Kill(r,'a',73000)
  b.hud:SetVisible(true);b.hud:Render(r:View(100000))
  assert(b.hud.rows[1].killTime.hidden and b.settings.showBossKillTimes==false)
 end,

 kill_time_is_elapsed_from_start_and_stays_fixed=function()
  local r=F.NewRun();F.Start(r,10000);F.Kill(r,'a',83000)
  assert(r:View(100000).bossRows[1].killTimeText=='01:13')
  assert(r:View(500000).bossRows[1].killTimeText=='01:13')
  assert(r:View(500000).bossRows[2].killTimeText==nil)
 end,
 killed_before_observed_start_has_no_invented_timestamp=function()
  local r=F.NewRun();F.Kill(r,'a',1000)
  assert(r:View(2000).bossRows[1].killTimeText==nil)
  F.Start(r,3000);assert(r:View(4000).bossRows[1].killTimeText==nil)
 end,
 elapsed_kill_times_survive_running_and_stopped_reload=function()
  for _,stopped in ipairs({false,true}) do
   local r=F.NewRun();F.Start(r,10000);F.Kill(r,'a',83000)
   if stopped then F.Kill(r,'b',100000);F.Kill(r,'c',120000) end
   local saved=KanaTrifecta.State:Save(r,{nowMs=120000,nowWallSec=1120})
   local restored=KanaTrifecta.State:Restore(saved,r.profile,
    {contextGeneration=2,freshness='same',language='en'},{nowMs=10,nowWallSec=1121})
   assert(restored:View(2000).bossRows[1].killTimeText=='01:13')
   if stopped then assert(restored:View(2000).bossRows[3].killTimeText=='01:50') end
  end
 end,
 setting_updates_visible_times_without_losing_kills_or_scrolling=function()
  local a=S.api();local options
  a.LibAddonMenu2={RegisterAddonPanel=function() return {} end,
   RegisterOptionControls=function(_,name,controls) options=controls end}
  local b=KanaTrifecta.Bootstrap.New(a);b.saved={};b.generation=1;b.context={contextGeneration=1}
  b.run=F.NewRun();F.Start(b.run,0);F.Kill(b.run,'a',73000)
  a.GetGameTimeMilliseconds=function() return 100000 end
  KanaTrifecta.Settings.Initialize(b)
  b.hud=KanaTrifecta.Hud.New(a,function() end,b.settings);b.hud.root:SetHidden(false);b:UpdateView()
  assert(b.hud.rows[1].killTime.text=='01:13' and not b.hud.rows[1].killTime.hidden)
  assert(options[1].getFunc()==true)
  options[1].setFunc(false)
  assert(b.saved.settings.showBossKillTimes==false and b.hud.rows[1].killTime.hidden)
  assert(b.run.bosses.a.killed)
  options[1].setFunc(true);assert(not b.hud.rows[1].killTime.hidden)
  b.hud:Relayout(180,110);assert(b.hud.scrollChild:GetHeight()>b.hud.scroll:GetHeight())
  assert(b.hud.rows[1].label.anchor[4]==0)
 end,
}
