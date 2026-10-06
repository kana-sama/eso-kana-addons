local K=KanaStatSources
local R={Policies={},registry={},DynamicSkills={}};K.Rules=R
-- Attribute deltas and native Mundus values already reflect their own scaling.
-- Percent rows explain only the recognized raw flat portion; any unmodeled
-- base/source/scaling stays in the signed remainder.
for _,stat in ipairs({'maxHealth','maxMagicka','maxStamina','weaponDamage','spellDamage','healthRecovery','magickaRecovery','staminaRecovery'}) do R.Policies[stat]={groups={{id='additive',scope={'flat'},requireBase=true}}} end
function R.Register(rule) assert(rule.id and rule.kind and rule.build,'invalid source rule');R.registry[rule.kind..':'..tostring(rule.id)]=rule end
function R.Resolve(source,snapshot)
    local rule=R.registry[source.kind..':'..tostring(source.id)]
    if not rule then return {},{K.Core.Diagnostic(source,'no verified rule')} end
    if rule.active and not rule.active(source,snapshot) then return {},{K.Core.Diagnostic(source,'condition inactive or unavailable')} end
    local cs=rule.build(source,snapshot) or {}
    if #cs==0 then return {},{K.Core.Diagnostic(source,'registered rule has no verified current amount')}end
    for _,c in ipairs(cs) do c.ruleId=rule.kind..':'..tostring(rule.id);c.evidence=c.evidence or rule.evidence end
    return cs,{}
end
function R.Emit(out,source,clauses,evidence)
    for i,c in ipairs(clauses) do for _,stat in ipairs(c.stats) do
        out[#out+1]={key=source.key..':'..i,sourceKey=source.key,stat=stat,category=source.category,label=source.label,source=source,amount=c.amount,operation=c.operation,group=c.operation=='percent' and 'additive' or nil,active=true,evidence=evidence,bonusText=c.raw}
    end end
end
-- These passives expose a native "Current bonus" already calculated from the
-- current armor or skill bar. Read that total rather than multiplying per-piece
-- or per-ability values from the preceding conditional sentence.
for _,definition in ipairs({
    {184887,{'physicalPenetration','spellPenetration'},'flat'},
    {185036,{'healthRecovery','magickaRecovery','staminaRecovery'},'flat'},
    {45572,{'weaponDamage','spellDamage'},'percent'},
    {45565,{'staminaRecovery'},'percent'},
    {45531,{'physicalResistance','spellResistance'},'flat'},
    {45526,{'healthRecovery'},'percent'},
    {29804,{'maxHealth'},'percent'},
})do
    local id,stats,operation=definition[1],definition[2],definition[3]
    R.DynamicSkills[id]=true
    R.Register({id=id,kind='skill',evidence='native current-bonus text for this passive ID',build=function(source,s)
        local language=(s.meta or {}).language
        if language~='ru' and language~='en' then return {}end
        local template,values=K.Descriptions.Tokens(source.description,language)
        local index,percent=template:match((language=='ru' and 'текущий бонус: ' or 'current bonus: ')..'@([0-9]+)@([%%]?)')
        local amount=index and values[tonumber(index)]
        if not K.Core.Finite(amount) or (operation=='percent')~=(percent=='%') then return {}end
        local out={};R.Emit(out,source,{{stats=stats,amount=amount,operation=operation}},'native current-bonus text for passive '..id)
        return out
    end})
end
