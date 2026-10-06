local K=KanaStatSources
K.CaptureEffects={}
local fields={'name','startTime','endTime','buffSlot','stacks','icon','deprecatedBuffType','effectType','abilityType','statusEffectType','abilityId','canClickOff','castByPlayer'}
function K.CaptureEffects.Identity(effects)
    local out={}
    for i,e in ipairs(effects)do out[i]={id=e.abilityId,slot=e.buffSlot,startTime=e.startTime,endTime=e.endTime,stacks=e.stacks,castByPlayer=e.castByPlayer}end
    return K.Core.Signature(out)
end
function K.CaptureEffects.ReadInfo(api,capabilities)
    local errors={};local read=K.Core.Reader(api,errors,capabilities);local effects={}
    for i=1,read('GetNumBuffs','player') or 0 do
        local values={read('GetUnitBuffInfo','player',i)};local e={index=i}
        for n,name in ipairs(fields)do e[name]=values[n]end
        effects[#effects+1]=e
    end
    return effects,errors
end
function K.CaptureEffects.Read(api,capabilities)
    local effects,errors=K.CaptureEffects.ReadInfo(api,capabilities);local read=K.Core.Reader(api,errors,capabilities)
    local data={effects=effects,context={}}
    for _,e in ipairs(effects)do
        if e.abilityId then
            e.description=read('GetAbilityDescription',e.abilityId,nil,'player')
            if api.GetAbilityEffectDescription and e.buffSlot then
                local description=read('GetAbilityEffectDescription',e.buffSlot)
                if description and description~='' then e.effectDescription=description end
            end
            if api.IsAbilityPermanent then e.permanent=read('IsAbilityPermanent',e.abilityId)end
            e.buffType=read('GetAbilityBuffType',e.abilityId,'player')
            e.mundusType=read('GetAbilityMundusStoneType',e.abilityId)
            e.derivedStats={}
            for n=1,read('GetAbilityNumDerivedStats',e.abilityId) or 0 do
                local stat,value=read('GetAbilityDerivedStatAndEffectByIndex',e.abilityId,n)
                e.derivedStats[#e.derivedStats+1]={id=stat,stat=K.Stats.KeyForId(api,stat),value=value}
            end
        end
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
