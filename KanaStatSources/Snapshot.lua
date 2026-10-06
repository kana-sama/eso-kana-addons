local K=KanaStatSources
local S={};K.Snapshot=S
local Instance={};Instance.__index=Instance
-- Read known enum names directly. Iterating _G also retrieves private native
-- functions, which ESO forbids even when they are never called.
local constantNames={
    'EQUIP_SLOT_ITERATION_BEGIN','EQUIP_SLOT_ITERATION_END','ARMORTYPE_HEAVY','ARMORTYPE_LIGHT',
    'ARMORTYPE_MEDIUM','ARMORTYPE_NONE','EQUIP_SLOT_BACKUP_MAIN','EQUIP_SLOT_BACKUP_OFF',
    'EQUIP_SLOT_BACKUP_POISON','EQUIP_SLOT_CHEST','EQUIP_SLOT_CLASS1','EQUIP_SLOT_CLASS2',
    'EQUIP_SLOT_CLASS3','EQUIP_SLOT_COSTUME','EQUIP_SLOT_FEET','EQUIP_SLOT_HAND',
    'EQUIP_SLOT_HEAD','EQUIP_SLOT_LEGS','EQUIP_SLOT_MAIN_HAND','EQUIP_SLOT_NECK',
    'EQUIP_SLOT_NONE','EQUIP_SLOT_OFF_HAND','EQUIP_SLOT_POISON','EQUIP_SLOT_RANGED',
    'EQUIP_SLOT_RING1','EQUIP_SLOT_RING2','EQUIP_SLOT_SHOULDERS','EQUIP_SLOT_WAIST',
    'EQUIP_SLOT_WRIST','ITEM_TRAIT_TYPE_ARMOR_AGGRESSIVE','ITEM_TRAIT_TYPE_ARMOR_AUGMENTED','ITEM_TRAIT_TYPE_ARMOR_BOLSTERED',
    'ITEM_TRAIT_TYPE_ARMOR_DIVINES','ITEM_TRAIT_TYPE_ARMOR_FOCUSED','ITEM_TRAIT_TYPE_ARMOR_IMPENETRABLE','ITEM_TRAIT_TYPE_ARMOR_INFUSED',
    'ITEM_TRAIT_TYPE_ARMOR_INTRICATE','ITEM_TRAIT_TYPE_ARMOR_NIRNHONED','ITEM_TRAIT_TYPE_ARMOR_ORNATE','ITEM_TRAIT_TYPE_ARMOR_PROLIFIC',
    'ITEM_TRAIT_TYPE_ARMOR_PROSPEROUS','ITEM_TRAIT_TYPE_ARMOR_QUICKENED','ITEM_TRAIT_TYPE_ARMOR_REINFORCED','ITEM_TRAIT_TYPE_ARMOR_SHATTERING',
    'ITEM_TRAIT_TYPE_ARMOR_SOOTHING','ITEM_TRAIT_TYPE_ARMOR_STURDY','ITEM_TRAIT_TYPE_ARMOR_TRAINING','ITEM_TRAIT_TYPE_ARMOR_VIGOROUS',
    'ITEM_TRAIT_TYPE_ARMOR_WELL_FITTED','ITEM_TRAIT_TYPE_JEWELRY_AGGRESSIVE','ITEM_TRAIT_TYPE_JEWELRY_ARCANE','ITEM_TRAIT_TYPE_JEWELRY_AUGMENTED',
    'ITEM_TRAIT_TYPE_JEWELRY_BLOODTHIRSTY','ITEM_TRAIT_TYPE_JEWELRY_BOLSTERED','ITEM_TRAIT_TYPE_JEWELRY_FOCUSED','ITEM_TRAIT_TYPE_JEWELRY_HARMONY',
    'ITEM_TRAIT_TYPE_JEWELRY_HEALTHY','ITEM_TRAIT_TYPE_JEWELRY_INFUSED','ITEM_TRAIT_TYPE_JEWELRY_INTRICATE','ITEM_TRAIT_TYPE_JEWELRY_ORNATE',
    'ITEM_TRAIT_TYPE_JEWELRY_PROLIFIC','ITEM_TRAIT_TYPE_JEWELRY_PROTECTIVE','ITEM_TRAIT_TYPE_JEWELRY_QUICKENED','ITEM_TRAIT_TYPE_JEWELRY_ROBUST',
    'ITEM_TRAIT_TYPE_JEWELRY_SHATTERING','ITEM_TRAIT_TYPE_JEWELRY_SOOTHING','ITEM_TRAIT_TYPE_JEWELRY_SWIFT','ITEM_TRAIT_TYPE_JEWELRY_TRIUNE',
    'ITEM_TRAIT_TYPE_JEWELRY_VIGOROUS','ITEM_TRAIT_TYPE_NONE','ITEM_TRAIT_TYPE_WEAPON_AGGRESSIVE','ITEM_TRAIT_TYPE_WEAPON_AUGMENTED',
    'ITEM_TRAIT_TYPE_WEAPON_BOLSTERED','ITEM_TRAIT_TYPE_WEAPON_CHARGED','ITEM_TRAIT_TYPE_WEAPON_DECISIVE','ITEM_TRAIT_TYPE_WEAPON_DEFENDING',
    'ITEM_TRAIT_TYPE_WEAPON_FOCUSED','ITEM_TRAIT_TYPE_WEAPON_INFUSED','ITEM_TRAIT_TYPE_WEAPON_INTRICATE','ITEM_TRAIT_TYPE_WEAPON_NIRNHONED',
    'ITEM_TRAIT_TYPE_WEAPON_ORNATE','ITEM_TRAIT_TYPE_WEAPON_POWERED','ITEM_TRAIT_TYPE_WEAPON_PRECISE','ITEM_TRAIT_TYPE_WEAPON_PROLIFIC',
    'ITEM_TRAIT_TYPE_WEAPON_QUICKENED','ITEM_TRAIT_TYPE_WEAPON_SHARPENED','ITEM_TRAIT_TYPE_WEAPON_SHATTERING','ITEM_TRAIT_TYPE_WEAPON_SOOTHING',
    'ITEM_TRAIT_TYPE_WEAPON_TRAINING','ITEM_TRAIT_TYPE_WEAPON_VIGOROUS','WEAPONTYPE_AXE','WEAPONTYPE_BOW',
    'WEAPONTYPE_DAGGER','WEAPONTYPE_FIRE_STAFF','WEAPONTYPE_FROST_STAFF','WEAPONTYPE_HAMMER',
    'WEAPONTYPE_HEALING_STAFF','WEAPONTYPE_LIGHTNING_STAFF','WEAPONTYPE_NONE','WEAPONTYPE_RUNE',
    'WEAPONTYPE_SHIELD','WEAPONTYPE_SWORD','WEAPONTYPE_TWO_HANDED_AXE','WEAPONTYPE_TWO_HANDED_HAMMER',
    'WEAPONTYPE_TWO_HANDED_SWORD',
}
function S.New(api) return setmetatable({api=api,generation=0,cache={}},Instance) end
function Instance:Invalidate(category)
    self.generation=self.generation+1
    if category=='all' then self.cache={} else self.cache[category]=nil end
