local T=dofile('KanaStatSources/tests/support.lua')
local K=T.load({'Core','Stats','Rules','Critical','Model','capture/Equipment','capture/Build','capture/Effects','Snapshot'})
local makeApi=dofile('KanaStatSources/tests/fixtures/capture.lua')
return {
    captures_character_and_both_bars=function()
        local s=K.Snapshot.New(makeApi()):Capture(true)
        T.eq(s.consistent,true);T.eq(s.schemaVersion,1);T.eq(s.bars.back[3].abilityId,103)
        T.eq(s.effects[1].abilityId,1001);T.eq(s.effects[1].castByPlayer,false)
        T.eq(s.attributes.health.spent,10);T.eq(s.attributes.health.perPoint,120)
        T.eq(s.stats.maxHealth.total,101);T.eq(s.stats.maxHealth.withoutBonus,100)
        T.eq(s.equipment[1].armorRating,100);T.eq(s.meta.characterId,'123')
    end,
    category_error_does_not_erase_others=function()
        local api=makeApi();api.GetItemLinkArmorRating=function()error('unavailable') end
        local s=K.Snapshot.New(api):Capture(true)
        T.eq(s.stats.maxHealth.total,101);T.eq(#s.effects,1)
        assert(#s.errors>0);T.eq(s.equipment[1].armorRating,nil)
    end,
    one_retry_then_mark_unstable=function()
        local api=makeApi();local count=0
        api.GetActiveWeaponPairInfo=function() count=count+1;return count%2+1,false end
        local s=K.Snapshot.New(api):Capture(false)
        T.eq(s.consistent,false);T.eq(count,4)
    end,
    changing_total_is_detected=function()
        local api=makeApi();local n=0
        api.GetPlayerStat=function(id,opt) n=n+1;return n end
        T.eq(K.Snapshot.New(api):Capture(false).consistent,false)
    end,
    missing_api_is_explicit=function()
        local api=makeApi();api.GetPlayerStat=nil
        local s=K.Snapshot.New(api):Capture(false)
        T.eq(s.stats.maxHealth.total,nil);assert(#s.errors>0)
    end,
    build_is_cached_until_invalidated=function()
        local api=makeApi();local calls=0
        api.GetNumSkillTypes=function()calls=calls+1;return 0 end
        local c=K.Snapshot.New(api);c:Capture(false);c:Capture(false);T.eq(calls,1)
        c:Invalidate('build');c:Capture(false);T.eq(calls,2)
    end,
}
