local T=dofile('KanaStatSources/tests/support.lua');local K=T.load({'Core','Stats','Rules','Critical','Model','Table'})
local function view()
    local api=dofile('KanaStatSources/tests/fixtures/controls.lua')()
    return K.Table.New(api,api.InformationTooltip),api
end
return {
 scroll_hint_only_on_overflow=function()
    local v=view();local b={available=true,total=10,rows={{name='Source',value=10}}}
    v:Render(b,'ru',{width=1280,height=720})
    T.eq(v.hint.hidden,true)
    for i=2,80 do b.rows[i]={name='Source '..i,value=1}end
    v:Render(b,'ru',{width=1280,height=720})
    T.eq(v.hint.hidden,false);T.eq(v.hint.text:find('мыши',1,true)~=nil,true)
 end,
 very_small_body=function()
    local v=view();local b={available=true,total=10000,rows={},critical={verified=true,rating=10000,pointsPerPercent=200,chance=50,offset=0}}
    for i=1,80 do b.rows[i]={name=string.rep('Длинное название ',12)..i,value=1}end
    -- Bounds are logical GuiRoot units; UI scaling is already applied by ESO.
    v:Render(b,'ru',{width=400,height=320,title='Title',description=string.rep('Description ',8)})
    T.eq(v.bodyHeight>0,true);T.eq(v.height+32<=320-64,true);v:Scroll(-100000)
    T.eq(v.offset+v.bodyHeight>=v.rows[80].y,true)
    T.eq(v.rows[1].labels[1].maxLines,1)
 end,
 percentage_effect_visible=function()
    local v=view()
    v:Render({available=true,total=16800,rows={{name='Source',value=800,amount=5,base=16000,operation='percent'}}},'ru',{width=1280,height=720})
    T.eq(v.rows[1].labels[2].text,'800 (5,00%)')
 end,
 bounded_scroll=function()
    local v,api=view();local b={available=true,total=80,rows={}}
    for i=1,80 do b.rows[i]={name=string.rep('Длинное название ',12)..i,value=1}end
    v:Render(b,'ru',{width=400,height=320})
    T.eq(v.height+32<=320-64,true);T.eq(v.footerValue.text,'80');T.eq(v.bodyHeight>0,true)
    v:Scroll(-100000);T.eq(v.offset,v.contentHeight-v.bodyHeight)
    local n=#api.created
    for _=1,100 do v:Render(b,'ru',{width=400,height=320,keepLayout=true})end
    T.eq(#api.created,n)
 end,
 reused=function()
    local v=view()
    v:Render({available=true,total=10,rows={{name='Original name',value=10}},preview={amount=5,total=15}},'fr',{width=800,height=720})
    T.eq(v.headers,nil);T.eq(v.rows[1].labels[1].text,'Original name')
    T.eq(v.preview.text:find('Attribute preview',1,true)~=nil,true)
    v:Clear();T.eq(v.control.hidden,true);T.eq(v.inserted,false)
 end,
 critical_footer=function()
    local v=view()
    v:Render({available=true,total=10000,rows={},critical={verified=true,rating=10000,pointsPerPercent=200,chance=50,offset=0}},'en',{width=1280,height=720})
    T.eq(v.footer.text,'Total');T.eq(v.footerValue.text,'50.0%')
    T.eq(v.formula,nil)
 end,
 unverified_critical_conversion_does_not_display_rating=function()
    local v=view()
    v:Render({available=true,total=6864,critical={verified=false,chance=31.3253},rows={{name='Unknown',value=6864}}},'en',{width=1280,height=720})
    T.eq(v.footerValue.text,'31.3%');T.eq(v.rows[1].labels[2].text,'Data unavailable')
 end,
 native_minimum_width_and_description_does_not_widen=function()
    local v,api=view()
    v:Render({available=true,total=10,rows={{name='Short',value=10}}},'en',{width=1800,height=900,title='A title long enough to wrap rather than enlarge the tooltip',description=string.rep('Long description ',30)})
    T.eq(api.InformationTooltip:GetWidth(),350);T.eq(v.description.width,318)
    T.eq(v.title.height>18,true)
 end,
 longest_source_sets_exact_width=function()
    local v,api=view()
    v:Render({available=true,total=123456,rows={{name=string.rep('N',60),value=123456}}},'en',{width=1800,height=900,description=string.rep('Long description ',30)})
    -- 60 glyphs*8 + icon22 + icon gap6 + columns24 + 6 digits*8 + rounding1 + padding32.
    T.eq(api.InformationTooltip:GetWidth(),613)
    T.eq(v.rows[1].labels[1].width,480);T.eq(v.rows[1].labels[2].width,49)
 end,
 new_longer_source_refits_without_delayed_growth=function()
    local v,api=view();local b={available=true,total=10,rows={{name='Short',value=10}}}
    v:Render(b,'en',{width=1800,height=900});T.eq(api.InformationTooltip:GetWidth(),350)
    b.rows[1].name=string.rep('N',60)
    v:Render(b,'en',{width=1800,height=900,keepLayout=true})
    T.eq(api.InformationTooltip:GetWidth(),581);T.eq(v.rows[1].labels[1].width,480)
    for _=1,5 do v:Render(b,'en',{width=1800,height=900,keepLayout=true});T.eq(api.InformationTooltip:GetWidth(),581)end
 end,
}
