local T=dofile('KanaStatSources/tests/support.lua');local K=T.load({'Core','Stats','Rules','Critical','Model','Table','Tooltip'})
local function setup(rows)
    local api=dofile('KanaStatSources/tests/fixtures/controls.lua')()
    local b=K.Tooltip.Install(api,function()return {available=true,total=80,rows=rows or {{name='Source',value=80}}},'en'end)
    local row=api.Control();row.statEntry={statType=1}
    return b,api,row
end
return {
 wheel_routes_from_stat_and_body=function()
    local rows={};for i=1,80 do rows[i]={label='Source '..i,value=1}end
    local bridge,api,row=setup(rows);row:SetMouseEnabled(true)
    local calls=0;row:SetHandler('OnMouseWheel',function()calls=calls+1 end)
    api.ZO_StatsEntry_OnMouseEnter(row)
    row:GetHandler('OnMouseWheel')(row,-1);T.eq(bridge.view.offset,36);T.eq(calls,1)
    bridge.view.body:GetHandler('OnMouseWheel')(bridge.view.body,-1);T.eq(bridge.view.offset,72)
    bridge:Refresh();T.eq(bridge.view.offset,72)
    api.ZO_StatsEntry_OnMouseExit(row);row:GetHandler('OnMouseWheel')(row,-1)
    T.eq(bridge.active,nil);T.eq(bridge.view.offset,72);T.eq(calls,2)
    api.CompleteFade(bridge.tooltip);T.eq(bridge.view.offset,0)
 end,
 native_hooks=function()
    local api=dofile('KanaStatSources/tests/fixtures/controls.lua')();local count=0
    local bridge=K.Tooltip.Install(api,function(key)count=count+1;return {available=true,total=1,rows={{name=key,value=1}}},'ru'end)
    local row=api.Control();row.statEntry={statType=1};row.iconTexture={untouched=true}
    api.ZO_StatsEntry_OnMouseEnter(row)
    T.eq(api.originalCalls,nil);T.eq(bridge.view.title.text,'Stat 1');T.eq(bridge.view.description.text,'Native description 1')
    T.eq(count,1);T.eq(bridge.tooltip.insertions,1);T.eq(row.iconTexture.untouched,true)
    local width,height=bridge.view.width,bridge.view.height
    bridge:Refresh();T.eq(bridge.tooltip.insertions,1);T.eq(count,2)
    T.eq(bridge.view.width,width);T.eq(bridge.view.height,height)
    bridge.tooltip:ClearLines();T.eq(bridge.active,nil);T.eq(bridge.view.control.hidden,true)
    local other=api.Control();other.statEntry={statType=100}
    local a,b,c=api.ZO_StatsEntry_OnMouseEnter(other);T.eq(a,'native');T.eq(b,nil);T.eq(c,42)
 end,
 all_stats=function()
    local b,api=setup();local seen=0
    for _,d in ipairs(K.Stats.Definitions)do
        local row=api.Control();row.statEntry={statType=api[d[2]]}
        api.ZO_StatsEntry_OnMouseEnter(row);T.eq(type(row:GetHandler('OnMouseWheel')),'function')
        T.eq(b.stat,d[1]);api.ZO_StatsEntry_OnMouseExit(row)
        api.CompleteFade(b.tooltip);T.eq(b.view.control.hidden,true);seen=seen+1
    end
    T.eq(seen,15)
 end,
 hidden_stat_hides_immediately=function()
    local b,api,row=setup();api.ZO_StatsEntry_OnMouseEnter(row)
    row:GetHandler('OnEffectivelyHidden')(row)
    T.eq(b.active,nil);T.eq(b.tooltip.hidden,true);T.eq(b.view.control.hidden,true)
 end,
 contents_and_size_survive_entire_fade=function()
    local b,api,row=setup();api.ZO_StatsEntry_OnMouseEnter(row)
    local w,h=b.view.tooltip:GetWidth(),b.view.tooltip:GetHeight()
    api.ZO_StatsEntry_OnMouseExit(row)
    T.eq(b.active,nil);T.eq(b.view.control.hidden,false)
    T.eq(b.view.tooltip:GetWidth(),w);T.eq(b.view.tooltip:GetHeight(),h)
    T.eq(b.view.rows[1].labels[1].text,'Source')
    b:Refresh();T.eq(b.view.control.hidden,false)
    api.CompleteFade(b.view.tooltip);T.eq(b.view.control.hidden,true);T.eq(b.view.layout,nil)
 end,
 reenter_during_fade_reuses_full_content=function()
    local b,api,row=setup();api.ZO_StatsEntry_OnMouseEnter(row)
    api.ZO_StatsEntry_OnMouseExit(row);api.ZO_StatsEntry_OnMouseEnter(row)
    T.eq(b.tooltip.owner,row);T.eq(b.tooltip.fading,false);T.eq(b.view.control.hidden,false)
    api.CompleteFade(b.tooltip);T.eq(b.view.control.hidden,false);T.eq(b.active,row)
 end,
 shared_map_tooltip_is_untouched=function()
    local b,api,row=setup();local info=api.InformationTooltip
    info:SetDimensions(280,190);info:SetDimensionConstraints(0,0,350,0)
    info.mapText='Map location';local cleared=0;info:SetHandler('OnCleared',function()cleared=cleared+1 end)
    api.InitializeTooltip(info,api.Control());cleared=0
    local handler=info:GetHandler('OnCleared')
    api.ZO_StatsEntry_OnMouseEnter(row)
    T.eq(info:GetWidth(),280);T.eq(info:GetHeight(),190);T.eq(info.mapText,'Map location')
    api.ZO_StatsEntry_OnMouseExit(row);api.CompleteFade(b.view.tooltip)
    T.eq(info:GetWidth(),280);T.eq(info:GetHeight(),190);T.eq(info:GetHandler('OnCleared'),handler)
    T.eq(cleared,0);T.eq(info.constraints[3],350);T.eq(info.constraints[1],0);T.eq(info.fading,false)
    local other=api.Control();other.statEntry={statType=100}
    T.eq(api.ZO_StatsEntry_OnMouseEnter(other),'native');T.eq(cleared,1)
 end,
 unrelated_exit_does_not_hide_active_stat=function()
    local b,api,row=setup();api.ZO_StatsEntry_OnMouseEnter(row)
    api.ZO_StatsEntry_OnMouseExit(api.Control());T.eq(b.active,row);T.eq(b.view.control.hidden,false)
 end,
 idempotent=function()
    local b,api=setup();T.eq(K.Tooltip.Install(api,function()end),b)
 end,
}
