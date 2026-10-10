local K=KanaStatSources
local E={};K.Sources.Effects=E
-- Effect identity facts from LibCombat's food-to-item mapping. Amounts are
-- always read from the running client, never from this classification list.
E.FoodIds={}
for _,id in ipairs({61218,61255,61257,61259,61260,61261,61294,61322,61325,61328,61335,61340,61345,61350,68411,68416,71057,72822,72824,84720,84731,84709,86673,89955,89957,89971,100498,107748,107789,127596,147687}) do E.FoodIds[id]=true end
local function savageryClauses(clauses,effect,s)
    if (s.meta or {}).apiVersion~=101051 then return clauses,false end
    -- Update 51 merged Savagery/Prophecy, but the native effect text in #14
    -- still names Weapon Critical alone. Identify the buff, not its granting
    -- skill/item. Type 4 is verified in #14, whose old snapshot lacks the enum.
    local buffType=(s.constants or {}).BUFF_TYPE_MAJOR_SAVAGERY or 4
    if effect.buffType~=buffType then return clauses,false end
    local out={}
    for i,clause in ipairs(clauses)do
        out[i]={};for key,value in pairs(clause)do out[i][key]=value end
        if clause.stats[1]=='weaponCritical' or clause.stats[1]=='spellCritical' then
            out[i].stats={'weaponCritical','spellCritical'}
        end
    end
    return out,true
end
function E.Build(s)
    local out,diagnostics,seen={},{},{};local language=(s.meta or {}).language or 'en';local context=s.context or {};local mundus={}
    for _,index in pairs(context.mundusIndices or {}) do mundus[index]=true end
    for _,effect in ipairs(s.effects or {}) do
        local id=effect.abilityId
        local active=effect.permanent==true or effect.endTime==0 or (K.Core.Finite(effect.startTime) and effect.endTime==effect.startTime) or (K.Core.Finite(effect.endTime) and K.Core.Finite(context.now) and effect.endTime>context.now/1000)
        if id and active then
            local category=mundus[effect.index] and 'mundus' or (E.FoodIds[id] and 'food' or 'effects')
            local canonical=effect.buffType and effect.buffType>0 and ('buff:'..effect.buffType) or ('effect:'..id)
            if category~='effects' then canonical=category..':'..id end
            local source={key=canonical,kind='effect',category=category,id=id,name=effect.name or tostring(id),icon=effect.icon,label=effect.name or tostring(id),description=effect.effectDescription or effect.description,stacks=effect.stacks,castByPlayer=effect.castByPlayer,buffType=effect.buffType}
            if not seen[canonical] then
                seen[canonical]=true
                if K.Rules.registry['effect:'..id] then
                    local c,d=K.Rules.Resolve(source,s);for _,r in ipairs(c) do r.label=r.label or source.label;r.source=r.source or source;out[#out+1]=r end;for _,r in ipairs(d) do diagnostics[#diagnostics+1]=r end
                elseif category=='mundus' then
                    local clauses={}
                    for _,r in ipairs(effect.derivedStats or {}) do if r.stat and K.Core.Finite(r.value) then clauses[#clauses+1]={stats={r.stat},operation='effectiveFlat',amount=r.value} end end
                    K.Rules.Emit(out,source,clauses,'active native Mundus index; GetAbilityDerivedStatAndEffectByIndex; no second Divines multiplier')
                    if #clauses==0 then diagnostics[#diagnostics+1]=K.Core.Diagnostic(source,'native Mundus contribution unavailable') end
                else
                    local clauses,tail=K.Descriptions.Parse(source.description,language,'effect')
                    local sharedCritical;clauses,sharedCritical=savageryClauses(clauses,effect,s)
                    local evidence=effect.effectDescription and 'GetAbilityEffectDescription(buffSlot)' or 'GetAbilityDescription caster player'
                    if sharedCritical then evidence=evidence..'; Update 51 Major Savagery affects both critical stats; native buff type' end
                    K.Rules.Emit(out,source,clauses,'GetUnitBuffInfo currently active; '..evidence..'; complete current stat clause')
                    if #clauses==0 or tail~='' then local d=K.Core.Diagnostic(source,'effect scaling or condition not recognized');d.unparsed=tail;diagnostics[#diagnostics+1]=d end
                end
            end
        elseif id and effect.endTime==nil then diagnostics[#diagnostics+1]={category='effects',source={id=id,name=effect.name},reason='effect lifetime unavailable'} end
    end
    return out,diagnostics
end
