local T=dofile('KanaStatSources/tests/support.lua');local K=T.load({'Core','Stats','Rules','Critical','Model','sources/Base'})
return {
 attributes=function() local s=T.snapshot({maxHealth=23000});s.meta={language='ru',apiVersion=101051};s.context={level=50,championPoints=160,battleLeveled=false,championBattleLeveled=false};s.attributes={health={spent=10,perPoint=150}};local c=K.Sources.Base.Build(s);local b=K.Model.Build(s,c);T.eq(b.maxHealth.rows[1].value,16000);T.eq(b.maxHealth.rows[2].value,1500);T.eq(T.sumRows(b.maxHealth),23000) end,
 no_inferred_base=function() local s=T.snapshot({maxHealth=99999});s.meta={apiVersion=999};s.context={level=30,battleLeveled=true};s.attributes={health={spent=1,perPoint=122}};s.stats.maxHealth.withoutBonus=99999;local c=K.Sources.Base.Build(s);T.eq(#c,1);T.eq(c[1].category,'attributes');T.eq(c[1].operation,'effectiveFlat') end,
}
