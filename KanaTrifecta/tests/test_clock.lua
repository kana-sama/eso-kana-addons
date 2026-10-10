local F=dofile('KanaTrifecta/tests/fixtures.lua')
return {
 countdown_and_boundary=function()
    local r=F.NewRun(); assert(r:View(0).timer.text=='25:00'); F.Start(r)
    for _, c in ipairs({{300000,'20:00','normal'},{1499999,'00:01','normal'},
        {1500000,'00:00','normal'},{1500001,'00:00','error'},
        {1501000,'00:01','error'},{1800000,'05:00','error'},{5160000,'61:00','error'}}) do
        local v=r:View(c[1]);assert(v.timer.text==c[2]);assert(v.timer.colorRole==c[3])
        if c[3]=='error' then assert(v.deaths.colorRole=='error') end
    end
 end,
 stops_after_all_required_kills=function()
    local r=F.NewRun();F.Start(r);F.Kill(r,'a',400000);F.Kill(r,'b',800000)
    assert(not r:View(1200000).timer.stopped);F.Kill(r,'c',1260000)
    local v=r:View(1800000);assert(v.timer.stopped);assert(v.timer.text=='04:00');assert(v.timer.colorRole=='normal')
 end,
 overtime_freezes=function()
    local r=F.NewRun();F.Start(r);F.Kill(r,'a',600000);F.Kill(r,'b',1200000);F.Kill(r,'c',1800000)
    assert(r:View(2400000).timer.text=='05:00');assert(r:View(2400000).deaths.colorRole=='error')
 end,
 strict_deadline=function()
    local r=F.NewRun({deadlineRule='before'});F.Start(r)
    assert(r:View(1500000).timer.colorRole=='normal')
    F.Kill(r,'a',100);F.Kill(r,'b',200);F.Kill(r,'c',1500000)
    assert(r:View(1500000).timer.colorRole=='error');assert(r:View(1500000).deaths.colorRole=='error')
 end,
 late_confirmation_uses_kill_time=function()
    local r=F.NewRun();F.Start(r);F.Kill(r,'c',1260000);F.Kill(r,'b',800000);F.Kill(r,'a',400000)
    assert(r:View(1800000).timer.text=='04:00')
 end,
 unknown_start_stays_unknown=function()
    local r=F.NewRun(nil,{runKey='late',contextGeneration=1,zoneId=1301,language='en',freshness='unknown'})
    F.Kill(r,'a',100);F.Kill(r,'b',200);F.Kill(r,'c',300)
    assert(r:View(400).timer.text=='--:--');assert(r:View(400).timer.stopped)
 end,
 start_once_and_old_context_ignored=function()
    local r=F.NewRun();F.Start(r,0);F.Start(r,300000)
    F.Emit(r,'BossKilled',{bossKey='a',pullId='x',terminal=true},100,'old',2)
    assert(r:View(300000).timer.text=='20:00');assert(r.bosses.a.state=='pending')
 end,
 snapshot_does_not_alias_model=function()
    local r=F.NewRun();local s=r:Snapshot();s.bosses.a.state='failed'
    assert(r.bosses.a.state=='pending')
 end,
 completion_does_not_stop_clock=function()
    local r=F.NewRun();F.Start(r);F.Emit(r,'RunCompleted',{},100)
    assert(not r:View(200).timer.stopped)
 end,
}
