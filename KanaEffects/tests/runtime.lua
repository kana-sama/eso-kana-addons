for _,path in ipairs({'integration/EsoApi.lua','dev/ApiProbe.lua','dev/Diagnostics.lua','dev/Replay.lua','localization/en.lua','localization/ru.lua','catalog/data/Families.lua','catalog/data/Categories.lua','catalog/Selectors.lua','catalog/Catalog.lua','model/Schema.lua','effects/History.lua','effects/Store.lua','effects/Sources.lua','rules/Rules.lua','widgets/Projector.lua','widgets/Layout.lua','integration/Anchors.lua','integration/TargetView.lua','integration/NativeHUD.lua','ui/Tooltip.lua','ui/Timers.lua','ui/Controls.lua','ui/FontMetrics.lua','ui/Renderer.lua','Runtime.lua','editor/Storage.lua','editor/Session.lua','editor/Demo.lua','editor/Picker.lua','editor/HiddenList.lua','editor/Inspector.lua','editor/SetEditor.lua','editor/Editor.lua','editor/Gestures.lua'}) do
    local file=io.open(TEST_ROOT..'/'..path,'r'); if file then file:close(); dofile(TEST_ROOT..'/'..path) end
end
local A,F=TestSupport.Assert,TestSupport.Fixtures
Tests.runtime_coalesces_artificial_effect_deltas_separately_from_abilities=function()
    local runtime=KanaEffects.Runtime.New({})
    runtime._Schedule=function() end
    runtime:_Change({artificialEffects={[17]=true},abilities={[17]=true},units={player=true}})
    runtime:_Change({artificialEffects={[18]=true},units={player=true}})
    A.True(runtime.change.artificialEffects[17]); A.True(runtime.change.artificialEffects[18])
    A.True(runtime.change.abilities[17]); A.Equal(runtime.change.abilities[18],nil)
