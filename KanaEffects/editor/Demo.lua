-- Isolated synthetic observations. IDs come only from the supplied catalog.
local Demo={}; KanaEffects.Demo=Demo
local function copy(v) if type(v)~='table' then return v end; local r={}; for k,x in pairs(v) do r[k]=copy(x) end; return r end
-- Count is per source. The legacy four-argument call previews player only.
function Demo.Build(count,seed,catalog,now,unitTags)
    count=count or 'ordinary'; local size=count=='ordinary' and 12 or count
    assert(size==12 and count=='ordinary' or count==50 or count==100 or count==250,'Unsupported demo count')
    assert(type(now)=='number' and now==now and math.abs(now)<math.huge,'Demo requires seconds time')
    seed=seed or 17; assert(type(seed)=='number' and seed==seed and math.abs(seed)<math.huge,'Demo requires numeric seed')
    local state=math.floor(math.abs(seed))%2147483646+1
    local function random() state=(state*48271)%2147483647; return state/2147483647 end
    local families=catalog:Search('',{kind='family'},0,1000); local pairs={}
    for _,item in ipairs(families) do
        local levels={}
        for _,id in ipairs(item.abilityIds) do local described=catalog:Describe(id); if described.level then levels[described.level]=id end end
        if levels.minor and levels.major then pairs[#pairs+1]={id=item.selector.id,minor=levels.minor,major=levels.major} end
        if #pairs==4 then break end
    end
    assert(#pairs==4,'Demo requires four catalog families with both levels')
    local rows={}; local excluded={}; for _,p in ipairs(pairs) do excluded[p.id]=true end
    local function add(id,variation)
        local slot=#rows+1; local c=copy(catalog:Describe(id)); local duration=20+math.floor(random()*40)
        if variation==1 then c.name='' elseif variation==2 then c.name='Демонстрационный эффект с очень длинным названием для проверки компактной раскладки' end
        local lifetime=variation==3 and 'permanent' or variation==4 and 'unknown' or 'finite'
        local metadata=catalog:Resolve({kind='ability',id=id})
        rows[slot]={key='player:1:'..slot,unit={tag='player',generation=1,name='Демо'},abilityId=id,effectSlot=slot,kind=metadata.kind or 'unknown',
            lifetime=lifetime,startTime=lifetime=='finite' and now or nil,endTime=lifetime=='finite' and now+duration or nil,
            fullDuration=lifetime=='finite' and duration or nil,stacks=1,castBy='unknown',catalog=c,observedAt=now,firstSeen=now,synthetic=true}
    end
    add(pairs[1].minor); add(pairs[2].major); add(pairs[3].minor); add(pairs[3].major)
    -- The fourth family deliberately has no live members.
    local candidates=catalog:Search('',{kind='ability'},0,1000); local ids={}
    for _,item in ipairs(candidates) do for _,id in ipairs(item.abilityIds) do local c=catalog:Describe(id); if not excluded[c.familyId] then ids[#ids+1]=id end end end
    assert(#ids>0,'Demo requires additional catalog abilities')
    -- A short sample must include a real catalog debuff as well as the first
    -- buff families, otherwise a target's debuff filter would still look empty.
    for index,id in ipairs(ids) do
        if catalog:Resolve({kind='ability',id=id}).kind=='debuff' then table.insert(ids,1,table.remove(ids,index)); break end
    end
    while #rows<size do add(ids[(#rows-4)%#ids+1],(#rows-4)%5+1) end
    local result,seen={},{}
    for _,tag in ipairs(unitTags or {'player'}) do if not seen[tag] then
        seen[tag]=true
        local boss=string.match(tag,'^boss(%d+)$')
        local name=tag=='reticleover' and 'Демо-цель' or boss and 'Демо-босс '..boss or 'Демо'
        for _,row in ipairs(rows) do
            local observation=copy(row)
            observation.key=tag..':1:'..row.effectSlot; observation.unit={tag=tag,generation=1,name=name}
            result[#result+1]=observation
        end
    end end
    return result
end
