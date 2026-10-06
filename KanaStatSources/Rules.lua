local K=KanaStatSources
local R={Policies={},registry={},DynamicSkills={}};K.Rules=R
-- Raw attribute deltas belong in the percentage base. Native Mundus values
-- use effectiveFlat because they already reflect their own scaling.
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
-- Erudition's flavor sentence precedes a permanent percentage clause. Accept
-- this exact known description, never skip arbitrary prose in generic parsing.
R.Register({id=185239,kind='skill',evidence='native Erudition ID and complete unconditional RU/EN description',build=function(source,s)
    local language=(s.meta or {}).language
    if language~='ru' and language~='en' then return {}end
    local text,values=K.Descriptions.Tokens(source.description,language)
    text=text:gsub('%s+',' ')
    local pattern=language=='ru' and '^знание — сила%.%s*ваша необычайная ученость увеличивает восстановление магии и запаса сил на @([0-9]+)@%%%.?$'
        or '^knowledge is power%.%s*your excessive scholarship increases your magicka and stamina recovery by @([0-9]+)@%%%.?$'
    local index=text:match(pattern);local amount=index and values[tonumber(index)]
    if not K.Core.Finite(amount) then return {}end
    local out={};R.Emit(out,source,{{stats={'magickaRecovery','staminaRecovery'},amount=amount,operation='percent'}},'native Erudition unconditional description for ability 185239')
    return out
end})
function R.Emit(out,source,clauses,evidence)
    for i,c in ipairs(clauses) do for _,stat in ipairs(c.stats) do
        out[#out+1]={key=source.key..':'..i,sourceKey=source.key,stat=stat,category=source.category,label=source.label,source=source,amount=c.amount,operation=c.operation,group=c.operation=='percent' and 'additive' or nil,active=true,evidence=evidence,bonusText=c.raw}
    end end
end
local function oneHandAndShield(_,s)
    local c=s.constants or {};local context=s.context or {};local bar=context.bar;local mainSlot,offSlot,category,pair
    if bar=='front' then mainSlot,offSlot,category,pair=c.EQUIP_SLOT_MAIN_HAND,c.EQUIP_SLOT_OFF_HAND,c.HOTBAR_CATEGORY_PRIMARY,1
    elseif bar=='back' then mainSlot,offSlot,category,pair=c.EQUIP_SLOT_BACKUP_MAIN,c.EQUIP_SLOT_BACKUP_OFF,c.HOTBAR_CATEGORY_BACKUP,2
    else return false end
    if not K.Core.Finite(category) or context.hotbarCategory~=category or context.weaponPair~=pair then return false end
    if not K.Core.Finite(mainSlot) or not K.Core.Finite(offSlot) or not K.Core.Finite(c.WEAPONTYPE_SHIELD) then return false end
    local main,off
    for _,item in ipairs(s.equipment or {})do
        if item.slot==mainSlot then main=item end
        if item.slot==offSlot then off=item end
    end
    if not main or not off or off.weaponType~=c.WEAPONTYPE_SHIELD then return false end
    for _,name in ipairs({'WEAPONTYPE_AXE','WEAPONTYPE_HAMMER','WEAPONTYPE_SWORD','WEAPONTYPE_DAGGER'})do
        if K.Core.Finite(c[name]) and main.weaponType==c[name] then return true end
    end
    return false
end
R.Register({id=29397,kind='skill',active=oneHandAndShield,evidence='native Sword and Board ID; one-hand weapon and shield on the active normal bar',build=function(source,s)
    local language=(s.meta or {}).language
    if language~='ru' and language~='en' then return {}end
    local text,values=K.Descriptions.Tokens(source.description,language)
    text=text:gsub('%s+',' ')
    local pattern=language=='ru' and '^ваша сила оружия и заклинаний увеличивается на @([0-9]+)@%%, а количество урона, которое вы можете заблокировать, — на @[0-9]+@%%%.?$'
        or '^increases your weapon and spell damage by @([0-9]+)@%% and the amount of damage you can block by @[0-9]+@%%%.?$'
    local index=text:match(pattern);local amount=index and values[tonumber(index)]
    if not K.Core.Finite(amount) then return {}end
    local out={};R.Emit(out,source,{{stats={'weaponDamage','spellDamage'},amount=amount,operation='percent'}},'native Sword and Board current description; verified active one-hand weapon plus shield')
    return out
end})
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
