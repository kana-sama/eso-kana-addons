local K=KanaStatSources
K.CaptureEffects={}
local fields={'name','startTime','endTime','buffSlot','stacks','icon','deprecatedBuffType','effectType','abilityType','statusEffectType','abilityId','canClickOff','castByPlayer'}
function K.CaptureEffects.Read(api,capabilities)
    local errors={};local read=K.Core.Reader(api,errors,capabilities)
    local data={effects={},context={}}
    for i=1,read('GetNumBuffs','player') or 0 do
        local values={read('GetUnitBuffInfo','player',i)};local e={index=i}
        for n,name in ipairs(fields) do e[name]=values[n] end
        if e.abilityId then
            e.description=read('GetAbilityDescription',e.abilityId,nil,'player')
            e.buffType=read('GetAbilityBuffType',e.abilityId,'player')
            e.mundusType=read('GetAbilityMundusStoneType',e.abilityId)
            e.derivedStats={}
            for n=1,read('GetAbilityNumDerivedStats',e.abilityId) or 0 do
                local stat,value=read('GetAbilityDerivedStatAndEffectByIndex',e.abilityId,n)
                e.derivedStats[#e.derivedStats+1]={id=stat,stat=K.Stats.KeyForId(api,stat),value=value}
            end
        end
        data.effects[#data.effects+1]=e
    end
    local c=data.context
    c.weaponPair,c.weaponSwapLocked=read('GetActiveWeaponPairInfo')
    c.bar=c.weaponPair==1 and 'front' or (c.weaponPair==2 and 'back' or nil)
    c.hotbarCategory=read('GetActiveHotbarCategory')
    if api.HOTBAR_CATEGORY_WEREWOLF and c.hotbarCategory==api.HOTBAR_CATEGORY_WEREWOLF then c.bar='werewolf' end
    for name,fn in pairs({level='GetUnitLevel',championPoints='GetUnitChampionPoints',raceId='GetUnitRaceId',classId='GetUnitClassId',battleLeveled='IsUnitBattleLeveled',championBattleLeveled='IsUnitChampionBattleLeveled',battleLevel='GetUnitBattleLevel',championBattleLevel='GetUnitChampionBattleLevel',inCombat='IsUnitInCombat',dead='IsUnitDead',zone='GetUnitZone'}) do c[name]=read(fn,'player') end
    c.curse=read('GetPlayerCurseType');c.zoneId=read('GetUnitWorldPosition','player')
    c.now=read('GetGameTimeMilliseconds')
    c.mundusIndices={read('GetUnitActiveMundusStoneBuffIndices','player')}
    c.powers={}
    for _,pair in ipairs({{'health','COMBAT_MECHANIC_FLAGS_HEALTH'},{'magicka','COMBAT_MECHANIC_FLAGS_MAGICKA'},{'stamina','COMBAT_MECHANIC_FLAGS_STAMINA'}}) do
        if api[pair[2]] then local current,max,effective=read('GetUnitPower','player',api[pair[2]]);c.powers[pair[1]]={current=current,max=max,effectiveMax=effective} end
    end
    return data,errors
end
