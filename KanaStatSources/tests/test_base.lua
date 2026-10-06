local T=dofile('KanaStatSources/tests/support.lua');local K=T.load({'Core','Stats','Rules','Critical','Model','sources/Base'})
return {
 attributes=function() local s=T.snapshot({maxHealth=23000});s.meta={language='ru',apiVersion=101051};s.context={level=50,championPoints=160,battleLeveled=false,championBattleLeveled=false};s.attributes={health={spent=10,perPoint=150}};local c=K.Sources.Base.Build(s);local b=K.Model.Build(s,c);T.eq(b.maxHealth.rows[1].value,16000);T.eq(b.maxHealth.rows[2].value,1500);T.eq(T.sumRows(b.maxHealth),23000) end,
 no_inferred_base=function() local s=T.snapshot({maxHealth=99999});s.meta={apiVersion=999};s.context={level=30,battleLeveled=true};s.attributes={health={spent=1,perPoint=122}};s.stats.maxHealth.withoutBonus=99999;local c=K.Sources.Base.Build(s);T.eq(#c,1);T.eq(c[1].category,'attributes');T.eq(c[1].operation,'flat') end,
 verified_recovery_and_critical_resistance_bases=function()
    local s=T.snapshot({healthRecovery=309,magickaRecovery=514,staminaRecovery=514,criticalResistance=1320})
    s.meta={apiVersion=101051};s.context={level=50,championPoints=527,battleLeveled=false,championBattleLeveled=false}
    local b=K.Model.Build(s,K.Sources.Base.Build(s))
    for key,expected in pairs({healthRecovery=309,magickaRecovery=514,staminaRecovery=514,criticalResistance=1320})do
        T.eq(b[key].unknown,0);T.eq(b[key].rows[1].key,'base:'..key);T.eq(b[key].rows[1].rawValue,expected)
    end
 end,
 new_bases_never_inferred_outside_verified_context=function()
    for _,override in ipairs({{level=49},{championPoints=159},{battleLeveled=true},{championBattleLeveled=true},{apiVersion=101052},{missing='battleLeveled'},{missing='championBattleLeveled'}})do
        local s=T.snapshot({healthRecovery=999,magickaRecovery=999,staminaRecovery=999,criticalResistance=999})
        s.meta={apiVersion=101051};s.context={level=50,championPoints=160,battleLeveled=false,championBattleLeveled=false}
        for k,v in pairs(override)do if k=='apiVersion'then s.meta[k]=v elseif k=='missing'then s.context[v]=nil else s.context[k]=v end end
        for _,stat in pairs(s.stats)do stat.withoutBonus=999 end
        local b=K.Model.Build(s,K.Sources.Base.Build(s))
        for key in pairs(s.stats)do T.eq(b[key].explained,0);T.eq(b[key].unknown,999)end
    end
 end,
 attributes_are_included_in_resource_percentage_base=function()
    local s=T.snapshot({maxHealth=24998,maxMagicka=12717,maxStamina=12717})
    s.meta={apiVersion=101051};s.context={level=50,championPoints=160,battleLeveled=false,championBattleLeveled=false}
    s.attributes={health={spent=64,perPoint=122},magicka={spent=1,perPoint=111},stamina={spent=1,perPoint=111}}
    local c=K.Sources.Base.Build(s)
    for key in pairs(s.stats)do c[#c+1]=T.percent('bonus:'..key,key,5,'additive')end
    local b=K.Model.Build(s,c,nil,K.Rules.Policies)
    for key in pairs(s.stats)do T.eq(b[key].unknown,0)end
    T.near(b.maxHealth.rawExplained,24998.4)
 end,
 native_attribute_and_base_icons=function()
    local s=T.snapshot({maxHealth=17000,maxMagicka=12111,maxStamina=12111})
    s.meta={language='ru',apiVersion=101051};s.context={level=50,championPoints=160,battleLeveled=false,championBattleLeveled=false}
    s.attributes={health={spent=1,perPoint=122},magicka={spent=1,perPoint=111},stamina={spent=1,perPoint=111}}
    local c=K.Sources.Base.Build(s);local b=K.Model.Build(s,c)
    for _,p in ipairs({{'maxHealth','health'},{'maxMagicka','magicka'},{'maxStamina','stamina'}})do
        T.eq(type(b[p[1]].rows[1].icon),'string')
        T.eq(b[p[1]].rows[2].icon,'/esoui/art/characterwindow/Gamepad/gp_characterSheet_'..p[2]..'Icon.dds')
    end
 end,
 base_critical_ten_percent_uses_client_conversion=function()
    for _,divisor in ipairs({200,219.12})do
        local s=T.snapshot({weaponCritical=5000,spellCritical=5000});s.meta={apiVersion=101051}
        for _,key in ipairs({'weaponCritical','spellCritical'})do
            s.criticalSamples[key]={{rating=0,chance=0},{rating=1,chance=1/divisor},{rating=5000,chance=5000/divisor}}
        end
        local cs=K.Sources.Base.Build(s);local b=K.Model.Build(s,cs)
        for _,key in ipairs({'weaponCritical','spellCritical'})do
            T.eq(b[key].rows[1].category,'base');T.near(b[key].rows[1].rawValue,10*divisor)
            T.eq(b[key].rows[1].amount,10);T.eq(type(b[key].rows[1].icon),'string')
            T.eq(T.sumRows(b[key]),5000)
        end
    end
 end,
 uncalibrated_critical_base_is_diagnostic=function()
    local s=T.snapshot({weaponCritical=5000});s.meta={apiVersion=101051}
    local c=K.Sources.Base.Build(s);local b=K.Model.Build(s,c).weaponCritical
    T.eq(b.explained,0);T.eq(b.unknown,5000);T.eq(#b.diagnostics,1)
 end,
}
