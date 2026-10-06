local T=dofile('KanaStatSources/tests/support.lua');local K=T.load({'Core','Stats','Rules','Critical','Model','Table'})
return {
 very_small_body=function()
    local api=dofile('KanaStatSources/tests/fixtures/controls.lua')();local v=K.Table.New(api,api.InformationTooltip)
    local b={available=true,total=10000,rows={},critical={verified=true,rating=10000,pointsPerPercent=200,chance=50,offset=0}}
    for i=1,80 do b.rows[i]={label=string.rep('Длинное название ',12)..i,value=1}end
    v:Render(b,'ru',{width=600,height=480,scale=1.5,nativeHeight=220})
    T.eq(v.bodyHeight>0,true);T.eq(v.height+220<=320,true);v:Scroll(-100000)
    T.eq(v.offset+v.bodyHeight>=v.rows[80].y,true)
 end,
 percentage_base_visible=function()
    local api=dofile('KanaStatSources/tests/fixtures/controls.lua')();local v=K.Table.New(api,api.InformationTooltip)
    v:Render({available=true,total=16800,rows={{label='Source',value=800,amount=5,base=16000,operation='percent'}}},'ru',{width=1280,height=720,scale=1})
    T.eq(v.rows[1].labels[2].text:find('16000',1,true)~=nil,true)
 end,
 bounded_scroll=function()local api=dofile('KanaStatSources/tests/fixtures/controls.lua')();local v=K.Table.New(api,api.InformationTooltip);local b={available=true,total=80,rows={}};for i=1,80 do b.rows[i]={label=string.rep('Длинное название ',12)..i,value=1,amount=1,operation='flat'}end;v:Render(b,'ru',{width=600,height=480,scale=1.5,nativeHeight=70});T.eq(v.height+70<=480/1.5,true);T.eq(v.footer.hidden,false);T.eq(v.bodyHeight>0,true);v:Scroll(-100000);T.eq(v.offset,v.contentHeight-v.bodyHeight);T.eq(v.footer.text:find('80',1,true)~=nil,true);local n=#api.created;for _=1,100 do v:Render(b,'ru',{width=600,height=480,scale=1.5,nativeHeight=70})end;T.eq(#api.created,n)end,
 reused=function()local api=dofile('KanaStatSources/tests/fixtures/controls.lua')();local v=K.Table.New(api,api.InformationTooltip);v:Render({available=true,total=10,rows={{label='Original name',value=10}},preview={amount=5,total=15}},'fr',{width=800,height=720,scale=1});T.eq(v.headers[1].text,'Source');T.eq(v.rows[1].labels[1].text,'Original name');T.eq(v.footer.text:find('Attribute preview',1,true)~=nil,true);v:Clear();T.eq(v.control.hidden,true);T.eq(v.inserted,false)end,
 critical_footer=function()local api=dofile('KanaStatSources/tests/fixtures/controls.lua')();local v=K.Table.New(api,api.InformationTooltip);v:Render({available=true,total=10000,rows={},critical={verified=true,rating=10000,pointsPerPercent=200,chance=50,offset=0}},'en',{width=1280,height=720,scale=1});T.eq(v.footer.text:find('10000 / 200.00 = 50.0%',1,true)~=nil,true)end,
}
