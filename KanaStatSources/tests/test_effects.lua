local T=dofile('KanaStatSources/tests/support.lua');local K=T.load({'Core','Stats','Rules','Descriptions','sources/Effects','capture/Effects'})
local function s(e) return {meta={language='en'},context={now=10000,mundusIndices={2}},effects=e} end
return {
 native_effect_slot_description=function()
    local api=dofile('KanaStatSources/tests/fixtures/capture.lua')()
    api.GetAbilityDescription=function()return ''end
    api.GetAbilityEffectDescription=function(slot)T.eq(slot,1);return 'Увеличивает силу оружия и заклинаний на 20%.'end
    api.IsAbilityPermanent=function()return true end
    local data=K.CaptureEffects.Read(api);data.meta={language='ru'}
    local cs=K.Sources.Effects.Build(data)
    T.eq(#cs,2);T.eq(cs[1].operation,'percent');T.eq(cs[1].amount,20)
    T.eq(data.effects[1].effectDescription~='',true)
 end,
 deduplicate=function() local c=K.Sources.Effects.Build(s({{abilityId=1,index=1,endTime=0,description='Increases your Weapon and Spell Damage by 430.',castByPlayer=false},{abilityId=1,index=3,endTime=0,description='Increases your Weapon and Spell Damage by 430.'}}));T.eq(#c,2);T.eq(c[1].amount,430) end,
 expiration=function() local c=K.Sources.Effects.Build(s({{abilityId=1,endTime=9,description='Increases Maximum Health by 1000.'},{abilityId=2,index=3,endTime=0,description='Increases Maximum Health by 500.'}}));T.eq(#c,1);T.eq(c[1].amount,500) end,
 categories=function() local c=K.Sources.Effects.Build(s({{abilityId=68411,index=1,endTime=1000,description='Increase Max Health by 5395 and Max Magicka by 4936 for 2 hours.'},{abilityId=13940,index=2,endTime=0,derivedStats={{stat='weaponCritical',value=2500},{stat='spellCritical',value=2500}},description='Increases Weapon and Spell Critical rating by 2000.'}}));T.eq(#c,4);T.eq(c[1].category,'food');T.eq(c[3].category,'mundus');T.eq(c[3].amount,2500);T.eq(c[3].operation,'effectiveFlat') end,
 canonical_buff=function() local c=K.Sources.Effects.Build(s({{abilityId=1,buffType=10,endTime=0,description='Increases Weapon and Spell Damage by 20%.'},{abilityId=2,buffType=10,endTime=0,description='Increases Weapon and Spell Damage by 20%.'},{abilityId=3,buffType=11,endTime=0,description='Increases Weapon and Spell Damage by 10%.'}}));T.eq(#c,4);T.eq(c[1].key~=c[3].key,true) end,
 stack_unknown=function() local c,d=K.Sources.Effects.Build(s({{abilityId=1,index=1,endTime=0,stacks=3,description='Increases Maximum Health by 1000 per stack.'}}));T.eq(#c,0);T.eq(#d,1) end,
 capture_native=function() local api=dofile('KanaStatSources/tests/fixtures/capture.lua')();api.GetAbilityNumDerivedStats=function()return 1 end;api.GetAbilityDerivedStatAndEffectByIndex=function()return api.STAT_HEALTH_MAX,1234 end;api.GetAbilityBuffType=function()return 10 end;local v=K.CaptureEffects.Read(api);T.eq(v.effects[1].derivedStats[1].stat,'maxHealth');T.eq(v.effects[1].derivedStats[1].value,1234);T.eq(v.effects[1].buffType,10) end,
}
