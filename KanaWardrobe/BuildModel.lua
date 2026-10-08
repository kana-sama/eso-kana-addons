local KW=KanaWardrobe
local M={};KW.BuildModel=M
local function integer(n) return type(n)=='number' and n>=0 and n<math.huge and n==math.floor(n) end
local function invalid() return nil,KW.Problem('invalidPreset') end
local function skillKind(key)
    if type(key)~='string' then return nil end
    local line,kind,id=key:match('^(%d+):(%a+):(%d+)$')
    if not line or tonumber(line)==0 or tonumber(id)==0 then return nil end
    return kind
end
function M.Equipment(p) return p and (p.slots or p.equipment) or {} end
function M.Normalize(p)
    if type(p)~='table' then return invalid() end
    local result={id=p.id,name=p.name,revision=p.revision}
    local input=p.slots or p.equipment
    if input~=nil then
        if type(input)~='table' then return invalid() end
        result.equipment={};local seen={}
        for slot,v in pairs(input) do
            if not KW.Slots.IsSupported(slot) or type(v)~='table' then
                return nil,KW.Problem('invalidSlot',{slot=slot})
            end
            if v.kind=='empty' then
                result.equipment[slot]={kind='empty'}
            elseif v.kind=='item' and type(v.uid)=='string' and v.uid~='' and v.uid~='0' and type(v.link)=='string' and v.link~='' then
                if seen[v.uid] then return nil,KW.Problem('duplicateUid',{uid=v.uid}) end
                seen[v.uid]=true
                result.equipment[slot]={kind='item',uid=v.uid,link=v.link}
            else
                return nil,KW.Problem('invalidItem',{slot=slot})
            end
        end
    end
    if p.appearance~=nil then
        if type(p.appearance)~='table' then return invalid() end
        result.appearance={}
        for category,id in pairs(p.appearance) do
            if not integer(category) or category==0 or not integer(id) then return invalid() end
            result.appearance[category]=id
        end
    end
    if p.attributes~=nil then
        local a=p.attributes
        if type(a)~='table' or not integer(a.health) or not integer(a.magicka) or not integer(a.stamina)
            or (a.unspentAtCapture~=nil and not integer(a.unspentAtCapture)) then
            return invalid()
        end
        result.attributes={health=a.health,magicka=a.magicka,stamina=a.stamina,unspentAtCapture=a.unspentAtCapture}
    end
    if p.abilities~=nil then
        if type(p.abilities)~='table' then return invalid() end
        local a={};result.abilities=a
        if p.abilities.skills~=nil then
            if type(p.abilities.skills)~='table' then return invalid() end
            a.skills={}
            for key,v in pairs(p.abilities.skills) do
                local kind=skillKind(key)
                if not kind or type(v)~='table' or v.kind~=kind then
                    return invalid()
                end
                if kind=='active' and type(v.purchased)=='boolean' and ((v.morph==nil and not v.purchased) or (integer(v.morph) and v.morph<=2)) then
                    a.skills[key]={kind=kind,purchased=v.purchased,morph=v.purchased and v.morph or nil}
                elseif kind=='passive' and integer(v.rank) then
                    a.skills[key]={kind=kind,rank=v.rank}
                else
                    return invalid()
                end
            end
        end
        if p.abilities.bars~=nil then
            if type(p.abilities.bars)~='table' then return invalid() end
            a.bars={}
            for bar,slots in pairs(p.abilities.bars) do
                if (bar~='front' and bar~='back' and bar~='werewolf') or type(slots)~='table' then
                    return invalid()
                end
                a.bars[bar]={}
                for slot,v in pairs(slots) do
                    if not integer(slot) or slot<1 or slot>6 or type(v)~='table' then
                        return invalid()
                    end
                    if v.kind=='empty' then
                        a.bars[bar][slot]={kind='empty'}
                    elseif v.kind=='skill' then
                        local kind=skillKind(v.skillKey)
                        local validMorph=kind=='active' and integer(v.expectedMorph) and v.expectedMorph<=2
                        local validCrafted=kind=='crafted' and (v.expectedMorph==nil or v.expectedMorph==0)
                        if not validMorph and not validCrafted then return invalid() end
                        a.bars[bar][slot]={kind='skill',skillKey=v.skillKey,expectedMorph=v.expectedMorph}
                    else
                        return invalid()
                    end
                end
            end
        end
    end
    return result
