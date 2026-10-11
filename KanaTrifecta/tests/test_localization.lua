local F=dofile('KanaTrifecta/tests/fixtures.lua')
return {
 canonical_client_names_recognize_encounters_with_source_spelling_errors=function()
  dofile('KanaTrifecta/profiles/catalog.lua')
  for _,case in ipairs({{31,'Treethane Kerninn','boss_1'},{131,'Commodore Ohmanil','boss_5'}}) do
   local p=KanaTrifecta.Profiles:Find(case[1],2);local c={contextGeneration=1,language='en',freshness='fresh'}
   local r=KanaTrifecta.Run.New(p,c)
   for _,e in ipairs(KanaTrifecta.Profiles:Observe(p,{kind='bossSnapshot',atMs=100,
    units={{name=case[2]..'^M',isDead=true,tag='boss1'}}},c,r:Snapshot())) do
    e.contextGeneration=1;r:Apply(e)
   end
   assert(r.bosses[case[3]].killed,'Client spelling must recognize '..case[2])
  end
 end,
 all_catalogue_titles_and_bosses_have_russian_display_and_matching=function()
  dofile('KanaTrifecta/profiles/catalog.lua');dofile('KanaTrifecta/profiles/coral_aerie.lua')
  for _,p in ipairs(KanaTrifecta.Profiles:List()) do
   local c={contextGeneration=1,freshness='fresh',language='ru'};local r=KanaTrifecta.Run.New(p,c)
   local v=r:View(0)
   assert(p.name.ru and v.title==p.name.ru and v.title:find('[\208\209]'),'Missing Russian dungeon: '..p.key)
   for i,def in ipairs(p.bosses) do
    local name=v.bossRows[i].name
    assert(def.name.ru and name==def.name.ru and name:find('[\208\209]') and not name:find('[A-Za-z]'),
     'Missing Russian boss: '..p.key..'/'..def.key)
    for _,e in ipairs(KanaTrifecta.Profiles:Observe(p,{kind='bossSnapshot',atMs=i*100,
     units={{name=name..'^M',isDead=true,tag='boss1'}}},c,r:Snapshot())) do
     e.contextGeneration=1;r:Apply(e)
    end
    assert(r.bosses[def.key].killed,'Russian name must identify its own encounter: '..p.key..'/'..def.key)
   end
  end
 end,
 wayrest_names_use_client_localization=function()
  dofile('KanaTrifecta/profiles/catalog.lua')
  local p=KanaTrifecta.Profiles:Find(146,2)
  local r=KanaTrifecta.Run.New(p,{contextGeneration=1,language='ru',freshness='fresh'})
  local expected={'Слизебрюх','Следователь Гаррон','Улгарг Голодный','Крысиный Шептун','Варейн Пеллингар','Аллин Пеллингар'}
  local v=r:View(0);assert(v.title=='Канализация Вэйреста I')
  for i,name in ipairs(expected) do assert(v.bossRows[i].name==name) end
 end,
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
