local T=dofile('KanaStatSources/tests/support.lua')
local files={}
for line in io.lines('KanaStatSources/KanaStatSources.addon')do if line:match('%.lua$')then files[#files+1]=line:gsub('%.lua$','')end end
local K=T.load(files)
local function snapshot()return dofile('KanaStatSources/tests/fixtures/live_ru_precise.lua')end
local function verify(b,total,unknown)
    for _,stat in ipairs({'weaponCritical','spellCritical'})do
        T.eq(b[stat].total,total);T.eq(b[stat].unknown,unknown)
        T.eq(b[stat].rawUnknown,unknown);T.eq(T.sumRows(b[stat]),total)
    end
end
return {
 one_precise_staff_matches_controlled_integer_rating=function()
    local s=snapshot();local b,c=K.App.New({}):Explain(s)
    verify(b,3539,0)
    T.eq(#b.weaponCritical.rows,2)
    T.eq(b.weaponCritical.rows[1].value,2181);T.eq(b.weaponCritical.rows[2].value,1358)
    for _,r in ipairs(c)do if r.sourceKey=='item:4:trait' then T.eq(r.operation,'criticalChanceInteger');T.eq(r.amount,6.2)end end
    local bare=dofile('KanaStatSources/tests/fixtures/live_ru_bare_critical.lua')
    T.eq(s.stats.weaponCritical.total-bare.stats.weaponCritical.total,1358)
    local api=dofile('KanaStatSources/tests/fixtures/controls.lua')()
    local view=K.Table.New(api,api.InformationTooltip)
    view:Render(b.weaponCritical,'ru',{width=1280,height=720})
    T.eq(view.rows[1].effect,'10,0%');T.eq(view.rows[2].effect,'6,2%');T.eq(view.footerValue.text,'16,2%')
 end,
 original_complete_build_has_no_fictitious_critical_penalty=function()
    verify(K.App.New({}):Explain(dofile('KanaStatSources/tests/fixtures/live_ru.lua')),6864,0)
 end,
 precise_rule_does_not_absorb_additional_unknown_bonus=function()
    local s=snapshot()
    for _,stat in ipairs({'weaponCritical','spellCritical'})do
        s.stats[stat].total=3546
        s.criticalSamples[stat]={{rating=0,chance=0},{rating=1,chance=0.0045637093},{rating=3546,chance=3546/219.12}}
    end
    verify(K.App.New({}):Explain(s),3546,7)
 end,
 precise_rating_uses_current_native_conversion_not_an_item_constant=function()
    local s=snapshot()
    for _,stat in ipairs({'weaponCritical','spellCritical'})do
        s.stats[stat].total=3421
        s.criticalSamples[stat]={{rating=0,chance=0},{rating=1,chance=0.005},{rating=3421,chance=17.105}}
    end
    local b=K.App.New({}):Explain(s);verify(b,3421,0)
    T.eq(b.weaponCritical.rows[2].value,1240)
 end,
 precise_trait_does_not_require_item_identity_type_quality_or_level_metadata=function()
    local changes={
        function(s)s.equipment[1].id=123456;s.equipment[1].name='Any precise weapon' end,
        function(s)s.equipment[1].quality=5 end,
        function(s)s.equipment[1].cp=150 end,
        function(s)s.equipment[1].level=49 end,
        function(s)s.equipment[1].weaponType=12 end,
        function(s)s.constants.WEAPONTYPE_LIGHTNING_STAFF=nil;s.equipment[1].weaponType=nil end,
        function(s)s.meta.apiVersion=101052 end,
        function(s)s.context.championPoints=159 end,
        function(s)s.context.level=49 end,
        function(s)s.context.battleLeveled=true end,
        function(s)s.context.championBattleLeveled=nil end,
    }
    for _,change in ipairs(changes)do
        local s=snapshot();change(s);local c=K.Sources.Equipment.Build(s)
        c[#c+1]=T.flat('baseline','weaponCritical',2181)
        c[#c+1]=T.flat('baseline','spellCritical',2181)
        verify(K.Model.Build(s,c),3539,0)
    end
 end,
 precise_trait_reads_changed_percentage_from_the_item=function()
    local s=snapshot();s.meta.language='en'
    s.equipment[1].quality=5;s.equipment[1].weaponType=6;s.equipment[1].id=55555
    s.equipment[1].trait.description='Increases Weapon and Spell Critical rating by 7.2%.'
    for _,stat in ipairs({'weaponCritical','spellCritical'})do
        s.stats[stat].total=3758
        s.criticalSamples[stat]={{rating=0,chance=0},{rating=1,chance=0.0045637093},{rating=3758,chance=3758/219.12}}
    end
    local b=K.App.New({}):Explain(s);verify(b,3758,0);T.eq(b.weaponCritical.rows[2].value,1577)
 end,
 two_precise_daggers_and_cp_are_separate_visible_sources=function()
    local s=dofile('KanaStatSources/tests/fixtures/live_ru_precise_daggers.lua')
    local b=K.App.New({}):Explain(s);verify(b,3699,0)
    for _,stat in ipairs({'weaponCritical','spellCritical'})do
        local rows=b[stat].rows;T.eq(#rows,4)
        T.eq(rows[2].value,679);T.eq(rows[3].value,679);T.eq(rows[4].value,160)
        T.eq(rows[2].source.slot,4);T.eq(rows[3].source.slot,5)
        T.eq(rows[2].name,rows[3].name);T.eq(rows[2].key~=rows[3].key,true)
        T.eq(rows[2].icon,s.equipment[1].icon);T.eq(rows[3].icon,s.equipment[2].icon)
    end
    local api=dofile('KanaStatSources/tests/fixtures/controls.lua')()
    local view=K.Table.New(api,api.InformationTooltip)
    view:Render(b.weaponCritical,'ru',{width=1280,height=720})
    for i,value in ipairs({'10,0%','3,1%','3,1%','0,7%'})do T.eq(view.rows[i].effect,value)end
    T.eq(view.footerValue.text,'16,9%')
 end,
 cp_changes_do_not_change_precise_item_contributions=function()
    local s=dofile('KanaStatSources/tests/fixtures/live_ru_precise_daggers.lua')
    local withCP=K.App.New({}):Explain(s)
    s.champion={}
    local samples=snapshot().criticalSamples
    for _,stat in ipairs({'weaponCritical','spellCritical'})do s.stats[stat].total=3539;s.criticalSamples[stat]=samples[stat]end
    local withoutCP=K.App.New({}):Explain(s);verify(withoutCP,3539,0)
    for _,stat in ipairs({'weaponCritical','spellCritical'})do
        T.eq(withCP[stat].total-withoutCP[stat].total,160)
        for _,i in ipairs({2,3})do T.eq(withCP[stat].rows[i].value,withoutCP[stat].rows[i].value)end
    end
 end,
 precise_traits_on_the_inactive_bar_do_not_contribute=function()
    local s=dofile('KanaStatSources/tests/fixtures/live_ru_precise_daggers.lua')
    s.equipment[1].slot=20;s.equipment[2].slot=21
    local b=K.App.New({}):Explain(s)
    for _,stat in ipairs({'weaponCritical','spellCritical'})do
        T.eq(b[stat].explained,2341);T.eq(b[stat].unknown,1358);T.eq(#b[stat].rows,3)
    end
 end,
}
