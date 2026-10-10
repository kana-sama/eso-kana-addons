local F=dofile('KanaTrifecta/tests/fixtures.lua')
local function succeed(r)
    F.Start(r);for i,k in ipairs({'a','b','c'}) do F.Pull(r,k,k,'active',i*100);F.Kill(r,k,i*100+50,k) end
end
return {
 complete_observed_requires_all_conditions=function()
    local r=F.NewRun();succeed(r);assert(r:View(1000).assessment=='possible')
    F.Emit(r,'RunCompleted',{},1000);assert(r:View(1000).assessment=='fulfilledObserved')
 end,
 unknown_additional_requirement=function()
    local r=F.NewRun({additionalRequirements={'trash'}});succeed(r);F.Emit(r,'RunCompleted',{},1000)
    assert(r:View(1000).assessment=='unknown');assert(r.clock.stopped)
 end,
 proven_failure_wins_over_gaps=function()
    local r=F.NewRun();F.Member(r,'one',false);F.Emit(r,'MemberDied',{memberKey='one'})
    F.Emit(r,'CoverageLost',{deaths=true,time=true});assert(r:View(0).assessment=='failed')
 end,
 historical_achievement_does_not_finish=function()
    local r=F.NewRun({achievementIds={trifecta=999}})
    F.Emit(r,'AchievementAwarded',{id=999,historical=true});assert(r.lifecycle=='ready');assert(not r.clock.stopped)
    F.Emit(r,'AchievementAwarded',{id=999});assert(r.serverConfirmations[999]);assert(not r.clock.stopped)
 end,
}
