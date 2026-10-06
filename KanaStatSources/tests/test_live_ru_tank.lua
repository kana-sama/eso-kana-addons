local T=dofile('KanaStatSources/tests/support.lua')
local files={};for line in io.lines('KanaStatSources/KanaStatSources.addon')do if line:match('%.lua$')then files[#files+1]=line:gsub('%.lua$','')end end
local K=T.load(files)
local function snapshot()
    local s=dofile('KanaStatSources/tests/fixtures/live_ru_tank.lua')
    -- 1.0.4 did not capture these enums. Replay with the same native API enum
    -- fixture used by the collector tests; leave the saved snapshot untouched.
    local api=dofile('KanaStatSources/tests/fixtures/capture.lua')()
    s.constants.HOTBAR_CATEGORY_PRIMARY=api.HOTBAR_CATEGORY_PRIMARY
    s.constants.HOTBAR_CATEGORY_BACKUP=api.HOTBAR_CATEGORY_BACKUP
    return s
end
local function row(b,key)
    for _,r in ipairs(b.rows)do if r.key==key then return r end end
    error('missing source '..key)
end
return {
 latest_remaining_unknowns_are_only_unverified_critical_conversion=function()
    local b=K.App.New({}):Explain(snapshot())
    for _,d in ipairs(K.Stats.Definitions)do
        T.eq(b[d[1]].unknown,(d[1]=='weaponCritical' or d[1]=='spellCritical') and -10 or 0)
    end
 end,
 latest_damage_includes_active_sword_and_board=function()
    local b=K.App.New({}):Explain(snapshot())
    for _,key in ipairs({'weaponDamage','spellDamage'})do
        T.eq(b[key].unknown,0)
        local r=row(b[key],'skill:29397:1');T.eq(r.amount,3);T.eq(r.base,2406);T.near(r.rawValue,72.18)
        T.near(b[key].rawExplained,3007.5);T.eq(T.sumRows(b[key]),3008)
    end
 end,
 latest_recovery_has_verified_base_and_current_passives=function()
    local b=K.App.New({}):Explain(snapshot())
    T.eq(b.healthRecovery.unknown,0);T.eq(row(b.healthRecovery,'base:healthRecovery').rawValue,309)
    T.eq(b.magickaRecovery.unknown,0);T.eq(row(b.magickaRecovery,'base:magickaRecovery').rawValue,514)
    T.eq(b.staminaRecovery.unknown,0);T.eq(row(b.staminaRecovery,'base:staminaRecovery').rawValue,514)
    T.near(row(b.healthRecovery,'skill:45526:1').base,552)
    T.near(row(b.magickaRecovery,'skill:185239:1').base,881)
    T.near(row(b.staminaRecovery,'skill:45565:1').rawValue,35.24)
    T.near(b.healthRecovery.rawExplained,662.4)
    T.near(b.magickaRecovery.rawExplained,1039.58)
    T.near(b.staminaRecovery.rawExplained,1074.82)
 end,
 latest_health_scales_committed_attributes_once=function()
    local b=K.App.New({}):Explain(snapshot()).maxHealth
    T.eq(b.unknown,0);T.eq(row(b,'attributes:health').rawValue,7808)
    T.eq(row(b,'skill:29804:1').base,30919);T.near(row(b,'skill:29804:1').rawValue,1545.95)
    T.near(b.rawExplained,32464.95)
 end,
 latest_critical_resistance_base_is_a_named_source=function()
    local b=K.App.New({}):Explain(snapshot()).criticalResistance
    T.eq(b.unknown,0);T.eq(#b.rows,1);T.eq(row(b,'base:criticalResistance').value,1320)
 end,
 unknown_sources_and_critical_discrepancy_are_retained=function()
    local s=snapshot();s.stats.magickaRecovery.total=s.stats.magickaRecovery.total+7
    -- withoutBonus mirrors the changed total; it must not become a guessed base.
    s.stats.magickaRecovery.withoutBonus=s.stats.magickaRecovery.total
    local b=K.App.New({}):Explain(s)
    T.eq(b.magickaRecovery.unknown,7)
    T.eq(b.weaponCritical.unknown,-10);T.eq(b.spellCritical.unknown,-10)
    for _,d in ipairs(K.Stats.Definitions)do T.eq(T.sumRows(b[d[1]]),s.stats[d[1]].total)end
 end,
}
