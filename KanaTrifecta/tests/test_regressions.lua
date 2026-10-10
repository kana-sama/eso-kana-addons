local F=dofile('KanaTrifecta/tests/fixtures.lua')
return {
 returning_to_progressed_zone_is_not_fresh=function()
  local p=F.NewRun().profile
  assert(KanaTrifecta.Profiles.ClassifyFresh(p,{profileKey=p.key},{freshEntry=true})=='unknown')
 end,
 saved_kill_times_share_restored_clock=function()
  local r=F.NewRun();F.Start(r,0);F.Kill(r,'a',100000)
  local saved=KanaTrifecta.State:Save(r,{nowMs=300000,nowWallSec=1300})
  local restored=KanaTrifecta.State:Restore(saved,r.profile,{freshness='same',contextGeneration=1}, {nowMs=10,nowWallSec=1310})
  F.Kill(restored,'b',10010);F.Kill(restored,'c',20010)
  assert(restored:View(900000).timer.text=='~19:30')
 end,
 required_hardmodes_have_icons=function()
  KanaTrifecta.Profiles.items={};KanaTrifecta.Profiles.zones={};dofile('KanaTrifecta/profiles/catalog.lua')
  local p=KanaTrifecta.Profiles:Find(1302,2);assert(p)
  for _,b in ipairs(p.bosses) do assert(b.hasHardMode,'required HM icon missing') end
 end,
}
