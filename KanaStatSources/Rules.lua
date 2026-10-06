local K=KanaStatSources
local R={Policies={},registry={}};K.Rules=R
function R.Register(rule) assert(rule.id and rule.kind and rule.build,'invalid source rule');R.registry[rule.kind..':'..tostring(rule.id)]=rule end
function R.Resolve(source,snapshot)
    local rule=R.registry[source.kind..':'..tostring(source.id)]
    if not rule then return {},{K.Core.Diagnostic(source,'no verified rule')} end
    if rule.active and not rule.active(source,snapshot) then return {},{K.Core.Diagnostic(source,'condition inactive or unavailable')} end
    local cs=rule.build(source,snapshot) or {}
    for _,c in ipairs(cs) do c.ruleId=rule.kind..':'..tostring(rule.id);c.evidence=c.evidence or rule.evidence end
    return cs,{}
end
function R.Emit(out,source,clauses,evidence)
    for i,c in ipairs(clauses) do for _,stat in ipairs(c.stats) do
        out[#out+1]={key=source.key..':'..i,sourceKey=source.key,stat=stat,category=source.category,label=source.label,source=source,amount=c.amount,operation=c.operation,group=c.operation=='percent' and 'additive' or nil,active=true,evidence=evidence,bonusText=c.raw}
    end end
end
