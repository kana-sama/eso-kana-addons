-- End-to-end production composition. Native API/control boundaries are recorded;
-- Bootstrap, Storage, Session, Sources, Catalog, Rules, Projector, Layout,
-- Renderer, Editor, Picker, Demo, TargetView and NativeHUD are the actual modules.
-- Configuration-only persistence, live-provider restoration, level filtering,
-- grid fan-out and shared geometry regressions must fail these four cases.
local manifest=assert(io.open(TEST_ROOT..'/KanaEffects.addon','r'))
for line in manifest:lines() do
    if line:match('%.lua$') and line~='Bootstrap.lua' then dofile(TEST_ROOT..'/'..line) end
end
manifest:close()
local A,F=TestSupport.Assert,TestSupport.Fixtures
local function copy(v)
    if type(v)~='table' then return v end
    local out={}; for k,x in pairs(v) do out[k]=copy(x) end; return out
end
local function callbacks(owner)
    owner.callbacks={}
    function owner:RegisterCallback(name,fn) self.callbacks[name]=self.callbacks[name] or {}; self.callbacks[name][fn]=true end
    function owner:UnregisterCallback(name,fn) self.callbacks[name][fn]=nil end
    function owner:Fire(name,...)
        local list={}; for fn in pairs(self.callbacks[name] or {}) do list[#list+1]=fn end
        for _,fn in ipairs(list) do if self.callbacks[name][fn] then fn(...) end end
    end
    owner.fragments={}
    function owner:AddFragment(f) self.fragments[f]=true; f.control:SetHidden(false) end
    function owner:RemoveFragment(f) self.fragments[f]=nil; f.control:SetHidden(true) end
end
local function buff(id,slot,ending) return {'Aura '..id,10,ending or 70,slot or 1,1,id..'.dds','',7,0,0,id,false,true} end
local function setup(profile,raw,buffs,artificial)
    local clock=TestSupport.FakeClock.New(10); local api=TestSupport.FakeApi.New(clock)
    local native=TestSupport.EditorNative.New()
    for k,v in pairs(native) do if k~='constants' and k~='capabilities' and k~='eventManager' then api[k]=v end end
    for k,v in pairs(native.constants) do api.constants[k]=v end
    local constants={EVENT_EFFECT_CHANGED=1,REGISTER_FILTER_UNIT_TAG=2,EVENT_RETICLE_TARGET_CHANGED=3,
        EVENT_BOSSES_CHANGED=4,EFFECT_RESULT_GAINED=5,EFFECT_RESULT_UPDATED=6,BUFF_EFFECT_TYPE_BUFF=7,
        EVENT_SCREEN_RESIZED=8,EVENT_ADD_ON_LOADED=91,EVENT_PLAYER_ACTIVATED=92,
        BOSS_RANK_ITERATION_BEGIN=1,BOSS_RANK_ITERATION_END=2,SCENE_SHOWING='showing',SCENE_SHOWN='shown',SCENE_HIDDEN='hidden'}
    for k,v in pairs(constants) do api.constants[k]=v end
    api.GetAPIVersion=function() return 101051 end
    api.DoesAbilityExist=function() return true end; api.GetAbilityName=function(id) return 'Native '..id end
    api.GetAbilityIcon=function(id) return id..'.dds' end
    api.units={player={name='Player'},reticleover={name='First'}}; api.buffs=buffs or {}
    if artificial then
        api.constants.EVENT_ARTIFICIAL_EFFECT_ADDED=193; api.constants.EVENT_ARTIFICIAL_EFFECT_REMOVED=194
        api.GetNextActiveArtificialEffectId=function(previous)
            local nextId; for id in pairs(artificial) do if (not previous or id>previous) and (not nextId or id<nextId) then nextId=id end end
            return nextId
        end
        api.GetArtificialEffectInfo=function(id) local v=artificial[id]; if v then return v.name,'native.dds',7,1,0,0 end end
    end
    api.GetWorldName=function() return 'Test World' end; api.GetDisplayName=function() return '@Test' end
    api.GetCurrentCharacterId=function() return '42' end
    api.raw=raw or {['Test World']={['@Test']={['42']={version=1,profile=copy(profile),history={}}}}}
    api.GetSettingsTable=function() return api.raw end; api.SetSettingsTable=function(v) api.raw=v end
    api.savedVars={NewCharacterIdSettings=function(_,root,version,namespace,defaults,world)
        local leaf=root[world]['@Test']['42']; A.Equal(version,1)
        if leaf.version==nil or leaf.version<version then for k in pairs(leaf) do leaf[k]=nil end end
        leaf.version=version
        return setmetatable({},{__index=leaf,__newindex=function(_,k,v) leaf[k]=v end})
    end}
    api.scenes={hud={},hudui={}}; for _,scene in pairs(api.scenes) do callbacks(scene) end
    callbacks(api.hudEditorScene); api.sceneFragmentClass={New=function(_,control) return {control=control} end}
    api.hudManager={elements={}}; callbacks(api.hudManager)
    function api.hudManager:RegisterKeyboardElement(control,name,config)
        local element={control=control,config=config,name=name}; self.elements[#self.elements+1]=element
        function element:ApplyOffset(x,y,save) A.Equal(save,false); self.control:SetAnchor('tl',api.controls.GuiRoot,'tl',x,y) end
        return element
    end
    function api.hudManager:RebuildAllElements() self:Fire('RebuildAllElements') end
    api.capabilities={nativeHudRegistration=true,nativeHudCallbacks=true,nativeHudRebuild=true}
    api.slashCommands={}
    local function flush()
        -- Drain only one-shot production flushes; never spin persistent timers.
        for round=1,10 do
            local pending={}
            for id,job in pairs(api.updates) do if job.interval==0 then pending[#pending+1]={id=id,job=job} end end
            if #pending==0 then return end
            for _,x in ipairs(pending) do if api.updates[x.id]==x.job then x.job.callback() end end
        end
        error('production flush failed to settle')
    end
    local original=KanaEffects.EsoApi.Build; KanaEffects.EsoApi.Build=function() return api end
    dofile(TEST_ROOT..'/Bootstrap.lua'); KanaEffects.EsoApi.Build=original
    api:Emit(91,'KanaEffects'); A.Equal(KanaEffects.application,nil)
    api:Emit(92); flush(); local app=assert(KanaEffects.application)
    A.False(app.replay.active); A.Equal(app.diagnostics.capture,nil); A.Equal(KanaEffects.ApiProbe.LastReport,nil)
    return {app=app,api=api,clock=clock,flush=flush,leaf=function() return api.raw['Test World']['@Test']['42'] end}
end
local function same(a,b)
    if type(a)~=type(b) then return false end; if type(a)~='table' then return a==b end
    for k,v in pairs(a) do if not same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end; return true
end
local function equalRect(a,b) for _,k in ipairs({'x','y','width','height'}) do A.Equal(a[k],b[k],k) end end
local function allSet() return {id='all',name='All',predicate={op='and',args={}},includeSets={},excludeSets={}} end
local function grid(id) local w=F.Widget(id); w.type='grid'; w.rules.includeSets={'all'}; return w end
Tests.aura_root_stays_below_stock_backgrounds_across_editor_lifecycle=function()
    local c=setup(F.Profile()); local app=c.app
    local function check()
        A.Equal(app.root.tier,c.api.constants.DT_LOW)
        A.Equal(app.root.layer,c.api.constants.DL_BACKGROUND)
        A.True(app.root.level<0,'root must precede stock loot background level 0 and subtitle level 1')
        A.Equal(app.root.allowBringToTop,false,'interactions must not raise the aura window')
    end
    check(); app.editor:Open(); check(); app.editor:Cancel(); check(); app:Dispose()
end
Tests.native_artificial_effect_flows_through_hud_hide_and_saved_history=function()
    local p=F.Profile(); p.sets={allSet()}; p.widgets[#p.widgets+1]=grid('grid-a')
    local artificial={[0]={name='Подписчик ESO Plus'}}
    local c=setup(p,nil,{player={buff(100)}},artificial); local app=c.app
    local view=app.runtime:GetView('grid-a'); A.Equal(#view.entries,2)
    local entry; for _,v in ipairs(view.entries) do if v.selector.kind=='artificial' then entry=v end end
    assert(entry,'native artificial effect did not reach HUD'); A.Equal(entry.single.kind,'permanent')
    app:OpenEffectContext('grid-a',entry,c.api.controls.GuiRoot); c.api.GetContextMenu().items[2].callback(); c.flush()
    A.Equal(c.leaf().profile.hidden[1].kind,'artificial')
    local entries=app.runtime:GetView('grid-a').entries; A.Equal(#entries,1); A.Equal(entries[1].selector.kind,'ability')
    local saved=copy(c.api.raw); app:Dispose()
    local restored=setup(p,saved,{player={buff(100)}},{})
    A.Equal(#restored.app.runtime:GetView('grid-a').entries,1)
    local history=restored.app.history:Query('ESO Plus',nil,0,10)
    A.Equal(#history,1); A.Equal(history[1].selector.kind,'artificial'); A.Equal(history[1].selector.id,0)
    restored.app:Dispose()
end
Tests.effect_context_hide_persists_outside_editor_and_preserves_table = function()
    local p=F.Profile(); p.sets={allSet()}; p.widgets[#p.widgets+1]=grid('grid-a')
    local c=setup(p,nil,{player={buff(100)}}); local app=c.app
    local entry=app.runtime:GetView('grid-a').entries[1]; A.True(entry~=nil)
    A.True(app:OpenEffectContext('grid-a',entry,c.api.controls.GuiRoot))
    A.Equal(c.api.GetContextMenu().items[1].label,'Редактировать панель')
    A.Equal(c.api.GetContextMenu().items[2].label,'Скрыть эффект')
    c.api.GetContextMenu().items[2].callback(); c.flush()
    A.False(app.editor:IsOpen()); A.Equal(app.session:ReadDraft(),nil)
    A.Equal(#c.leaf().profile.hidden,1); A.Equal(#app.runtime:GetView('grid-a').entries,0)
    A.True(#app.runtime:GetView('widget-a').entries>0)
    app:Dispose()
end
Tests.effect_context_hide_is_draft_scoped_and_stale_menu_is_inert = function()
    local p=F.Profile(); p.sets={allSet()}; p.widgets[#p.widgets+1]=grid('grid-a')
    local c=setup(p,nil,{player={buff(100)}}); local app=c.app
    local entry=app.runtime:GetView('grid-a').entries[1]
    app.editor:Open(); c.flush()
    app:OpenEffectContext('grid-a',entry,c.api.controls.GuiRoot)
    local stale=c.api.GetContextMenu().items[2].callback
    app.editor:Cancel(); c.flush(); stale(); c.flush()
    A.Equal(#c.leaf().profile.hidden,0)
    app.editor:Open(); c.flush(); app:OpenEffectContext('grid-a',entry,c.api.controls.GuiRoot)
    c.api.GetContextMenu().items[2].callback(); c.flush()
    A.Equal(#app.session:ReadDraft().hidden,1); A.Equal(#c.leaf().profile.hidden,0)
    app.editor:Cancel(); c.flush(); A.Equal(#app.runtime:GetView('grid-a').entries,1)
    app:Dispose()
end
Tests.full_edit_session_save_reload=function()
    local c=setup(F.Profile(),nil,{player={buff(100)}}); local app=c.app
    c.api.slashCommands['/ke'](); A.True(app.editor:IsOpen()); c.flush()
    A.True(app.editor.setEditor:Put(allSet()))
    for _,id in ipairs({'grid-a','grid-b'}) do A.True(app.editor:Apply({type='widget.add',widget=grid(id)})) end
    A.True(app.editor:PatchWidget('widget-a',{name='Сохранено',style={mode='list',iconSize=37},layout={rows=2,columns=2},anchor={x=111,y=222}}))
    A.True(app.editor:Apply({type='profile.threshold',seconds=90}))
    A.True(app.editor:Apply({type='editor.toolbar',x=80,y=90}))
    A.True(app.editor:Apply({type='hidden.add',selector=F.Selector(200)}))
    A.True(app.editor:SetTest('ordinary')); c.flush()
    c.api.buffs.player={buff(100,1,120)}; app.sources:Refresh(); c.flush()
    local expected=app.session:ReadDraft(); A.True(app.editor:Save()); c.flush()
    A.True(same(c.leaf().profile,expected)); A.Equal(app.runtime:GetView('widget-a').entries[1].single.endTime,120)
    for _,id in ipairs({'grid-a','grid-b'}) do A.Equal(#app.runtime:GetView(id).entries,1); A.True(app.runtime:GetView(id).entries[1].active) end
    A.Equal(c.leaf().profile.widgets[1].slots[3][6].id,200) -- shrinking retains assignment
    A.Equal(#c.leaf().history,1); A.False(c.leaf().history[1].synthetic)
    local persisted=copy(c.api.raw); app:Dispose()
    local reload=setup(nil,persisted,{})
    A.True(same(reload.app.storage:Load(),expected)); A.Equal(#reload.app.store:ReadUnit('player'),0)
    A.False(reload.app.runtime:GetView('widget-a').entries[1].active)
    A.Equal(#reload.app.runtime:GetView('grid-a').entries,0); A.Equal(#reload.app.history:Export(),1)
    reload.app:Dispose()
end
Tests.cancel_with_live_target_switch=function()
    local p=F.Profile(); p.widgets[1].unitTag='reticleover'; p.widgets[1].slots={[1]={[1]=F.Selector(100),[2]=F.Selector(200)}}
    local c=setup(p,nil,{reticleover={buff(100)}}); local app=c.app
    local first=app.store:Snapshot('reticleover',10).unit.generation
    A.True(app.editor:Open()); A.True(app.editor:PatchWidget('widget-a',{anchor={x=400},style={mode='under'}}))
    A.True(app.editor:SetTest('ordinary')); c.flush()
    c.clock:Set(20); c.api.units.reticleover={name='Second'}; c.api.buffs.reticleover={buff(200,2,95)}
    c.api:Emit(3); c.flush(); app.editor:Cancel(); c.flush()
    A.True(same(app.storage:Load(),p)); local view=app.runtime:GetView('widget-a')
    A.Equal(view.layout.rect.x,20); A.False(view.entries[1].active); A.True(view.entries[2].active)
    A.Equal(view.entries[2].single.endTime,95); A.Equal(view.entries[2].unit.name,'Second')
    A.True(view.entries[2].unit.generation>first); A.Equal(#app.store:ReadUnit('reticleover'),1)
    for _,row in ipairs(c.leaf().history) do A.False(row.synthetic) end
    app:Dispose()
end
Tests.blacklist_bypass_fixed_table_end_to_end=function()
    local p=F.Profile(); p.sets={allSet()}; p.widgets={F.Widget(),grid('a'),grid('b')}
    p.widgets[1].slots={[3]={[6]={kind='family',id='berserk',level='pair'}}}
    p.hidden={{kind='family',id='berserk',level='minor'}}
    local c=setup(p,nil,{player={buff(61744,1),buff(61745,2)}}); local app=c.app
    for _,id in ipairs({'a','b'}) do local e=app.runtime:GetView(id).entries[1]
        A.True(e.active); A.True(e.pair); A.Equal(e.minor.kind,'missing'); A.Equal(e.major.kind,'finite')
    end
    local e=app.runtime:GetView('widget-a').entries[1]
    A.Equal(e.row,3); A.Equal(e.column,6); A.True(e.hiddenInGrids); A.Equal(e.minor.kind,'finite'); A.Equal(e.major.kind,'finite')
    app.editor:Open(); A.True(app.editor:Apply({type='hidden.add',selector={kind='family',id='berserk',level='pair'}})); A.True(app.editor:Save()); c.flush()
    A.Equal(#app.runtime:GetView('a').entries,0); A.Equal(#app.runtime:GetView('b').entries,0)
    A.True(app.runtime:GetView('widget-a').entries[1].active)
    c.api.buffs.player={}; app.sources:Refresh(); c.flush(); e=app.runtime:GetView('widget-a').entries[1]
    A.False(e.active); A.Equal(e.minor.kind,'missing'); A.Equal(e.major.kind,'missing'); A.Equal(e.row,3); A.Equal(e.column,6)
    A.Equal(app.storage:Load().widgets[1].slots[3][6].level,'pair'); app:Dispose()
end
Tests.native_edit_then_custom_edit_uses_same_coordinates=function()
    for _,mode in ipairs({'over','under','right','list'}) do
        local p=F.Profile(); p.widgets[1].style.mode=mode; p.widgets[1].anchor.pointX=0.5; p.widgets[1].anchor.pointY=0.5
        local c=setup(p,nil,{player={buff(100)}}); local app=c.app; local h=app.nativeHud
        c.api.hudEditorScene:Fire('StateChange','hidden','showing'); A.True(h:IsEditing()); A.False(app.editor:Open())
        local record=h.records['widget-a']; record.control:SetAnchor('tl',c.api.controls.GuiRoot,'tl',420,310)
        c.api.hudManager:Fire('OffsetsChanged',record.element); c.flush()
        c.api.hudEditorScene:Fire('StateChange','shown','hidden'); A.False(h:IsEditing())
        local before=app.runtime:GetView('widget-a'); A.Equal(before.layout.rect.x,420); A.Equal(before.layout.rect.y,310)
        A.True(app.editor:Open()); c.flush(); local overlay=app.editor:GetOverlay('widget-a')
        equalRect(overlay.rect,before.layout.rect)
        for i,placement in ipairs(before.layout.placements) do equalRect(overlay.placements[i].rect,placement.rect) end
        A.False(app.session:IsDirty()); A.True(app.editor:Save()); c.flush()
        equalRect(app.runtime:GetView('widget-a').layout.rect,before.layout.rect)
        A.True(app.editor:Open()); c.flush(); app.editor:Cancel(); c.flush()
        equalRect(app.runtime:GetView('widget-a').layout.rect,before.layout.rect); app:Dispose()
    end
end
Tests.missing_panel_reference_remains_saved_and_visible_after_reload=function()
    local p=F.Profile(); p.widgets[1].type='grid'; p.widgets[1].rules.expression='on_panel("Absent")'
    local c=setup(p); local app=c.app; local id=p.widgets[1].id
    A.Equal(#app.runtime:GetView(id).ruleDiagnostics,1)
    app.session:Begin(); A.True(app.session:Apply({type='widget.patch',widgetId=id,patch={name='Changed'}})); A.True(app.session:Save())
    A.Equal(c.leaf().profile.widgets[1].rules.expression,'on_panel("Absent")')
    local saved=copy(c.api.raw); app:Dispose()
    local restored=setup(p,saved); A.Equal(restored.app.runtime:GetView(id).widget.name,'Changed')
    A.Equal(#restored.app.runtime:GetView(id).ruleDiagnostics,1)
    local warning=restored.app.runtime.deps.renderer.widgets[id].warning
    A.False(warning:IsControlHidden()); warning.handlers.OnMouseUp(warning,1,true)
    A.True(restored.app.editor:IsOpen()); A.Equal(restored.app.editor.selected,id); A.Equal(restored.app.editor.inspector.tab,'effects')
    restored.app:Dispose()
end
Tests.saved_old_panel_call_loads_as_positive_on_panel_without_losing_profile=function()
    local p=F.Profile(); p.widgets[1].type='grid'; p.widgets[1].rules.expression='not_on_panel("Support")'
    p.widgets[2]=F.Widget('support'); p.widgets[2].name='Support'; p.widgets[2].type='grid'; p.widgets[2].rules.expression='true'
    local c=setup(p,nil,{player={buff(100)}}); local app=c.app; local id=p.widgets[1].id
    local view=app.runtime:GetView(id); A.Equal(view.widget.rules.expression,'on_panel("Support")'); A.Equal(#view.entries,1)
    A.Equal(c.leaf().profile.widgets[1].rules.expression,'not_on_panel("Support")','loading does not rewrite raw SavedVariables')
    app.session:Begin(); A.True(app.session:Save()); A.Equal(c.leaf().profile.widgets[1].rules.expression,'on_panel("Support")')
    local saved=copy(c.api.raw); app:Dispose()
    local restored=setup(p,saved,{player={buff(100)}}); A.Equal(restored.app.runtime:GetView(id).widget.rules.expression,'on_panel("Support")')
    A.Equal(#restored.app.runtime:GetView(id).entries,1); restored.app:Dispose()
end
