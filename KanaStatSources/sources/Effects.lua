local K=KanaStatSources
local E={};K.Sources.Effects=E
-- Effect identity facts from LibCombat's food-to-item mapping. Amounts are
-- always read from the running client, never from this classification list.
E.FoodIds={}
for _,id in ipairs({61218,61255,61257,61259,61260,61261,61294,61322,61325,61328,61335,61340,61345,61350,68411,68416,71057,72822,72824,84720,84731,84709,86673,89955,89957,89971,100498,107748,107789,127596,147687}) do E.FoodIds[id]=true end
function E.Build(s)
    local out,diagnostics,seen={},{},{};local language=(s.meta or {}).language or 'en';local context=s.context or {};local mundus={}
    for _,index in pairs(context.mundusIndices or {}) do mundus[index]=true end
    for _,effect in ipairs(s.effects or {}) do
        local id=effect.abilityId
        local active=effect.endTime==0 or (K.Core.Finite(effect.endTime) and K.Core.Finite(context.now) and effect.endTime>context.now/1000)
        if id and active then
            local category=mundus[effect.index] and 'mundus' or (E.FoodIds[id] and 'food' or 'effects')
            local canonical=effect.buffType and effect.buffType>0 and ('buff:'..effect.buffType) or ('effect:'..id)
            if category~='effects' then canonical=category..':'..id end
            local source={key=canonical,kind='effect',category=category,id=id,label=effect.name or tostring(id),description=effect.description,stacks=effect.stacks,castByPlayer=effect.castByPlayer,buffType=effect.buffType}
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
                    local clauses,tail=K.Descriptions.Parse(effect.description,language,'effect')
                    K.Rules.Emit(out,source,clauses,'GetUnitBuffInfo currently active; GetAbilityDescription caster player; complete current stat clause')
                    if #clauses==0 or tail~='' then diagnostics[#diagnostics+1]=K.Core.Diagnostic(source,'effect scaling or condition not recognized') end
                end
            end
        elseif id and effect.endTime==nil then diagnostics[#diagnostics+1]={category='effects',source={id=id,name=effect.name},reason='effect lifetime unavailable'} end
    end
    return out,diagnostics
end
