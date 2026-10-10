local K=KanaTrifecta
local State={};K.State=State
function State:Save(run,clocks)
    local saved=run:Snapshot()
    local view=run:View(clocks.nowMs)
    saved.sample={gameMs=clocks.nowMs,wallSec=clocks.nowWallSec,elapsedMs=view.timer.elapsedMs}
    if view.failureReasons.time then saved.failureReasons.time=true end
    return saved
end
function State:Restore(saved,profile,context,clocks)
    if type(saved)~='table' or saved.schemaVersion~=1 or saved.profileKey~=profile.key
        or saved.profileVersion~=profile.version or context.freshness~='same'
        or type(saved.clock)~='table' or type(saved.bosses)~='table'
        or type(saved.members)~='table' or type(saved.deathCount)~='number'
        or type(saved.failureReasons)~='table' or type(saved.sample)~='table' then return nil end
    for _,def in ipairs(profile.bosses or {}) do
        if type(saved.bosses[def.key])~='table' then return nil end
    end
    local run=K.Run.New(profile,context)
    for _,key in ipairs({'runKey','lifecycle','clock','deathCount','deathCoverage','members','bosses',
        'additionalConditions','failureReasons','serverConfirmations','seen','deathWindowOpen'}) do
        if saved[key]~=nil then run[key]=K.Copy(saved[key]) end
    end
    if run.lifecycle=='suspended' then run.lifecycle=run.clock.startedAtMs and 'running' or 'observing' end
    if run.deathWindowOpen and run.deathCoverage=='full' then run.deathCoverage='partial' end
    for _,boss in pairs(run.bosses) do
        if not boss.killed then
            boss.mode='unknown';boss.modePriority=nil;boss.pullActive=false;boss.pullId=nil;boss.coverageLost=true
        end
    end
    local clock,sample=run.clock,saved.sample
    if not clock.stopped then
        local gap=type(sample.wallSec)=='number' and clocks.nowWallSec-sample.wallSec or -1
        if type(sample.elapsedMs)=='number' and gap>=0 then
            local spread=clock.rangeOffsetMs and math.max(math.abs(clock.rangeOffsetMs[1]),math.abs(clock.rangeOffsetMs[2])) or 0
            clock.startedAtMs=clocks.nowMs-sample.elapsedMs-gap*1000
            if clocks.monotonicContinuous then
                clock.startedAtMs=clocks.nowMs-sample.elapsedMs-(clocks.nowMs-sample.gameMs)
            else
                clock.quality='estimated';clock.rangeOffsetMs={-spread-1000,spread+1000}
            end
        else clock.quality='unknown';clock.startedAtMs=nil;run.lifecycle='observing' end
    end
    if not clock.stopped and clock.startedAtMs and type(saved.clock.startedAtMs)=='number' then
        for _,boss in pairs(run.bosses) do
            if boss.killed and type(boss.killedAtMs)=='number' then
                boss.originalKilledAtMs=boss.originalKilledAtMs or boss.killedAtMs
                boss.killedAtMs=clock.startedAtMs+(boss.killedAtMs-saved.clock.startedAtMs)
            end
        end
    end
    return run
end
