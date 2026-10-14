local T=dofile('KanaStatSources/tests/support.lua')
local K=T.load({'Core','Stats','Rules','Critical','Model','capture/Equipment','capture/Build','capture/Effects','Snapshot','Dump'})
local makeApi=dofile('KanaStatSources/tests/fixtures/capture.lua')
local function archiveApi()
    local api=makeApi()
    api.IsInstanceEndlessDungeon=function()return true end
    api.IsEndlessDungeonStarted=function()return true end
    api.IsEndlessDungeonCompleted=function()return false end
    api.GetNextEndlessDungeonVisionAbilityAndStackCount=function(previous)
        if previous==nil then return 200686,2 end
        if previous==200686 then return 201414,1 end
    end
    api.GetNumEndlessDungeonActiveVerses=function()return 1 end
    api.GetEndlessDungeonActiveVerseAbility=function(index)T.eq(index,1);return 90001 end
    api.GetAbilityName=function(id)return 'Buff '..id end
    api.GetAbilityIcon=function(id)return 'icon:'..id end
    local original=api.GetAbilityDescription
    api.GetAbilityDescription=function(id,rank,caster)
        if id==200686 or id==201414 or id==90001 then
            T.eq(rank,nil);T.eq(caster,'player');return 'Current bonus for '..id
        end
        return original(id,rank,caster)
    end
    return api
end
return {
 full_dump_records_current_archive_sources_separately_from_unit_buffs=function()
    local s=K.Snapshot.New(archiveApi()):Capture(true)
    T.eq(s.archiveContext.inDungeon,true);T.eq(s.archiveContext.started,true);T.eq(s.archiveContext.completed,false)
    T.eq(#s.archiveBuffs,3);T.eq(s.archiveBuffs[1].id,200686);T.eq(s.archiveBuffs[1].stacks,2)
    T.eq(s.archiveBuffs[1].kind,'vision');T.eq(s.archiveBuffs[1].name,'Buff 200686')
    T.eq(s.archiveBuffs[1].description,'Current bonus for 200686');T.eq(s.archiveBuffs[1].icon,'icon:200686')
    T.eq(s.archiveBuffs[2].id,201414);T.eq(s.archiveBuffs[3].id,90001);T.eq(s.archiveBuffs[3].kind,'verse')
    T.eq(s.archiveBuffs[3].stacks,1);T.eq(s.categoryStatus.archiveAudit,'available')
    local report=K.Dump.Build(s,{}, {}, {})
    T.eq(report.snapshot.archiveBuffs[1].stacks,2)
 end,
 archive_audit_does_not_run_on_hover=function()
    local api=archiveApi();api.GetNextEndlessDungeonVisionAbilityAndStackCount=function()error('audit ran on hover')end
    local s=K.Snapshot.New(api):Capture(false)
    T.eq(s.archiveBuffs,nil);T.eq(s.categoryStatus.archiveAudit,nil)
 end,
 completed_or_inactive_archives_do_not_record_lifetime_buffs_as_active=function()
    for _,fn in ipairs({'IsInstanceEndlessDungeon','IsEndlessDungeonStarted','IsEndlessDungeonCompleted'})do
        local api=archiveApi();api[fn]=function()return fn=='IsEndlessDungeonCompleted' end
        api.GetNextEndlessDungeonVisionAbilityAndStackCount=function()error('stale buff was queried')end
        local s=K.Snapshot.New(api):Capture(true)
        T.eq(#s.archiveBuffs,0);T.eq(s.categoryStatus.archiveAudit,'available')
    end
 end,
 archive_iterator_cycle_is_bounded_and_diagnostic=function()
    local api=archiveApi();api.GetNextEndlessDungeonVisionAbilityAndStackCount=function()return 200686,2 end
    local s=K.Snapshot.New(api):Capture(true)
    T.eq(#s.archiveBuffs,1);T.eq(s.categoryStatus.archiveAudit,'partial');T.eq(s.stats.maxHealth.total,101)
 end,
 invalid_archive_counts_do_not_discard_the_rest_of_the_snapshot=function()
    local api=archiveApi();api.GetNumEndlessDungeonActiveVerses=function()return math.huge end
    local s=K.Snapshot.New(api):Capture(true)
    T.eq(#s.archiveBuffs,2);T.eq(s.categoryStatus.archiveAudit,'partial');T.eq(s.stats.maxHealth.total,101)
 end,
 unavailable_optional_archive_api_preserves_ordinary_snapshots=function()
    local s=K.Snapshot.New(makeApi()):Capture(true)
    T.eq(#s.archiveBuffs,0);T.eq(s.archiveContext.inDungeon,nil);T.eq(s.stats.maxHealth.total,101)
    T.eq(s.capabilities.IsInstanceEndlessDungeon,false);T.eq(s.categoryStatus.archiveAudit,'partial')
 end,
}
