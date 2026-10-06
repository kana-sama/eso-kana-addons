local T=dofile('KanaStatSources/tests/support.lua');local K=T.load({'Core','Stats','Rules','Descriptions','sources/Skills'})
local function s() return {meta={language='en'},context={bar='front'},skills={{id=100,name='Passive',rank=2,purchased=true,passive=true,lineActive=true,description='Increases your Maximum Magicka by 2000.'}},bars={front={},back={[3]={abilityId=200}}}} end
return {
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
