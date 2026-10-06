local T=dofile('KanaStatSources/tests/support.lua')
local files={};for line in io.lines('KanaStatSources/KanaStatSources.addon')do if line:match('%.lua$')then files[#files+1]=line:gsub('%.lua$','')end end
local K=T.load(files)
local makeApi=dofile('KanaStatSources/tests/fixtures/capture.lua')
local function capture(category,pair,missing)
    local api=makeApi()
    api.GetActiveHotbarCategory=function()return category end
    api.GetActiveWeaponPairInfo=function()return pair,false end
    api.EQUIP_SLOT_MAIN_HAND=4;api.EQUIP_SLOT_OFF_HAND=5;api.EQUIP_SLOT_BACKUP_MAIN=20;api.EQUIP_SLOT_BACKUP_OFF=21
    api.EQUIP_SLOT_ITERATION_BEGIN=pair==2 and 20 or 4;api.EQUIP_SLOT_ITERATION_END=pair==2 and 21 or 5
    api.WEAPONTYPE_AXE=1;api.WEAPONTYPE_SHIELD=14
    -- Both bars equip an axe and shield; only the category/pair admission varies.
    api.GetItemLinkWeaponType=function(link)local slot=tonumber(link:match(':(%d+)$'));return (slot==5 or slot==21) and 14 or 1 end
    if missing then api[missing]=nil end
    local s=K.Snapshot.New(api):Capture(false)
    s.skills={{id=29397,purchased=true,passive=true,lineActive=true,description='Increases your Weapon and Spell Damage by 5% and the amount of damage you can block by 20%.'}}
    s.meta.language='en'
    return s
end
return {
 native_hotbar_enums_are_captured=function()
    local s=capture(0,1)
    T.eq(s.constants.HOTBAR_CATEGORY_PRIMARY,0);T.eq(s.constants.HOTBAR_CATEGORY_BACKUP,1)
 end,
 collector_to_rule_accepts_matching_normal_bars=function()
    T.eq(#K.Sources.Skills.Build(capture(0,1)),2)
    T.eq(#K.Sources.Skills.Build(capture(1,2)),2)
 end,
 collector_to_rule_rejects_temporary_unknown_missing_or_mismatched_bars=function()
    for _,p in ipairs({{2,1},{123,1},{1,1},{0,2},{0,1,'HOTBAR_CATEGORY_PRIMARY'},{1,2,'HOTBAR_CATEGORY_BACKUP'},{3,1,'HOTBAR_CATEGORY_WEREWOLF'}})do
        T.eq(#K.Sources.Skills.Build(capture(p[1],p[2],p[3])),0)
    end
    T.eq(#K.Sources.Skills.Build(capture(nil,1)),0)
 end,
 legacy_snapshot_without_hotbar_enums_remains_unknown=function()
    local s=dofile('KanaStatSources/tests/fixtures/live_ru_tank.lua')
    local b=K.App.New({}):Explain(s)
    T.eq(b.weaponDamage.unknown,73);T.eq(b.spellDamage.unknown,73)
 end,
}
