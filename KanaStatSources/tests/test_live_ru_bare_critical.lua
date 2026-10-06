local T=dofile('KanaStatSources/tests/support.lua')
local K=T.load({'Core','Stats','Rules','Critical','Model','sources/Base'})
local function snapshot()return dofile('KanaStatSources/tests/fixtures/live_ru_bare_critical.lua')end
return {
 bare_native_critical_baseline_has_no_unknown=function()
    local s=snapshot();local b=K.Model.Build(s,K.Sources.Base.Build(s))
    for _,key in ipairs({'weaponCritical','spellCritical'})do
        T.eq(b[key].explained,2181);T.eq(b[key].unknown,0);T.eq(b[key].rawUnknown,0)
        T.eq(#b[key].rows,1);T.eq(b[key].rows[1].category,'base')
        T.eq(b[key].critical.verified,true);T.near(b[key].critical.chance,9.9534492493)
        T.eq(K.Stats.Number(b[key].rows[1].value/b[key].critical.pointsPerPercent,'ru',2),'9,95')
    end
 end,
 native_critical_baseline_preserves_unidentified_changes=function()
    local s=snapshot();s.stats.weaponCritical.total=2188
    local b=K.Model.Build(s,K.Sources.Base.Build(s)).weaponCritical
    T.eq(b.explained,2181);T.eq(b.unknown,7);T.eq(b.rawUnknown,7);T.eq(T.sumRows(b),2188)
 end,
}
