local K=KanaStatSources
local S={};K.Snapshot=S
local Instance={};Instance.__index=Instance
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
local function stats(api,errors)
    local out={};local read=K.Core.Reader(api,errors)
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
        local read=K.Core.Reader(api,s.errors)
        s.constants={}
        for name,value in pairs(api) do if type(value)=='number' and (name:match('^ITEM_TRAIT_TYPE_') or name:match('^EQUIP_SLOT_') or name:match('^ARMORTYPE_') or name:match('^WEAPONTYPE_')) then s.constants[name]=value end end
        s.meta={addonVersion=K.version,apiVersion=read('GetAPIVersion'),language=read('GetCVar','language.2') or 'en',characterId=read('GetCurrentCharacterId'),characterName=read('GetUnitName','player'),time=read('GetTimeStamp'),timeMs=read('GetGameTimeMilliseconds')}
        s.stats=stats(api,s.errors)
        local equipment,gearErrors=K.CaptureEquipment.Read(api);merge(s,equipment,gearErrors,'equipment')
        local effects,effectErrors=K.CaptureEffects.Read(api);merge(s,effects,effectErrors,'effects')
        local build=self.cache.build
        if not build then local values,errors=K.CaptureBuild.Read(api);build={data=values,errors=errors};self.cache.build=build end
        merge(s,K.Core.CopySerializable(build.data),K.Core.CopySerializable(build.errors),'build')
        -- Attribute deltas can scale when effects change: read their native current values each capture.
        for _,a in ipairs({{'health','ATTRIBUTE_HEALTH','STAT_HEALTH_MAX'},{'magicka','ATTRIBUTE_MAGICKA','STAT_MAGICKA_MAX'},{'stamina','ATTRIBUTE_STAMINA','STAT_STAMINA_MAX'}}) do
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
            for ci=1,read('GetNumAdvancedStatCategories') or 0 do
                local id=read('GetAdvancedStatsCategoryId',ci)
                local name,count=read('GetAdvancedStatCategoryInfo',id)
                for i=1,count or 0 do
                    local kind,label,description,flatDescription,percentDescription=read('GetAdvancedStatInfo',id,i)
                    local format,flat,percent=read('GetAdvancedStatValue',kind)
                    s.advancedStats[#s.advancedStats+1]={categoryId=id,categoryName=name,type=kind,name=label,description=description,flatDescription=flatDescription,percentDescription=percentDescription,format=format,flat=flat,percent=percent}
                end
            end
        end
        local endStats=stats(api,{})
        local endEquipment=K.CaptureEquipment.Read(api)
        local endEffects=K.CaptureEffects.Read(api)
        s.consistent=self.generation==s.generation and endEffects.context.weaponPair==s.context.weaponPair and K.Core.Signature(endStats)==K.Core.Signature(s.stats) and K.Core.Signature(endEquipment.equipment)==K.Core.Signature(s.equipment) and K.Core.Signature(endEffects.effects)==K.Core.Signature(s.effects)
        for name,value in pairs(api) do if type(value)=='function' and name:match('^Get') then s.capabilities[name]=true end end
        last=s
        if s.consistent then return s end
        self.cache={}
    end
    return last
end
