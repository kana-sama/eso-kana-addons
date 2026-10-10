local F=dofile('KanaTrifecta/tests/fixtures.lua')
return {
 bounded_disabled_journal=function()
    assert(KanaTrifecta.Diagnostics,'Diagnostics not implemented')
    local d=KanaTrifecta.Diagnostics.New(512);d:Record({key='off'});assert(#d:Dump({}).events==0)
    d:SetEnabled(true);for i=1,600 do d:Record({key=i}) end
    local dump=d:Dump({bosses={a={killed=true}}});assert(#dump.events==512);assert(dump.events[1].key==89)
    assert(dump.snapshot.bosses.a.killed)
 end,
}
