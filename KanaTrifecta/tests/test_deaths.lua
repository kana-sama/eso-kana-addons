local F=dofile('KanaTrifecta/tests/fixtures.lua')
return {
 same_member_two_tags=function()
    local r=F.NewRun();F.Start(r);F.Member(r,'@one#char',false)
    F.Emit(r,'MemberDied',{memberKey='@one#char',transitionId=1,unitTag='player'},100)
    F.Emit(r,'MemberDied',{memberKey='@one#char',transitionId=1,unitTag='group2'},100)
    assert(r:View(100).deaths.count==1);assert(r:View(100).deaths.colorRole=='error');assert(r:View(100).timer.colorRole=='normal')
 end,
 duplicate_corpse_and_revive_then_die=function()
    local r=F.NewRun();F.Member(r,'one',false)
    F.Emit(r,'MemberDied',{memberKey='one'},100);F.Member(r,'one',true,200)
    assert(r.deathCount==1);F.Emit(r,'MemberRevived',{memberKey='one'},300)
    F.Emit(r,'MemberDied',{memberKey='one'},400);assert(r.deathCount==2)
 end,
 reordered_group=function()
    local r=F.NewRun();F.Member(r,'one',false);F.Emit(r,'MemberDied',{memberKey='one'},100)
    F.Emit(r,'MemberObserved',{memberKey='one',unitTag='group3',inInstance=true,human=true,isDead=true},200)
    assert(r.deathCount==1)
 end,
 outside_member_companion_pet=function()
    local r=F.NewRun()
    for _,p in ipairs({{memberKey='away',inInstance=false,human=true,isDead=true},
        {memberKey='pet',inInstance=true,human=false,isDead=true}}) do F.Emit(r,'MemberObserved',p) end
    assert(r.deathCount==0)
 end,
 gap_preserves_lower_bound=function()
    local r=F.NewRun();F.Emit(r,'CoverageLost',{deaths=true});assert(r:View(0).deaths.text=='0')
    F.Member(r,'one',false);F.Emit(r,'MemberDied',{memberKey='one'},100)
    assert(r:View(100).deaths.text=='1');F.Member(r,'one',false,200);assert(r.deathCoverage~='full')
 end,
 initial_dead_without_window_is_unknown=function()
    local r=F.NewRun(nil,{runKey='late',contextGeneration=1,freshness='unknown'})
    F.Member(r,'one',true);assert(r.deathCount==0);assert(r.deathCoverage~='full')
 end,
 deaths_before_start_and_after_clock_stop=function()
    local r=F.NewRun();F.Member(r,'one',false);F.Emit(r,'MemberDied',{memberKey='one'},10)
    F.Start(r,20);assert(r.deathCount==1);F.Emit(r,'MemberRevived',{memberKey='one'},30)
    F.Kill(r,'a',100);F.Kill(r,'b',200);F.Kill(r,'c',300)
    F.Emit(r,'MemberDied',{memberKey='one'},400);assert(r.deathCount==2)
    F.Emit(r,'RunCompleted',{},500);F.Emit(r,'MemberRevived',{memberKey='one'},600)
    F.Emit(r,'MemberDied',{memberKey='one'},700);assert(r.deathCount==2)
 end,
}
