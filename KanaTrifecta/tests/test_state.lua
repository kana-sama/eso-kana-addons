local F=dofile('KanaTrifecta/tests/fixtures.lua')
local clocks={nowMs=300000,nowWallSec=1300,monotonicContinuous=false}
local function setup()
    assert(KanaTrifecta.State,'State not implemented')
    local r=F.NewRun();F.Start(r,0)
    local c={runKey='run1',contextGeneration=2,zoneId=1301,freshness='same',language='en'}
    return r,c,KanaTrifecta.State
end
return {
 reload_running_keeps_start=function()
    local r,c,s=setup();local saved=s:Save(r,clocks)
    local result=s:Restore(saved,r.profile,c,{nowMs=100,nowWallSec=1310,monotonicContinuous=false})
    local v=result:View(100);assert(v.timer.text=='~19:50');assert(result.clock.startedAtWallSec==1000)
    assert(result.clock.rangeOffsetMs[1]==-1000);assert(result.clock.rangeOffsetMs[2]==1000)
    assert(result.deathCoverage=='partial')
 end,
 reload_stopped_keeps_04_00=function()
    local r,c,s=setup();F.Kill(r,'a',100);F.Kill(r,'b',200);F.Kill(r,'c',1260000)
    local saved=s:Save(r,{nowMs=1300000,nowWallSec=2300})
    local result=s:Restore(saved,r.profile,c,{nowMs=10,nowWallSec=3000})
    assert(result:View(1000000).timer.text=='04:00');assert(result.clock.stopped)
 end,
 reload_stopped_overtime_keeps_05_00=function()
    local r,c,s=setup();F.Kill(r,'a',100);F.Kill(r,'b',200);F.Kill(r,'c',1800000)
    local saved=s:Save(r,{nowMs=2000000,nowWallSec=3000})
    local result=s:Restore(saved,r.profile,c,{nowMs=10,nowWallSec=5000})
    assert(result:View(999999).timer.text=='05:00');assert(result:View(999999).deaths.colorRole=='error')
 end,
 context_and_profile_mismatch=function()
    local r,c,s=setup();local saved=s:Save(r,clocks);c.freshness='unknown'
    assert(s:Restore(saved,r.profile,c,clocks)==nil);c.freshness='same';saved.profileVersion=99
    assert(s:Restore(saved,r.profile,c,clocks)==nil)
 end,
 wall_clock_backwards_preserves_facts=function()
    local r,c,s=setup();F.Kill(r,'a',100);local saved=s:Save(r,clocks)
    local result=s:Restore(saved,r.profile,c,{nowMs=10,nowWallSec=1200})
    assert(result.clock.quality=='unknown');assert(result.bosses.a.killed)
 end,
 estimated_range_crosses_deadline=function()
    local r,c,s=setup();local saved=s:Save(r,{nowMs=1490000,nowWallSec=2490})
    local result=s:Restore(saved,r.profile,c,{nowMs=10,nowWallSec=2500})
    assert(result:View(10).timer.colorRole=='hint');assert(result:View(10).assessment=='unknown')
 end,
 reload_invalidates_unfinished_pool=function()
    local r,c,s=setup();F.Pull(r,'a','before','active',100)
    local saved=s:Save(r,clocks);local result=s:Restore(saved,r.profile,c,{nowMs=10,nowWallSec=1310})
    assert(result.bosses.a.mode=='unknown');assert(not result.bosses.a.pullActive)
 end,
 malformed_snapshot_rejected=function()
    local r,c,s=setup();local saved=s:Save(r,clocks);saved.clock='corrupt'
    assert(s:Restore(saved,r.profile,c,clocks)==nil)
 end,
}
