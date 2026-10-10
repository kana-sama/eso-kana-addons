dofile('KanaTrifecta/Run.lua')
dofile('KanaTrifecta/lang/en.lua')
dofile('KanaTrifecta/lang/ru.lua')
dofile('KanaTrifecta/Profiles.lua')
dofile('KanaTrifecta/Diagnostics.lua')
dofile('KanaTrifecta/Observer.lua')
dofile('KanaTrifecta/State.lua')
dofile('KanaTrifecta/Hud.lua')
dofile('KanaTrifecta/Achievements.lua')
dofile('KanaTrifecta/Settings.lua')
dofile('KanaTrifecta/Bootstrap.lua')
local F = {}
function F.NewRun(overrides, context)
    local p = {key='fixture', version=1, activityType='dungeon', zoneIds={1301},
        name={en='Fixture', ru='Пример'}, limitMs=1500000, deadlineRule='atOrBefore',
        supportStatus='validated', bosses={}}
    for _, key in ipairs({'a','b','c'}) do
        p.bosses[#p.bosses+1] = {key=key, name={en=key,ru=key}, hasHardMode=true, requiresHardMode=true}
    end
    for k,v in pairs(overrides or {}) do p[k]=v end
    context = context or {runKey='run1',contextGeneration=1,zoneId=1301,difficulty=2,language='en',freshness='fresh'}
    return KanaTrifecta.Run.New(p,context)
end
function F.Emit(run, kind, payload, atMs, key, generation)
    F.serial = (F.serial or 0)+1
    return run:Apply({kind=kind,key=key or ('event'..F.serial),
        contextGeneration=generation or 1,atMs=atMs or 0,wallSec=1000+(atMs or 0)/1000,
        payload=payload or {},evidence={source='fixture'}})
end
function F.Start(run, atMs) F.Emit(run,'RunStarted',{},atMs or 0) end
function F.Pull(run, boss, pull, mode, atMs)
    F.Emit(run,'PullStarted',{bossKey=boss,pullId=pull},atMs)
    if mode then F.Emit(run,'HardModeObserved',{bossKey=boss,pullId=pull,mode=mode},atMs) end
end
function F.Kill(run, boss, atMs, pull)
    pull = pull or 'pull-'..boss
    if not run.bosses[boss].pullId then F.Pull(run,boss,pull,nil,(atMs or 0)-1) end
    F.Emit(run,'BossKilled',{bossKey=boss,pullId=pull,terminal=true},atMs)
end
function F.Member(run, key, dead, atMs)
    F.Emit(run,'MemberObserved',{memberKey=key,isDead=dead or false,inInstance=true,human=true},atMs)
end
return F
