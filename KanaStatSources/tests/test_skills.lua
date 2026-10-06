local T=dofile('KanaStatSources/tests/support.lua');local K=T.load({'Core','Stats','Rules','Descriptions','sources/Skills'})
local function s() return {meta={language='en'},context={bar='front'},skills={{id=100,name='Passive',rank=2,purchased=true,passive=true,lineActive=true,description='Increases your Maximum Magicka by 2000.'}},bars={front={},back={[3]={abilityId=200}}}} end
local function sword(language,description)
    local v=s();v.meta.language=language or 'en'
    v.constants={SKILL_TYPE_WEAPON=2,EQUIP_SLOT_MAIN_HAND=4,EQUIP_SLOT_OFF_HAND=5,EQUIP_SLOT_BACKUP_MAIN=20,EQUIP_SLOT_BACKUP_OFF=21,WEAPONTYPE_AXE=1,WEAPONTYPE_HAMMER=2,WEAPONTYPE_SWORD=3,WEAPONTYPE_DAGGER=11,WEAPONTYPE_SHIELD=14,WEAPONTYPE_FROST_STAFF=13,WEAPONTYPE_TWO_HANDED_SWORD=4}
    v.equipment={{slot=4,weaponType=1},{slot=5,weaponType=14},{slot=20,weaponType=13}}
    v.skills={{id=29397,purchased=true,passive=true,lineActive=true,skillType=2,description=description or 'Increases your Weapon and Spell Damage by 5% and the amount of damage you can block by 20%.'}}
    return v
end
return {
 sword_and_board_reads_native_ru_en_amount=function()
    for _,v in ipairs({sword(),sword('ru','Ваша сила оружия и заклинаний увеличивается на |cffffff3|r%, а количество урона, которое вы можете заблокировать, — на |cffffff10%|r.')})do
        local c=K.Sources.Skills.Build(v);T.eq(#c,2)
        T.eq(c[1].stat,'weaponDamage');T.eq(c[2].stat,'spellDamage');T.eq(c[1].operation,'percent')
        T.eq(c[1].amount,v.meta.language=='en' and 5 or 3)
    end
 end,
 sword_and_board_accepts_supported_one_hand_types_on_either_bar=function()
    for _,weapon in ipairs({1,2,3,11})do
        local v=sword();v.equipment[1].weaponType=weapon;T.eq(#K.Sources.Skills.Build(v),2)
        v.context.bar='back';T.eq(#K.Sources.Skills.Build(v),0)
        v.equipment[3].weaponType=weapon;v.equipment[4]={slot=21,weaponType=14}
        T.eq(#K.Sources.Skills.Build(v),2)
    end
 end,
 sword_and_board_rejects_missing_or_inactive_weapon_metadata=function()
    for _,change in ipairs({
        function(v)v.context.bar='back'end,
        function(v)v.context.bar='werewolf'end,
        function(v)v.context.bar=nil end,
        function(v)v.equipment[2]=nil end,
        function(v)v.equipment[2].weaponType=11 end,
        function(v)v.equipment[1].weaponType=4 end,
        function(v)v.equipment[1].weaponType=13 end,
        function(v)v.equipment[1].weaponType=nil end,
        function(v)v.equipment[2].weaponType=nil end,
        function(v)v.constants.WEAPONTYPE_SHIELD=nil end,
        function(v)v.constants.WEAPONTYPE_AXE=nil end,
        function(v)v.constants.EQUIP_SLOT_MAIN_HAND=nil end,
        function(v)v.constants.EQUIP_SLOT_OFF_HAND=nil end,
        function(v)v.equipment=nil end,
    })do
        local v=sword();change(v);local c,d=K.Sources.Skills.Build(v)
        T.eq(#c,0);T.eq(#d>0,true)
    end
 end,
 sword_and_board_requires_active_purchase_and_complete_description=function()
    for _,change in ipairs({
        function(v)v.skills[1].purchased=false end,
        function(v)v.skills[1].lineActive=false end,
        function(v)v.skills[1].lineActive=nil end,
        function(v)v.meta.language='de'end,
        function(v)v.skills[1].description='Increases your Weapon and Spell Damage by 5% while in combat.'end,
        function(v)v.skills[1].description=v.skills[1].description..' While in combat.'end,
        function(v)v.skills[1].description=nil end,
    })do local v=sword();change(v);T.eq(#K.Sources.Skills.Build(v),0)end
 end,
 erudition_uses_complete_current_description=function()
    for _,p in ipairs({{'ru','Знание — сила. Ваша необычайная ученость увеличивает восстановление магии и запаса сил на |cffffff18%|r.',18},{'en','Knowledge is power.Your excessive scholarship increases your Magicka and Stamina Recovery by 9%.',9}})do
        local v=s();v.meta.language=p[1];v.skills={{id=185239,passive=true,purchased=true,lineActive=true,description=p[2]}}
        local c=K.Sources.Skills.Build(v);T.eq(#c,2)
        T.eq(c[1].stat,'magickaRecovery');T.eq(c[2].stat,'staminaRecovery');T.eq(c[1].amount,p[3]);T.eq(c[2].operation,'percent')
        v.skills[1].description=p[2]..' While in combat.';T.eq(#K.Sources.Skills.Build(v),0)
        v.skills[1].description=p[2];v.skills[1].id=999;T.eq(#K.Sources.Skills.Build(v),0)
        v.skills[1].id=185239;v.skills[1].lineActive=false;T.eq(#K.Sources.Skills.Build(v),0)
        v.skills[1].lineActive=true;v.skills[1].purchased=false;T.eq(#K.Sources.Skills.Build(v),0)
    end
 end,
 weapon_passive_needs_equipped_weapon_rule=function()
    local v=s();v.constants={SKILL_TYPE_WEAPON=2}
    v.skills[1]={id=29397,purchased=true,passive=true,lineActive=true,skillType=2,description='Ваша сила оружия и заклинаний увеличивается на 3%, а количество заблокированного урона — на 10%.'}
    v.meta.language='ru'
    local c,d=K.Sources.Skills.Build(v);T.eq(#c,0);T.eq(#d>0,true)
 end,
 committed=function() local v=s();local c=K.Sources.Skills.Build(v);T.eq(#c,1);T.eq(c[1].amount,2000);v.skills[1].purchased=false;T.eq(#K.Sources.Skills.Build(v),0);v.skills[1].purchased=true;v.skills[1].lineActive=false;T.eq(#K.Sources.Skills.Build(v),0) end,
 active_not_static=function() local v=s();v.skills[1].passive=false;T.eq(#K.Sources.Skills.Build(v),0) end,
 registered_condition=function() K.Rules.Register({id=200,kind='skill',evidence='synthetic bar rule',active=function(source,v) for _,a in pairs(v.bars[v.context.bar]) do if a.abilityId==source.id then return true end end;return false end,build=function(source) return {{key=source.key,category='skills',stat='weaponDamage',operation='flat',amount=100}} end});local v=s();v.skills={{id=200,purchased=true,lineActive=true,passive=false}};T.eq(#K.Sources.Skills.Build(v),0);v.context.bar='back';T.eq(#K.Sources.Skills.Build(v),1) end,
 conditional=function() local v=s();v.skills[1].description='Increases your Maximum Health by 200 for each piece of Heavy Armor equipped.';local c,d=K.Sources.Skills.Build(v);T.eq(#c,0);T.eq(#d,1) end,
 other_language=function() local v=s();v.meta.language='fr';T.eq(#K.Sources.Skills.Build(v),0) end,
}
