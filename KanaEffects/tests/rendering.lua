for _,path in ipairs({'integration/EsoApi.lua','widgets/Layout.lua','ui/Timers.lua','ui/Controls.lua','ui/FontMetrics.lua','ui/Renderer.lua'}) do
    local file=io.open(TEST_ROOT..'/'..path,'r'); if file then file:close(); dofile(TEST_ROOT..'/'..path) end
end
local A,F=TestSupport.Assert,TestSupport.Fixtures
local function native()
    local api={constants={CT_CONTROL='control',CT_LABEL='label',CT_TEXTURE='texture',CT_BACKDROP='backdrop',
        TOPLEFT='tl',TEXT_ALIGN_RIGHT='right',TEXT_ALIGN_CENTER='center',TEXT_ALIGN_LEFT='left',
        TEXT_ALIGN_TOP='top',TEXT_WRAP_MODE_ELLIPSIS='ellipsis',DL_BACKGROUND=0,DL_CONTROLS=1,DL_TEXT=2,DL_OVERLAY=3,DT_LOW=0,DT_HIGH=3,SPACE_INTERFACE=1,MOUSE_BUTTON_INDEX_RIGHT=2},controls={},created={},updates={},scale=0.8,calls={}}
    api.Now=function() return api.time or 0 end
    api.GetUIGlobalScale=function() return api.scale end
    api.fonts={game={GetFontInfo=function() return 'native-face',16,'shadow' end},gameBold={GetFontInfo=function() return 'native-bold-face',16,'shadow' end}}
    api.CreateFont=function(symbol,descriptor)
        api.fontCreates=(api.fontCreates or 0)+1
        return {SetFont=function(self,desc) self.descriptor=desc end}
    end
    api.GetStringWidthScaled=function(font,text,scale,space)
        A.Equal(scale,1); A.Equal(space,1); api.widthCalls=(api.widthCalls or 0)+1
        return #text*7
    end
    api.eventManager={RegisterForUpdate=function(_,key,interval,callback)
        A.Equal(interval,100); api.updates[key]=callback; api.registers=(api.registers or 0)+1
    end,UnregisterForUpdate=function(_,key) api.updates[key]=nil end}
    local function control(name,parent,kind)
        local c={name=name,parent=parent,kind=kind,handlers={},calls={},hidden=false}
        local function record(self,method) self.calls[method]=(self.calls[method] or 0)+1 end
        function c:SetHandler(key,fn) self.handlers[key]=fn; record(self,'SetHandler') end
        function c:SetHidden(v) self.hidden=v; record(self,'SetHidden') end
        function c:IsControlHidden() return self.hidden or (self.parent and self.parent:IsControlHidden()) or false end
        function c:ClearAnchors() self.anchor=nil; record(self,'ClearAnchors') end
        function c:SetAnchor(point,to,relative,x,y) self.anchor={x=x,y=y,to=to}; record(self,'SetAnchor') end
        function c:SetDimensions(w,h) self.width=w; self.height=h; record(self,'SetDimensions') end
        function c:SetText(v) self.text=v; record(self,'SetText') end
        function c:SetFont(v) self.font=v; record(self,'SetFont') end
        function c:GetFontHeight() return 19 end
        function c:SetTexture(v) self.texture=v; record(self,'SetTexture') end
        function c:SetTextureCoords(...) self.coords={...} end
        function c:SetColor(...) self.color={...} end
        function c:SetCenterColor(...) self.center={...} end
        function c:SetEdgeColor(...) self.edge={...} end
        function c:SetEdgeTexture(...) self.edgeTexture={...} end
        function c:SetInsets(...) self.insets={...} end
        function c:SetAlpha(v) self.alpha=v end
        function c:SetDesaturation(v) self.desaturation=v end
        function c:SetMouseEnabled(v) self.mouse=v end
        function c:SetDrawLayer(v) self.layer=v end
        function c:SetDrawLevel(v) self.level=v end
        function c:GetDrawLevel() return self.level or 0 end
        function c:GetDrawLayer() return self.layer or 1 end
        function c:GetDrawTier() return self.tier or 1 end
        function c:SetDrawTier(v) self.tier=v end
        function c:SetHorizontalAlignment(v) self.align=v end
        function c:SetVerticalAlignment(v) self.valign=v end
        function c:SetWrapMode(v) self.wrap=v end
        function c:SetMaxLineCount(v) self.lines=v end
        api.created[#api.created+1]=c; return c
    end
    api.controls.CreateControl=control; api.controls.GuiRoot=control('screen',nil,'control')
    return api
end
local function components()
    assert(KanaEffects.Renderer and KanaEffects.Controls and KanaEffects.Timers and KanaEffects.FontMetrics,'missing native rendering modules')
    local api=native(); local controls=KanaEffects.Controls.New(api)
    local clock=TestSupport.FakeClock.New(0); local scheduler=KanaEffects.Timers.New(clock)
    local renderer=KanaEffects.Renderer.New(api.controls.GuiRoot,controls,scheduler)
    return renderer,controls,scheduler,clock,api
end
local function entry(key)
    return {key=key or 'effect',active=true,pair=true,name='Русское длинное название',icon='real.dds',kind='buff',
        minor={kind='finite',endTime=10},major={kind='finite',endTime=20},count=1}
end
local m={cellWidth=120,cellHeight=80,iconWidth=48,timerColumnWidth=40,timerLineHeight=20,contentGap=4,nameColumnWidth=28,nameLineHeight=18}
local function result(e)
    local placements={}; for i,item in ipairs(e) do placements[i]={key=item.key,visible=true,row=1,column=i,rect={x=20+(i-1)*124,y=30,width=120,height=80}} end
    return {rect={x=20,y=30,width=120*#e,height=80},measurement=m,placements=placements}
end
local function drawn(api,texture)
    for _,c in ipairs(api.created) do if c.texture==texture and not c:IsControlHidden() then return c.parent end end
end
local function labels(api,cell)
    local r={}; for _,c in ipairs(api.created) do if c.parent==cell and c.kind=='label' and not c.hidden then r[#r+1]=c end end; return r
end
Tests.all_four_styles_draw_one_earliest_pair_timer=function()
    for _,mode in ipairs({'over','under','right','list'}) do
        local r,_,scheduler,_,api=components(); local w=F.Widget(); w.style.mode=mode; local e=entry()
        r:Render(w,{e},result({e})); local cell=r.widgets[w.id].cells[e.key]
        A.Equal(#cell.timers,1); A.Equal(cell.timers[1].text,'10'); A.Equal(scheduler.count,1)
        A.Equal(#labels(api,cell.root),mode=='list' and 2 or 1)
        if cell.name then A.Equal(cell.name.wrap,'ellipsis'); A.Equal(cell.name.lines,1) end
    end
end

Tests.timers_keep_bold_outline_and_no_backing_in_every_style=function()
    for _,mode in ipairs({'over','under','right','list'}) do for _,pair in ipairs({true,false}) do
        local r,_,_,_,api=components(); local w=F.Widget(); w.style.mode=mode; w.style.timerFontSize=23
        local e=entry(); e.pair=pair; e.single={kind='finite',endTime=10}; e.level=nil
        r:Render(w,{e},result({e})); local cell=r.widgets[w.id].cells[e.key]
        for _,label in ipairs(cell.timers) do if not label.hidden then
            A.Equal(label.font,'native-bold-face|23|outline')
            for _,value in ipairs(label.color) do A.Equal(value,1) end
        end end
        for _,control in ipairs(api.created) do
            if control.parent==cell.root and control.kind=='backdrop' and not control.hidden and control~=cell.background then
                A.Equal(control.center[4],0,'timer area must have no filled backing')
            end
        end
        r:Dispose()
    end end
end
Tests.overlay_cell_icon_and_timer_center_stay_fixed_when_font_changes=function()
    local r=components(); local w=F.Widget(); w.style.mode='over'; w.style.iconSize=24
    local e=entry(); e.row,e.column=1,1
    local metrics={MeasureText=function(_,text,size) return #text*size,size+4 end}
    local screen={x=0,y=0,width=2000,height=1200}
    for _,size in ipairs({12,48}) do
        w.style.timerFontSize=size
        local measured=KanaEffects.Layout.Measure(w.style,metrics)
        r:Render(w,{e},KanaEffects.Layout.Place(w,{e},screen,screen,measured))
        local cell=r.widgets[w.id].cells[e.key]; local label=cell.timers[1]
        A.Equal(cell.icon.width,24); A.Equal(cell.icon.height,24)
        A.Equal(cell.root.width,24); A.Equal(cell.root.height,24)
        A.Equal(label.anchor.x+label.width/2,12); A.Equal(label.anchor.y+label.height/2,12)
        A.Equal(label.align,'center'); A.Equal(label.font,'native-bold-face|'..size..'|outline')
    end
end

Tests.horizontal_timers_have_right_inset_without_name_overlap=function()
    for _,mode in ipairs({'list','right'}) do for _,rowWidth in ipairs({1,220}) do
        local r,controls=components(); local metrics=KanaEffects.FontMetrics.New(controls)
        local w=F.Widget(); w.style.mode=mode; w.style.rowWidth=rowWidth
        local e=entry(); e.row=1; e.column=1
        local measure=KanaEffects.Layout.Measure(w.style,metrics)
        local screen={x=0,y=0,width=1000,height=1000}
        local placement=KanaEffects.Layout.Place(w,{e},screen,screen,measure)
        r:Render(w,{e},placement)
        local cell=r.widgets[w.id].cells[e.key]
        for _,label in ipairs(cell.timers) do
            local rightInset=cell.root.width-label.anchor.x-label.width
            A.Equal(rightInset,4)
            assert(label.anchor.x>=cell.icon.anchor.x+cell.icon.width+4)
            if cell.name then assert(cell.name.anchor.x+cell.name.width+4<=label.anchor.x) end
        end
        if mode=='list' and rowWidth==220 then A.Equal(cell.root.width,220) end
    end end
end
Tests.only_text_changes_do_not_relayout=function()
    local r,_,s,clock,api=components(); local w=F.Widget(); local e=entry(); local l=result({e}); r:Render(w,{e},l)
    local calls=0; for _,c in ipairs(api.created) do calls=calls+(c.calls.SetAnchor or 0)+(c.calls.SetDimensions or 0) end
    clock:Set(1); s:Advance(1); e.minor={kind='finite',endTime=11}; r:Render(w,{e},l)
    local after=0; for _,c in ipairs(api.created) do after=after+(c.calls.SetAnchor or 0)+(c.calls.SetDimensions or 0) end
    A.Equal(after,calls)
end
Tests.same_formatted_text_does_not_call_SetText=function()
    local r,_,s,clock,api=components(); local e=entry(); e.minor.endTime=10.5; e.major.endTime=20.5; r:Render(F.Widget(),{e},result({e})); local timers=labels(api,drawn(api,e.icon)); local before=0
    for _,l in ipairs(timers) do before=before+(l.calls.SetText or 0) end
    clock:Set(0.01); s:Advance(0.01); r:Render(F.Widget(),{e},result({e}))
    local after=0; for _,l in ipairs(timers) do after=after+(l.calls.SetText or 0) end; A.Equal(before,after)
end
Tests.permanent_and_offscreen_have_no_timer_jobs=function()
    local r,_,s,_,api=components(); local e=entry(); e.minor={kind='missing'}; e.major={kind='permanent'}
    r:Render(F.Widget(),{e},result({e})); A.Equal(next(api.updates),nil)
    e.minor={kind='finite',endTime=20}; local l=result({e}); l.placements={}; r:Render(F.Widget(),{e},l); A.Equal(next(api.updates),nil)
    local count=0; s:SubscribeActivity(function(active) if active then count=count+1 end end); A.Equal(count,0)
end
Tests.released_control_resets_debuff_and_handlers=function()
    local r,_,_,_,api=components(); local e=entry(); e.kind='debuff'; r:Render(F.Widget(),{e},result({e})); local cell=drawn(api,e.icon)
    cell:SetHandler('OnMouseEnter',function() error('stale') end); r:ReleaseWidget('widget-a')
    A.Equal(next(cell.handlers),nil); A.True(cell.hidden)
    e=entry('new'); e.icon='next.dds'; r:Render(F.Widget('other'),{e},result({e})); local reused=drawn(api,e.icon); A.Equal(reused,cell)
    for _,c in ipairs(api.created) do if c.parent==cell and c.kind=='backdrop' and c.edge and c.edge[1]>0.7 then A.True(c.hidden) end end
end
Tests.timer_expiry_notifies_once=function()
    local r,_,s,clock=components(); local events={}; r:SetCallbacks({onExpired=function(widget,key) events[#events+1]={widget,key} end})
    local e=entry(); e.minor={kind='finite',endTime=1}; r:Render(F.Widget(),{e},result({e}))
    clock:Set(1); s:Advance(1); s:Advance(2); r:Render(F.Widget(),{e},result({e})); s:Advance(3)
    A.Equal(#events,1); A.Equal(events[1][1],'widget-a'); A.Equal(events[1][2],'effect')
end
Tests.dispose_unsubscribes_everything=function()
    local r,_,s,clock,api=components(); local e=entry(); local n=0; r:SetCallbacks({onExpired=function() n=n+1 end}); r:Render(F.Widget(),{e},result({e}))
    assert(next(api.updates)); r:Dispose(); r:Dispose(); A.Equal(next(api.updates),nil)
    clock:Set(99); s:Advance(99); A.Equal(n,0)
    for _,c in ipairs(api.created) do A.Equal(next(c.handlers),nil) end
end
Tests.hidden_semantics_and_effective_scene_hide_stop_shared_driver=function()
    local r,_,s,clock,api=components(); local e=entry(); r:Render(F.Widget(),{e},result({e})); A.Equal(api.registers,1)
    r:SetVisible(false); A.Equal(next(api.updates),nil); local content
    for _,c in ipairs(api.created) do if c.handlers.OnEffectivelyHidden then content=c end end; assert(content,'effective visibility owner missing')
    local texts=labels(api,drawn(api,e.icon) or {}); clock:Set(5); s:Advance(5)
    r:SetVisible(true); assert(next(api.updates)); content.handlers.OnEffectivelyHidden(content,true); A.Equal(next(api.updates),nil)
    content.handlers.OnEffectivelyShown(content,false); assert(next(api.updates)); r:Dispose()
end
Tests.missing_pair_and_single_have_no_timer_or_job=function()
    local r,_,scheduler=components(); local w=F.Widget(); local e=entry(); e.minor=nil; e.major={kind='missing'}
    r:Render(w,{e},result({e})); local cell=r.widgets[w.id].cells[e.key]
    A.True(cell.timers[1].hidden); A.Equal(scheduler.count,0)
    e.pair=false; e.single={kind='missing'}; r:Render(w,{e},result({e}))
    A.True(cell.timers[1].hidden); A.Equal(cell.timers[1].text,''); A.Equal(scheduler.count,0)
end

Tests.empty_slots_only_create_separate_editor_chrome=function()
    local r,_,_,_,api=components(); local w=F.Widget(); local l=result({}); l.placements={{key='empty',visible=false,row=2,column=3,rect={x=90,y=80,width=120,height=80}}}
    r:Render(w,{},l); local count=#api.created; r:SetEditorOverlay(w.id,true)
    local outline; for _,c in ipairs(api.created) do if c.kind=='backdrop' and not c:IsControlHidden() then outline=c end end
    assert(outline,'empty editor slot outline missing'); A.Equal(outline.anchor.x,90); A.Equal(outline.anchor.y,80); A.Equal(outline.width,120)
    for i=count+1,#api.created do A.False(api.created[i].kind=='texture'); A.False(api.created[i].kind=='label') end
    r:SetEditorOverlay(w.id,false); A.False(outline.hidden)
    r:SetEditorOverlay(w.id,nil); A.True(outline.hidden)
end
Tests.timer_formatter_boundaries_and_next_string_changes=function()
    assert(KanaEffects.Timers,'missing timer module'); local format=KanaEffects.Timers.Format
    A.Equal(format({kind='missing'},0),'—'); A.Equal(format({kind='permanent'},0),''); A.Equal(format({kind='unknown'},0),'')
    for _,case in ipairs({{2.95,'2.9'},{3,'3'},{59.9,'59'},{60,'1m'},{3599,'60m'},{3600,'1h'},{999*3600,'999h'},{999*3600+1,'999h+'},{-2,'0.0'}}) do
        local state={kind='finite',endTime=case[1]}; local text,nextAt=format(state,0); A.Equal(text,case[2])
        if case[1]>0 then assert(nextAt and nextAt>0 and nextAt<=case[1]); local changed=format(state,nextAt+0.00001); assert(changed~=text,'nextChangeAt did not change '..text) else A.Equal(nextAt,nil) end
    end
end
Tests.font_metrics_cache_bounded_reuses_native_objects_without_double_scale=function()
    local _,controls,_,_,api=components(); local metrics=KanaEffects.FontMetrics.New(controls)
    local width,height=metrics:MeasureText('999h+',16,'timer'); A.Equal(width,35); A.Equal(height,19)
    metrics:MeasureText('999h+',16,'timer'); A.Equal(api.widthCalls,1)
    for size=1,25 do metrics:MeasureText('999h+',size+0.001,'timer') end
    A.Equal(api.fontCreates,1); local before=api.widthCalls; metrics:MeasureText('999h+',16,'timer'); A.Equal(api.widthCalls,before+1)
    before=api.widthCalls; api.scale=1; metrics:MeasureText('999h+',16,'timer'); A.Equal(api.widthCalls,before+1)
    local measured=KanaEffects.Layout.Measure(F.Widget().style,metrics); assert(measured.timerColumnWidth>=35)
    local again=api.widthCalls; KanaEffects.Layout.Measure(F.Widget().style,metrics); A.Equal(api.widthCalls,again)
    metrics:Dispose(); A.Throws(function() metrics:MeasureText('1',16,'timer') end,'disposed')
end
Tests.scheduler_callback_mutation_and_resume_expiry_are_safe=function()
    assert(KanaEffects.Timers,'missing timer module'); local clock=TestSupport.FakeClock.New(); local s=KanaEffects.Timers.New(clock); local n=0
    s:Watch('a',{kind='finite',endTime=1},function() end,function() n=n+1; s:Unwatch('b') end)
    s:Watch('b',{kind='finite',endTime=1},function() end,function() n=n+1 end)
    s:SetVisible(false); clock:Set(2); s:Advance(2); A.Equal(n,0); s:SetVisible(true); A.True(n>=1 and n<=2)
    s:Advance(3); A.True(n>=1 and n<=2); s:Dispose(); local activity=0; s:SubscribeActivity(function() activity=activity+1 end); A.Equal(activity,0)
end
Tests.editor_chrome_does_not_relayout_on_timer_data_changes_and_reuses_pool=function()
    local r,_,_,_,api=components(); local w=F.Widget(); local e=entry(); local l=result({e}); r:Render(w,{e},l); r:SetEditorOverlay(w.id,true)
    local outline
    for _,c in ipairs(api.created) do if c.kind=='backdrop' and c.parent~=drawn(api,e.icon) and not c.hidden then outline=c end end
    assert(outline); local n=outline.calls.SetAnchor; e.minor.endTime=12; r:Render(w,{e},l); A.Equal(outline.calls.SetAnchor,n)
    r:ReleaseWidget(w.id); local allocated=#api.created
    w.id='new-widget'; r:Render(w,{e},l); r:SetEditorOverlay(w.id,true); A.Equal(#api.created,allocated)
end
Tests.timer_replacement_keeps_one_driver_and_old_native_callbacks_cannot_fire=function()
    local r,_,_,clock,api=components(); local w=F.Widget(); local e=entry(); local l=result({e}); r:Render(w,{e},l)
    local _,callback=next(api.updates); A.Equal(api.registers,1)
    e.minor={kind='finite',endTime=12}; r:Render(w,{e},l); A.Equal(api.registers,1)
    r:ReleaseWidget(w.id); A.Equal(next(api.updates),nil)
    local calls=0; for _,c in ipairs(api.created) do calls=calls+(c.calls.SetText or 0) end
    clock:Set(10); callback(); local after=0; for _,c in ipairs(api.created) do after=after+(c.calls.SetText or 0) end; A.Equal(after,calls)
end
Tests.font_metric_text_cache_also_plateaus_and_disposal_disables_native_measure=function()
    local _,controls,_,_,api=components(); local metrics=KanaEffects.FontMetrics.New(controls)
    metrics:MeasureText('first',16,'name')
    for n=1,1300 do metrics:MeasureText('name'..n,16,'name') end
    local before=api.widthCalls; metrics:MeasureText('first',16,'name'); A.Equal(api.widthCalls,before+1)
    controls:Dispose(); A.Throws(function() metrics:MeasureText('new',16,'name') end,'disposed')
end
Tests.next_change_times_do_not_skip_hour_or_minute_rounding_boundaries=function()
    local format=KanaEffects.Timers.Format
    local text,nextAt=format({kind='finite',endTime=7201},0); A.Equal(text,'3h'); A.Equal(nextAt,1)
    A.Equal(format({kind='finite',endTime=7201},nextAt),'2h')
    text,nextAt=format({kind='finite',endTime=181},0); A.Equal(text,'4m'); A.Equal(nextAt,1)
    A.Equal(format({kind='finite',endTime=181},nextAt),'3m')
end
Tests.scheduler_skips_formatted_work_until_due_and_activity_unsubscribe_is_safe=function()
    local clock=TestSupport.FakeClock.New(); local s=KanaEffects.Timers.New(clock); local n=0
    local original=KanaEffects.Timers.Format
    KanaEffects.Timers.Format=function(...) n=n+1; return original(...) end
    s:Watch('x',{kind='finite',endTime=90},function() end,function() end)
    s:Advance(0.1); s:Advance(1); A.Equal(n,1)
    clock:Set(30); s:Advance(30); A.Equal(n,2)
    KanaEffects.Timers.Format=original
    local activity=0; local unsub=s:SubscribeActivity(function() activity=activity+1 end); A.Equal(activity,1)
    unsub(); unsub(); s:Unwatch('x'); A.Equal(activity,1)
end
Tests.category_badge_does_not_treat_application_count_as_stacks_or_change_geometry=function()
    local r,_,_,_,api=components(); local w=F.Widget(); local e=entry(); e.pair=false; e.single={kind='permanent'}; e.count=3
    e.selector={kind='ability',id=100}; r:Render(w,{e},result({e})); local cell=drawn(api,e.icon)
    local ls=labels(api,cell); A.Equal(#ls,0)
    local anchorCalls=cell.calls.SetAnchor; e.selector={kind='category',id='food'}; r:Render(w,{e},result({e}))
    local badge; for _,c in ipairs(labels(api,cell)) do if c.text=='3' then badge=c end end; assert(badge,'category count badge missing')
    A.Equal(cell.calls.SetAnchor,anchorCalls); A.True(badge.width<=m.iconWidth); A.True(badge.height<=m.iconWidth)
    e.count=1; r:Render(w,{e},result({e})); A.True(badge.hidden)
    r:ReleaseWidget(w.id); e.selector={kind='ability',id=100}; e.count=9; r:Render(F.Widget('new'),{e},result({e})); A.True(badge.hidden)
end
Tests.hover_callbacks_use_current_entry_then_clear_after_pooled_reuse=function()
    local r,_,_,_,api=components(); local events={}
    r:SetCallbacks({onEnter=function(id,e,c) events[#events+1]={event='enter',id=id,entry=e,control=c} end,
        onExit=function(id,e,c) events[#events+1]={event='exit',id=id,entry=e,control=c} end})
    local e=entry(); local w=F.Widget(); r:Render(w,{e},result({e})); local cell=drawn(api,e.icon)
    assert(cell.handlers.OnMouseEnter and cell.handlers.OnMouseExit); A.True(cell.mouse)
    local fresh=entry(); fresh.name='Fresh immutable snapshot'; r:Render(w,{fresh},result({fresh})); cell.handlers.OnMouseEnter(cell)
    A.Equal(events[1].entry,fresh); A.Equal(events[1].id,w.id); A.Equal(events[1].control,cell)
    r:ReleaseWidget(w.id); A.Equal(events[2].event,'exit'); A.Equal(events[2].entry,fresh); A.Equal(next(cell.handlers),nil)
    local reused=entry('next'); r:Render(F.Widget('other'),{reused},result({reused})); cell.handlers.OnMouseEnter(cell)
    A.Equal(events[3].id,'other'); A.Equal(events[3].entry,reused); r:SetVisible(false); A.Equal(events[4].event,'exit')
    r:Dispose(); A.Equal(#events,4)
end
Tests.stale_native_handlers_cannot_mutate_reused_cells_or_restarted_driver=function()
    local r,_,_,_,api=components(); local n=0; r:SetCallbacks({onEnter=function() n=n+1 end})
    local e=entry(); local w=F.Widget(); r:Render(w,{e},result({e})); local cell=drawn(api,e.icon)
    local oldEnter=cell.handlers.OnMouseEnter; local _,oldTick=next(api.updates)
    r:ReleaseWidget(w.id); local fresh=entry('fresh'); fresh.minor.endTime=1; r:Render(F.Widget('new'),{fresh},result({fresh}))
    oldEnter(cell); A.Equal(n,0)
    local before=0; for _,l in ipairs(labels(api,cell)) do before=before+(l.calls.SetText or 0) end
    api.time=0.9; oldTick(); local after=0; for _,l in ipairs(labels(api,cell)) do after=after+(l.calls.SetText or 0) end; A.Equal(after,before)
    cell.handlers.OnMouseEnter(cell); A.Equal(n,1)
end

Tests.editor_selection_changes_chrome_without_moving_content=function()
    local r,_,_,_,api=components(); local e=entry(); local w=F.Widget(); r:Render(w,{e},result({e}))
    local cell=drawn(api,e.icon); local anchors=cell.calls.SetAnchor
    r:SetEditorOverlay(w.id,false); local unselected
    for _,c in ipairs(api.created) do if c.kind=='backdrop' and c.parent~=cell and not c.hidden then unselected=c end end
    assert(unselected); local dim=unselected.calls.SetDimensions; local alpha=unselected.edge[4]
    r:SetEditorOverlay(w.id,true); A.True(unselected.edge[4]>alpha); A.Equal(unselected.calls.SetDimensions,dim)
    A.Equal(cell.calls.SetAnchor,anchors); r:SetEditorOverlay(w.id,nil); A.True(unselected.hidden)
end
Tests.visibility_unsubscribe_rejects_queued_native_callbacks=function()
    local _,controls,_,_,api=components(); local own=controls:Create('control',api.controls.GuiRoot); local n=0
    local unsub=controls:ObserveVisibility(own,function() n=n+1 end); A.Equal(n,1)
    local hidden=own.handlers.OnEffectivelyHidden; local shown=own.handlers.OnEffectivelyShown
    unsub(); unsub(); hidden(own,true); shown(own,false); A.Equal(n,1)
end
Tests.reentrant_activity_hide_cannot_restart_native_driver_from_stale_broadcast=function()
    assert(KanaEffects.Timers and KanaEffects.Controls,'missing scheduling modules')
    local api=native(); local controls=KanaEffects.Controls.New(api)
    local scheduler=KanaEffects.Timers.New(TestSupport.FakeClock.New()); local hid=false
    local driver=function(now) scheduler:Advance(now) end
    local function observer()
        return function(active)
            -- Same activity-to-native-driver transport as Renderer. Either first
            -- observer hides on activation, so this test does not rely on pairs
            -- iteration order for function keys in Lua5.1.
            controls:SetTimerDriver(active and driver or nil)
            if active and not hid then hid=true; scheduler:SetVisible(false) end
        end
    end
    local unsubA=scheduler:SubscribeActivity(observer()); local unsubB=scheduler:SubscribeActivity(observer())
    scheduler:Watch('finite',{kind='finite',endTime=10},function() end,function() end)
    A.True(hid); A.Equal(next(api.updates),nil)
    unsubA(); unsubB(); scheduler:Dispose(); controls:Dispose()
end
Tests.reentrant_activity_flip_away_and_back_cancels_obsolete_equal_value_broadcast=function()
    local api=native(); local controls=KanaEffects.Controls.New(api)
    local scheduler=KanaEffects.Timers.New(TestSupport.FakeClock.New()); local flipped=false; local trueNotifications=0
    local driver=function(now) scheduler:Advance(now) end
    local function observer()
        return function(active)
            controls:SetTimerDriver(active and driver or nil)
            if active then
                trueNotifications=trueNotifications+1
                if not flipped then
                    flipped=true; scheduler:SetVisible(false); scheduler:SetVisible(true)
                end
            end
        end
    end
    local unsubA=scheduler:SubscribeActivity(observer()); local unsubB=scheduler:SubscribeActivity(observer())
    scheduler:Watch('finite',{kind='finite',endTime=10},function() end,function() end)
    -- First activation reaches one observer; the fresh final activation reaches
    -- both. The interrupted old true broadcast must not notify its second one.
    A.Equal(trueNotifications,3); assert(next(api.updates))
    scheduler:SetVisible(false); A.Equal(next(api.updates),nil)
    unsubA(); unsubB(); scheduler:Dispose(); controls:Dispose()
end

Tests.snapshot_heading_has_positive_native_height_all_styles_and_empty=function()
    for _,mode in ipairs({'over','under','right','list'}) do
        for _,empty in ipairs({false,true}) do
            local r,controls=components(); local w=F.Widget(); w.type='grid'; w.style.mode=mode
            local e=empty and {} or {entry()}; local measurement=KanaEffects.Layout.Measure(w.style,{MeasureText=function(_,t,n) return #t*n/2,n end})
            local placed=KanaEffects.Layout.Place(w,e,{x=0,y=0,width=1000,height=800},{x=0,y=0,width=1000,height=800},measurement)
            local before={x=placed.rect.x,y=placed.rect.y,width=placed.rect.width,height=placed.rect.height}
            r:Render(w,e,placed,{frozenAt=0,snapshot={observedAt=0,title='Enemy'}})
            local marker=r.widgets[w.id].snapshotLabel
            if empty then A.Equal(marker,nil,'empty widget must not allocate a target caption')
            else assert(marker.height>0,mode..' snapshot marker height')
            A.Equal(marker.anchor.y,placed.rect.y-marker.height)
            A.Equal(marker.anchor.x+marker.width/2,placed.placements[1].rect.x+placed.placements[1].rect.width/2)
            A.True(marker.width>0 and marker.width<=360); A.Equal(marker.text,'Enemy'); A.Equal(marker.wrap,'ellipsis'); A.Equal(marker.lines,1)
            end
            for k,v in pairs(before) do A.Equal(placed.rect[k],v) end
            if mode~='list' then A.Equal(measurement.nameLineHeight,0) end
            r:Dispose()
        end
    end
end
Tests.native_stock_caption_font_height_uses_label_font_alias=function()
    local _,controls=components(); local metrics=KanaEffects.FontMetrics.New(controls)
    assert(metrics.TargetCaptionHeight,'missing native target caption font measure')
    A.Equal(metrics:TargetCaptionHeight(),19); A.Equal(controls.fontHeightLabel.font,'ZoFontGameShadow')
    local control=controls.fontHeightLabel; A.True(control.hidden); metrics:TargetCaptionHeight(); A.Equal(controls.fontHeightLabel,control)
end
Tests.drag_preview_moves_actual_cells_without_rebuilding_and_restores=function()
    local r,_,_,_,api=components(); local w=F.Widget(); local a,b=entry('a'),entry('b')
    local placed=result({a,b}); r:Render(w,{a,b},placed); r:SetEditorOverlay(w.id,true)
    local state=r.widgets[w.id]; local count=#api.created
    r:SetGesturePreview({kind='move',widgetId=w.id,dx=40,dy=25})
    A.Equal(state.cells.a.root.anchor.x,60); A.Equal(state.cells.b.root.anchor.x,184)
    A.Equal(state.cells.a.root.anchor.y,55); A.Equal(state.outlines[1].anchor.x,60)
    A.Equal(placed.placements[1].rect.x,20); A.Equal(#api.created,count)
    a.minor.endTime=13; r:Render(w,{a,b},placed)
    A.Equal(state.cells.a.root.anchor.x,60); A.Equal(state.cells.b.root.anchor.y,55)
    r:SetGesturePreview(nil)
    A.Equal(state.cells.a.root.anchor.x,20); A.Equal(state.cells.b.root.anchor.x,144)
    A.Equal(state.outlines[1].anchor.x,20); A.Equal(#api.created,count)
end
Tests.slot_preview_moves_only_selected_icon_content_and_restores=function()
    local r=components(); local w=F.Widget(); local a,b=entry('a'),entry('b'); local placed=result({a,b})
    r:Render(w,{a,b},placed); r:SetEditorOverlay(w.id,true); local state=r.widgets[w.id]
    r:SetGesturePreview({kind='slot',widgetId=w.id,row=1,column=2,dx=-100,dy=45})
    A.Equal(state.cells.a.root.anchor.x,20); A.Equal(state.cells.b.root.anchor.x,44)
    A.Equal(state.cells.b.root.anchor.y,75); A.Equal(state.outlines[2].anchor.x,144)
    A.Equal(state.cells.b.icon:GetDrawTier(),0,'drag stays below system panels')
    A.Equal(state.cells.b.icon:GetDrawLayer(),state.cells.a.icon:GetDrawLayer())
    assert(state.cells.b.icon:GetDrawLevel()>state.cells.a.icon:GetDrawLevel(),'dragged icon must draw above other slots')
    r:SetGesturePreview(nil); A.Equal(state.cells.b.root.anchor.x,144); A.Equal(state.cells.b.root.anchor.y,30)
    A.Equal(state.cells.b.icon:GetDrawTier(),state.cells.a.icon:GetDrawTier())
end
Tests.unknown_duration_has_no_label_backing_or_timer_driver=function()
    local r,_,_,_,api=components(); local w=F.Widget(); w.style.mode='over'
    local e=entry(); e.pair=false; e.single={kind='finite',endTime=10}; r:Render(w,{e},result({e}))
    local cell=r.widgets[w.id].cells[e.key]; assert(next(api.updates))
    e.single={kind='unknown'}; r:Render(w,{e},result({e}))
    A.True(cell.timers[1].hidden); A.Equal(cell.timers[1].text,'')
    A.Equal(next(api.updates),nil); A.False(cell.icon.hidden)
    e.single={kind='finite',endTime=12}; r:Render(w,{e},result({e}))
    A.False(cell.timers[1].hidden); A.Equal(cell.timers[1].text,'12')
end

local function compactLayout(w,e)
    w.style.iconSize=48
    e.row,e.column=1,1
    local measured=KanaEffects.Layout.Measure(w.style,{MeasureText=function() return 40,20 end})
    local screen={x=0,y=0,width=2000,height=1200}
    return KanaEffects.Layout.Place(w,{e},screen,screen,measured)
end
Tests.pair_timer_selects_minimum_and_colors_active_levels_without_geometry_changes=function()
    local minorColor={145/255,210/255,235/255,1}; local majorColor={244/255,211/255,137/255,1}; local white={1,1,1,1}
    local cases={
        {minor={kind='finite',endTime=10},major={kind='missing'},text='10',color=minorColor},
        {minor={kind='missing'},major={kind='finite',endTime=20},text='20',color=majorColor},
        {minor={kind='finite',endTime=10},major={kind='finite',endTime=20},text='10',color=white},
        {minor={kind='finite',endTime=30},major={kind='finite',endTime=20},text='20',color=white},
        {minor={kind='finite',endTime=10},major={kind='permanent'},text='10',color=white},
        {minor={kind='permanent'},major={kind='finite',endTime=20},text='20',color=white},
        {minor={kind='permanent'},major={kind='permanent'},text=''},
        {minor={kind='unknown'},major={kind='finite',endTime=12},text='12',color=white},
        {minor={kind='unknown'},major={kind='missing'},text=''},
        {minor=nil,major=nil,text=''},
    }
    local positions={over=14,under=52,right=14,list=14}
    for _,mode in ipairs({'over','under','right','list'}) do
        local r,_,scheduler,clock=components(); local w=F.Widget(); w.style.mode=mode; w.style.timerFontSize=17
        local e=entry(); local layout=compactLayout(w,e); local rootCalls,iconCalls,font
        for _,case in ipairs(cases) do
            e.minor,e.major=case.minor,case.major; r:Render(w,{e},layout)
            local cell=r.widgets[w.id].cells[e.key]; local label=cell.timers[1]
            A.Equal(#cell.timers,1); A.Equal(cell.timers[2],nil)
            A.Equal(label.text,case.text); A.Equal(label.hidden,case.text==''); A.Equal(scheduler.count,case.text=='' and 0 or 1)
            if case.color then for i,value in ipairs(case.color) do A.Equal(label.color[i],value) end end
            if case.text~='' then A.Equal(label.anchor.y,positions[mode]); A.Equal(label.height,20) end
            rootCalls=rootCalls or cell.root.calls.SetAnchor; iconCalls=iconCalls or cell.icon.calls.SetAnchor; font=font or label.font
            A.Equal(cell.root.calls.SetAnchor,rootCalls); A.Equal(cell.icon.calls.SetAnchor,iconCalls); A.Equal(label.font,font)
        end
        e.minor={kind='finite',endTime=10}; e.major=nil; r:Render(w,{e},layout)
        local label=r.widgets[w.id].cells[e.key].timers[1]; local anchors=label.calls.SetAnchor
        clock:Set(1); scheduler:Advance(1); A.Equal(label.text,'9'); A.Equal(label.calls.SetAnchor,anchors)
        r:Dispose()
    end
end
Tests.single_timer_expiry_rebinds_remaining_pair_without_second_watch=function()
    local r,_,scheduler,clock=components(); local w=F.Widget(); local e=entry(); e.minor.endTime=1
    local layout=compactLayout(w,e); local expired=0
    r:SetCallbacks({onExpired=function()
        expired=expired+1; e.minor={kind='missing'}; r:Render(w,{e},layout)
    end})
    r:Render(w,{e},layout); A.Equal(scheduler.count,1)
    clock:Set(1); scheduler:Advance(1)
    local cell=r.widgets[w.id].cells[e.key]; A.Equal(expired,1); A.Equal(scheduler.count,1)
    A.Equal(cell.timers[1].text,'19'); A.Equal(cell.timers[1].color[1],244/255)
    r:SetGesturePreview({kind='slot',widgetId=w.id,row=1,column=1,dx=30,dy=10})
    r:ReleaseWidget(w.id); A.Equal(scheduler.count,0); r:SetGesturePreview(nil)
    e.key='new'; e.major={kind='permanent'}; r:Render(w,{e},compactLayout(w,e))
    A.Equal(r.widgets[w.id].cells.new,cell); A.True(cell.timers[1].hidden); A.Equal(cell.icon:GetDrawTier(),0)
end
Tests.permanent_and_unknown_transitions_hide_all_timer_artifacts_in_four_styles=function()
    for _,mode in ipairs({'over','under','right','list'}) do for _,pair in ipairs({false,true}) do
        local r,_,_,_,api=components(); local w=F.Widget(); w.style.mode=mode
        local e=entry(); e.pair=pair; e.single={kind='finite',endTime=10}
        local layout=compactLayout(w,e); r:Render(w,{e},layout); local cell=r.widgets[w.id].cells[e.key]
        for _,kind in ipairs({'permanent','unknown','permanent'}) do
            e.single={kind=kind}; e.minor={kind=kind}; e.major={kind='permanent'}
            r:Render(w,{e},layout)
            for _,label in ipairs(cell.timers) do A.True(label.hidden); A.Equal(label.text,'') end
            A.Equal(next(api.updates),nil)
        end
        e.single={kind='finite',endTime=15}; e.major={kind='finite',endTime=15}
        r:Render(w,{e},layout); local timer=cell.timers[1]
        A.False(timer.hidden); A.Equal(timer.text,'15'); assert(next(api.updates))
        r:ReleaseWidget(w.id); e.key='reused'; e.single={kind='permanent'}; e.major={kind='permanent'}
        r:Render(w,{e},compactLayout(w,e)); A.Equal(r.widgets[w.id].cells.reused,cell)
        for _,label in ipairs(cell.timers) do A.True(label.hidden); A.Equal(label.text,'') end
        A.Equal(next(api.updates),nil); r:Dispose()
    end end
end
Tests.right_click_context_hides_hover_uses_current_entry_and_rejects_stale_handlers=function()
    local r,_,_,_,api=components(); local w=F.Widget(); local e=entry(); local events={}
    r:SetCallbacks({onEnter=function(id,entry,root,icon) events[#events+1]='enter'; assert(icon and icon.parent==root) end,
        onExit=function() events[#events+1]='exit' end,
        onCellContext=function(id,entry,root) events[#events+1]={id=id,entry=entry,root=root} end})
    r:Render(w,{e},result({e})); local cell=r.widgets[w.id].cells[e.key]
    cell.root.handlers.OnMouseEnter(cell.root); local old=cell.root.handlers.OnMouseUp
    assert(old,'missing native context handler')
    old(cell.root,1,true); old(cell.root,2,false); A.Equal(#events,1)
    local fresh=entry(); fresh.name='Fresh'; r:Render(w,{fresh},result({fresh}))
    old(cell.root,2,true); A.Equal(events[#events-1],'exit'); A.Equal(events[#events].entry,fresh)
    A.Equal(events[#events].root,cell.root); A.Equal(events[#events].id,w.id)
    r:ReleaseWidget(w.id); local count=#events; old(cell.root,2,true); A.Equal(#events,count)
    e=entry('new'); r:Render(w,{e},result({e})); old(cell.root,2,true); A.Equal(#events,count)
    local current=cell.root.handlers.OnMouseUp; r:SetVisible(false); current(cell.root,2,true); A.Equal(#events,count)
    r:Dispose(); current(cell.root,2,true); A.Equal(#events,count)
end

Tests.snapshot_caption_is_bounded_near_viewport_edges_and_restores_after_drag=function()
    local r=components(); local w=F.Widget(); w.type='grid'; w.anchor.x=380; w.anchor.y=60
    local e=entry(); local viewport={x=10,y=20,width=400,height=200}
    local layout=KanaEffects.Layout.Place(w,{e},viewport,viewport,m)
    local title=string.rep('Очень длинное имя ',20)
    r:Render(w,{e},layout,{snapshot={title=title},frozenAt=0})
    local label=r.widgets[w.id].snapshotLabel; local x,y=label.anchor.x,label.anchor.y
    A.Equal(label.text,title); A.Equal(label.wrap,'ellipsis'); A.Equal(label.lines,1)
    assert(x>=10 and x+label.width<=410); assert(y>=20 and y+label.height<=220)
    r:SetGesturePreview({kind='move',widgetId=w.id,dx=-30,dy=15})
    A.Equal(label.anchor.x,x-30); A.Equal(label.anchor.y,y+15)
    r:SetGesturePreview(nil); A.Equal(label.anchor.x,x); A.Equal(label.anchor.y,y)
    r:ReleaseWidget(w.id)
    w.anchor.x=-100; w.anchor.y=-30; viewport.width=150
    layout=KanaEffects.Layout.Place(w,{e},viewport,viewport,m)
    layout.placements[1].visible=true
    r:Render(w,{e},layout,{snapshot={title='Новая цель'},frozenAt=0})
    A.Equal(r.widgets[w.id].snapshotLabel,label)
    A.Equal(label.text,'Новая цель'); A.Equal(label.width,150); A.Equal(label.anchor.x,10); A.Equal(label.anchor.y,20)
end

Tests.target_caption_hides_after_last_visible_effect_and_centers_over_widget=function()
    local r=components(); local w=F.Widget(); w.type='grid'; w.anchor.x=400; w.anchor.y=200
    local e=entry(); local viewport={x=0,y=0,width=1000,height=800}
    local layout=KanaEffects.Layout.Place(w,{e},viewport,viewport,m)
    r:Render(w,{e},layout,{snapshot={title='Enemy'}})
    local label=r.widgets[w.id].snapshotLabel
    A.False(label.hidden); A.Equal(label.align,'center')
    A.Equal(label.anchor.x+label.width/2,layout.placements[1].rect.x+layout.placements[1].rect.width/2)
    local empty=KanaEffects.Layout.Place(w,{},viewport,viewport,m)
    r:Render(w,{},empty,{snapshot={title='Enemy'}}); A.True(label.hidden)
    r:Render(w,{e},layout,{snapshot={title='Enemy'}}); A.False(label.hidden)
    layout.placements[1].visible=false
    r:Render(w,{e},layout,{snapshot={title='Enemy'}}); A.True(label.hidden)
    r:Dispose()
end

Tests.aura_controls_stay_below_system_panels_through_drag_and_reuse=function()
    local r,_,_,_,api=components(); local w=F.Widget(); w.style.mode='list'; local e=entry()
    local function check() for _,c in ipairs(api.created) do if c~=api.controls.GuiRoot then A.Equal(c:GetDrawTier(),api.constants.DT_LOW,'aura control tier') end end end
    r:Render(w,{e},result({e}),{snapshot={title='Enemy'}}); check()
    local cell=r.widgets[w.id].cells[e.key]; local layer,level=cell.icon:GetDrawLayer(),cell.icon:GetDrawLevel()
    r:SetGesturePreview({kind='slot',widgetId=w.id,row=1,column=1,dx=30,dy=10}); check()
    r:SetGesturePreview(nil); check(); A.Equal(cell.icon:GetDrawLayer(),layer); A.Equal(cell.icon:GetDrawLevel(),level)
    r:ReleaseWidget(w.id); r:Render(w,{e},result({e})); check(); r:Dispose()
end

Tests.snapshot_caption_centers_on_visible_effects_in_partial_aligned_grid=function()
    for _,alignment in ipairs({'start','center','end'}) do
        local r=components(); local w=F.Widget(); w.type='grid'; w.layout.count=8; w.layout.align=alignment
        w.layout.gap=4; w.anchor.x=200; w.anchor.y=200; w.style.mode='over'; w.style.iconSize=24
        local e={entry('a'),entry('b')}; local viewport={x=0,y=0,width=2000,height=1000}
        local measure=KanaEffects.Layout.Measure(w.style,{MeasureText=function() return 40,20 end})
        local layout=KanaEffects.Layout.Place(w,e,viewport,viewport,measure)
        r:Render(w,e,layout,{snapshot={title='Enemy'}})
        local label=r.widgets[w.id].snapshotLabel
        local left=layout.placements[1].rect.x; local right=layout.placements[2].rect.x+24
        A.Equal(label.anchor.x+label.width/2,(left+right)/2); A.Equal(label.anchor.y+label.height,200)
        layout.placements[1].visible=false
        r:Render(w,e,layout,{snapshot={title='Enemy'}})
        A.Equal(label.anchor.x+label.width/2,right-12)
        e[2].active=false; r:Render(w,e,layout,{snapshot={title='Enemy'}}); A.True(label.hidden)
    end
end

Tests.snapshot_caption_shrinks_at_screen_edges_without_shifting_effect_center=function()
    for _,case in ipairs({{10,0,68,34},{342,332,68,366},{176,80,240,200}}) do
        local r=components(); local w=F.Widget(); w.type='grid'; w.style.mode='over'; w.style.iconSize=48
        w.layout.count=1; w.anchor.x=case[1]; w.anchor.y=100
        local e=entry(); local viewport={x=0,y=0,width=400,height=300}
        local measure=KanaEffects.Layout.Measure(w.style,{MeasureText=function() return 40,20 end})
        local layout=KanaEffects.Layout.Place(w,{e},viewport,viewport,measure)
        r:Render(w,{e},layout,{snapshot={title='A long target name'}})
        local label=r.widgets[w.id].snapshotLabel
        A.Equal(label.anchor.x,case[2]); A.Equal(label.width,case[3]); A.Equal(label.anchor.x+label.width/2,case[4])
        A.Equal(label.wrap,'ellipsis'); A.Equal(label.lines,1)
        r:SetGesturePreview({kind='move',widgetId=w.id,dx=5,dy=10}); r:SetGesturePreview(nil)
        A.Equal(label.anchor.x,case[2]); A.Equal(label.width,case[3]); r:Dispose()
    end
end
Tests.aura_order_stays_below_stock_backgrounds_through_drag_and_pool_reuse=function()
    local r,controls,_,_,api=components(); local w=F.Widget(); w.style.mode='list'
    local entries={entry('a'),entry('b')}; for _,e in ipairs(entries) do e.kind='debuff'; e.selector={kind='category',id='food'}; e.count=2 end
    local layout=result(entries); local display={snapshot={title='Enemy'}}
    r:Render(w,entries,layout,display); r:SetEditorOverlay(w.id,true)
    local state=r.widgets[w.id]; local first,dragged=state.cells.a,state.cells.b
    -- Native comparison is tier, then layer, then level. Comparing only LOW
    -- missed the regression against LOW/BACKGROUND stock HUD backgrounds.
    local function below(a,b)
        local av={a:GetDrawTier(),a:GetDrawLayer(),a:GetDrawLevel()}
        local bv={b:GetDrawTier(),b:GetDrawLayer(),b:GetDrawLevel()}
        for i=1,3 do if av[i]~=bv[i] then return av[i]<bv[i] end end
        return false
    end
    local function stock(level) return {GetDrawTier=function() return api.constants.DT_LOW end,GetDrawLayer=function() return api.constants.DL_BACKGROUND end,GetDrawLevel=function() return level end} end
    local loot,subtitles=stock(0),stock(1)
    local function check(cell)
        for _,c in ipairs(controls.owned) do
            assert(below(c,loot),'owned aura control must be strictly below stock loot background')
            assert(below(c,subtitles),'owned aura control must be below stock subtitle background')
        end
        assert(below(cell.background,cell.icon),'row fill must stay behind icon')
        for _,text in ipairs({cell.timers[1],cell.name,cell.badge}) do
            assert(below(cell.icon,text),'icon must stay behind its text')
            assert(below(text,cell.debuff),'border must stay above text')
        end
    end
    check(first); check(dragged)
    local originals={}; for _,c in ipairs(controls.owned) do originals[c]={c:GetDrawLayer(),c:GetDrawLevel()} end
    r:SetGesturePreview({kind='slot',widgetId=w.id,row=1,column=2,dx=-124,dy=0}); check(dragged)
    assert(below(first.debuff,dragged.background),'whole dragged aura must rise over every normal aura part')
    r:Render(w,entries,layout,display); check(dragged)
    r:SetGesturePreview(nil); check(dragged)
    for c,order in pairs(originals) do A.Equal(c:GetDrawLayer(),order[1]); A.Equal(c:GetDrawLevel(),order[2]) end
    r:SetGesturePreview({kind='slot',widgetId=w.id,row=1,column=2,dx=1,dy=1}); r:ReleaseWidget(w.id)
    local nextWidget=F.Widget('next'); nextWidget.style.mode='list'; local nextEntry=entry('new'); nextEntry.kind='debuff'; nextEntry.selector={kind='category',id='food'}; nextEntry.count=2
    r:Render(nextWidget,{nextEntry},result({nextEntry}),display); r:SetEditorOverlay(nextWidget.id,true)
    local reused=r.widgets[nextWidget.id].cells.new; assert(reused==first or reused==dragged,'must exercise pooled cell reuse'); check(reused)
    for _,c in ipairs({reused.root,reused.background,reused.icon,reused.debuff,reused.timers[1],reused.name,reused.badge}) do A.Equal(c:GetDrawLevel(),originals[c][2],'pooled cell must return to unraised ordering') end
end
Tests.rule_warning_visible_on_empty_panel_and_clears_on_repair=function()
    local r,controls,_,_,api=components(); local w=F.Widget(); local layout=result({})
    layout.viewport={x=0,y=0,width=320,height=180}
    local entered,exited,edited=0,0,0
    r:SetCallbacks({onRuleErrorEnter=function(id,issues,c) A.Equal(id,w.id); A.Equal(issues[1].code,'missing_panel'); entered=entered+1 end,
        onRuleErrorExit=function() exited=exited+1 end,onRuleError=function(id) A.Equal(id,w.id); edited=edited+1 end})
    r:Render(w,{},layout,{ruleDiagnostics={{code='missing_panel',message='Не найдена панель «еда».'}}})
    local warning=assert(r.widgets[w.id].warning,'empty panel must still show its error')
    A.False(warning:IsControlHidden()); A.True(warning.mouse); A.True(warning.anchor.x>=0); A.True(warning.anchor.y>=0)
    A.Equal(warning:GetDrawTier(),api.constants.DT_LOW); A.Equal(warning:GetDrawLayer(),api.constants.DL_BACKGROUND); A.True(warning:GetDrawLevel()<0)
    warning.handlers.OnMouseEnter(warning); A.Equal(entered,1)
    warning.handlers.OnMouseUp(warning,1,true); A.Equal(edited,1)
    local stale=warning.handlers.OnMouseUp
    r:Render(w,{},layout); A.True(warning:IsControlHidden()); A.Equal(exited,1)
    stale(warning,1,true); A.Equal(edited,1)
    r:Render(w,{},layout,{ruleDiagnostics={{code='missing_panel',message='Missing'}}})
    warning.handlers.OnMouseEnter(warning); r:ReleaseWidget(w.id); A.True(warning:IsControlHidden()); A.Equal(exited,2)
    stale(warning,1,true); A.Equal(edited,1)
end
