local F=dofile('KanaTrifecta/tests/fixtures.lua')
return {
 fungal_grotto_names_and_kills_follow_client_language=function()
  dofile('KanaTrifecta/profiles/catalog.lua')
  local p=KanaTrifecta.Profiles:Find(283,2)
  local russian={'Тазкад Вожак Стаи','Вождь Озозай','Мать выводка','Щелкун','Кра’гх Король Дреугов'}
  for _,language in ipairs({'ru','en'}) do
   local c={contextGeneration=1,freshness='fresh',language=language};local r=KanaTrifecta.Run.New(p,c)
   local v=r:View(0)
   for i,def in ipairs(p.bosses) do
    local name=language=='ru' and russian[i] or def.name.en
    assert(v.bossRows[i].name==name,'Missing '..language..' boss name: '..def.key)
    local events=KanaTrifecta.Profiles:Observe(p,{kind='bossSnapshot',atMs=i*100,units={{name=name..'^M',isDead=true,tag='boss1'}}},c,r:Snapshot())
    for _,e in ipairs(events) do e.contextGeneration=1;r:Apply(e) end
    assert(r.bosses[def.key].killed,'Localized death must match '..def.key)
   end
  end
 end,
}
