local K=KanaStatSources
K.Sources.Champion={}
function K.Sources.Champion.Build(s)
    local out,diagnostics={},{};local language=(s.meta or {}).language or 'en'
    for _,star in ipairs(s.champion or {}) do
        local source={key='champion:'..star.id,kind='champion',id=star.id,category='champion',label=star.name or tostring(star.id),points=star.points,slot=star.slot,description=star.description,currentBonus=star.currentBonus}
        if not star.points or star.points<=0 then
        elseif star.slottable==nil then diagnostics[#diagnostics+1]=K.Core.Diagnostic(source,'champion skill type unavailable')
        elseif star.slottable and not star.slot then diagnostics[#diagnostics+1]=K.Core.Diagnostic(source,'slottable champion star not slotted')
        elseif K.Rules.registry['champion:'..star.id] then
            local c,d=K.Rules.Resolve(source,s);for _,r in ipairs(c) do r.label=r.label or source.label;r.source=r.source or source;out[#out+1]=r end;for _,r in ipairs(d) do diagnostics[#diagnostics+1]=r end
        else
            local clauses,tail=K.Descriptions.Parse(star.currentBonus,language,'champion')
            K.Rules.Emit(out,source,clauses,'GetChampionSkillCurrentBonusText(id, savedPoints); native step calculation; active star')
            if #clauses==0 or tail~='' then diagnostics[#diagnostics+1]=K.Core.Diagnostic(source,'current CP bonus not recognized; full description is not a total') end
        end
    end
    return out,diagnostics
end
