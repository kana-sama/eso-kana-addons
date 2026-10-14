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
-- Archive Visions/Verses are maintained separately from GetUnitBuffInfo.
-- Keep their native IDs, stack counts and current descriptions in full dumps;
-- absent historical data never establishes a contribution from the residual.
function K.CaptureEffects.AuditArchive(api,capabilities)
    local data={archiveBuffs={},archiveContext={}};local errors={}
    local read=K.Core.Reader(api,errors,capabilities);local context=data.archiveContext
    context.inDungeon=read('IsInstanceEndlessDungeon')
    if context.inDungeon~=true then return data,errors end
    context.started=read('IsEndlessDungeonStarted');context.completed=read('IsEndlessDungeonCompleted')
    if context.started~=true or context.completed~=false then return data,errors end
    local function valid(value,minimum,maximum)
        return K.Core.Finite(value) and value==math.floor(value) and value>=minimum and value<=maximum
    end
    local seen={}
    local function append(id,stacks,kind)
        if not valid(id,1,2147483647) or not valid(stacks,1,1024) or seen[id] then
            errors[#errors+1]={api=kind=='vision' and 'GetNextEndlessDungeonVisionAbilityAndStackCount' or 'GetEndlessDungeonActiveVerseAbility',reason='invalid or repeated active archive buff'}
            return false
        end
        seen[id]=true
        data.archiveBuffs[#data.archiveBuffs+1]={id=id,stacks=stacks,kind=kind,
            name=read('GetAbilityName',id),icon=read('GetAbilityIcon',id),description=read('GetAbilityDescription',id,nil,'player')}
        return true
    end
    local previous
    for index=1,1025 do
        local id,stacks=read('GetNextEndlessDungeonVisionAbilityAndStackCount',previous)
        if id==nil then break end
        if index==1025 then errors[#errors+1]={api='GetNextEndlessDungeonVisionAbilityAndStackCount',reason='archive buff iteration limit'};return data,errors end
        if not append(id,stacks,'vision') then return data,errors end
        previous=id
    end
    local count=read('GetNumEndlessDungeonActiveVerses')
    if not valid(count,0,1024) then
        errors[#errors+1]={api='GetNumEndlessDungeonActiveVerses',reason='invalid active verse count'}
        return data,errors
    end
    for index=1,count do
        if not append(read('GetEndlessDungeonActiveVerseAbility',index),1,'verse') then break end
    end
    return data,errors
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