end
dofile(TEST_ROOT..'/catalog/data/Presets.lua')
local function setup(profile)
    assert(KanaEffects.Runtime and KanaEffects.Runtime.New,'missing Runtime.New')
    local clock=TestSupport.FakeClock.New(10); local api=TestSupport.FakeApi.New(clock)
    local native=TestSupport.NativeRecording.New()
    api.controls=native.controls; api.fonts=native.fonts; api.CreateFont=native.CreateFont; api.GetStringWidthScaled=native.GetStringWidthScaled; api.GetUIGlobalScale=native.GetUIGlobalScale
    for k,v in pairs(native.constants) do api.constants[k]=v end
    api.constants.EVENT_EFFECT_CHANGED=1; api.constants.REGISTER_FILTER_UNIT_TAG=2; api.constants.EVENT_RETICLE_TARGET_CHANGED=3
    api.constants.EVENT_BOSSES_CHANGED=4; api.constants.EFFECT_RESULT_GAINED=5; api.constants.EFFECT_RESULT_UPDATED=6
    api.constants.BUFF_EFFECT_TYPE_BUFF=7; api.constants.EVENT_SCREEN_RESIZED=8
    api.GetAPIVersion=function() return 101051 end
    api.DoesAbilityExist=function() return true end; api.GetAbilityName=function(id) return 'Native '..id end
    api.GetAbilityIcon=function(id) return id..'.dds' end
    api.scans={}; api.GetNumBuffs=function(tag) api.scans[tag]=(api.scans[tag] or 0)+1; return #(api.buffs[tag] or {}) end
    api.units.player={name='Player'}; api.units.reticleover={name='Enemy'}; api.units.boss2={name='Boss'}
    local root=api.controls.CreateTopLevelWindow('runtime-test')
    local store=KanaEffects.Store.New(); local catalog=KanaEffects.Catalog.New(api)
    local history=KanaEffects.History.New(1000,api.NormalizeName); local sources=KanaEffects.Sources.New(api,catalog,store,history)
    local controls=KanaEffects.Controls.New(api); local metrics=KanaEffects.FontMetrics.New(controls)
    local timers=KanaEffects.Timers.New(clock); local renderer=KanaEffects.Renderer.New(root,controls,timers)
    local queue={}; local stats={build=0,place=0,measure=0}
    local deps={schema=KanaEffects.Schema,catalog=catalog,store=store,sources=sources,rules=KanaEffects.Rules,
        projector={BuildWidget=function(...) stats.build=stats.build+1; return KanaEffects.Projector.BuildWidget(...) end,AffectedWidgets=KanaEffects.Projector.AffectedWidgets},
        layout={Measure=function(...) stats.measure=stats.measure+1; return KanaEffects.Layout.Measure(...) end,Place=function(...) stats.place=stats.place+1; return KanaEffects.Layout.Place(...) end},
        renderer=renderer,fontMetrics=metrics,anchors=KanaEffects.Anchors.New(api),clock=clock,
        historyUnitTags={player=true,reticleover=true,boss1=true,boss2=true},defer=function(fn)
            local item={fn=fn}; queue[#queue+1]=item; return function() item.cancelled=true end
        end}
    local rt=KanaEffects.Runtime.New(deps)
    local function flush() local old=queue; queue={}; for _,item in ipairs(old) do if not item.cancelled then item.fn() end end end
    local function pending() local n=0; for _,item in ipairs(queue) do if not item.cancelled then n=n+1 end end; return n end
    return {rt=rt,api=api,clock=clock,store=store,history=history,root=root,renderer=renderer,timers=timers,
        native=native,flush=flush,pending=pending,stats=stats,profile=profile or F.Profile()}
end
local function buff(id,ending) return {'Aura',10,ending or 70,1,1,id..'.dds','',7,0,0,id,false,true} end
Tests.grid_resize_preview_rebuilds_changed_capacity_and_reuses_identical_capacity=function()
    local p=F.Profile(); p.widgets[1].type='grid'; p.widgets[1].layout.count=2
    local c=setup(p); c.rt:Start(p); c.flush(); c.rt:Preview(p); c.flush()
    local w=p.widgets[1]
    local preview={kind='resize',widgetId=w.id,rows=w.layout.rows,columns=w.layout.columns,
        patch={layout={count=3},anchor={x=w.anchor.x,y=w.anchor.y}}}
    local temporary=c.rt:SetGesturePreview(preview); A.Equal(temporary.widget.layout.count,3)
    local places=c.stats.place; c.rt:SetGesturePreview(preview); A.Equal(c.stats.place,places)
    preview.patch.layout.count=4; temporary=c.rt:SetGesturePreview(preview)
    A.Equal(temporary.widget.layout.count,4); A.Equal(c.stats.place,places+1)
    c.rt:SetGesturePreview(nil); A.Equal(c.rt:GetView(w.id).widget.layout.count,2)
end
Tests.resize_gesture_renders_before_commit_without_reprojection_and_restores_canonical_geometry=function()
    local c=setup(); c.rt:Start(c.profile); c.flush(); c.rt:Preview(c.profile); c.flush(); c.rt:SetEditorOverlay('widget-a',true)
    local before=c.rt:GetView('widget-a'); local builds,measures,places=c.stats.build,c.stats.measure,c.stats.place
    local preview={kind='resize',widgetId='widget-a',columns=1,rows=1,patch={layout={columns=1,rows=1},anchor={x=20,y=40}}}
    local temporary=c.rt:SetGesturePreview(preview)
    A.Equal(temporary.widget.layout.columns,1); A.Equal(c.rt:GetView('widget-a').widget.layout.columns,6)
    A.Equal(c.renderer.widgets['widget-a'].layout.rect.width,before.layout.measurement.cellWidth)
    A.Equal(c.stats.build,builds); A.Equal(c.stats.measure,measures); A.Equal(c.stats.place,places+1)
    c.rt:SetGesturePreview(preview); A.Equal(c.stats.place,places+1,'same snapped size reuses layout')
    preview.columns=7; preview.rows=4; preview.patch.layout={columns=7,rows=4}; c.rt:SetGesturePreview(preview)
    local visible=0; for _ in pairs(c.renderer.widgets['widget-a'].cells) do visible=visible+1 end; A.Equal(visible,2,'expansion recovers retained assignments')
    c.rt:SetGesturePreview(nil); A.Equal(c.renderer.widgets['widget-a'].layout.rect.width,before.layout.rect.width)
    A.Equal(c.renderer.widgets['widget-a'].layout.rect.height,before.layout.rect.height); A.Equal(c.stats.build,builds)
end
Tests.live_observations_during_resize_keep_temporary_geometry_and_cancel_uses_latest_entries=function()
    local c=setup(); c.rt:Start(c.profile); c.flush(); c.rt:Preview(c.profile); c.flush()
    local preview={kind='resize',widgetId='widget-a',columns=1,rows=1,patch={layout={columns=1,rows=1},anchor={x=20,y=40}}}
    c.rt:SetGesturePreview(preview); c.store:Upsert(F.Observation(100,{synthetic=false,endTime=95})); c.flush()
    A.Equal(c.renderer.widgets['widget-a'].layout.rect.width,c.rt:GetView('widget-a').layout.measurement.cellWidth)
    c.rt:SetGesturePreview(nil)
    A.Equal(c.renderer.widgets['widget-a'].layout.rect.width,c.rt:GetView('widget-a').layout.rect.width)
    A.Equal(c.rt:GetView('widget-a').entries[1].single.endTime,95)
    for _,cell in pairs(c.renderer.widgets['widget-a'].cells) do if cell.currentEntry.row==1 then A.True(cell.currentEntry.active) end end
end
Tests.offscreen_move_materializes_newly_visible_slots_only_at_cell_range_changes=function()
    local p=F.Profile(); p.widgets[1].anchor.x=-400; p.widgets[1].layout.columns=1000
    local c=setup(p); c.rt:Start(p); c.flush(); c.rt:Preview(p); c.flush()
    local function source() for _,cell in pairs(c.renderer.widgets['widget-a'].cells) do if cell.currentEntry.row==1 then return cell end end end
    A.Equal(source(),nil); local builds,measures=c.stats.build,c.stats.measure
    local preview={kind='move',widgetId='widget-a',dx=450,dy=0,patch={anchor={x=50,y=40}}}
    c.rt:SetGesturePreview(preview); assert(source(),'offscreen assignment must appear while moving into viewport'); A.Equal(source().root.anchor.x,50)
    local places=c.stats.place; preview.dx=451; preview.patch.anchor.x=51; c.rt:SetGesturePreview(preview)
    A.Equal(source().root.anchor.x,51); A.Equal(c.stats.place,places,'unchanged visible cell range translates existing roots')
    A.Equal(c.stats.build,builds); A.Equal(c.stats.measure,measures)
    c.store:Upsert(F.Observation(100,{synthetic=false,endTime=98})); c.flush(); A.Equal(source().root.anchor.x,51); A.True(source().currentEntry.active)
    c.rt:SetGesturePreview(nil); A.Equal(source(),nil); A.Equal(c.rt:GetView('widget-a').layout.rect.x,-400)
end
Tests.centered_partial_grid_line_materializes_at_its_own_move_clip_boundary=function()
    local p=F.Profile(); p.widgets[1].type='grid'; p.widgets[1].layout.count=3; p.widgets[1].layout.align='center'; p.widgets[1].anchor.x=0
    p.sets={{id='all',name='All',predicate={op='and',args={}},includeSets={},excludeSets={}}}; p.widgets[1].rules.includeSets={'all'}
    local c=setup(p); c.rt:Start(p); c.flush()
    for i=1,5 do c.store:Upsert(F.Observation(100+i,{key='grid:'..i,effectSlot=i,synthetic=false})) end; c.flush()
    local m=c.rt:GetView('widget-a').layout.measurement; p.widgets[1].anchor.x=-m.cellWidth-(m.cellWidth+p.widgets[1].layout.gap)/2-1
    c.rt:ApplyConfig(p); c.flush(); c.rt:Preview(p); c.flush()
    local canonical=c.rt:GetView('widget-a'); A.Equal(#canonical.entries,5); local key=canonical.entries[4].key
    local preview={kind='move',widgetId='widget-a',dx=0,dy=0}; c.rt:SetGesturePreview(preview)
    A.Equal(c.renderer.widgets['widget-a'].cells[key],nil)
    preview.dx=2; c.rt:SetGesturePreview(preview)
    local cell=c.renderer.widgets['widget-a'].cells[key]; assert(cell,'centered partial cell enters between uniform-grid clipping boundaries')
    A.Equal(cell.root.anchor.x,-m.cellWidth+1); A.Equal(c.rt:GetView('widget-a').layout.rect.x,canonical.layout.rect.x)
    c.rt:SetGesturePreview(nil); A.Equal(c.renderer.widgets['widget-a'].cells[key],nil)
end
Tests.startup_scans_once_per_unit_not_widget=function()
    local p=F.Profile(); for i=2,10 do p.widgets[i]=F.Widget('widget-'..i) end
    local c=setup(p); c.api.buffs.boss2={buff(61693)}; c.rt:Start(p); c.flush()
    A.Equal(c.api.scans.player,1); A.Equal(c.api.scans.reticleover,1); A.Equal(c.api.scans.boss2,1); A.Equal(c.api.scans.boss1,nil)
    A.Equal(#c.store:ReadUnit('boss2'),1); local items,total=c.history:Query('',{},0,100); A.Equal(total,1)
    A.Equal(items[1].abilityIds[1],61693); A.Equal(c.stats.build,10); A.Equal(c.stats.measure,1)
    c.rt:ApplyConfig(p); c.flush(); A.Equal(c.api.scans.player,1)
end
Tests.burst_events_coalesce_one_flush=function()
    local c=setup(); c.rt:Start(c.profile); c.flush(); local builds=c.stats.build; local measures=c.stats.measure
    for i=1,50 do c.store:Upsert(F.Observation(100,{synthetic=false,endTime=80+i})) end
    A.Equal(c.pending(),1); A.Equal(c.stats.build,builds); c.flush(); A.Equal(c.stats.build,builds+1)
    A.Equal(c.stats.measure,measures); A.Equal(c.rt:GetView('widget-a').entries[1].single.endTime,130)
    local places=c.stats.place; c.store:Upsert(F.Observation(100,{synthetic=false,endTime=150})); c.flush(); A.Equal(c.stats.place,places)
end
Tests.expiry_cannot_leave_stale_active_icon=function()
    local c=setup(); c.api.buffs.player={buff(100,12)}; c.rt:Start(c.profile); c.flush()
    A.True(c.rt:GetView('widget-a').entries[1].active)
    c.clock:Set(13); local callbacks={}; for _,job in pairs(c.api.updates) do callbacks[#callbacks+1]=job.callback end
    for _,fn in ipairs(callbacks) do fn() end; c.flush()
    A.False(c.rt:GetView('widget-a').entries[1].active); A.Equal(c.rt:GetView('widget-a').entries[1].single.kind,'missing')
    A.Equal(#c.store:ReadUnit('player'),1); A.Equal(next(c.api.updates),nil)
end
Tests.hidden_scene_does_not_reappear_when_root_shown=function()
    local c=setup(); c.api.buffs.player={buff(100)}; c.rt:Start(c.profile); c.flush(); c.rt:SetVisible(false)
    c.root:SetHidden(true); c.root:SetHidden(false); A.True(c.renderer.content:IsControlHidden()); A.Equal(next(c.api.updates),nil)
    c.rt:SetVisible(true); c.flush(); A.False(c.renderer.content:IsControlHidden()); assert(next(c.api.updates))
end
Tests.empty_hud_no_periodic_catalog_scan=function()
    local p=F.Profile(); p.widgets={}; local c=setup(p); c.rt:Start(p); c.flush()
    A.Equal(next(c.api.updates),nil); A.Equal(c.pending(),0); A.Equal(c.stats.measure,0)
    c.clock:Set(999); c.flush(); A.Equal(c.api.scans.player,1); A.Equal(c.stats.build,0)
end
Tests.identity_marker_survives_batched_nonempty_membership=function()
    local p=F.Profile(); p.widgets[1].unitTag='reticleover'; local c=setup(p); c.rt:Start(p); c.flush()
    c.store:ReplaceUnit({tag='reticleover',generation=2,name='Next'},{F.Observation(999,{unit={tag='reticleover',generation=2,name='Next'}})})
    c.store:Upsert(F.Observation(100,{synthetic=false})); c.flush()
    A.Equal(c.rt:GetView('widget-a').entries[1].unit.generation,2); A.Equal(c.rt:GetView('widget-a').entries[1].unit.name,'Next')
end
Tests.anchor_change_invalidates_measurement_once_per_shared_style=function()
    local p=F.Profile(); p.widgets[2]=F.Widget('other'); local c=setup(p); c.rt:Start(p); c.flush()
    A.Equal(c.stats.measure,1); c.api:Emit(8); c.flush(); A.Equal(c.stats.measure,2)
end
Tests.preview_end_restores_live_provider_and_clears_overlay=function()
    local c=setup(); c.rt:Start(c.profile); c.flush(); local demo=KanaEffects.Store.New()
    demo:Upsert(F.Observation(100)); c.rt:Preview(c.profile,demo); c.flush(); c.rt:SetEditorOverlay('widget-a',false)
    A.True(c.rt:GetView('widget-a').entries[1].active); A.Equal(c.rt:GetView('widget-a').editorOverlay,false)
    demo:Upsert(F.Observation(100,{endTime=120})); c.flush(); A.Equal(c.rt:GetView('widget-a').entries[1].single.endTime,120)
    c.rt:EndPreview(); c.flush(); A.False(c.rt:GetView('widget-a').entries[1].active); A.Equal(c.rt:GetView('widget-a').editorOverlay,nil)
    demo:Upsert(F.Observation(100,{endTime=140})); A.Equal(c.pending(),0)
end
Tests.view_snapshots_do_not_allow_mutation_and_removed_widgets_notify_once=function()
    local c=setup(); local events={}; c.rt:SubscribeViews(function(id,v) events[#events+1]={id=id,view=v}; if v then v.widget.name='corrupted' end end)
    c.rt:Start(c.profile); c.flush(); local v=c.rt:GetView('widget-a'); v.widget.name='external'; v.layout.rect.x=999
    A.Equal(c.rt:GetView('widget-a').widget.name,'Effects'); A.Equal(c.rt:GetView('widget-a').layout.rect.x,20)
    local p=F.Profile(); p.widgets={}; c.rt:ApplyConfig(p); c.flush(); A.Equal(#events,2); A.Equal(events[2].id,'widget-a'); A.Equal(events[2].view,nil)
end
Tests.invalid_configuration_keeps_previous_view_and_dispose_rejects_queued_work=function()
    local c=setup(); c.rt:Start(c.profile); c.flush(); local p=F.Profile(); p.longThreshold=-1
    local ok,diagnostics=c.rt:ApplyConfig(p); A.False(ok); assert(#diagnostics>0); A.Equal(c.pending(),0)
    c.store:Upsert(F.Observation(100)); c.rt:Dispose(); c.flush(); A.Equal(c.rt:GetView('widget-a'),nil); A.Equal(next(c.api.updates),nil)
    for _,ev in pairs(c.api.events) do A.Equal(next(ev),nil) end
end
local function bootstrapApi()
    local c=setup(); local api=c.api; c.rt:Dispose(); c.timers:Dispose()
    api.constants.EVENT_ADD_ON_LOADED=91; api.constants.EVENT_ADD_ONS_LOADED=94; api.constants.EVENT_PLAYER_ACTIVATED=92
    api.constants.BOSS_RANK_ITERATION_BEGIN=1; api.constants.BOSS_RANK_ITERATION_END=2
    api.scenes={}; for _,name in ipairs({'hud','hudui'}) do
        local scene={fragments={}}; api.scenes[name]=scene
        function scene:AddFragment(fragment) self.fragments[fragment]=true; fragment.control:SetHidden(false) end
        function scene:RemoveFragment(fragment) self.fragments[fragment]=nil; fragment.control:SetHidden(true) end
    end
    api.sceneFragmentClass={New=function(_,control) return {control=control} end}
    api.slashCommands={}; api.messages={}; api.LocalMessage=function(message) api.messages[#api.messages+1]=message end
    api.raw={}; api.GetWorldName=function() return 'EU Megaserver' end
    api.GetCurrentCharacterId=function() return '42' end; api.GetDisplayName=function() return '@Kana' end
    api.GetSettingsTable=function() return api.raw end; api.SetSettingsTable=function(value) api.raw=value end
    api.savedVars={NewCharacterIdSettings=function(_,root,version,namespace,defaults,world)
        api.opens=(api.opens or 0)+1
        local leaf=root[world]['@Kana']['42']; if leaf.version==nil or leaf.version<version then for k in pairs(leaf) do leaf[k]=nil end end
        leaf.version=version
        return setmetatable({default=defaults},{__index=leaf,__newindex=function(_,k,v)
            if k=='history' then api.historyWrites=(api.historyWrites or 0)+1 end
            leaf[k]=v
        end})
    end}
    local savedBuild=KanaEffects.EsoApi.Build; KanaEffects.EsoApi.Build=function() return api end
    dofile(TEST_ROOT..'/Bootstrap.lua'); KanaEffects.EsoApi.Build=savedBuild
    local function frame()
        local pending={}; for id,job in pairs(api.updates) do pending[#pending+1]={id=id,job=job} end
        for _,item in ipairs(pending) do if api.updates[item.id]==item.job then item.job.callback() end end
    end
    return api,frame
end
Tests.bootstrap_waits_for_player_activation_and_reconciles_next_zone=function()
    local api,frame=bootstrapApi(); api.units.player=nil; api.buffs.player={buff(61693,70)}
    api:Emit(91,'KanaEffects'); A.Equal(KanaEffects.application,nil); A.Equal(api.scans.player,nil)
    api.units.player={name='Player'}; api:Emit(92); frame(); assert(KanaEffects.application)
    local app=KanaEffects.application; A.Equal(api.scans.player,1); A.Equal(#app.store:ReadUnit('player'),1)
    A.Equal(app.runtime:GetView('player-pairs'),nil)
    local oldTarget=app.store:Snapshot('reticleover',10).unit.generation
    api.buffs.player={}; api:Emit(92); frame(); A.Equal(api.scans.player,2)
    A.Equal(#app.store:ReadUnit('player'),0)
    A.True(app.store:Snapshot('reticleover',10).unit.generation>oldTarget)
    app:Dispose(); A.Equal(KanaEffects.application,nil); A.Equal(next(api.updates),nil)
    for _,scene in pairs(api.scenes) do A.Equal(next(scene.fragments),nil) end
    for _,events in pairs(api.events) do A.Equal(next(events),nil) end
end
Tests.bootstrap_preset_defaults_use_shared_catalog_before_sources_start=function()
    local api,frame=bootstrapApi(); local original=KanaEffects.Presets.Build; local seen,seenMetrics={},{}
    local createFont=api.CreateFont; local fontCreates=0
    api.CreateFont=function(...) fontCreates=fontCreates+1; return createFont(...) end
    KanaEffects.Presets.Build=function(catalog,viewport,fontMetrics)
        seen[#seen+1]=catalog; A.Equal(viewport.width,(api.controls.GuiRoot:GetDimensions()))
        seenMetrics[#seenMetrics+1]=fontMetrics
        return original(catalog,viewport,fontMetrics)
    end
    api:Emit(91,'KanaEffects'); A.True(#seen>0); A.Equal(api.scans.player,nil)
    api:Emit(92); frame(); local app=assert(KanaEffects.application)
    for _,catalog in ipairs(seen) do A.Equal(catalog,app.catalog) end
    A.Equal(#app.storage:Load().widgets,4); assert(app.runtime:GetView('named-widget'))
    A.True(#seenMetrics>1); for _,fontMetrics in ipairs(seenMetrics) do A.Equal(fontMetrics,app.fontMetrics) end
    A.Equal(fontCreates,1) -- repeated defaults and live renderer reuse one font owner
    A.Equal(app.runtime:GetView('named-widget').widget.style.iconSize,36)
    KanaEffects.Presets.Build=original; app:Dispose()
end
Tests.bootstrap_valid_saved_profile_bypasses_defaults_and_preserves_styles=function()
    local api,frame=bootstrapApi(); local p=F.Profile(); p.widgets[1].style.mode='right'; p.widgets[1].style.iconSize=57
    p.widgets[1].anchor.relativeTo='actionBar'; p.widgets[1].anchor.y=-73
    api.raw={['EU Megaserver']={['@Kana']={['42']={version=1,profile=p,history={}}}}}
    local original=KanaEffects.Presets.Build; local calls=0
    local originalControls=KanaEffects.Controls.New; local adapters=0
    KanaEffects.Controls.New=function(...) adapters=adapters+1; return originalControls(...) end
    KanaEffects.Presets.Build=function(...) calls=calls+1; return original(...) end
    api:Emit(91,'KanaEffects'); A.Equal(adapters,0)
    api:Emit(92); frame(); local app=assert(KanaEffects.application); A.Equal(adapters,1)
    A.Equal(calls,0); A.Equal(#app.storage:Load().widgets,1)
    local w=app.runtime:GetView('widget-a').widget
    A.Equal(w.style.mode,'right'); A.Equal(w.style.iconSize,57); A.Equal(w.slots[1][1].id,100)
    A.Equal(w.anchor.y,-73); A.Equal(w.anchor.relativeTo,'actionBar')
    KanaEffects.Presets.Build=original; KanaEffects.Controls.New=originalControls; app:Dispose()
end
Tests.bootstrap_disposes_untransferred_presentation_once_before_activation=function()
    local api=bootstrapApi(); local original=KanaEffects.Presets.Build; local measured
    KanaEffects.Presets.Build=function(c,v,m) measured=m; return original(c,v,m) end
    api:Emit(91,'KanaEffects'); KanaEffects.Presets.Build=original
    assert(measured,'missing owned defaults metrics')
    local controls=measured.controls; local metricDispose,controlDispose=measured.Dispose,controls.Dispose
    local metricCalls,controlCalls=0,0
    measured.Dispose=function(self) metricCalls=metricCalls+1; return metricDispose(self) end
    controls.Dispose=function(self) controlCalls=controlCalls+1; return controlDispose(self) end
    KanaEffects.Bootstrap.Dispose(); KanaEffects.Bootstrap.Dispose()
    A.Equal(metricCalls,1); A.Equal(controlCalls,1); A.True(measured.disposed); A.True(controls.disposed)
    api:Emit(92); A.Equal(KanaEffects.application,nil)
end
Tests.bootstrap_transferred_presentation_keeps_application_disposal_owner=function()
    local api,frame=bootstrapApi(); api:Emit(91,'KanaEffects'); api:Emit(92); frame()
    local app=assert(KanaEffects.application); local measured=app.fontMetrics; local controls=measured.controls
    local metricDispose,controlDispose=measured.Dispose,controls.Dispose; local metricCalls,controlCalls=0,0
    measured.Dispose=function(self) metricCalls=metricCalls+1; return metricDispose(self) end
    controls.Dispose=function(self) controlCalls=controlCalls+1; return controlDispose(self) end
    KanaEffects.Bootstrap.Dispose(); KanaEffects.Bootstrap.Dispose()
    A.Equal(metricCalls,0); A.Equal(controlCalls,0); assert(app.runtime:GetView('named-widget'))
    app:Dispose(); app:Dispose(); A.Equal(metricCalls,1); A.Equal(controlCalls,1)
end
Tests.bootstrap_slash_commands_are_local_opt_in_and_dispose_owned_callbacks=function()
    local api,frame=bootstrapApi(); api:Emit(91,'KanaEffects'); api:Emit(92); frame(); local app=KanaEffects.application
    A.Equal(KanaEffects.ApiProbe.LastReport,nil); api.slashCommands['/ke'](); assert(app.editor,'missing composed editor'); A.True(app.editor:IsOpen()); A.Equal(#api.messages,0)
    api.slashCommands['/keprobe'](); assert(KanaEffects.ApiProbe.LastReport); A.Equal(#KanaEffects.ApiProbe.LastReport.samples,1)
    local command=api.slashCommands['/ke']; app:Dispose(); A.Equal(api.slashCommands['/ke'],nil); A.Equal(api.slashCommands['/keprobe'],nil)
    command(); A.Equal(#api.messages,1); KanaEffects.ApiProbe.LastReport=nil
end
Tests.retired_view_callback_dispose_cannot_restart_sources_or_schedule_work=function()
    local c=setup(); c.rt:Start(c.profile); c.flush()
    c.rt:SubscribeViews(function(_,view) if not view then c.rt:Dispose() end end)
    local p=F.Profile(); p.widgets={}; c.rt:ApplyConfig(p); c.flush()
    A.Equal(next(c.api.updates),nil); A.Equal(c.pending(),0)
    for _,events in pairs(c.api.events) do A.Equal(next(events),nil) end
end
Tests.probe_command_uses_history_tags_as_dense_unit_list=function()
    local api,frame=bootstrapApi(); api:Emit(91,'KanaEffects'); api:Emit(92); frame(); api.slashCommands['/keprobe']()
    local sample=KanaEffects.ApiProbe.LastReport.samples[1]
    assert(sample.units.player,'probe missed player'); assert(sample.units.boss2,'probe missed verified boss range')
    A.Equal(sample.units.boss3,nil); KanaEffects.application:Dispose(); KanaEffects.ApiProbe.LastReport=nil
end
Tests.configuration_waiting_for_flush_keeps_complete_last_rendered_view=function()
    local c=setup(); c.rt:Start(c.profile); c.flush(); local p=F.Profile(); p.widgets[1].anchor.x=100
    c.rt:ApplyConfig(p); local before=c.rt:GetView('widget-a')
    assert(before.layout,'last rendered LayoutResult was removed before flush'); A.Equal(before.layout.rect.x,20); A.Equal(before.widget.anchor.x,20)
    c.flush(); A.Equal(c.rt:GetView('widget-a').layout.rect.x,100)
    c.api:Emit(8); assert(c.rt:GetView('widget-a').layout); c.flush()
end
Tests.bootstrap_initializes_storage_at_load_and_reuses_session_after_activation=function()
    local api,frame=bootstrapApi(); api:Emit(91,'KanaEffects')
    A.Equal(api.opens,1); A.Equal(KanaEffects.application,nil)
    local leaf=api.raw['EU Megaserver']['@Kana']['42']; leaf.profile=F.Profile(); api.buffs.player={buff(100,70)}
    api:Emit(92); frame(); local app=KanaEffects.application; A.Equal(api.opens,1)
    assert(app.storage); assert(app.session); A.True(app.runtime:GetView('widget-a').entries[1].active)
    local session=app.session; session:Begin(); A.True(session:Apply({type='profile.threshold',seconds=90}))
    api:Emit(92); frame(); A.Equal(app.session,session); A.Equal(session:ReadDraft().longThreshold,90); A.Equal(api.opens,1)
    A.Equal(leaf.history[1].abilityId,100); app:Dispose(); A.Equal(next(api.updates),nil)
end
Tests.session_preview_and_demo_restore_latest_live_events_after_cancel=function()
    local c=setup(); c.rt:Start(c.profile); c.flush()
    local committed=KanaEffects.Schema.CopyProfile(c.profile)
    local storage={Load=function() return KanaEffects.Schema.CopyProfile(committed),{} end,Write=function(_,p) committed=KanaEffects.Schema.CopyProfile(p); return true,{} end}
    local s=KanaEffects.Session.New(storage)
    local unsubscribe=s:Subscribe(function(draft) if draft then c.rt:Preview(draft,c.store) else c.rt:EndPreview() end end)
    s:Begin(); s:Apply({type='widget.patch',widgetId='widget-a',patch={anchor={x=99}}}); c.flush()
    local demo=KanaEffects.Store.New(); demo:Upsert(F.Observation(100,{endTime=50})); c.rt:Preview(s:ReadDraft(),demo); c.flush()
    A.Equal(c.rt:GetView('widget-a').entries[1].single.endTime,50)
    c.clock:Set(15)
    c.api:Emit(1,6,1,'Native effect','player',10,120,1,'native.dds','',7,0,0,'Player',7,100,99)
    c.flush(); local _,total=c.history:Query('',{},0,100); A.Equal(total,1)
    A.Equal(c.rt:GetView('widget-a').entries[1].single.endTime,50)
    s:Cancel(); c.flush(); A.Equal(c.rt:GetView('widget-a').entries[1].single.endTime,120)
    A.Equal(c.rt:GetView('widget-a').widget.anchor.x,20); A.Equal(c.clock:Now(),15)
    unsubscribe(); c.rt:Dispose()
end
Tests.bootstrap_persists_real_history_once_after_source_event_burst=function()
    local api,frame=bootstrapApi(); api.buffs.player={buff(100,70)}; api:Emit(91,'KanaEffects'); api:Emit(92); frame()
    local before=api.historyWrites; A.Equal(before,1)
    for i=1,50 do api:Emit(1,6,1,'Native effect','player',10,120+i,1,'native.dds','',7,0,0,'Player',7,100,99) end
    A.Equal(api.historyWrites,before); frame(); A.Equal(api.historyWrites,before+1)
    local leaf=api.raw['EU Megaserver']['@Kana']['42']; A.Equal(#leaf.history,1); A.Equal(leaf.history[1].synthetic,false)
    A.Equal(leaf.profile,nil); KanaEffects.application:Dispose(); A.Equal(next(api.updates),nil)
end
Tests.bootstrap_ignores_unrelated_addon_events_before_owned_storage_load=function()
    local api,frame=bootstrapApi(); local original=api.raw
    api:Emit(94); api:Emit(91,'OtherAddon'); api:Emit(91,'kanaeffects'); api:Emit(92); frame()
    local premature=KanaEffects.application; local opened=api.opens; local changed=next(original)~=nil
    if premature then premature:Dispose() end
    A.Equal(opened,nil); A.Equal(api.raw,original); A.False(changed); A.Equal(premature,nil)
    api:Emit(91,'KanaEffects'); A.Equal(api.opens,1); A.Equal(KanaEffects.application,nil)
    api:Emit(91,'KanaEffects'); A.Equal(api.opens,1)
    api:Emit(92); frame(); local app=KanaEffects.application; local storage,session=app.storage,app.session
    api:Emit(92); frame(); A.Equal(api.opens,1); A.Equal(app.storage,storage); A.Equal(app.session,session)
    app:Dispose(); A.Equal(next(api.updates),nil)
end

Tests.bootstrap_native_history_timestamp_is_independent_of_timer_frame_clock=function()
    local api,frame=bootstrapApi(); local stamp=123456; api.GetTimeStamp=function() return stamp end
    api.buffs.player={buff(100,70)}; api:Emit(91,'KanaEffects'); api:Emit(92); frame()
    local app=KanaEffects.application; local obs=app.store:ReadUnit('player')[1]
    A.Equal(obs.observedAt,10); A.Equal(obs.endTime,70)
    local saved=api.raw['EU Megaserver']['@Kana']['42'].history[1]
    A.Equal(saved.lastSeen,123456); A.Equal(saved.lastSeenClock,'native-timestamp-seconds')
    stamp=123455
    app.history:Observe(F.Observation(101,{synthetic=false,observedAt=11,catalog={abilityId=101,name='New effect',icon='fixture.dds',aliases={},categories={},origin='unknown',apiVersion=101051,provenance='real fixture',verified=false}}))
    A.Equal(app.history:Query('')[1].selector.id,101)
    app:Dispose()
end
Tests.bootstrap_performance_command_is_opt_in_and_restores_owned_command=function()
    local api,frame=bootstrapApi(); local previous=function() end; api.slashCommands['/keperf']=previous
    api:Emit(91,'KanaEffects'); api:Emit(92); frame(); local app=assert(KanaEffects.application)
    local command=api.slashCommands['/keperf']; assert(command and command~=previous,'missing opt-in performance slash command')
    A.Equal(app.diagnostics.capture,nil); command(); A.Equal(app.replay.active,false); A.Equal(app.runtime.preview,nil)
    A.True(string.find(api.messages[#api.messages],'unavailable',1,true)~=nil)
    A.True(app.replay:Start()); frame(); api.slashCommands['/ke'](); A.False(app.editor:IsOpen())
    command('stop'); frame(); A.Equal(app.runtime.preview,false); app:Dispose(); A.Equal(api.slashCommands['/keperf'],previous); A.Equal(next(api.updates),nil)
end
Tests.panel_reference_warning_survives_empty_preview_and_clears_after_repair=function()
    local p=F.Profile(); local w=p.widgets[1]; w.type='grid'; w.rules.expression='on_panel("Support")'
    local c=setup(p); A.True(c.rt:Start(p)); c.flush()
    local view=c.rt:GetView(w.id); A.Equal(#view.ruleDiagnostics,1); A.Equal(#view.entries,0)
    local warning=c.renderer.widgets[w.id].warning; A.False(warning:IsControlHidden())
    local unrelated=F.Widget('other'); unrelated.type='grid'; unrelated.name='Other'; unrelated.rules.expression='is_buff()'
    p.widgets[2]=unrelated; A.True(c.rt:Preview(p)); c.flush(); A.Equal(#c.rt:GetView(w.id).ruleDiagnostics,1)
    c.rt:SetGesturePreview({kind='resize',widgetId=w.id,rows=1,columns=1,patch={layout={count=2},anchor={x=30,y=40}}})
    A.False(warning:IsControlHidden()); c.rt:SetGesturePreview(nil); A.False(warning:IsControlHidden())
    p.widgets[2].name='Support'; A.True(c.rt:Preview(p)); c.flush()
    A.Equal(#c.rt:GetView(w.id).ruleDiagnostics,0); A.True(warning:IsControlHidden())
    c.rt:EndPreview(); c.flush(); A.Equal(#c.rt:GetView(w.id).ruleDiagnostics,1); A.False(warning:IsControlHidden())
    c.rt:Dispose(); A.True(warning:IsControlHidden())
end
