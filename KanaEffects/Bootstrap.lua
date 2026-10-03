-- Sole composition root. Storage opens at addon-load; HUD starts at activation.
local Bootstrap={}; KanaEffects.Bootstrap=Bootstrap
local sequence=0
function Bootstrap.DefaultProfile(catalog,viewportRect,fontMetrics)
    return KanaEffects.Presets.Build(catalog,viewportRect,fontMetrics)
end
local function historyTags(api)
    local tags={player=true,reticleover=true}
    local first,last=api.constants.BOSS_RANK_ITERATION_BEGIN,api.constants.BOSS_RANK_ITERATION_END
    local function integer(n) return type(n)=='number' and n==n and n<math.huge and n>=1 and n%1==0 end
    if integer(first) and integer(last) and last>=first then
        for rank=first,last do tags['boss'..rank]=true end
    else api.LocalMessage('KanaEffects: диапазон boss-тегов недоступен; история боссов отключена.') end
    return tags
end
function Bootstrap.Build(api,storage,catalog,presentation)
    sequence=sequence+1; local owner='KanaEffectsApplication'..sequence
    local app={api=api,owner=owner,storage=assert(storage,'Storage must initialize at addon-load')}
    app.diagnostics=KanaEffects.Diagnostics.New(api)
    app.session=KanaEffects.Session.New(storage)
    local clock={Now=function() return api.Now() end}
    app.root=api.controls.CreateTopLevelWindow(owner..'Root'); app.root:SetHidden(true)
    -- Stock subtitles also use LOW, at BACKGROUND/1. Keep the entire HUD
    -- below stock backgrounds; child drawing roles use the same negative band.
    app.root:SetDrawTier(api.constants.DT_LOW); app.root:SetDrawLayer(api.constants.DL_BACKGROUND)
    app.root:SetDrawLevel(KanaEffects.Controls.DrawLevels.root); app.root:SetAllowBringToTop(false)
    app.root:SetAnchor(api.constants.TOPLEFT,api.controls.GuiRoot,api.constants.TOPLEFT,0,0)
    local width,height=api.controls.GuiRoot:GetDimensions(); app.root:SetDimensions(width,height)
    app.fragment=api.sceneFragmentClass:New(app.root)
    catalog=catalog or KanaEffects.Catalog.New(api)
    app.store=KanaEffects.Store.New();
    app.targetView=KanaEffects.TargetView.New(app.store,clock); app.tooltip=KanaEffects.Tooltip.New(api)
    app.history=KanaEffects.History.New(1000,api.NormalizeName,api.GetTimeStamp)
    local recent,historyDiagnostics=storage:LoadHistory(); app.history:Import(recent)
    for _,diag in ipairs(historyDiagnostics) do api.LocalMessage('KanaEffects: '..diag.message) end
    app.picker=KanaEffects.Picker.New(catalog,app.history,app.store,app.session,api)
    app.hiddenList=KanaEffects.HiddenList.New(catalog,app.session,app.picker,api)
    catalog.diagnostics=app.diagnostics
    app.catalog=catalog -- Public dependency for T11 editor/demo composition.
    app.sources=KanaEffects.Sources.New(api,catalog,app.store,app.history,app.diagnostics)
    local controls=presentation and assert(presentation.controls,'Presentation requires Controls') or KanaEffects.Controls.New(api)
    app.fontMetrics=presentation and assert(presentation.fontMetrics,'Presentation requires FontMetrics') or KanaEffects.FontMetrics.New(controls)
    app.timers=KanaEffects.Timers.New(clock)
    local renderer=KanaEffects.Renderer.New(app.root,controls,app.timers,app.diagnostics)
    local anchors=KanaEffects.Anchors.New(api)
    app.nativeHud=KanaEffects.NativeHUD.New(api,anchors,app.session)
    local flushSequence=0
    local function defer(callback)
        flushSequence=flushSequence+1; local name=owner..'Flush'..flushSequence; local active=true
        api.eventManager:RegisterForUpdate(name,0,function()
            if not active or app.disposed then return end
            active=false; api.eventManager:UnregisterForUpdate(name); callback()
        end,true)
        return function() if active then active=false; api.eventManager:UnregisterForUpdate(name) end end
    end
    -- Sources observes History immediately after its Store publication. Defer the
    -- separate export until that event completes and coalesce bursts into one write.
    local historyPending
    app.unsubscribeHistory=app.store:Subscribe(function()
        if app.disposed or historyPending then return end
        historyPending=defer(function()
            historyPending=nil
            app.diagnostics:Count('history_exports')
            app.diagnostics:Count('history_export_records',app.history.size)
            local ok,diag=storage:WriteHistory(app.history:Export())
            if not ok and not app.historyWriteReported then
                app.historyWriteReported=true
                for _,issue in ipairs(diag) do api.LocalMessage('KanaEffects: '..issue.message) end
            end
        end)
    end)
    app.cancelHistory=function() if historyPending then historyPending(); historyPending=nil end end
    app.runtime=KanaEffects.Runtime.New({schema=KanaEffects.Schema,catalog=catalog,store=app.store,sources=app.sources,
        rules=KanaEffects.Rules,projector=KanaEffects.Projector,layout=KanaEffects.Layout,renderer=renderer,anchors=anchors,
        fontMetrics=app.fontMetrics,clock=clock,targetView=app.targetView,
        hoverCallbacks={onEnter=function(...) app.tooltip:Enter(...) end,onExit=function(...) app.tooltip:Exit(...) end,
            onCellContext=function(...) return app:OpenEffectContext(...) end},historyUnitTags=historyTags(api),defer=defer,diagnostics=app.diagnostics})
    app.fragmentScenes={}; for _,scene in pairs(api.scenes) do app.fragmentScenes[#app.fragmentScenes+1]=scene end
    if api.hudEditorScene then app.fragmentScenes[#app.fragmentScenes+1]=api.hudEditorScene end
    for _,scene in ipairs(app.fragmentScenes) do scene:AddFragment(app.fragment) end
    app.runtime:Start(storage:Load())
    app.editor=KanaEffects.Editor.New(app.session,app.runtime,app.picker,anchors,{api=api,store=app.store,catalog=catalog,hiddenList=app.hiddenList,clock=clock,nativeHud=app.nativeHud,
        contextItems=function(...) return app:EffectContextItems(...) end})
    function app:EffectContextItems(widgetId,entry)
        if self.disposed or not entry or not entry.selector or not self.runtime:GetView(widgetId) then return {} end
        local selector=KanaEffects.Picker.Copy(entry.selector)
        local generation=self.session.generation
        local editorGeneration=self.editor.generation
        local editing=self.editor:IsOpen()
        return {{label=self.editor.labels.contextHide,callback=function()
            if self.disposed or generation~=self.session.generation or editorGeneration~=self.editor.generation
                or editing~=self.editor:IsOpen() or not self.runtime:GetView(widgetId) then return end
            local command={type='hidden.add',selector=selector}
            if editing then self.editor:Apply(command); return end
            -- Outside the editor this one action is a complete transaction;
            -- never open, save or overwrite somebody else's existing draft.
            if self.session:ReadDraft() then return end
            self.session:Begin()
            local ok,issues=self.session:Apply(command)
            local candidate=ok and self.session:ReadDraft()
            if ok then ok,issues=self.session:Save() end
            if not ok then self.session:Cancel(); self.editor:Report(false,issues); return end
            self.runtime:ApplyConfig(candidate)
        end}}
    end
    function app:OpenEffectContext(widgetId,entry,control)
        if self.disposed or not api.ContextMenu or not self.runtime:GetView(widgetId) then return false end
        self.tooltip:Exit(nil,nil,control)
        if self.editor:IsOpen() and self.editor.OpenWidgetContext then return self.editor:OpenWidgetContext(widgetId,control,entry) end
        local generation=self.session.generation
        local editorGeneration=self.editor.generation
        local items={{label=self.editor.labels.contextEdit,callback=function()
            if self.disposed or generation~=self.session.generation or editorGeneration~=self.editor.generation
                or not self.runtime:GetView(widgetId) then return end
            if self.editor:Open() then self.editor:Select(widgetId) end
        end}}
        for _,item in ipairs(self:EffectContextItems(widgetId,entry)) do items[#items+1]=item end
        return api.ContextMenu(control,items)
    end
    app.gestures=KanaEffects.Gestures.New(app.session,app.editor,app.runtime,{Position=function()
        if api.GetUIMousePosition then return api.GetUIMousePosition() end
    end},api)
    app.nativeHud:Bind(app.runtime,app.editor,app.root); app.nativeHud:Sync(storage:Load())
    app.unsubscribeNativeComposition=app.session:Subscribe(function(draft) if not draft then app.nativeHud:Sync(storage:Load()) end end)
    app.targetCallbacks={}
    for name,scene in pairs(api.scenes) do
        if scene.RegisterCallback then
            local callback=function(_,state)
                if state==api.constants.SCENE_SHOWING then
                    if name=='hudui' then app.targetView:Capture() else app.targetView:ResumeLive() end
                end
            end
            scene:RegisterCallback('StateChange',callback); app.targetCallbacks[#app.targetCallbacks+1]={scene=scene,callback=callback}
        end
    end
    if api.constants.EVENT_PLAYER_COMBAT_STATE then api.eventManager:RegisterForEvent(owner,api.constants.EVENT_PLAYER_COMBAT_STATE,function(_,combat) if combat then app.targetView:ResumeLive() end end) end
    app.editor:SetGestureController(app.gestures); app.editor:SetCanvasHandlers(app.gestures:Handlers())
    if not catalog.versionMatches then api.LocalMessage('KanaEffects: версия API отличается от проверенного каталога 101051.') end
    local function bounds()
        local cells,free=0,#renderer.free
        for _,state in pairs(renderer.widgets) do for _ in pairs(state.cells) do cells=cells+1 end end
        local observations=0; for _,unit in pairs(app.store.units) do for _ in pairs(unit.rows) do observations=observations+1 end end
        return {controls=#controls.owned,cells=cells,pooledCells=free,timerWatches=app.timers.count,
            activeTimerJobs=app.timers.active and app.timers.count or 0,storeObservations=observations,historyRecords=app.history.size,
            catalog=catalog:GetCacheStats(),allUserAddonsMemoryMB=api.GetTotalUserAddOnMemoryPoolUsageMB and api.GetTotalUserAddOnMemoryPoolUsageMB() or nil}
    end
    app.replay=KanaEffects.Replay.New({api=api,runtime=app.runtime,diagnostics=app.diagnostics,editor=app.editor,nativeHud=app.nativeHud,bounds=bounds,isVisible=function() return not renderer.content:IsControlHidden() end})
    local function performanceSummary(report)
        if app.disposed then return end
        local result='KanaEffects: render+ingestion profiler '..report.status
        if report.status=='measured' then
            result=result..string.format('; frames %d; p50 %.3f / p95 %.3f / max %.3f ms',report.frames,report.p50MS,report.p95MS,report.maxMS)
            result=result..'; overhead included; synthetic history/export excluded; whole-addon target not assessed'
        elseif report.reason then result=result..'; '..report.reason end
        api.LocalMessage(result..'; KanaEffects.Diagnostics.LastReport')
    end
    app.commands={
        ['/ke']=function()
            if not app.disposed then
                if app.replay.active then api.LocalMessage('KanaEffects: capture active; /keperf stop restores live HUD.'); return end
                app.targetView:Capture(); app.editor:Open()
            end
        end,
        ['/keperf']=function(argument)
            if app.disposed then return end
            if argument=='stop' then app.replay:Stop('stopped by user'); return end
            local ok,reason=app.replay:Start({native=true,onComplete=performanceSummary})
            if ok then api.LocalMessage('KanaEffects: profiler capture5s; processing bounded; live HUD restores automatically.')
            else api.LocalMessage('KanaEffects: profiler unavailable; '..tostring(reason)) end
        end,
        ['/kelive']=function() if not app.disposed then app.targetView:ResumeLive() end end,
        ['/keprobe']=function()
            if app.disposed then return end
            if app.probe then app.probe:Stop() end
            local tags={}; for tag in pairs(historyTags(api)) do tags[#tags+1]=tag end; table.sort(tags)
            app.probe=KanaEffects.ApiProbe.Start(api,{unitTags=tags,maxSamples=100})
            api.LocalMessage('KanaEffects: локальная API-проба включена; отчёт KanaEffects.ApiProbe.LastReport.')
        end}
    app.previousCommands={}
    if api.slashCommands then
        for name,fn in pairs(app.commands) do app.previousCommands[name]=api.slashCommands[name]; api.slashCommands[name]=fn end
    end
    function app:Dispose()
        if self.disposed then return end; self.disposed=true
        if self.probe then self.probe:Stop() end
        self.replay:Dispose(); self.diagnostics:Dispose()
        self.nativeHud:Dispose(); self.unsubscribeNativeComposition()
        for _,c in ipairs(self.targetCallbacks) do c.scene:UnregisterCallback('StateChange',c.callback) end
        if api.constants.EVENT_PLAYER_COMBAT_STATE then api.eventManager:UnregisterForEvent(owner,api.constants.EVENT_PLAYER_COMBAT_STATE) end
        self.editor:Dispose(); self.gestures:Dispose(); self.tooltip:Dispose(); self.targetView:Dispose(); self.hiddenList:Dispose(); self.picker:Dispose()
        self.unsubscribeHistory(); self.cancelHistory(); self.session:Cancel()
        self.runtime:Dispose()
        for _,scene in ipairs(self.fragmentScenes) do scene:RemoveFragment(self.fragment) end
        self.root:SetHidden(true); self.timers:Dispose(); self.fontMetrics:Dispose()
        if api.slashCommands then for name,fn in pairs(self.commands) do
            if api.slashCommands[name]==fn then api.slashCommands[name]=self.previousCommands[name] end
        end end
        if self.disposeBootstrap then self.disposeBootstrap() end
        if KanaEffects.application==self then KanaEffects.application=nil end
    end
    return app
end
local api=KanaEffects.EsoApi.Build()
if api.eventManager and api.constants.EVENT_ADD_ON_LOADED and api.constants.EVENT_PLAYER_ACTIVATED then
    local owner='KanaEffectsBootstrap'
    local active=true
    local storage
    local presentation,transferred
    local function getPresentation()
        if not presentation then
            assert(active,'Bootstrap disposed before presentation creation')
            local controls=KanaEffects.Controls.New(api)
            presentation={controls=controls,fontMetrics=KanaEffects.FontMetrics.New(controls)}
        end
        return presentation
    end
    local function disposeBootstrap()
        if not active then return end
        active=false
        api.eventManager:UnregisterForEvent(owner,api.constants.EVENT_ADD_ON_LOADED)
        api.eventManager:UnregisterForEvent(owner,api.constants.EVENT_PLAYER_ACTIVATED)
        if presentation and not transferred then
            presentation.fontMetrics:Dispose(); presentation.controls:Dispose(); presentation=nil
        end
    end
    -- Owned registrations and pre-transfer resources only. A running app keeps
    -- its existing app:Dispose owner for Renderer/Controls and FontMetrics.
    Bootstrap.Dispose=disposeBootstrap
    api.eventManager:RegisterForEvent(owner,api.constants.EVENT_ADD_ON_LOADED,function(_,addonName)
        if not active or addonName~='KanaEffects' then return end
        api.eventManager:UnregisterForEvent(owner,api.constants.EVENT_ADD_ON_LOADED)
        -- One catalog is shared by defaults and the activation-time consumers.
        -- A valid saved profile bypasses this provider entirely in Storage.
        local catalog=KanaEffects.Catalog.New(api)
        storage=KanaEffects.Storage.New(api,function()
            local screen=api.controls.GuiRoot; local width,height=screen:GetDimensions()
            return Bootstrap.DefaultProfile(catalog,{x=screen:GetLeft(),y=screen:GetTop(),width=width,height=height},getPresentation().fontMetrics)
        end)
        local _,diagnostics=storage:Load()
        for _,diag in ipairs(diagnostics) do api.LocalMessage('KanaEffects: '..diag.message) end
        api.eventManager:RegisterForEvent(owner,api.constants.EVENT_PLAYER_ACTIVATED,function()
            if not active then return end
            if KanaEffects.application then KanaEffects.application.sources:Refresh()
            else
                local app=Bootstrap.Build(api,storage,catalog,getPresentation()); transferred=true
                app.disposeBootstrap=disposeBootstrap; KanaEffects.application=app
            end
        end)
    end)
end
