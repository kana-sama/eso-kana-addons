local T=dofile('KanaStatSources/tests/support.lua')
local files={}
for line in io.lines('KanaStatSources/KanaStatSources.addon')do if line:match('%.lua$')then files[#files+1]=line:gsub('%.lua$','')end end
local K=T.load(files)
local function native()return dofile('KanaStatSources/tests/fixtures/live_ru_savagery.lua')end
local function snapshot()
    local data=native()
    return {meta={language='ru',apiVersion=101051},context={now=5000000},constants={},effects={data.effect}}
end
local function both(cs,amount)
    T.eq(#cs,2)
    for i,stat in ipairs({'weaponCritical','spellCritical'})do
        T.eq(cs[i].stat,stat);T.eq(cs[i].amount,amount);T.eq(cs[i].operation,'flat')
    end
end
return {
 native_rating_and_equivalent_percent_are_one_contribution=function()
    local s=snapshot();local cs,diagnostics=K.Sources.Effects.Build(s)
    both(cs,2629);T.eq(#diagnostics,0)
    T.eq(cs[1].source.id,61667);T.eq(cs[1].source.icon,s.effects[1].icon)
    local clauses,tail=K.Descriptions.Parse(s.effects[1].effectDescription,'ru','effect')
    T.eq(#clauses,1);T.eq(clauses[1].amount,2629);T.eq(tail,'')
 end,
 dump14_critical_totals_reconcile_without_unknown=function()
    -- The previous live fixture has the same independently captured critical
    -- sources (6864 rating). Only the buff and critical probes come from #14.
    local s=dofile('KanaStatSources/tests/fixtures/live_ru.lua');local data=native()
    s.effects[#s.effects+1]=data.effect
    for _,stat in ipairs({'weaponCritical','spellCritical'})do
        s.stats[stat].total=data.total;s.stats[stat].withoutBonus=data.withoutBonus
        s.criticalSamples[stat]=data.samples
    end
    local b=K.App.New({}):Explain(s)
    for _,stat in ipairs({'weaponCritical','spellCritical'})do
        T.eq(b[stat].explained,9493);T.eq(b[stat].unknown,0);T.eq(T.sumRows(b[stat]),9493)
        local count=0
        for _,row in ipairs(b[stat].rows)do if row.source and row.source.id==61667 then count=count+1;T.eq(row.value,2629)end end
        T.eq(count,1)
    end
    local api=dofile('KanaStatSources/tests/fixtures/controls.lua')()
    local view=K.Table.New(api,api.InformationTooltip)
    view:Render(b.weaponCritical,'ru',{width=1280,height=720})
    local found=false
    for _,row in ipairs(view.rows)do if row.name=='Великая свирепость' then found=true;T.eq(row.effect,'12,0%')end end
    T.eq(found,true);T.eq(view.footerValue.text,'43,3%')
 end,
 other_granting_abilities_deduplicate_by_buff_type=function()
    local s=snapshot();s.effects[1].abilityId=900001
    local duplicate=K.Core.CopySerializable(s.effects[1]);duplicate.abilityId=900002
    s.effects[2]=duplicate
    both(K.Sources.Effects.Build(s),2629)
 end,
 captured_buff_enum_takes_precedence_over_legacy_dump_value=function()
    local s=snapshot();s.constants.BUFF_TYPE_MAJOR_SAVAGERY=404;s.effects[1].buffType=404
    both(K.Sources.Effects.Build(s),2629)
 end,
 other_weapon_only_effects_and_old_api_keep_their_stat_scope=function()
    for _,change in ipairs({function(s)s.effects[1].buffType=400 end,function(s)s.meta.apiVersion=101050 end})do
        local s=snapshot();change(s)
        local cs=K.Sources.Effects.Build(s)
        T.eq(#cs,1);T.eq(cs[1].stat,'weaponCritical');T.eq(cs[1].amount,2629)
    end
    -- Applying a buff scope must not modify the cached generic parse result.
    K.Sources.Effects.Build(snapshot())
    local clauses=K.Descriptions.Parse(native().effect.effectDescription,'ru','effect')
    T.eq(#clauses[1].stats,1);T.eq(clauses[1].stats[1],'weaponCritical')
 end,
 english_native_rating_is_not_recomputed_from_rounded_percent=function()
    local s=snapshot();s.meta.language='en'
    s.effects[1].effectDescription='Increases your Weapon Critical rating by 371, increasing your chance to critically strike by 1.7%.'
    local cs,diagnostics=K.Sources.Effects.Build(s)
    both(cs,371);T.eq(#diagnostics,0)
 end,
 expired_or_unavailable_buff_is_not_invented_from_its_type=function()
    local s=snapshot();s.effects[1].endTime=4999
    T.eq(#K.Sources.Effects.Build(s),0)
    s=snapshot();s.effects[1].effectDescription=''
    local cs,diagnostics=K.Sources.Effects.Build(s)
    T.eq(#cs,0);T.eq(#diagnostics,1)
 end,
}