end
local function subset(actual,target)
    if type(target)~='table' then return actual==target end
    if type(actual)~='table' then return false end
    for k,v in pairs(target) do
        if k~='unspentAtCapture' and k~='link' and not subset(actual[k],v) then return false end
    end
    return true
end
function M.Matches(actual,target)
    for _,part in ipairs({'equipment','abilities','attributes','appearance'}) do
        if target[part]~=nil and not subset(actual and actual[part],target[part]) then return false end
    end
    return true
end
-- Use the same subset rule as Matches, but keep one entry per item/talent/slot.
-- Only requested fields participate; captured metadata and unselected slots do not.
function M.Differences(actual,target)
    actual=actual or {};target=target or {};local result={}
    local function compare(domain,field,wanted,current,context)
        if subset(current,wanted) then return end
        local row=KW.Copy(context or {})
        row.domain=domain;row.expected=KW.Copy(wanted);row.actual=KW.Copy(current)
        if domain=='equipment' or domain=='bars' then row.slot=field
        elseif domain=='skills' then row.key=field else row.field=field end
        result[#result+1]=row
    end
    local function map(domain,wanted,current,context)
        if wanted==nil then return end
        local keys={};for key in pairs(wanted)do
            if key~='unspentAtCapture' and key~='link' then keys[#keys+1]=key end
        end
        table.sort(keys,function(a,b)
            if type(a)=='number' and type(b)=='number' then return a<b end
            return tostring(a)<tostring(b)
        end)
        for _,key in ipairs(keys)do compare(domain,key,wanted[key],current and current[key],context)end
        if #keys==0 and type(current)~='table'then compare(domain,nil,wanted,current,context)end
    end
    map('equipment',target.equipment,actual.equipment)
    map('attributes',target.attributes,actual.attributes)
    map('appearance',target.appearance,actual.appearance)
    local wanted,current=target.abilities or {},actual.abilities or {}
    map('skills',wanted.skills,current.skills)
    for _,bar in ipairs({'front','back','werewolf'})do
        map('bars',wanted.bars and wanted.bars[bar],current.bars and current.bars[bar],{bar=bar})
    end
    if #result==0 and not M.Matches(actual,target)then
        result[1]={domain='abilities',unavailable=true}
    end
    return result
end
function M.Merge(actual,partial)
    local result=KW.Copy(actual or {})
    local function merge(dst,src)
        for k,v in pairs(src) do
            if type(v)=='table' and v.kind==nil and k~='attributes' then dst[k]=dst[k] or {};merge(dst[k],v)
            else dst[k]=KW.Copy(v) end
        end
    end
    merge(result,partial or {});return result
end
function M.Select(build,selection)
    local result={}
    local function selectMap(input,flags)
        local output={};for k,v in pairs(input or {}) do if flags and flags[k]==true then output[k]=KW.Copy(v) end end
        if next(output) then return output end
    end
    result.equipment=selectMap(build.equipment,selection.equipment)
    result.appearance=selectMap(build.appearance,selection.appearance)
    local a=build.abilities or {};local skills=selectMap(a.skills,selection.skills);local bars={}
    for _,bar in ipairs({'front','back','werewolf'}) do bars[bar]=selectMap(a.bars and a.bars[bar],selection.bars and selection.bars[bar]) end
    if skills or next(bars) then result.abilities={skills=skills,bars=next(bars) and bars or nil} end
    if selection.attributes==true then result.attributes=KW.Copy(build.attributes) end
    return result
end
function M.HasParts(build)
    if build.appearance and next(build.appearance) then return true end
    if build.attributes then return true end
    if build.equipment and next(build.equipment) then return true end
    local a=build.abilities
    if not a then return false end
    if a.skills and next(a.skills) then return true end
    return a.bars~=nil and ((a.bars.front and next(a.bars.front)~=nil) or (a.bars.back and next(a.bars.back)~=nil) or (a.bars.werewolf and next(a.bars.werewolf)~=nil)) or false
end
