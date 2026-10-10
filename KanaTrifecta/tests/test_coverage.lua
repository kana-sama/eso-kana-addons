local F=dofile('KanaTrifecta/tests/fixtures.lua')
KanaTrifecta.Profiles.items={};KanaTrifecta.Profiles.zones={}
dofile('KanaTrifecta/profiles/catalog.lua');dofile('KanaTrifecta/profiles/coral_aerie.lua')
return {
 catalogue_complete_and_unique=function()
  assert(#KanaTrifecta.Profiles:List()>=58,'catalogue incomplete');local seen={}
  for _,p in ipairs(KanaTrifecta.Profiles:List()) do
   for _,zone in ipairs(p.zoneIds) do assert(not seen[zone]);seen[zone]=true end
   assert(p.activityType=='dungeon');assert(p.supportStatus~='validated');assert(p.limitMs>0)
   assert(#p.achievementCatalogIds>0);assert(#p.bosses>0)
  end
 end,
 profile_source_and_unknown_start=function()
  local p=KanaTrifecta.Profiles:Find(1301,2);assert(p.bosses[3].healthModes[13195414]=='active')
  assert(not KanaTrifecta.Profiles:Find(1301,1));assert(not KanaTrifecta.Profiles:Find(1000,2))
 end,
}
