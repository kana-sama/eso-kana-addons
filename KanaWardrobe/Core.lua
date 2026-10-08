KanaWardrobe = KanaWardrobe or {}
local KW = KanaWardrobe
KW.name = "KanaWardrobe"
KW.Core = {}
KW.Strings = KW.Strings or {}

function KW.Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = KW.Copy(child) end
    return result
end

function KW.Problem(code, details) return {code=code, details=details or {}} end
function KW.Text(key) return KW.Strings[key] or key end

function KW.Core.NewEvents()
    local events = {listeners={}, nextId=0}
    function events:Subscribe(name, callback)
        self.nextId = self.nextId + 1
        local handle = {id=self.nextId, name=name, callback=callback}
        self.listeners[handle] = true
        return handle
    end
    function events:Unsubscribe(handle) self.listeners[handle] = nil end
    function events:Emit(name, payload)
        local pending = {}
        for handle in pairs(self.listeners) do
            if handle.name == name then pending[#pending+1] = handle end
        end
        table.sort(pending, function(a,b) return a.id < b.id end)
        for _, handle in ipairs(pending) do
            if self.listeners[handle] then handle.callback(payload) end
        end
    end
    return events
end

function KW.Core.NewClock(api)
    api = api or _G
    local clock = {nextId=0}
    function clock:NowMs() return api.GetFrameTimeMilliseconds() end
    function clock:Schedule(delayMs, callback)
        self.nextId = self.nextId + 1
        local handle = KW.name .. "Timer" .. tostring(self.nextId)
        api.EVENT_MANAGER:RegisterForUpdate(handle, math.max(1, delayMs), function()
            api.EVENT_MANAGER:UnregisterForUpdate(handle)
            callback()
        end)
        return handle
    end
    function clock:Cancel(handle) api.EVENT_MANAGER:UnregisterForUpdate(handle) end
    return clock
end

-- Diagnostics deliberately read state only; they never resume a session.
function KW.Core.Status(runtime)
    local view=runtime.session:GetView()
    local phase=KW.Strings["STATE_"..view.state] or view.state
    if view.paused then phase=phase.." / "..KW.Text("PAUSED") end
    local problem=KW.Dialogs.Problem(view.problem)
    return KW.name..": "..phase..(problem~="" and " / "..problem or "").." / API "..tostring(runtime.apiVersion)
end

function KW.Core.BuildCapabilitiesStatus(runtime)
    if not KW.BuildCapabilities then return KW.name..": build capabilities unavailable" end
    local c = KW.BuildCapabilities.Read(runtime.api)
    runtime.buildCapabilities = c
    local missing = {}
    for _,problem in ipairs(c.problems) do missing[#missing+1] = problem.details.name end
    return KW.name..": API "..tostring(c.apiVersion).." / skills="..tostring(c.skills)
        .." / attributes="..tostring(c.attributes)
        ..(#missing > 0 and " / missing: "..table.concat(missing, ", ") or "")
end

function KW.Core.Initialize(api)
    if KW.runtime then return KW.runtime end
    api=api or _G
    local world, account = api.GetWorldName(), api.GetDisplayName()
    local saved = api.ZO_SavedVars:NewAccountWide("KanaWardrobeSaved", 1, nil,
        {schemaVersion=1, servers={}}, world, account)
    local events = KW.Core.NewEvents()
    local function emit(name, payload) events:Emit(name, payload) end
    local runtime = {saved=saved, api=api, events=events, emit=emit, clock=KW.Core.NewClock(api),
        apiVersion=api.GetAPIVersion(), capabilities={fullBagEquipSwap=false}}
    -- Some isolated equipment consumers intentionally load Core without this module.
    if KW.BuildCapabilities then runtime.buildCapabilities = KW.BuildCapabilities.Read(api) end
    runtime.repo = KW.Presets.New(saved, world, account, api.GetCurrentCharacterId(), api.GetUnitName("player"), emit)
    runtime.inventory = KW.Inventory.New(api, emit)
    runtime.protection = KW.Protection.New(runtime.repo,runtime.inventory)
    runtime.runner = KW.EquipmentRunner.New(runtime.inventory,events,runtime.clock)
    local buildServices, displayState, invalidateActual
    if KW.SkillAdapter and KW.AttributeAdapter and KW.BuildPlanner and KW.BuildRunner and KW.BuildDraft then
        runtime.skills=KW.SkillAdapter.New(api,events,runtime.clock)
        runtime.attributes=KW.AttributeAdapter.New(api,events)
        runtime.appearance=KW.AppearanceAdapter and KW.AppearanceAdapter.New(api)
        runtime.buildPlanner=KW.BuildPlanner.New({skills=runtime.skills,attributes=runtime.attributes,appearance=runtime.appearance})
        runtime.actualRevisions={equipment=0,abilities=0,attributes=0,appearance=0}
        local function capture(scope)
            -- nil is a deliberate full QuickSave; components and plans read
            -- only their domains. Skills additionally depend on worn gear.
            local function includes(domain)
                return scope==nil or scope==domain or type(scope)=='table' and scope[domain]~=nil
            end
            local snapshot={budgets={}};local catalogue
            if includes('equipment') or includes('abilities') then
                local eq=runtime.inventory:Capture('equipment')
                snapshot.equipment=KW.Copy(eq.worn);snapshot.equipmentState=eq
            end
            if includes('abilities') then
                catalogue=runtime.skills:Catalogue()
                if catalogue.available then
                    snapshot.abilities=KW.Copy(catalogue.abilities);snapshot.budgets.skills=catalogue.budgets.skills
                    snapshot.budgets.mastery=KW.Copy(catalogue.budgets.mastery);snapshot.catalogueRevision=catalogue.revision
                elseif scope=='abilities' then return nil,nil,catalogue.problem end
            end
            if includes('attributes') then
                local attributes,budget=runtime.attributes:Capture()
                if attributes then snapshot.attributes=attributes;snapshot.budgets.attributes=budget
                elseif scope=='attributes' then return nil,nil,budget end
            end
            if includes('appearance') and runtime.appearance then
                local value,problem=runtime.appearance:Capture()
                if value then snapshot.appearance=value
                elseif scope=='appearance' or type(scope)=='table' and scope.appearance then return nil,nil,problem end
            end
            return snapshot,catalogue
        end
        -- The list is a presentation consumer, never a preflight consumer.
        -- Cache each actual domain independently; stock page transitions do
        -- not change a build. All mutation/editor services keep fresh capture.
        local display={}
        displayState=display
        local function captureDisplay()
            local revisions=runtime.actualRevisions
            if not display.equipment or display.equipmentRevision~=revisions.equipment then
                display.equipment=runtime.inventory:Capture(false)
                display.equipmentRevision=revisions.equipment
            end
            local view=runtime.session and runtime.session:GetView() or {}
            local needSkills=view.component=='abilities'
            local needAttributes=view.component=='attributes'
            local needAppearance=view.component=='appearance'
            if not view.isEditor then
                for _,preset in ipairs(runtime.repo:List())do
                    needSkills=needSkills or preset.abilities~=nil
                    needAttributes=needAttributes or preset.attributes~=nil
                    needAppearance=needAppearance or preset.appearance~=nil
                end
            end
            if needSkills and (not display.catalogue or display.skillRevision~=revisions.abilities)then
                display.catalogue=KW.SkillState.ReadDisplay(api)
                display.catalogue.revision=revisions.abilities
                display.skillRevision=revisions.abilities
            end
            if needAttributes and (not display.attributesRead or display.attributeRevision~=revisions.attributes)then
                display.attributes,display.attributeProblem=runtime.attributes:Capture()
                display.attributesRead=true;display.attributeRevision=revisions.attributes
            end
            if needAppearance and runtime.appearance and (not display.appearance or display.appearanceRevision~=revisions.appearance)then
                display.appearance=runtime.appearance:Capture();display.appearanceRevision=revisions.appearance
            end
            local eq=display.equipment
            local snapshot={equipment=eq.worn,equipmentState=eq}
            local catalogue=needSkills and display.catalogue or nil
            if catalogue and catalogue.available then snapshot.abilities=catalogue.abilities end
            if needAttributes then snapshot.attributes=display.attributes end
            if needAppearance then snapshot.appearance=display.appearance end
            return snapshot,catalogue
        end
        runtime.captureDisplay=captureDisplay
        local function checkDrafts(scope)
            if scope=="equipment" or scope=="appearance" or type(scope)=="table" and (scope.equipment or scope.appearance) and not scope.abilities and not scope.attributes then return true end
            for _,adapter in ipairs({runtime.skills,runtime.attributes})do
                local state=adapter:GetSubmissionState()
                if state.phase=="entry" or state.phase=="dispatching" or state.phase=="waiting" or state.phase=="unknown" then return nil,KW.Problem("buildSubmissionUnresolved") end
            end
            local global=api.SKILLS_AND_ACTION_BAR_MANAGER
            if global then
                if type(global.HasAnyPendingChanges)~="function" or type(global.GetSkillPointAllocationMode)~="function" then return nil,KW.Problem("buildCapabilityUnavailable") end
                if global.isDirty or KW.SkillState.HasPendingChanges(api) or global:GetSkillPointAllocationMode()~=api.SKILL_POINT_ALLOCATION_MODE_PURCHASE_ONLY then return nil,KW.Problem("foreignSkillDraft") end
            end
            for _,name in ipairs({"GetSkillRespecCastTimeRemainingMs","GetAttributeRespecCastTimeRemainingMs"})do
                if type(api[name])=="function" and api[name]()>0 then return nil,KW.Problem("buildSubmissionUnresolved") end
            end
            local lines=api.SKILL_LINE_ASSIGNMENT_MANAGER
            if lines and (type(lines.IsAnyChangePending)~="function" or lines:IsAnyChangePending())then return nil,KW.Problem("foreignSkillDraft") end
            local clean=pcall(runtime.attributes.CheckForeign,runtime.attributes,false)
            if not clean then return nil,KW.Problem("foreignAttributeDraft") end
            return true
        end
        if not KW.OperationSession then
            runtime.buildRunner=KW.BuildRunner.New(runtime.skills,runtime.attributes,runtime.runner,events,runtime.clock,
                {capture=capture,revalidateRemaining=runtime.buildPlanner.RevalidateRemaining})
        end
        buildServices={capture=capture,buildPlanner=runtime.buildPlanner,buildRunner=runtime.buildRunner,
            operations=KW.OperationSession~=nil,clock=runtime.clock,events=events,
            skills=runtime.skills,attributes=runtime.attributes,appearance=runtime.appearance,checkDrafts=checkDrafts,
            describeFailure=function(problem,op,step)
                if runtime.buildProbe then
                    runtime.buildProbe:RecordSkillBlock(problem,op.intent.kind,
                        {id=op.id,index=op.index,step=step.kind,page=op.intent.page,
                            presetName=op.intent.name,attempt=#(step.attempts or {})},true)
                end
            end,
            requestPage=function(page)
                local manager=api.SCENE_MANAGER
                local names={inventory='inventory',skills='skills',stats='stats',collectionsBook='collectionsBook'}
                if not names[page] or not manager or type(manager.Show)~='function' then return nil,KW.Problem('buildCapabilityUnavailable')end
                manager:Show(names[page]);return true -- requested; native Continue may keep the old scene
            end}
    end
    runtime.session = KW.Session.New(runtime.repo,runtime.inventory,KW.EquipmentPlan,runtime.runner,
        runtime.protection,runtime.repo.character,runtime.capabilities,emit,buildServices)
    -- Ordinary accepted transitions run before the scene refreshes fragments.
    -- This leaves native ConfirmHide and OnHidden entirely in native ownership.
    if buildServices and api.SCENE_MANAGER and type(api.SCENE_MANAGER.GetScene)=='function' then
        for _,page in ipairs({'inventory','skills','stats','collectionsBook'})do
            local scene=api.SCENE_MANAGER:GetScene(page)
            if scene and type(scene.RegisterCallback)=='function'then
                scene:RegisterCallback('StateChange',function(_,state)
                    if state==api.SCENE_SHOWING and runtime.performanceProbe then runtime.performanceProbe:Begin(page)end
                    if state==api.SCENE_HIDING then runtime.session:OnNativePageState(page,'hiding')
                    elseif state==api.SCENE_SHOWING then runtime.session:OnNativePageState(page,'showing')end
                end)
            end
        end
    end
    runtime.preview = KW.SetPreview.New()
    runtime.pages=buildServices and KW.PageAdapters and KW.PageAdapters.New(api)
    runtime.ui = KW.UI.New(runtime.repo,runtime.session,runtime.preview,runtime.inventory,
        {pages=runtime.pages,captureActual=runtime.captureDisplay,events=events,
        describeProblem=function(problem,action,args)
            if runtime.buildProbe then
                local context
                if problem.code=='skillBarOverride' then
                    local journal=runtime.session.journal
                    local id=(action=='Apply' or action=='BeginEdit') and args and args[1]
                        or action=='QuickLoad' and KW.Presets.QUICK_ID or journal and journal.presetId
                    local preset=id and runtime.repo:Get(id)
                    context={presetId=id,presetName=preset and preset.name,presetRevision=preset and preset.revision,
                        sessionState=journal and journal.state or 'idle',phase=journal and journal.phase,
                        component=journal and journal.component,kind=journal and journal.kind}
                end
                runtime.buildProbe:RecordSkillBlock(problem,action,context)
            end
        end})
    if runtime.session.operations and KW.OperationWindow then
        runtime.operationWindow=KW.OperationWindow.New(runtime.session.operations,api)
        events:Subscribe('OperationChanged',function(view)runtime.operationWindow:Refresh(view)end)
    end
    runtime.tooltips = KW.ItemTooltips.New(runtime.repo,runtime.inventory)
    runtime.filters = KW.InventoryFilters.New(runtime.repo,runtime.inventory,runtime.session,runtime.repo.character)
    if KW.BuildProbe then
        runtime.repo.character.buildProbeJournal = runtime.repo.character.buildProbeJournal or {}
        local probeStorage=runtime.repo.character.buildProbeJournal
        runtime.buildProbe = KW.BuildProbe.New(api, probeStorage, function(text)
            local reportText=text
            if KW.ProbeReport then KW.ProbeReport.Show(text,function(err)
                reportText=reportText.."\nReport display error:\n"..tostring(err)
                probeStorage.latestReport=reportText
            end)end
        end)
        runtime.buildProbe.IsSessionIdle = function()return runtime.session:GetView().state == "idle" end
    end
    KW.runtime = runtime
    local function report(problem)
        runtime.ui:Problem(problem)
    end
    runtime.protection:Attach(events,report)
    runtime.tooltips:Attach()
    events:Subscribe("InventoryChanged",function()runtime.session:CheckLateCompletion()end)
    for _,name in ipairs({"InventoryChanged","PresetsChanged"})do
        events:Subscribe(name,function()runtime.tooltips:Invalidate()end)
    end
    for _,name in ipairs({"InventoryChanged","PresetsChanged","SessionChanged","PlayerStateChanged","BuildActualChanged"})do
        events:Subscribe(name,function()runtime.ui:ScheduleRefresh()end)
    end
    events:Subscribe("SessionFinished",function(payload)runtime.ui:OnSessionFinished(payload)end)
    runtime.filters:Attach(api,events,function()runtime.ui:RefreshToggles()end)
    for _,context in ipairs(runtime.filters:GetContexts())do
        runtime.ui:RegisterHideToggle(context.parent,context.context,runtime.filters)
    end
    local function register(name,callback)
        if api[name] then api.EVENT_MANAGER:RegisterForEvent(KW.name..name,api[name],callback) end
    end
    register("EVENT_START_SKILL_RESPEC",function(_,allocationMode,paymentType)
        emit("NativeSkillRespecStarted",{allocationMode=allocationMode,paymentType=paymentType})
    end)
    register("EVENT_SKILL_RESPEC_RESULT",function(_,result)emit("NativeSkillRespecResult",{result=result})end)
    register("EVENT_ATTRIBUTE_RESPEC_RESULT",function(_,result)emit("NativeAttributeRespecResult",{result=result})end)
    if buildServices then
        local function invalidate(domain)
            local revision=runtime.actualRevisions[domain]+1
            runtime.actualRevisions[domain]=revision
            emit("BuildActualChanged",{domain=domain,revision=revision})
        end
        invalidateActual=invalidate
        -- Native updates are invalidation facts, never allocation confirmation.
        -- The deferred UI refresh coalesces them before one actual capture.
        events:Subscribe("InventoryChanged",function(snapshot)
            invalidate("equipment")
            -- Inventory already published this identity snapshot. Reuse it
            -- instead of scanning the same bags again in the UI callback.
            if snapshot and snapshot.worn and snapshot.byUid then
                displayState.equipment=snapshot
                displayState.equipmentRevision=runtime.actualRevisions.equipment
            end
        end)
        for _,name in ipairs({"EVENT_SKILLS_FULL_UPDATE","EVENT_SKILL_POINTS_CHANGED","EVENT_SKILL_LINE_ADDED",
            "EVENT_SKILL_RANK_UPDATE","EVENT_ABILITY_PROGRESSION_RANK_UPDATE","EVENT_HOTBAR_SLOT_UPDATED","EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED"})do
            register(name,function()invalidate("abilities")end)
        end
        register("EVENT_ATTRIBUTE_UPGRADE_UPDATED",function()invalidate("attributes")end)
        local function appearanceChanged()
            invalidate('appearance');emit('AppearanceChanged',{})
            local s=runtime.session
            if s:IsEditorActive() and s.journal.component=='appearance'then s:SyncDraft();s:Notify()end
        end
        register('EVENT_COLLECTIBLE_UPDATED',appearanceChanged)
        register('EVENT_COLLECTION_UPDATED',appearanceChanged)
        register('EVENT_COLLECTIBLE_USE_RESULT',function(_,result,isAttemptingActivation)
            emit('AppearanceUseResult',{result=result,isAttemptingActivation=isAttemptingActivation});appearanceChanged()
        end)
        events:Subscribe('NativeSkillRespecResult',function()invalidate('abilities')end)
        events:Subscribe('NativeAttributeRespecResult',function()invalidate('attributes')end)
    end
    local function refresh()runtime.inventory:Refresh()end
    for _,name in ipairs({"EVENT_INVENTORY_SINGLE_SLOT_UPDATE","EVENT_INVENTORY_FULL_UPDATE","EVENT_OPEN_BANK",
        "EVENT_CLOSE_BANK"})do register(name,refresh)end
    register("EVENT_PLAYER_ACTIVATED",function()
        -- Native managers can be replaced on activation; never reuse handles.
        if invalidateActual then invalidateActual('abilities');invalidateActual('attributes');invalidateActual('appearance')end
        refresh()
        runtime.session:OnPlayerActivated()
        if runtime.buildProbe and runtime.repo.character.buildProbeJournal.journal then
            local name=KW.name.."ProbeRecovery"
            api.EVENT_MANAGER:RegisterForUpdate(name,250,function()
                api.EVENT_MANAGER:UnregisterForUpdate(name)
                runtime.buildProbe:Recover()
            end)
        end
    end)
    register("EVENT_CLOSE_GUILD_BANK",function()runtime.inventory:SetGuildBankReady(false);refresh()end)
    register("EVENT_GUILD_BANK_SELECTED",function()runtime.inventory:SetGuildBankReady(false);refresh()end)
    register("EVENT_GUILD_BANK_ITEMS_READY",function()runtime.inventory:SetGuildBankReady(true);refresh()end)
    local function playerState()
        local problem
        if api.IsUnitInCombat("player") then problem="inCombat"
        elseif api.IsUnitDeadOrReincarnating and api.IsUnitDeadOrReincarnating("player")
            or api.IsUnitDead and api.IsUnitDead("player") then problem="dead" end
        local view=runtime.session:GetView()
        if problem and view.state~="idle" and not view.paused then runtime.session:Pause(problem) end
        emit("PlayerStateChanged")
    end
    for _,name in ipairs({"EVENT_PLAYER_COMBAT_STATE","EVENT_PLAYER_DEAD","EVENT_PLAYER_ALIVE","EVENT_PLAYER_REINCARNATED"})do
        register(name,playerState)
    end
    register("EVENT_PLAYER_DEACTIVATED",function()
        -- Pause stops the runner, which removes its transient timers/listeners.
        -- UI restores native anchors and invalidates hover callbacks on hide.
        runtime.ui:OnSceneHidden()
        runtime.inventory:SetGuildBankReady(false)
        emit("PlayerStateChanged")
    end)
    api.SLASH_COMMANDS["/kw"]=function(command)
        if (command or ''):match('^%s*operation%s+report%s*$') and runtime.session.operations then
            KW.OperationJournal.ShowReport(runtime.repo.character)
        elseif (command or ''):match('^%s*operation%s*$') and runtime.session.operations then
            runtime.session.operations:SetVisible(true)
        elseif (command or ""):match("^%s*perf%s*$") then
            KW.ProbeReport.Show(runtime.repo.character.performanceReport or 'No page timing recorded yet.')
        elseif (command or ""):match("^%s*status%s*$") then
            if api.d then api.d(KW.Core.Status(runtime)) end
        elseif (command or ""):match("^%s*capabilities%s*$") then
            if api.d then api.d(KW.Core.BuildCapabilitiesStatus(runtime)) end
        elseif (command or ""):match("^%s*probe%s+") then
            local action = command:match("^%s*probe%s+(%S+)%s*$")
            local ok, problem
            if runtime.buildProbe then ok, problem = runtime.buildProbe:Run(action) end
            if not ok and api.d then api.d("KanaWardrobe probe: "..tostring(problem and problem.details.reason or "helper unavailable")) end
        elseif api.d then api.d("/kw operation | /kw operation report | /kw status | /kw perf | /kw capabilities | /kw probe attributes|skills|restore|status|batch|reset") end
    end
    if KW.PerformanceProbe then KW.PerformanceProbe.Attach(runtime)end
    runtime.ui:ScheduleRefresh()
    emit("Initialized", runtime)
    runtime.session:CheckLateCompletion() -- release settled gear-only recovery after reload
    return runtime
end

if EVENT_MANAGER and EVENT_ADD_ON_LOADED then
    EVENT_MANAGER:RegisterForEvent(KW.name, EVENT_ADD_ON_LOADED, function(_, addonName)
        if addonName ~= KW.name then return end
        EVENT_MANAGER:UnregisterForEvent(KW.name, EVENT_ADD_ON_LOADED)
        KW.Core.Initialize()
    end)
end
