local T=dofile('KanaStatSources/tests/support.lua');local K=T.load({'Core','Stats','Rules','Critical','Model','Table','Tooltip'})
return {
 wheel_routes_from_stat_and_body=function()
    local api=dofile('KanaStatSources/tests/fixtures/controls.lua')();local rows={}
    for i=1,80 do rows[i]={label='Source '..i,value=1}end
    local bridge=K.Tooltip.Install(api,function()return {available=true,total=80,rows=rows},'en'end)
    local row=api.Control();row.statEntry={statType=1};row:SetMouseEnabled(true)
    local nativeWheelCalls=0;row:SetHandler('OnMouseWheel',function()nativeWheelCalls=nativeWheelCalls+1 end)
    api.ZO_StatsEntry_OnMouseEnter(row)
    row:GetHandler('OnMouseWheel')(row,-1);T.eq(bridge.view.offset,36);T.eq(nativeWheelCalls,1)
    bridge.view.body:GetHandler('OnMouseWheel')(bridge.view.body,-1);T.eq(bridge.view.offset,72)
    bridge:Refresh();T.eq(bridge.view.offset,72)
    T.eq(bridge.view.body.mouse,true);api.ZO_StatsEntry_OnMouseExit(row)
    row:GetHandler('OnMouseWheel')(row,-1);T.eq(bridge.view.offset,0);T.eq(nativeWheelCalls,2)
 end,
 native_hooks=function()
    local api=dofile('KanaStatSources/tests/fixtures/controls.lua')();local count=0
    local bridge=K.Tooltip.Install(api,function(key)count=count+1;return {available=true,total=1,rows={{name=key,value=1}}},'ru'end)
    local row=api.Control();row.statEntry={statType=1};row.iconTexture={untouched=true}
    api.ZO_StatsEntry_OnMouseEnter(row)
    T.eq(api.originalCalls,nil);T.eq(bridge.view.title.text,'Stat 1');T.eq(bridge.view.description.text,'Native description 1')
    T.eq(count,1);T.eq(api.InformationTooltip.insertions,1);T.eq(row.iconTexture.untouched,true)
    local width,height=bridge.view.width,bridge.view.height
    bridge:Refresh();T.eq(api.InformationTooltip.insertions,1);T.eq(count,2)
    T.eq(bridge.view.width,width);T.eq(bridge.view.height,height);T.eq(bridge.active,row)
    api.InformationTooltip:ClearLines();T.eq(bridge.active,nil);T.eq(bridge.view.control.hidden,true)
    local other=api.Control();other.statEntry={statType=100}
    local a,b,c=api.ZO_StatsEntry_OnMouseEnter(other);T.eq(a,'native');T.eq(b,nil);T.eq(c,42)
 end,
 all_stats=function()local api=dofile('KanaStatSources/tests/fixtures/controls.lua')();local keys={};local b=K.Tooltip.Install(api,function(key)keys[key]=true;return {available=true,total=0,rows={}},'en'end);for _,d in ipairs(K.Stats.Definitions)do local row=api.Control();row.statEntry={statType=api[d[2]]};api.ZO_StatsEntry_OnMouseEnter(row);local f=row:GetHandler('OnMouseWheel');T.eq(type(f),'function');api.ZO_StatsEntry_OnMouseExit(row);T.eq(b.view.control.hidden,true)end;local n=0;for _ in pairs(keys)do n=n+1 end;T.eq(n,15)end,
 hide_and_other_tooltip=function()local api=dofile('KanaStatSources/tests/fixtures/controls.lua')();local b=K.Tooltip.Install(api,function()return {available=true,total=0,rows={}},'ru'end);local row=api.Control();row.statEntry={statType=1};api.ZO_StatsEntry_OnMouseEnter(row);row:GetHandler('OnEffectivelyHidden')(row);T.eq(b.active,nil);api.ZO_StatsEntry_OnMouseEnter(row);api.InformationTooltip:ClearLines();T.eq(b.view.control.hidden,true)end,
 idempotent=function()local api=dofile('KanaStatSources/tests/fixtures/controls.lua')();local a=K.Tooltip.Install(api,function()return {available=true,total=0,rows={}},'ru'end);T.eq(K.Tooltip.Install(api,function()end),a)end,
}
