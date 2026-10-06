local T=dofile('KanaStatSources/tests/support.lua')
local files={}
for line in io.lines('KanaStatSources/KanaStatSources.addon')do if line:match('%.lua$')then files[#files+1]=line:gsub('%.lua$','')end end
local K=T.load(files)
local function breakdown()
    local s=dofile('KanaStatSources/tests/fixtures/live_ru_bare_critical.lua')
    return K.Model.Build(s,K.Sources.Base.Build(s)).weaponCritical
end
return {
 bare_critical_source_and_total_share_native_display_precision=function()
    local api=dofile('KanaStatSources/tests/fixtures/controls.lua')()
    local v=K.Table.New(api,api.InformationTooltip);local b=breakdown()
    v:Render(b,'ru',{width=1280,height=720})
    T.eq(v.rows[1].labels[2].text,'10,0%');T.eq(v.footerValue.text,'10,0%')
    T.eq(b.rows[1].rawValue,2181);T.eq(b.rawUnknown,0)
    T.near(b.critical.chance,9.9534492493)
 end,
 critical_cells_use_native_stat_formatter_including_integer_and_locale_rules=function()
    local api=dofile('KanaStatSources/tests/fixtures/controls.lua')()
    local original=api.zo_strformat
    api.SI_STAT_VALUE_PERCENT=12345
    -- Native zo_strformat has one fractional digit by default; integers
    -- remain integers. Grammar supplies the running client's separators.
    api.zo_strformat=function(format,value)
        if format==api.SI_STAT_VALUE_PERCENT then
            if type(value)=='string' then
                -- Native localization expects English numeric separators;
                -- a Russian comma here is an English thousands separator.
                T.eq(value:find(',',1,true),nil)
                return (value..'%'):gsub('%.',',')
            end
            return (value==math.floor(value) and string.format('%d%%',value) or string.format('%.1f%%',value)):gsub('%.',',')
        end
        return original(format,value)
    end
    local v=K.Table.New(api,api.InformationTooltip)
    v:Render(breakdown(),'en',{width=1280,height=720})
    T.eq(v.rows[1].labels[2].text,'10,0%');T.eq(v.footerValue.text,'10,0%')
    v:Render({available=true,total=10000,critical={verified=true,pointsPerPercent=200,chance=50},rows={{name='Source',value=1000}}},'en',{width=1280,height=720})
    T.eq(v.rows[1].labels[2].text,'5%');T.eq(v.footerValue.text,'50%')
    v:Render({available=true,total=10000,critical={verified=true,pointsPerPercent=200,chance=50},rows={{name='Unknown',value=-1,rawValue=-1}}},'en',{width=1280,height=720})
    T.eq(v.rows[1].labels[2].text,'-0,005%');T.eq(v.footerValue.text,'50%')
 end,
 negative_critical_source_is_localized_only_once=function()
    local api=dofile('KanaStatSources/tests/fixtures/controls.lua')()
    local v=K.Table.New(api,api.InformationTooltip)
    -- Exercise a genuine negative contribution, not the incorrectly inferred
    -- Precise rating in the old live dump.
    local b={available=true,total=10000,critical={verified=true,pointsPerPercent=200,chance=50},rows={{name='Debuff',value=-1,rawValue=-1}}}
    api.SI_STAT_VALUE_PERCENT=12345
    api.zo_strformat=function(format,value)
        if format==api.SI_STAT_VALUE_PERCENT then
            if type(value)=='number' then value=string.format('%.1f',value)end
            T.eq(value:find(',',1,true),nil)
            return (value..'%'):gsub('%.',',')
        end
        return value
    end
    v:Render(b,'ru',{width=1280,height=720})
    T.eq(v.rows[1].labels[2].text,'-0,005%');T.eq(v.footerValue.text,'50,0%')
    T.eq(b.rows[1].rawValue,-1)
 end,
 small_positive_critical_residual_is_not_displayed_as_zero=function()
    local api=dofile('KanaStatSources/tests/fixtures/controls.lua')()
    local v=K.Table.New(api,api.InformationTooltip)
    local b={available=true,total=10000,critical={verified=true,pointsPerPercent=219.12,chance=45.637091},rows={{name='Unknown',value=1,rawValue=1}}}
    v:Render(b,'en',{width=1280,height=720})
    T.eq(v.rows[1].labels[2].text,'0.005%');T.eq(v.footerValue.text,'45.6%')
    b.rows[1].rawValue=0.000001
    v:Render(b,'en',{width=1280,height=720})
    T.eq(v.rows[1].labels[2].text,'0.000000005%');T.eq(v.footerValue.text,'45.6%')
 end,
}
