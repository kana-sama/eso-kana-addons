local T=dofile('KanaStatSources/tests/support.lua')
local files={};for line in io.lines('KanaStatSources/KanaStatSources.addon')do if line:match('%.lua$')then files[#files+1]=line:gsub('%.lua$','')end end
local K=T.load(files)
local function snapshot()return dofile('KanaStatSources/tests/fixtures/live_ru.lua')end
local function amount(cs,id,stat)
    local total=0
    for _,c in ipairs(cs)do if c.source and c.source.id==id and c.stat==stat then total=total+c.amount end end
    return total
end
return {
 native_float_critical_formula=function()
    local s=snapshot();local c=K.Critical.Calibrate(s.criticalSamples.weaponCritical,s.stats.weaponCritical.total)
    T.eq(c.verified,true)
    local formula=K.Critical.Formula(c,'ru')
    T.eq(formula:find('31,3%',1,true)~=nil,true)
    T.eq(formula:find('не распознана',1,true),nil)
    T.near(c.pointsPerPercent,219.12,0.001)
 end,
 native_lower_used=function()
    local old=LocaleAwareToLower;local calls=0
    LocaleAwareToLower=function(text)calls=calls+1;T.eq(text,'Макс. запас сил +802.');return 'макс. запас сил +802.'end
    local ok,result=pcall(K.Descriptions.Lower,'Макс. запас сил +802.')
    LocaleAwareToLower=old
    T.eq(ok,true);T.eq(result,'макс. запас сил +802.');T.eq(calls,1)
 end,
 food_and_permanent_effects=function()
    local c=K.Sources.Effects.Build(snapshot())
    T.eq(amount(c,86673,'maxStamina'),4515)
    T.eq(amount(c,86673,'staminaRecovery'),451)
    T.eq(amount(c,13975,'weaponCritical'),1897)
    -- The original dump had no effect-slot description: do not invent its 20%.
    T.eq(amount(c,61665,'weaponDamage'),0)
 end,
 equipped_glyphs_and_sets=function()
    local c=K.Sources.Equipment.Build(snapshot());local glyphs=0;local total=0
    for _,r in ipairs(c)do if r.stat=='maxStamina' and r.source.key:find(':enchant',1,true)then glyphs=glyphs+1;total=total+r.amount end end
    T.eq(glyphs,7);T.eq(total,3702)
    T.eq(amount(c,809,'physicalPenetration'),1435)
    T.eq(amount(c,127,'weaponDamage'),248)
 end,
 native_champion_text=function()
    local c=K.Sources.Champion.Build(snapshot())
    T.eq(amount(c,5,'maxStamina'),1300);T.eq(amount(c,3,'maxMagicka'),364)
    T.eq(amount(c,4,'weaponDamage'),150);T.eq(amount(c,11,'weaponCritical'),160)
 end,
 purchased_passive_sources=function()
    local c=K.Sources.Skills.Build(snapshot())
    T.eq(amount(c,45255,'maxHealth'),1000)
    T.eq(amount(c,45247,'maxStamina'),1000);T.eq(amount(c,45247,'maxMagicka'),1000)
    T.eq(amount(c,184887,'physicalPenetration'),4960)
    T.eq(amount(c,45572,'weaponDamage'),14)
 end,
 replay_reconciles_every_stat=function()
    local s=snapshot();local b=K.App.New({}):Explain(s)
    for _,d in ipairs(K.Stats.Definitions)do T.eq(T.sumRows(b[d[1]]),s.stats[d[1]].total)end
    T.eq(b.maxHealth.unknown,0);T.eq(b.maxMagicka.unknown,0)
    T.eq(b.maxStamina.unknown,421)
    T.eq(b.physicalPenetration.unknown,0)
 end,
 native_damage_total_with_current_brutality_description=function()
    local s=snapshot()
    for _,effect in ipairs(s.effects)do
        if effect.abilityId==61665 then effect.effectDescription='Увеличивает силу оружия и заклинаний на 20%.' end
    end
    local b=K.App.New({}):Explain(s)
    T.eq(b.weaponDamage.total,4218);T.eq(b.weaponDamage.unknown,0);T.near(b.weaponDamage.rawUnknown,-0.32)
    T.eq(T.sumRows(b.weaponDamage),4218);T.eq(b.spellDamage.unknown,0)
 end,
}
