local T = dofile('KanaCombatBookmarks/tests/support.lua')
T.load('Names'); T.load('Model'); T.load('LogView')
local makeApi = dofile('KanaCombatBookmarks/tests/ui_support.lua')
local names = {'DAMAGE_OUT','DAMAGE_IN','DAMAGE_SELF','HEAL_OUT','HEAL_IN','HEAL_SELF','EFFECTS_IN','EFFECTS_OUT','GROUPEFFECTS_IN','GROUPEFFECTS_OUT','PLAYERSTATS','RESOURCES','MESSAGES','DEATH','PLAYERSTATS_ADVANCED','SKILL_TIMINGS','BOSSHP','PERFORMANCE'}
for i,name in ipairs(names) do _G['LIBCOMBAT_EVENT_'..name]=i+3 end
POWERTYPE_HEALTH=-2
LibCombat={GetFormattedAbilityName=function(id)return tostring(id)end}
local function setup(count, marks, configure)
    local a=makeApi()
    a.fight={combatstart=1000,log={},kanaCombatBookmarks={version=1,entries={}}}
    for i=1,count do a.fight.log[i]={4,1000+i,1,1,2,3,text=(i%7==0 and 'wrapped ' or '')..'event '..i} end
    for i,offset in ipairs(marks) do a.fight.kanaCombatBookmarks.entries[i]={id=i,name='Кракен '..i,offsetMs=offset} end
    if configure then configure(a) end
    local v=KanaCombatBookmarks.LogView.New(a,a.adapter)
    assert(v:Install()); a.controls.panel:Update();a:flush()
    return a,v
end
local function centered(a,v,id)
    local span=assert(v.markerSpans[id]); local b=a.controls.buffer
    local top=b.total-b.position-a.visible
    assert(math.abs((span.before+span.after)/2-top-a.visible/2)<=0.5,'marker is not centered')
