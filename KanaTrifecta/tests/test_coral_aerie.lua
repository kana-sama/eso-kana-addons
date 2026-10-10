local F=dofile('KanaTrifecta/tests/fixtures.lua')
dofile('KanaTrifecta/profiles/catalog.lua');dofile('KanaTrifecta/profiles/coral_aerie.lua')
local function signal(r,s)
    for _,e in ipairs(KanaTrifecta.Profiles:Observe(r.profile,s,{contextGeneration=1,language='en'},r:Snapshot())) do
        F.Emit(r,e.kind,e.payload,e.atMs or s.atMs,nil,1)
    end
end
return {
 source_backed_varallion_health=function()
    local p=KanaTrifecta.Profiles:Find(1301,2);assert(#p.bosses==3,'Coral boss profile missing')
    local r=KanaTrifecta.Run.New(p,{runKey='ca',contextGeneration=1,language='en',freshness='fresh'})
    signal(r,{kind='combatState',inCombat=true,atMs=0})
    signal(r,{kind='bossSnapshot',units={{name='Varallion',health=12000000,maxHealth=13195414,inCombat=true}},atMs=100})
    signal(r,{kind='bossSnapshot',units={{name='Varallion',health=0,maxHealth=13195414,isDead=true}},atMs=200})
    assert(r.bosses.varallion.state=='completed')
 end,
 normal_health_and_unknown_health=function()
    local p=KanaTrifecta.Profiles:Find(1301,2);assert(#p.bosses==3,'Coral boss profile missing')
    for _,c in ipairs({{6766879,'failed'},{9000000,'unknown'}}) do
        local r=KanaTrifecta.Run.New(p,{runKey='ca',contextGeneration=1,language='en',freshness='fresh'})
        signal(r,{kind='bossSnapshot',units={{name='Varallion',health=c[1],maxHealth=c[1],inCombat=true}},atMs=100})
        signal(r,{kind='bossSnapshot',units={{name='Varallion',health=0,maxHealth=c[1],isDead=true}},atMs=200})
        assert(r.bosses.varallion.state==c[2])
    end
 end,
 disappearance_is_not_kill_and_last_required_stops=function()
    local p=KanaTrifecta.Profiles:Find(1301,2);assert(#p.bosses==3,'Coral boss profile missing')
    local r=KanaTrifecta.Run.New(p,{runKey='ca',contextGeneration=1,language='en',freshness='fresh'})
    signal(r,{kind='combatState',inCombat=true,atMs=0})
    for i,name in ipairs({'Maligalig','Sarydil','Varallion'}) do
        signal(r,{kind='bossSnapshot',units={{name=name,health=1,maxHealth=9000000,inCombat=true}},atMs=i*100})
        signal(r,{kind='bossSnapshot',units={},atMs=i*100+10});assert(not r.clock.stopped)
        signal(r,{kind='bossSnapshot',units={{name=name,health=0,maxHealth=9000000,isDead=true}},atMs=i*100+20})
    end
    assert(r.clock.stopped);assert(r.clock.stoppedElapsedMs==320)
 end,
 first_engagement_tracks_local_time_after_late_join=function()
    local p=KanaTrifecta.Profiles:Find(1301,2);assert(p.Observe,'Coral observer missing')
    local r=KanaTrifecta.Run.New(p,{runKey='late',contextGeneration=1,language='en',freshness='unknown'})
    signal(r,{kind='combatState',inCombat=true,atMs=100})
    assert(r.clock.quality=='estimated' and r.clock.localObservation and r.clock.unboundedStart)
    assert(r:View(1100).timer.text=='24:59');assert(r:View(1100).assessment=='unknown')
 end,
}
