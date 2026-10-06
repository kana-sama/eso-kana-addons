local T=dofile('KanaStatSources/tests/support.lua')
local files={}
for line in io.lines('KanaStatSources/KanaStatSources.addon')do if line:match('%.lua$')then files[#files+1]=line:gsub('%.lua$','')end end
local K=T.load(files)
local function fixtures()return dofile('KanaStatSources/tests/fixtures/live_ru_mixed_set_damage.lua')end
local function damage(value)return '(3 items) Adds '..value..' Weapon and Spell Damage.'end
local function sample(slot,weaponType,value,setId)
    return {slot=slot,weaponType=weaponType,setId=setId or 90001,familyId=setId or 90001,name='Unrelated item',setBonuses={{index=1,required=3,description=damage(value),perfected=false}}}
end
local function snapshot()
    local s=fixtures()[13]
    s.meta.language='en';s.equipment={};s.sets={[90001]={id=90001,familyId=90001,name='Unrelated set',normal=3,perfected=0,bonuses={{index=1,required=3,description=damage(63),perfected=false}}}}
    return s
end
local function setAmounts(s)
    local c,d=K.Sources.Equipment.Build(s);local totals={};local rows={}
    for _,v in ipairs(c)do if v.category=='sets' and v.operation=='flat'then totals[v.stat]=(totals[v.stat]or 0)+v.amount;rows[v.stat]=v end end
    return totals,d,rows
end
return {
 controlled_mixed_quality_damage_reconciles_before_and_after_major_brutality=function()
    local s=fixtures()
    for _,case in ipairs({{11,2183,27342},{12,1758,26837},{13,1819,22406}})do
        local b=K.App.New({}):Explain(s[case[1]])
        for _,stat in ipairs({'weaponDamage','spellDamage'})do
            T.eq(b[stat].total,case[2]);T.eq(b[stat].unknown,0);T.eq(T.sumRows(b[stat]),case[2])
            if case[1]~=12 then
                local found=false
                for _,r in ipairs(b[stat].rows)do if r.category=='sets'then T.eq(r.amount,61);found=true end end
                T.eq(found,true)
            end
        end
        T.eq(b.maxStamina.total,case[3]);T.eq(b.maxStamina.unknown,0)
    end
 end,
 reported_quality_combinations_produce_58_60_and_61=function()
    for _,case in ipairs({{false,false,58},{true,false,60},{false,true,61}})do
        local s=snapshot();local c=s.constants
        s.equipment={sample(4,c.WEAPONTYPE_LIGHTNING_STAFF,58),sample(11,c.WEAPONTYPE_NONE,case[2]and 67 or 58)}
        if case[1]then s.equipment[#s.equipment+1]=sample(12,c.WEAPONTYPE_NONE,67);s.sets[90001].normal=4 end
        local amounts,_,rows=setAmounts(s)
        T.eq(amounts.weaponDamage,case[3]);T.eq(amounts.spellDamage,case[3])
        local audit=rows.weaponDamage.source.damageAverages.weaponDamage
        T.eq(audit.denominator,case[1]and 4 or 3);T.eq(audit.samples[1].weight,2)
    end
 end,
 all_native_two_handed_types_use_double_weight_without_item_or_quality_lookup=function()
    for _,name in ipairs({'WEAPONTYPE_TWO_HANDED_AXE','WEAPONTYPE_TWO_HANDED_HAMMER','WEAPONTYPE_TWO_HANDED_SWORD','WEAPONTYPE_BOW','WEAPONTYPE_FIRE_STAFF','WEAPONTYPE_FROST_STAFF','WEAPONTYPE_LIGHTNING_STAFF','WEAPONTYPE_HEALING_STAFF'})do
        local s=snapshot();s.equipment={sample(4,s.constants[name],82),sample(11,s.constants.WEAPONTYPE_NONE,121)}
        s.equipment[1].quality=1;s.equipment[1].level=1;s.equipment[1].cp=0;s.equipment[1].id=400001
        s.equipment[2].quality=5;s.equipment[2].level=50;s.equipment[2].cp=160;s.equipment[2].id=500002
        local amounts=setAmounts(s);T.eq(amounts.weaponDamage,95);T.eq(amounts.spellDamage,95)
    end
 end,
 one_handed_weapons_shields_and_body_items_use_single_weight=function()
    for _,name in ipairs({'WEAPONTYPE_AXE','WEAPONTYPE_HAMMER','WEAPONTYPE_SWORD','WEAPONTYPE_DAGGER','WEAPONTYPE_SHIELD'})do
        local s=snapshot();s.equipment={sample(name=='WEAPONTYPE_SHIELD'and 5 or 4,s.constants[name],82),sample(11,s.constants.WEAPONTYPE_NONE,121),sample(3,s.constants.WEAPONTYPE_NONE,121)}
        local amounts=setAmounts(s);T.eq(amounts.weaponDamage,108);T.eq(amounts.spellDamage,108)
    end
 end,
 inactive_weapon_bar_and_other_sets_do_not_enter_average=function()
    local s=snapshot();local c=s.constants
    s.equipment={sample(4,c.WEAPONTYPE_BOW,58),sample(11,c.WEAPONTYPE_NONE,67),sample(20,c.WEAPONTYPE_HEALING_STAFF,79),sample(3,c.WEAPONTYPE_NONE,900,90002)}
    local amounts,_,rows=setAmounts(s);T.eq(amounts.weaponDamage,61)
    T.eq(#rows.weaponDamage.source.damageAverages.weaponDamage.samples,2)
    s.context.bar='back';s.context.weaponPair=2;s.context.hotbarCategory=c.HOTBAR_CATEGORY_BACKUP
    amounts=setAmounts(s);T.eq(amounts.weaponDamage,75)
 end,
 percentage_and_non_damage_set_clauses_keep_native_behavior=function()
    local s=snapshot();s.equipment={sample(4,s.constants.WEAPONTYPE_BOW,58),sample(11,s.constants.WEAPONTYPE_NONE,67)}
    local bonuses=s.sets[90001].bonuses
    bonuses[2]={index=2,required=2,description='(2 items) Adds 535 Maximum Stamina.'}
    bonuses[3]={index=3,required=3,description='(3 items) Increases your Weapon and Spell Damage by 2%.'}
    local amounts=setAmounts(s);T.eq(amounts.weaponDamage,61);T.eq(amounts.maxStamina,535)
    local contributions=K.Sources.Equipment.Build(s)
    for _,v in ipairs(contributions)do if v.operation=='percent'then T.eq(v.amount,2)end end
 end,
 missing_item_values_do_not_create_a_partial_average=function()
    for _,change in ipairs({
        function(s)s.equipment[2].setBonuses=nil end,
        function(s)s.equipment[2].setBonuses[1].description='While sneaking, adds 67 Weapon and Spell Damage.'end,
        function(s)s.equipment[1].weaponType=nil end,
        function(s)s.equipment[2].setBonuses[1].required=5 end,
    })do
        local s=snapshot();s.equipment={sample(4,s.constants.WEAPONTYPE_BOW,58),sample(11,s.constants.WEAPONTYPE_NONE,67)};change(s)
        local amounts,diagnostics=setAmounts(s);T.eq(amounts.weaponDamage,63);T.eq(#diagnostics>0,true)
    end
 end,
 shared_and_perfected_bonuses_average_their_own_members=function()
    local s=snapshot();local c=s.constants;local common='(5 items) Adds %d Weapon and Spell Damage.';local perfect='(2 items) Adds %d Spell Damage.'
    local function item(slot,weaponType,id,value,extra)
        return {slot=slot,weaponType=weaponType,setId=id,familyId=90001,setBonuses={{index=1,required=5,description=string.format(common,value),perfected=false},extra and {index=2,required=2,description=string.format(perfect,extra),perfected=true}or nil}}
    end
    s.equipment={item(11,c.WEAPONTYPE_NONE,90001,58),item(3,c.WEAPONTYPE_NONE,90001,58),item(4,c.WEAPONTYPE_BOW,90002,100,17),item(0,c.WEAPONTYPE_NONE,90002,100,31)}
    local shared={index=1,required=5,description=string.format(common,84),perfected=false}
    s.sets={
        [90001]={id=90001,familyId=90001,name='Normal set',normal=2,perfected=3,bonuses={shared}},
        [90002]={id=90002,familyId=90001,name='Perfected set',normal=2,perfected=3,bonuses={shared,{index=2,required=2,description=string.format(perfect,24),perfected=true}}},
    }
    local amounts=setAmounts(s);T.eq(amounts.weaponDamage,83);T.eq(amounts.spellDamage,104)
 end,
 unexplained_damage_is_preserved_after_correcting_the_set=function()
    local s=fixtures()[13];s.stats.weaponDamage.total=1826;s.stats.spellDamage.total=1826
    local b=K.App.New({}):Explain(s)
    T.eq(b.weaponDamage.unknown,7);T.eq(b.spellDamage.unknown,7)
 end,
}
