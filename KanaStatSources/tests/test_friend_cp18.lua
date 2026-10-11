local T=dofile('KanaStatSources/tests/support.lua')
local files={}
for line in io.lines('KanaStatSources/KanaStatSources.addon')do if line:match('%.lua$')then files[#files+1]=line:gsub('%.lua$','')end end
local K=T.load(files)
local function snapshot()return dofile('KanaStatSources/tests/fixtures/live_ru_cp18.lua')end
local function sourceAmount(cs,id,stat)
    local amount=0
    for _,c in ipairs(cs)do if c.source and c.source.id==id and c.stat==stat then amount=amount+c.amount end end
    return amount
end
return {
 native_current_passive_totals_are_not_multiplied_per_piece=function()
    local cs=K.Sources.Skills.Build(snapshot())
    for _,p in ipairs({{31425,'weaponDamage',270},{31425,'spellDamage',270},
        {45557,'magickaRecovery',12},{45559,'spellResistance',2178},
        {45561,'weaponCritical',659},{45561,'spellCritical',659},
        {45562,'physicalPenetration',2817},{45562,'spellPenetration',2817},
        {45188,'healthRecovery',141},{45188,'magickaRecovery',141},{45188,'staminaRecovery',141},
        {45262,'magickaRecovery',130},{45262,'spellResistance',2310}})do
        T.eq(sourceAmount(cs,p[1],p[2]),p[3])
    end
 end,
 equal_active_set_values_exclude_different_backup_weapons=function()
    local cs=K.Sources.Equipment.Build(snapshot())
    T.eq(sourceAmount(cs,809,'weaponCritical'),221)
    T.eq(sourceAmount(cs,809,'spellCritical'),221)
    T.eq(sourceAmount(cs,809,'physicalPenetration'),501)
    T.eq(sourceAmount(cs,809,'spellPenetration'),501)
 end,
 friend_damage_critical_resistance_and_penetration_reconcile=function()
    local s=snapshot();local b=K.App.New({}):Explain(s)
    for _,stat in ipairs({'weaponDamage','spellDamage','weaponCritical','spellCritical',
        'physicalResistance','spellResistance','physicalPenetration','spellPenetration','criticalResistance'})do
        T.eq(b[stat].unknown,0);T.eq(T.sumRows(b[stat]),s.stats[stat].total)
    end
 end,
 only_known_parts_of_battle_leveling_are_attributed=function()
    local b=K.App.New({}):Explain(snapshot())
    for stat,unknown in pairs({maxHealth=995,maxMagicka=1684,maxStamina=2328,
        healthRecovery=56,magickaRecovery=306,staminaRecovery=348})do T.eq(b[stat].unknown,unknown)end
 end,
 extra_unknown_bonus_is_preserved=function()
    local s=snapshot();s.stats.spellDamage.total=s.stats.spellDamage.total+7
    local b=K.App.New({}):Explain(s)
    T.eq(b.spellDamage.unknown,7);T.eq(b.weaponDamage.unknown,0)
 end,
 non_damage_set_values_are_not_averaged_when_active_items_disagree=function()
    local s=snapshot()
    for _,item in ipairs(s.equipment)do if item.slot==11 then
        for _,bonus in ipairs(item.setBonuses)do
            if bonus.required==3 then bonus.description='(3 предмета) Шанс крит. удара +222'
            elseif bonus.required==4 then bonus.description='(4 предмета) Пробивание +502' end
        end
    end end
    local cs,diagnostics=K.Sources.Equipment.Build(s)
    T.eq(sourceAmount(cs,809,'weaponCritical'),320)
    T.eq(sourceAmount(cs,809,'physicalPenetration'),726)
    T.eq(#diagnostics>0,true)
 end,
 absent_item_values_or_ambiguous_weapon_context_keep_native_set_description=function()
    for _,change in ipairs({function(s)for _,item in ipairs(s.equipment)do if item.slot==11 then item.setBonuses=nil end end end,
        function(s)s.context.hotbarCategory=nil end})do
        local s=snapshot()
        change(s)
        local cs=K.Sources.Equipment.Build(s)
        T.eq(sourceAmount(cs,809,'weaponCritical'),320)
    end
 end,
 new_native_current_bonus_rules_still_require_purchased_active_skills=function()
    local s=snapshot()
    for _,skill in ipairs(s.skills)do skill.purchased=false end
    T.eq(#K.Sources.Skills.Build(s),0)
    s=snapshot();for _,skill in ipairs(s.skills)do skill.lineActive=false end
    T.eq(#K.Sources.Skills.Build(s),0)
 end,
 spell_attunement_reads_only_verified_unconditional_bonuses=function()
    local s={meta={language='en'},skills={{id=45262,purchased=true,lineActive=true,passive=true,
        description='Increases your Spell Resistance by 2310. This effect is doubled if you are afflicted with Burning, Chilled, or Concussed.\n\nIncreases your Magicka Recovery by 130.'}}}
    local cs=K.Sources.Skills.Build(s)
    T.eq(sourceAmount(cs,45262,'spellResistance'),2310);T.eq(sourceAmount(cs,45262,'magickaRecovery'),130)
    s.skills[1].description=s.skills[1].description..' While in combat.'
    T.eq(sourceAmount(K.Sources.Skills.Build(s),45262,'magickaRecovery'),0)
 end,
 spell_attunement_unknown_tail_preserves_the_recognized_base_prefix=function()
    local s={meta={language='en'},skills={{id=45262,purchased=true,lineActive=true,passive=true,
        description='Increases your Spell Resistance by 2310. An unrecognized conditional bonus follows.'}}}
    local cs,diagnostics=K.Sources.Skills.Build(s)
    T.eq(sourceAmount(cs,45262,'spellResistance'),2310)
    T.eq(sourceAmount(cs,45262,'magickaRecovery'),0);T.eq(#diagnostics,1)
 end,
 uniform_active_set_rule_uses_arbitrary_sets_stats_and_values=function()
    local s=snapshot();s.meta.language='en';s.sets={};s.equipment={}
    local descriptions={'Adds 123 Maximum Health.','Adds 123 Magicka Recovery.',
        'Adds 123 Critical Chance.','Adds 123 Offensive Penetration.','Adds 123 Armor.'}
    local bonuses={};for i,text in ipairs(descriptions)do bonuses[i]={index=i,required=3,description=text}end
    s.sets[90001]={id=90001,familyId=90001,name='Arbitrary set',normal=3,perfected=0,bonuses=K.Core.CopySerializable(bonuses)}
    for _,p in ipairs({{4,s.constants.WEAPONTYPE_BOW},{11,s.constants.WEAPONTYPE_NONE},{20,s.constants.WEAPONTYPE_BOW}})do
        local item={slot=p[1],weaponType=p[2],setId=90001,familyId=90001,setBonuses=K.Core.CopySerializable(bonuses)}
        if p[1]==20 then for _,bonus in ipairs(item.setBonuses)do bonus.description=bonus.description:gsub('123','999')end end
        s.equipment[#s.equipment+1]=item
    end
    local cs=K.Sources.Equipment.Build(s)
    for _,stat in ipairs({'maxHealth','magickaRecovery','weaponCritical','spellCritical',
        'physicalPenetration','spellPenetration','physicalResistance','spellResistance'})do
        T.eq(sourceAmount(cs,90001,stat),123)
    end
 end,
 unverified_battle_scaling_context_does_not_enable_fixed_bases=function()
    for _,change in ipairs({function(s)s.context.level=49 end,function(s)s.context.battleLevel=49 end,
        function(s)s.context.championBattleLevel=nil end,function(s)s.meta.apiVersion=101052 end})do
        local s=snapshot();change(s);local cs=K.Sources.Base.Build(s)
        for _,c in ipairs(cs)do T.eq(c.key~='base:healthRecovery',true);T.eq(c.key~='base:maxHealth',true)end
    end
 end,
 triple_recovery_clause_in_english_is_unconditional=function()
    local s={meta={language='en'},skills={{id=45188,purchased=true,lineActive=true,passive=true,
        description='Increases your Health, Magicka, and Stamina Recovery by 141.'}}}
    local cs=K.Sources.Skills.Build(s)
    T.eq(#cs,3)
    for _,stat in ipairs({'healthRecovery','magickaRecovery','staminaRecovery'})do T.eq(sourceAmount(cs,45188,stat),141)end
 end,
}