end
local function merge(s,data,errors,category)
    for key,value in pairs(data) do s[key]=value end
    s.categoryStatus[category]=#errors==0 and 'available' or 'partial'
    for _,e in ipairs(errors) do e.category=category;s.errors[#s.errors+1]=e end
end
local function capture(api,collector,fallback,capabilities)
    local ok,data,errors=pcall(collector,api,capabilities)
    if ok and type(data)=='table' and type(errors)=='table' then return data,errors end
    return fallback,{{api='collector',reason=ok and 'invalid collector result' or tostring(data)}}
end
local function stats(api,errors,capabilities)
    local out={};local read=K.Core.Reader(api,errors,capabilities)
    for _,d in ipairs(K.Stats.List(api)) do
        out[d.key]={id=d.id,name=d.name}
        if d.id then
            local v=read('GetPlayerStat',d.id,api.STAT_BONUS_OPTION_APPLY_BONUS)
            local base=read('GetPlayerStat',d.id,api.STAT_BONUS_OPTION_DONT_APPLY_BONUS)
            if K.Core.Finite(v) then out[d.key].total=v end
            if K.Core.Finite(base) then out[d.key].withoutBonus=base end
        end
    end
    return out
end
function Instance:Capture(full)
    local api=self.api
    local last
    for attempt=1,2 do
        local s={schemaVersion=1,errors={},capabilities={},categoryStatus={},generation=self.generation,consistent=true,preview={},advancedStats={},criticalSamples={}}
        local read=K.Core.Reader(api,s.errors,s.capabilities)
        s.constants={}
        for _,name in ipairs(constantNames)do local value=api[name];if K.Core.Finite(value)then s.constants[name]=value end end
        s.meta={addonVersion=K.version,apiVersion=read('GetAPIVersion'),language=read('GetCVar','language.2') or 'en',characterId=read('GetCurrentCharacterId'),characterName=read('GetUnitName','player'),time=read('GetTimeStamp'),timeMs=read('GetGameTimeMilliseconds')}
        s.stats=stats(api,s.errors,s.capabilities)
        local equipment,gearErrors=capture(api,K.CaptureEquipment.Read,{equipment={},sets={}},s.capabilities);merge(s,equipment,gearErrors,'equipment')
        local effects,effectErrors=capture(api,K.CaptureEffects.Read,{effects={},context={}},s.capabilities);merge(s,effects,effectErrors,'effects')
        local build=self.cache.build
        if not build then
            local capabilities={}
            local values,errors=capture(api,K.CaptureBuild.Read,{attributes={},skills={},champion={},bars={front={},back={},werewolf={}}},capabilities)
            build={data=values,errors=errors,capabilities=capabilities};self.cache.build=build
        end
        for name in pairs(build.capabilities)do s.capabilities[name]=type(api[name])=='function'end
        merge(s,K.Core.CopySerializable(build.data),K.Core.CopySerializable(build.errors),'build')
        -- Attribute deltas can scale when effects change: read their native current values each capture.
        for _,a in ipairs({{'health','ATTRIBUTE_HEALTH','STAT_HEALTH_MAX'},{'magicka','ATTRIBUTE_MAGICKA','STAT_MAGICKA_MAX'},{'stamina','ATTRIBUTE_STAMINA','STAT_STAMINA_MAX'}}) do
            s.attributes[a[1]]=s.attributes[a[1]] or {}
            s.attributes[a[1]].perPoint=read('GetAttributeDerivedStatPerPointValue',api[a[2]],api[a[3]])
        end
        for _,key in ipairs({'weaponCritical','spellCritical'}) do
            local rating=s.stats[key].total
            if K.Core.Finite(rating) then
                local seen={};s.criticalSamples[key]={}
                for _,r in ipairs({0,1,100,1000,rating,rating+1000}) do
                    if not seen[r] then seen[r]=true;s.criticalSamples[key][#s.criticalSamples[key]+1]={rating=r,chance=read('GetCriticalStrikeChance',r)} end
                end
            end
        end
        if api.STATS and type(api.STATS.GetPendingStatBonuses)=='function' then
            for _,d in ipairs(K.Stats.List(api)) do local ok,v=pcall(api.STATS.GetPendingStatBonuses,api.STATS,d.id);if ok and K.Core.Finite(v) then s.preview[d.key]=v end end
        end
        if full then
            local errorCount=#s.errors
            for ci=1,read('GetNumAdvancedStatCategories') or 0 do
                local id=read('GetAdvancedStatsCategoryId',ci)
                local name,count=read('GetAdvancedStatCategoryInfo',id)
                for i=1,count or 0 do
                    local kind,label,description,flatDescription,percentDescription=read('GetAdvancedStatInfo',id,i)
                    local format,flat,percent=read('GetAdvancedStatValue',kind)
                    s.advancedStats[#s.advancedStats+1]={categoryId=id,categoryName=name,type=kind,name=label,description=description,flatDescription=flatDescription,percentDescription=percentDescription,format=format,flat=flat,percent=percent}
                end
            end
            s.categoryStatus.advancedStats=#s.errors==errorCount and 'available' or 'partial'
        end
        local endStats=stats(api,{},s.capabilities)
        local endEquipment=capture(api,K.CaptureEquipment.Read,{equipment={},sets={}},s.capabilities)
        local endEffects=capture(api,K.CaptureEffects.Read,{effects={},context={}},s.capabilities)
        s.consistent=self.generation==s.generation and endEffects.context.weaponPair==s.context.weaponPair and K.Core.Signature(endStats)==K.Core.Signature(s.stats) and K.Core.Signature(endEquipment.equipment)==K.Core.Signature(s.equipment) and K.Core.Signature(endEffects.effects)==K.Core.Signature(s.effects)
        last=s
        if s.consistent then return s end
        self.cache={}
    end
    return last
end
