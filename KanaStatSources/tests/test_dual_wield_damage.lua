local T=dofile('KanaStatSources/tests/support.lua')
local files={}
for line in io.lines('KanaStatSources/KanaStatSources.addon')do if line:match('%.lua$')then files[#files+1]=line:gsub('%.lua$','')end end
local K=T.load(files)
local function snapshots()return dofile('KanaStatSources/tests/fixtures/live_ru_dual_wield_damage.lua')end
local function row(b,key)
    for _,r in ipairs(b.rows)do if r.key==key then return r end end
    error('Missing contribution '..key)
end
local function verify(s,total,unknown)
    local b=K.App.New({}):Explain(s)
    for _,stat in ipairs({'weaponDamage','spellDamage'})do
        T.eq(b[stat].total,total);T.eq(b[stat].unknown,unknown)
        T.eq(T.sumRows(b[stat]),total)
    end
    return b
end
return {
 second_weapon_explains_controlled_damage_without_a_residual=function()
    local b=verify(snapshots()[9],3128,0)
    for _,stat in ipairs({'weaponDamage','spellDamage'})do
        T.eq(row(b[stat],'item:4:power:1').value,1132)
        local off=row(b[stat],'item:5:power:1')
        T.eq(off.value,201);T.eq(off.source.slot,5);T.eq(off.name,'Смертоносный кинжал')
        T.near(b[stat].rawExplained,3128.4)
        T.eq(row(b[stat],'buff:2:1').base,2607)
    end
 end,
 medium_shoulder_adds_53_to_both_damage_stats=function()
    local s=snapshots();local before=verify(s[9],3128,0);local after=verify(s[10],3181,0)
    for _,stat in ipairs({'weaponDamage','spellDamage'})do
        T.eq(after[stat].total-before[stat].total,53)
        local agility=row(after[stat],'skill:45572:1')
        T.eq(agility.base,2607);T.eq(agility.amount,2);T.near(agility.rawValue,52.14)
        T.near(after[stat].rawExplained,3180.54)
    end
 end,
 offhand_rule_keeps_an_unrelated_unknown_bonus=function()
    local s=snapshots()[9]
    for _,stat in ipairs({'weaponDamage','spellDamage'})do s.stats[stat].total=3135 end
    local b=verify(s,3135,7)
    T.eq(row(b.spellDamage,'item:5:power:1').value,201)
 end,
 offhand_rule_uses_current_power_for_all_one_handed_weapon_types=function()
    local cases={{'WEAPONTYPE_AXE',1500,267},{'WEAPONTYPE_HAMMER',1700,302},{'WEAPONTYPE_SWORD',1000,178},{'WEAPONTYPE_DAGGER',1132,201}}
    for _,case in ipairs(cases)do
        local s=snapshots()[9];s.sets={};s.champion={};s.effects={};s.skills={}
        s.equipment[1].weaponPower=1000;s.equipment[1].weaponType=s.constants.WEAPONTYPE_SWORD
        local off=s.equipment[2];off.weaponType=s.constants[case[1]];off.weaponPower=case[2]
        off.id=99999;off.name='Unrelated weapon';off.quality=5;off.cp=0;off.level=20;off.trait=nil
        local expected=2000+case[3]
        for _,stat in ipairs({'weaponDamage','spellDamage'})do s.stats[stat].total=expected end
        local b=verify(s,expected,0)
        T.eq(row(b.spellDamage,'item:5:power:1').value,case[3])
    end
 end,
 offhand_rule_follows_the_active_weapon_bar=function()
    local s=snapshots()[9]
    s.context.bar='back';s.context.weaponPair=2;s.context.hotbarCategory=s.constants.HOTBAR_CATEGORY_BACKUP
    s.equipment[1].slot=20;s.equipment[2].slot=21
    local b=verify(s,3128,0);T.eq(row(b.spellDamage,'item:21:power:1').value,201)
    s.context.bar='front';s.context.weaponPair=1;s.context.hotbarCategory=s.constants.HOTBAR_CATEGORY_PRIMARY
    b=K.App.New({}):Explain(s)
    for _,r in ipairs(b.spellDamage.rows)do T.eq(r.source and (r.source.slot==20 or r.source.slot==21) or false,false)end
 end,
 offhand_power_is_not_inferred_for_shields_or_incomplete_weapon_context=function()
    local changes={
        function(s)s.equipment[2].weaponType=s.constants.WEAPONTYPE_SHIELD end,
        function(s)s.equipment[1].weaponType=s.constants.WEAPONTYPE_LIGHTNING_STAFF end,
        function(s)s.equipment[1].weaponType=nil end,
        function(s)s.context.hotbarCategory=nil end,
        function(s)s.context.hotbarCategory=s.constants.HOTBAR_CATEGORY_WEREWOLF end,
        function(s)s.context.weaponPair=2 end,
        function(s)s.constants.HOTBAR_CATEGORY_PRIMARY=nil end,
    }
    for _,change in ipairs(changes)do
        local s=snapshots()[9];change(s);local b=verify(s,3128,241)
        for _,r in ipairs(b.spellDamage.rows)do T.eq(r.key=='item:5:power:1',false)end
    end
 end,
}
