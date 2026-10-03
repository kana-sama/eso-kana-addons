local KW=KanaWardrobe
local Description={};KW.BuildDescription=Description

local function copy(value)
    if type(value)~='table' then return value end
    local result={}
    for key,v in pairs(value) do result[key]=copy(v) end
    return result
end

-- These native getters read cached catalogue/progression data. In particular,
-- never ask an allocator or GetCurrentProgressionData for a normal skill.
local function get(object,method,...)
    if not object then return nil end
    local fn=object[method]
    if type(fn)~='function' then return nil end
    local ok,a,b,c=pcall(fn,object,...)
    if ok then return a,b,c end
end

local function off(state)
    return state and ((state.kind=='active' and not state.purchased)
        or (state.kind=='passive' and state.rank==0)) or false
end

local function unresolved(entry,reason,catalogue)
    entry.available=false;entry.icon=nil;entry.tooltip.progression=nil
    entry.unresolvedReason={code=reason=='missingCatalogue' and 'buildCapabilityUnavailable' or 'skillUnavailable',
        details={component='skills',skillKey=entry.skillKey,reason=reason}}
    if reason=='missingCatalogue' then
        entry.unresolvedReason.details.name=catalogue and catalogue.problem and catalogue.problem.details
            and catalogue.problem.details.name or 'skillCatalogue'
    end
    return entry
end

local function skill(key,state,morph,catalogue,isBar)
    local lineId,kind=key:match('^(%d+):(%a+):%d+$')
    local entry={skillKey=key,kind=kind,state=state and copy(state) or nil,
        name=key,lineId=tonumber(lineId),available=false,
        tooltip={kind=kind,inactive=off(state),showSkillPointCost=false,
            showUpgradeText=false,showAdvised=false,showBadMorph=false}}
    if kind=='active' then
        entry.tooltip.morph=isBar and morph or (state.purchased and state.morph or 0)
    elseif kind=='passive' then
        entry.tooltip.rank=math.max(1,state.rank)
    end
    if not catalogue or catalogue.available~=true then return unresolved(entry,'missingCatalogue',catalogue) end
    local record=catalogue.byKey and catalogue.byKey[key]
    if not record then return unresolved(entry,'missingSkill') end
    entry.lineId=record.lineId;entry.mastery=record.mastery==true
    entry.category,entry.lineIndex,entry.skillIndex=get(record.native,'GetIndices')
    if not record.available then return unresolved(entry,'lineUnavailable') end
    if not isBar and record.mutable==false then return unresolved(entry,'immutableSkill') end
    if kind=='crafted' and not record.craftedReady then return unresolved(entry,'craftedNotReady') end
    local progression
    if kind=='active' then progression=get(record.native,'GetMorphData',entry.tooltip.morph)
    elseif kind=='passive' then progression=get(record.native,'GetRankData',entry.tooltip.rank)
    elseif kind=='crafted' then progression=get(record.native,'GetCurrentProgressionData') end
    if not progression then return unresolved(entry,'missingProgression') end
    local name,icon=get(progression,'GetName'),get(progression,'GetIcon')
    if type(name)~='string' or name=='' or type(icon)~='string' or icon==''
        or type(entry.category)~='number' or type(entry.lineIndex)~='number' or type(entry.skillIndex)~='number' then
        return unresolved(entry,'missingMetadata')
    end
    if kind=='crafted' then
        entry.tooltip.abilityId=get(progression,'GetAbilityId')
        if type(entry.tooltip.abilityId)~='number' or entry.tooltip.abilityId<=0 then
            return unresolved(entry,'missingMetadata')
        end
    end
    entry.available=true;entry.name=name;entry.icon=icon
    -- Runtime description only: this handle must never be persisted in a preset.
    entry.tooltip.progression=progression
    return entry
end

local function nativeOrder(a,b)
    for _,field in ipairs({'category','lineIndex','skillIndex'}) do
        local av,bv=a[field] or math.huge,b[field] or math.huge
        if av~=bv then return av<bv end
    end
    return a.skillKey<b.skillKey
end

-- Only saved canonical parts select content; the catalogue supplies metadata.
function Description.Build(preset,catalogue)
    local result={enabled={},disabled={}}
    result.attributes=preset.attributes and copy(preset.attributes) or nil
    -- Detached UID map, NOT computed gear statistics. The renderer passes this
    -- canonical map through the existing SetModel/EffectModel equipment path.
    result.equipmentSummary=preset.equipment and copy(preset.equipment) or nil
    local abilities=preset.abilities or {}
    for key,state in pairs(abilities.skills or {}) do
        local entries=off(state) and result.disabled or result.enabled
        entries[#entries+1]=skill(key,state,nil,catalogue,false)
    end
    table.sort(result.enabled,nativeOrder);table.sort(result.disabled,nativeOrder)
    if abilities.bars~=nil then
        result.bars={}
        for _,bar in ipairs({'front','back','werewolf'}) do
            local saved=abilities.bars[bar] or {}
            if bar~='werewolf' or next(saved) then
                local entries={};result.bars[bar]=entries
                for slot=1,6 do
                    local ref=saved[slot];local entry
                    if ref and ref.kind=='skill' then
                        entry=skill(ref.skillKey,abilities.skills and abilities.skills[ref.skillKey],ref.expectedMorph,catalogue,true)
                        entry.kind='skill';entry.expectedMorph=ref.expectedMorph
                    else entry={kind=ref and 'empty' or 'unchanged'} end
                    entry.slot=slot;entries[slot]=entry
                end
            end
        end
    end
    return result
end
