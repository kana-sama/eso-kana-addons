local F=dofile('KanaTrifecta/tests/fixtures.lua')
return {
 hm_wipe_then_normal_kill=function()
    local r=F.NewRun();F.Pull(r,'a','old','active',0);F.Pull(r,'a','new','inactive',100)
    F.Kill(r,'a',200,'new');assert(r.bosses.a.state=='failed')
 end,
 normal_wipe_then_hm_kill=function()
    local r=F.NewRun();F.Pull(r,'a','old','inactive');F.Pull(r,'a','new','active',100)
    F.Kill(r,'a',200,'new');assert(r.bosses.a.state=='completed')
 end,
 kill_unknown_hm_and_non_hm_boss=function()
    local r=F.NewRun();F.Kill(r,'a',100);assert(r.bosses.a.state=='unknown')
    local s=F.NewRun({bosses={{key='a',name='a',requiresHardMode=false}}})
    F.Kill(s,'a',100);assert(s.bosses.a.state=='completed')
 end,
 phase_does_not_kill=function()
    local r=F.NewRun();F.Pull(r,'a','phase','active')
    F.Emit(r,'BossKilled',{bossKey='a',pullId='phase',terminal=false},100)
    assert(not r.bosses.a.killed);assert(r.bosses.a.state=='pending')
 end,
 old_pull_and_conflicting_modes=function()
    local r=F.NewRun();F.Pull(r,'a','old','active');F.Pull(r,'a','new','inactive',100)
    F.Emit(r,'HardModeObserved',{bossKey='a',pullId='old',mode='active'},200)
    F.Kill(r,'a',300,'new');assert(r.bosses.a.state=='failed')
    F.Emit(r,'HardModeObserved',{bossKey='a',pullId='new',mode='active'},400)
    assert(r.bosses.a.state=='unknown')
 end,
 strong_late_confirmation_corrects_same_kill=function()
    local r=F.NewRun();F.Pull(r,'a','p','inactive');F.Kill(r,'a',100,'p')
    F.Emit(r,'HardModeObserved',{bossKey='a',pullId='p',mode='active',priority=2},200)
    assert(r.bosses.a.state=='completed')
 end,
 failure_does_not_prevent_clock_stop=function()
    local r=F.NewRun();F.Start(r);F.Pull(r,'a','p','inactive');F.Kill(r,'a',100,'p')
    F.Kill(r,'b',200);F.Kill(r,'c',300);local v=r:View(1000)
    assert(v.timer.stopped);assert(v.bossRows[1].colorRole=='error');assert(v.assessment=='failed')
 end,
}