end
T.test('UI implementation',function() assert(KanaCombatBookmarks.LogView.Install) end)
if T.failed>0 then T.finish() end
T.test('page-boundary jumps keep context and native wheel/slider controls',function()
    local a,v=setup(2500,{998,999,1000})
    for id=1,3 do
        assert(v:JumpTo(id)); centered(a,v,id)
        local span=v.markerSpans[id]
        assert(span.before>20 and a.controls.buffer.total-span.after>20)
    end
    local b=a.controls.buffer; local old=b.position
    b:GetHandler('OnMouseWheel')(b,1); T.eq(b.position,old+1)
    local page=a.controls.pages:GetNamedChild('Page2')
    page:GetHandler('OnMouseUp')(page); T.eq(v.page,2); T.eq(v.jumpId,nil)
    assert(not a.nativeNavigation)
end)
T.test('short viewport, fight endpoints and all events filtered out remain centered',function()
    local a,v=setup(2,{-1,1,5})
    for _,visible in ipairs({20,5}) do
        a.visible=visible
        for id=1,3 do assert(v:JumpTo(id)); centered(a,v,id) end
        a.CMX.db.FightReport.CLSelection={}
        a.controls.panel:Update(); assert(v:JumpTo(2)); centered(a,v,2)
    end
    T.eq(#a.fight.log,2)
end)
T.test('copy uses the visible wrapped context and clean marker text',function()
    local a,v=setup(100,{49}); v:JumpTo(1)
    local b=a.controls.buffer; local old=b.position
    a.controls.window:SetHidden(true);a.controls.copy:SetHidden(false)
    a.CMX.db.FightReport.CLSelection.CopyPaste=true
    a.controls.panel:Update()
    local text=a.controls.copy:GetText()
    assert(text:find('Кракен 1',1,true));assert(not text:find('|c',1,true));assert(not text:find('|t',1,true))
    assert(text:find('event 48',1,true));assert(not text:find('event 1\n',1,true))
    T.eq(b.position,old)
    v:JumpTo(1);assert(not a.controls.window:IsHidden());assert(a.controls.copy:IsHidden())
    assert(not a.CMX.db.FightReport.CLSelection.CopyPaste);centered(a,v,1)
end)
T.test('bookmark list remains scrollable to its last entry at a smaller height',function()
    local marks={};for i=1,48 do marks[i]=i end
    local a,v=setup(60,marks)
    a.controls.panel.height=100;a.controls.panel.width=360;a.visible=5
    a.controls.panel:Update()
    T.eq(v.scroll.template,'ZO_ScrollContainer');assert(v.scroll.extent>0)
    local last=v.buttons[48];assert(not last:IsHidden())
    last:GetHandler('OnMouseWheel')(last,-100);T.eq(v.scroll.offset,v.scroll.extent)
    last:GetHandler('OnClicked')(last);centered(a,v,48)
    assert(v.sidebar:GetWidth()<=a.controls.panel:GetWidth()*0.4)
end)
T.test('fight switch restores native layout, navigation and missing-log distinction',function()
    local a,v=setup(50,{25}); v:JumpTo(1)
    a.fight={combatstart=1000,log={{4,1001}}}
    a.controls.panel:Update();assert(not v.active);assert(v.sidebar:IsHidden());T.eq(a.nativeUpdates,1)
    local _,_,_,_,x=a.controls.window:GetAnchor(1);T.eq(x,-4)
    local page=a.controls.pages:GetNamedChild('Page2');page:GetHandler('OnMouseUp')(page);T.eq(a.nativeNavigation,1)
    a.fight={combatstart=0,kanaCombatBookmarks={version=1,entries={{id=1,name='Армагеддон',offsetMs=3}}}}
    a.controls.panel:Update();assert(v.active);assert(not v.buttons[1]:IsHidden())
    assert(not v:JumpTo(1));assert(a.alerts[#a.alerts]:find('подробного лога',1,true))
end)
T.test('installation waits for native lazy initialization and is idempotent',function()
    local a=makeApi();local native=a.controls.panel.Update;a.controls.panel.Update=nil
    local v=KanaCombatBookmarks.LogView.New(a,a.adapter)
    assert(not v:Install());a.controls.panel.Update=native
    assert(v:Install());local handler=a.controls.panel.Update
    assert(v:Install());T.eq(a.controls.panel.Update,handler)
    local b=makeApi();b.controls.window.children.Buffer=nil
    assert(not KanaCombatBookmarks.LogView.New(b,b.adapter):Install())
    b.controls.panel:Update();T.eq(b.nativeUpdates,1)
end)
T.test('report captures its own selections without stealing temporary statistics selections',function()
    local a=makeApi();local selection={unit={damageOut={[3]=true}}}
    a.CMX.GenerateSelectionStats=function(_,_,s)return s end
    a.controls.report.Update=function()a.CMX.GenerateSelectionStats(a.fight,'damageOut',selection);a.controls.panel:Update()end
    local v=KanaCombatBookmarks.LogView.New(a,a.adapter);assert(v:Install())
    a.controls.report:Update();T.eq(a.adapter.selections,selection)
    a.CMX.GenerateSelectionStats(a.fight,'damageOut',{});T.eq(a.adapter.selections,selection)
end)
T.test('layout settles before final measurement and stale deferred renders cannot replace a fight',function()
    local a,v=setup(100,{49})
    local b=a.controls.buffer;local width=500
    b.GetWidth=function()return width end
    a.controls.panel.width=600
    a.controls.panel:Update();v:JumpTo(1)
    local initial=v.markerControls[1]:GetWidth()
    width=240 -- ESO resolves anchors between frames.
    a:flush()
    assert(v.markerControls[1]:GetWidth()~=initial,'separator still uses stale buffer width')
    centered(a,v,1)
    local nativeAnchor=a.controls.window.SetAnchor;local writes=0
    a.controls.window.SetAnchor=function(self,...)writes=writes+1;return nativeAnchor(self,...)end
    a.controls.panel:Update();a:flush();T.eq(writes,0)
    a.controls.panel.width=650;a.controls.panel:Update()
    a.fight={combatstart=0,log={{4,1}}};a.controls.panel:Update();a:flush()
    assert(not v.active);assert(v.sidebar:IsHidden())
end)
T.test('bookmark buttons have one-line names, time-based fills and hover/click feedback',function()
    local a,v=setup(100,{25,50,150})
    a.fight.combatend=1100;a.controls.panel:Update();a:flush()
    for i,fraction in ipairs({0.25,0.5,1}) do
        local button=v.buttons[i]
        T.eq(button.controlType,a.CT_BUTTON)
        T.eq(button.label:GetText(),'Кракен '..i);T.eq(button.label.maxLines,1)
        T.eq(button.label.wrapMode,a.TEXT_WRAP_MODE_ELLIPSIS)
        T.eq(button.progress,fraction)
        T.eq(button.fill:GetWidth(),button:GetWidth()*fraction)
        T.eq(button.label.horizontalAlignment,a.TEXT_ALIGN_LEFT)
        T.eq(button:GetHeight(),20*a.CMX.db.FightReport.scale)
        T.eq(button.background.edgeColor[4],0)
        local idle=button.background.centerColor[4]
        button:GetHandler('OnMouseEnter')(button)
        assert(button.background.centerColor[4]>idle)
        button:GetHandler('OnMouseExit')(button);T.eq(button.background.centerColor[4],idle)
    end
    local button=v.buttons[2];button:GetHandler('OnClicked')(button)
    T.eq(v.jumpId,2);centered(a,v,2)
    a.fight.kanaCombatBookmarks.entries[1].name='Сингулярность · 12'
    a.controls.panel.width=250;a.controls.panel.height=70;a.controls.panel:Update();a:flush()
    T.eq(v.buttons[1].label:GetText(),'Сингулярность · 12')
    T.eq(v.buttons[1].label.maxLines,1);assert(v.scroll.extent>0)
end)
T.test('log markers use solid gold bands with centered white labels and follow native scroll',function()
    local a,v=setup(100,{49});v:JumpTo(1)
    local band=assert(v.markerControls[1]);local b=a.controls.buffer
    T.eq(v.markerLayer.controlType,a.CT_SCROLL);T.eq(v.markerLayer.mouse,false)
    T.eq(band.centerColor[1],0.58);T.eq(band.label.color[1],1);T.eq(band.label.color[2],1);T.eq(band.label.color[3],1)
    T.eq(band.label:GetText(),'Кракен 1');T.eq(band.label.horizontalAlignment,a.TEXT_ALIGN_CENTER)
    T.eq(band:GetWidth(),b:GetWidth());assert(not band:IsHidden());assert(not band.mouse)
    local _,_,_,_,_,y=band:GetAnchor(0)
    assert(math.abs(y+band:GetHeight()/2-b:GetHeight()/2)<=v.measure:GetFontHeight()/2)
    b:GetHandler('OnMouseWheel')(b,1);v.markerLayer:GetHandler('OnUpdate')()
    local _,_,_,_,_,moved=band:GetAnchor(0);T.eq(moved-y,v.measure:GetFontHeight())
    b:SetScrollPosition(0);v.markerLayer:GetHandler('OnUpdate')();assert(band:IsHidden())
    v:JumpTo(1);assert(not band:IsHidden())
    a.controls.window:SetHidden(true);T.eq(v.markerLayer:IsHidden(),true)
    a.controls.window:SetHidden(false);a.fight={combatstart=0,log={{4,1}}};a.controls.panel:Update()
    assert(v.markerLayer:IsHidden())
end)
T.test('sidebar fits the longest name or title and recalculates when names or scale change',function()
    local a,v=setup(10,{2,5})
    -- ESO's native text pixels can differ from the UI units used by controls.
    a.nativeTextScale=2
    for _,scale in ipairs({1,1.5}) do
        a.CMX.db.FightReport.scale=scale
        for _,name in ipairs({'Джинн','Сингулярность · 12','Око'}) do
            a.fight.kanaCombatBookmarks.entries[1].name=name
            a.controls.panel:Update();a:flush()
            local expected=math.ceil(math.max(v.title:GetTextWidth(),v.buttons[1].label:GetTextWidth(),
                v.buttons[2].label:GetTextWidth())+4*scale)
            T.eq(v.sidebar:GetWidth(),expected);T.eq(v.buttons[1]:GetWidth(),expected)
            local _,_,_,_,x=a.controls.window:GetAnchor(1)
            T.eq(x,-4*scale-expected)
            local _,_,relative,_,sidebarX=v.sidebar:GetAnchor(0)
            T.eq(relative,a.controls.window);T.eq(sidebarX,0)
            local _,_,_,_,titleX=v.title:GetAnchor(0)
            local _,_,_,_,labelX=v.buttons[1].label:GetAnchor(0)
            T.eq(titleX,labelX)
            T.eq(v.title:GetWidth(),v.buttons[1]:GetWidth()-2*labelX)
        end
    end
end)
T.test('wrapped events and bookmark bands occupy separate measured rows at different widths',function()
    local a,v=setup(100,{49});local b=a.controls.buffer
    for _,width in ipairs({500,240}) do
        b.width=width;a.controls.panel.width=width+150
        -- A viewport need not be an exact multiple of Label:GetFontHeight().
        b.GetHeight=function()return a.visible*14+9 end
        a.controls.panel:Update();a:flush();v:JumpTo(1)
        local span=assert(v.markerSpans[1]);local band=v.markerControls[1]
        local _,_,_,_,_,bandY=band:GetAnchor(0)
        assert(math.abs(bandY+band:GetHeight()/2-b:GetHeight()/2)<=v.slotHeight/2)
        local wrapped=false
        for _,label in ipairs(v.eventControls or {}) do
            if not label:IsHidden() then
                local _,_,_,_,_,y=label:GetAnchor(0)
                assert(y+label:GetHeight()<=bandY or y>=bandY+band:GetHeight(),'event overlaps bookmark')
                if label:GetText():find('wrapped',1,true) then
                    wrapped=true;assert(label:GetHeight()>=label:GetTextHeight())
                end
            end
        end
        assert(wrapped,'wrapped event must remain visible beside bookmark')
        centered(a,v,1)
        for _,message in ipairs(b.messages) do assert(message.text:find('%S')) end
        T.eq(b:GetAlpha(),0)
        assert(span.before>49,'wrapped events must reserve their full height')
    end
end)
T.test('fresh and saved bookmarked logs remain visible when empty native messages are discarded',function()
    for _,saved in ipairs({false,true}) do
        local a,v=setup(100,{49},function(api)
            api.rejectWhitespace=true
            api.controls.buffer:SetAlpha(0.75)
            if saved then
                local storage=T.storage()
                local fight=api.fight
                fight.starttime=fight.combatstart;fight.APIversion=101050
                fight.units={[1]={name='Player',unitType=1},[2]={name='Enemy',unitType=4}}
                fight.calculated={units={},DPSOut=1,DPSIn=0,HPSOut=0,HPSIn=0}
                storage.Save(fight,false);api.fight=storage.Load(1)
            end
        end)
        local b=a.controls.buffer
        assert(b:GetNumHistoryLines()>a.visible,'scroll history is empty')
        assert(#v.eventControls>0,'opening the fight shows no events')
        assert(not a.controls.slider:IsHidden())
        T.eq(b:GetAlpha(),0);T.eq(v.markerLayer:GetParent(),a.controls.window)
        assert(v:JumpTo(1));centered(a,v,1)
        assert(not v.markerControls[1]:IsHidden());assert(v.markerControls[1]:GetHeight()>0)
        assert(not v.eventControls[1]:IsHidden());assert(v.eventControls[1]:GetHeight()>0)
        v:CopyVisible();assert(a.controls.copy:GetText():find('event 48',1,true))
        a.fight={combatstart=0,log={{4,1}}};a.controls.panel:Update()
        T.eq(b:GetAlpha(),0.75);T.eq(a.nativeUpdates,1)
    end
end)
T.test('clearing native history cannot turn one empty line into the entire viewport',function()
    local a,v=setup(100,{49},function(api)api.emptyVisibleZero=true end)
    assert(v.slotHeight<=v.measure:GetFontHeight()+1,'empty-buffer metrics inflated line height')
    assert(#v.eventControls>1,'opening the fight has no readable context')
    assert(v:JumpTo(1));centered(a,v,1)
    assert(#v.eventControls>1);assert(v.markerControls[1]:GetHeight()<=v.measure:GetFontHeight()+1)
end)
T.test('native scroll sentinels are invisible while event labels and native scrolling remain usable',function()
    local a,v=setup(100,{49})
    local b=a.controls.buffer
    for _,jump in ipairs({false,true}) do
        if jump then assert(v:JumpTo(1));centered(a,v,1) end
        assert(b:GetNumHistoryLines()>a.visible)
        T.eq(b:GetMessageAlpha(),0)
        assert(not b:IsHidden(),'the buffer must still receive mouse wheel input')
        assert(not v.eventControls[1]:IsHidden());T.eq(v.eventControls[1]:GetAlpha(),1)
        local position=b:GetScrollPosition()
        b:GetHandler('OnMouseWheel')(b,-1)
        T.eq(b:GetScrollPosition(),position-1)
    end
    a.fight={combatstart=0,log={{4,1}}};a.controls.panel:Update()
    T.eq(b:GetMessageAlpha(),1)
    assert(v.markerLayer:IsHidden());T.eq(a.nativeUpdates,1)
end)
T.finish()
