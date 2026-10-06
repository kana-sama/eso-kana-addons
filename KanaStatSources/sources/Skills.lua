local K=KanaStatSources
K.Sources.Skills={}
function K.Sources.Skills.Build(s)
    local out,diagnostics={},{};local language=(s.meta or {}).language or 'en'
    for _,skill in ipairs(s.skills or {}) do
        local source={key='skill:'..tostring(skill.id),kind='skill',id=skill.id,category='skills',name=skill.name or tostring(skill.id),icon=skill.icon,label=skill.name or tostring(skill.id),rank=skill.rank,lineId=skill.lineId,description=skill.description}
        if skill.rank then source.label=source.label..' ('..K.Stats.Text(language,'rank')..' '..skill.rank..')'end
        if skill.purchased and skill.lineActive==true then
            if K.Rules.registry['skill:'..tostring(skill.id)] then
                local c,d=K.Rules.Resolve(source,s);for _,r in ipairs(c) do r.label=r.label or source.label;r.source=r.source or source;out[#out+1]=r end;for _,r in ipairs(d) do diagnostics[#diagnostics+1]=r end
            elseif skill.passive then
                if ((s.constants or {}).SKILL_TYPE_WEAPON~=nil and skill.skillType==s.constants.SKILL_TYPE_WEAPON) or skill.id==29397 then
                    diagnostics[#diagnostics+1]=K.Core.Diagnostic(source,'weapon passive requires a verified active weapon rule')
                else
                local clauses,tail=K.Descriptions.Parse(skill.description,language,'skill')
                K.Rules.Emit(out,source,clauses,'GetSkillAbilityId committed rank; purchased, active skill line; unconditional passive clause')
                if tail~='' then local d=K.Core.Diagnostic(source,'passive condition or description not recognized');d.unparsed=tail;diagnostics[#diagnostics+1]=d end
                end
            end
        elseif skill.purchased and skill.lineActive==nil then diagnostics[#diagnostics+1]=K.Core.Diagnostic(source,'skill line activation unavailable') end
    end
    return out,diagnostics
end
