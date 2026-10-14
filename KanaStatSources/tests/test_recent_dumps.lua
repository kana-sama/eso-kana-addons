local T=dofile('KanaStatSources/tests/support.lua')
local files={}
for line in io.lines('KanaStatSources/KanaStatSources.addon')do if line:match('%.lua$')then files[#files+1]=line:gsub('%.lua$','')end end
local K=T.load(files)
local function snapshot(id)return dofile('KanaStatSources/tests/fixtures/live_ru_recent.lua')[id]end
local function amount(cs,id,stat)
    local value=0
    for _,c in ipairs(cs)do if c.source and c.source.id==id and c.stat==stat then value=value+c.amount end end
    return value
end
return {
 slayer_reads_native_current_bonus_without_multiplying_slots=function()
    local s=snapshot(16);local cs=K.Sources.Skills.Build(s)
    T.eq(amount(cs,45596,'weaponDamage'),3);T.eq(amount(cs,45596,'spellDamage'),3)
    for _,skill in ipairs(s.skills)do if skill.id==45596 then
        skill.description='Increases your Weapon and Spell Damage by 3% for each Fighters Guild ability slotted.\n\nCurrent bonus: 9%.'
    end end
    s.meta.language='en';cs=K.Sources.Skills.Build(s)
    T.eq(amount(cs,45596,'weaponDamage'),9);T.eq(amount(cs,45596,'spellDamage'),9)
 end,
 russian_piercing_current_bonus_uses_native_amount_at_each_stage=function()
    for _,pair in ipairs({{15,350},{16,700}})do
        local cs=K.Sources.Champion.Build(snapshot(pair[1]))
        T.eq(amount(cs,10,'physicalPenetration'),pair[2]);T.eq(amount(cs,10,'spellPenetration'),pair[2])
    end
 end,
 rejuvenation_current_bonus_applies_to_all_three_recoveries=function()
    local cs=K.Sources.Champion.Build(snapshot(16))
    for _,stat in ipairs({'healthRecovery','magickaRecovery','staminaRecovery'})do T.eq(amount(cs,35,stat),90)end
    local s={meta={language='ru'},champion={{id=90001,points=50,slottable=true,slot=11,
        currentBonus='Увеличение восстановления здоровья, магии и запаса сил на 123'}}}
    cs=K.Sources.Champion.Build(s)
    for _,stat in ipairs({'healthRecovery','magickaRecovery','staminaRecovery'})do T.eq(amount(cs,90001,stat),123)end
    s.champion[1].slot=nil;T.eq(#K.Sources.Champion.Build(s),0)
 end,
 overland_dump_16_reconciles_all_fifteen_stats=function()
    local s=snapshot(16);local b=K.App.New({}):Explain(s)
    for _,def in ipairs(K.Stats.Definitions)do
        T.eq(b[def[1]].unknown,0);T.eq(T.sumRows(b[def[1]]),s.stats[def[1]].total)
    end
 end,
 old_archive_dump_keeps_bonuses_without_recorded_sources_unknown=function()
    local s=snapshot(15);local b=K.App.New({}):Explain(s)
    local residuals={maxStamina=1264,staminaRecovery=196,physicalPenetration=6642,spellPenetration=6642}
    for _,def in ipairs(K.Stats.Definitions)do
        T.eq(b[def[1]].unknown,residuals[def[1]] or 0);T.eq(T.sumRows(b[def[1]]),s.stats[def[1]].total)
    end
 end,
 extra_unknown_bonus_is_not_absorbed_by_new_source_rules=function()
    local s=snapshot(16);s.stats.spellDamage.total=s.stats.spellDamage.total+7
    local b=K.App.New({}):Explain(s)
    T.eq(b.spellDamage.unknown,7);T.eq(b.weaponDamage.unknown,0)
 end,
 per_stage_cp_descriptions_are_not_treated_as_current_totals=function()
    local s={meta={language='ru'},champion={{id=10,points=20,slottable=false,
        currentBonus='Пробивание увеличивается на 350 за каждую стадию.'},
        {id=35,points=50,slottable=true,slot=11,
        currentBonus='Восстановление здоровья, магии и запаса сил увеличивается на 1,8 за каждую стадию.'}}}
    T.eq(#K.Sources.Champion.Build(s),0)
 end,
}
