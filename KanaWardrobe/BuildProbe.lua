local KW=KanaWardrobe
KW.BuildProbe={}
-- Local diagnostics. Mutating probes remain explicit; blocked-action reports only read.
function KW.BuildProbe.New(api, storage, report)
    local p={api=api,storage=storage,report=report or function()end}
    local timer=KW.name.."BuildProbeTimeout"
    local sending=false
    local recovered=false
    local ticks=0
    local processEntry
    local function traceback(err)
        return debug and debug.traceback and debug.traceback(tostring(err),2) or tostring(err)
    end
    local function plain(value)
        if type(value)~="table"then return tostring(value)end
        local keys={};for k in pairs(value)do keys[#keys+1]=k end
        table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
        local rows={};for _,k in ipairs(keys)do rows[#rows+1]=tostring(k).."="..plain(value[k])end
        return "{"..table.concat(rows,",").."}"
    end
    local function stop()if api.EVENT_MANAGER and api.EVENT_MANAGER.UnregisterForUpdate then api.EVENT_MANAGER:UnregisterForUpdate(timer)end end
    local function emit(text)
        storage.latestReport=text
        local ok,err=xpcall(function()p.report(text)end,traceback)
        if not ok then storage.latestReport=text.."\nReport display error:\n"..err end
    end
    function p:RecordBarBlock(problem,action,context,silent)
        if not problem or problem.code~='skillBarOverride' then return end
        local rows={}
        local function field(name,value)
            rows[#rows+1]=name..'='..tostring(value):gsub('\r','\\r'):gsub('\n','\\n')
            return value
        end
        local function fields(prefix,value)
            if type(value)~='table' then field(prefix,value);return end
            for key,item in pairs(value)do fields(prefix..'.'..tostring(key),item)end
        end
        local function read(name,fn)
            local ok,value=pcall(fn)
            if not ok then field(name,'ERROR: '..tostring(value));return end
            return field(name,value)
        end
        local function method(name,object,key,...)
            local args={...}
            return read(name,function()
                if not object or type(object[key])~='function' then return 'unavailable' end
                return object[key](object,(unpack or table.unpack)(args))
            end)
        end
        local function apiRead(name,key,...)
            local args={...}
            return read(name,function()
                if type(api[key])~='function' then return 'unavailable' end
                return api[key]((unpack or table.unpack)(args))
            end)
        end
        local details=problem.details or {}
        local captured=details.slotContext or {}
        field('problem',problem.code);fields('slotContext',captured)
        fields('operation',context or {})
        if captured.override then field('reason.override',true)end
        if captured.runtimeOverride then field('reason.runtimeOverride',true)end
        if captured.mutable==false then field('reason.immutable',true)
        elseif captured.mutable==nil then field('reason.mutableUnreadable',true)end
        apiRead('api','GetAPIVersion')
        method('scene',api.SCENE_MANAGER,'GetCurrentSceneName')
        local global=api.SKILLS_AND_ACTION_BAR_MANAGER
        method('live.mode',global,'GetSkillPointAllocationMode')
        read('live.dirty',function()return global and global.isDirty end)
        method('live.pending',global,'HasAnyPendingChanges')
        method('live.allocationPending',api.SKILL_POINT_ALLOCATION_MANAGER,'IsAnyChangePending')
        method('live.linesPending',api.SKILL_LINE_ASSIGNMENT_MANAGER,'IsAnyChangePending')
        apiRead('live.skillCastMs','GetSkillRespecCastTimeRemainingMs')
        apiRead('live.attributeCastMs','GetAttributeRespecCastTimeRemainingMs')
        apiRead('live.activeHotbar','GetActiveHotbarCategory')
        apiRead('live.inCombat','IsUnitInCombat','player')
        local category=captured.category or details.category
        local slot=captured.nativeSlot or details.nativeSlot
        if type(category)=='number' and type(slot)=='number' then
            apiRead('live.slot.actualType','GetSlotType',slot,category)
            local actualId=apiRead('live.slot.actualId','GetSlotBoundId',slot,category)
            if type(actualId)=='number' and actualId>0 then apiRead('live.slot.actualName','GetAbilityName',actualId)end
            apiRead('live.slot.overrideProgression','GetSkillProgressionIdForHotbarSlotOverrideRule',slot,category)
            local bars=api.ACTION_BAR_ASSIGNMENT_MANAGER
            method('live.bar.submittable',bars,'ShouldSubmitChangesForHotbarCategory',category)
            -- Inspect existing hotbars only; GetHotbar may initialize a new one.
            local hotbar
            read('live.bar.exists',function()hotbar=bars and bars.hotbars and bars.hotbars[category];return hotbar~=nil end)
            method('live.slot.locked',hotbar,'IsSlotLocked',slot)
            method('live.slot.mutable',hotbar,'IsSlotMutable',slot)
            method('live.slot.pending',hotbar,'DoesSlotHavePendingChanges',slot)
            local assignment
            read('live.slot.assignmentExists',function()assignment=hotbar and hotbar:GetSlotData(slot);return assignment~=nil end)
            for label,key in pairs({pendingId='GetActionId',pendingType='GetActionType',effectiveId='GetEffectiveAbilityId',slottableType='GetSlottableActionType'})do
                method('live.slot.'..label,assignment,key)
            end
        end
        table.sort(rows)
        local fingerprint=table.concat(rows,'\n')
        local text=table.concat({'KanaWardrobe action slot block report','addon='..tostring(KW.version),
            'action='..tostring(action),fingerprint},'\n')
        storage.skillBlockReport=text
        problem.details=details;details.nativeReportSaved=true;details.nativeReport=text
        if not silent and self.lastBarBlockFingerprint~=fingerprint then
            self.lastBarBlockFingerprint=fingerprint;emit(text)
        end
    end
    function p:RecordSkillBlock(problem,action,context,silent)
        if problem and problem.code=='skillBarOverride' then return self:RecordBarBlock(problem,action,context,silent)end
        if not problem or problem.code~='foreignSkillDraft' then return end
        local rows,reasons={},{}
        local function field(name,value) rows[#rows+1]=name..'='..tostring(value);return value end
        local function read(name,object,method,...)
            if not object or type(object[method])~='function' then field(name,'unavailable');return end
            local ok,value=pcall(object[method],object,...)
            if not ok then field(name,'ERROR: '..tostring(value));return end
            return field(name,value)
        end
        local function apiRead(name)
            if type(api[name])~='function' then return field(name,'unavailable') end
            local ok,value=pcall(api[name]);return field(name,ok and value or 'ERROR: '..tostring(value))
        end
        local function inspect(name,fn)
            local ok,err=pcall(fn);if not ok then field(name..'.error',err)end
        end
        local global=api.SKILLS_AND_ACTION_BAR_MANAGER
        for key,value in pairs(context or {})do field('operation.'..key,value)end
        if KW.SkillState then inspect('pendingCheck',function()
            local blocked,err=KW.SkillState.HasPendingChanges(api)
            field('pendingCheck.blocked',blocked)
            if err then field('pendingCheck.error',err)end
        end)end
        local mode=read('mode',global,'GetSkillPointAllocationMode')
        field('purchaseOnlyMode',api.SKILL_POINT_ALLOCATION_MODE_PURCHASE_ONLY)
        local dirty=field('dirty',global and global.isDirty or false)
        read('global.pending',global,'HasAnyPendingChanges')
        local managers={
            {'allocation',api.SKILL_POINT_ALLOCATION_MANAGER},
            {'bars',api.ACTION_BAR_ASSIGNMENT_MANAGER},
            {'lines',api.SKILL_LINE_ASSIGNMENT_MANAGER},
        }
        local pending,names={},{}
        for _,entry in ipairs(managers)do
            local name,manager=entry[1],entry[2]
            pending[name]=read(name..'.pending',manager,'IsAnyChangePending')
            if manager then names[manager]=name end
            if pending[name] then reasons[#reasons+1]=name end
        end
        for index,manager in ipairs(global and global.managers or {})do
            field('manager.'..index..'.name',names[manager] or 'unknown')
            read('manager.'..index..'.pending',manager,'IsAnyChangePending')
        end
        if mode~=nil and api.SKILL_POINT_ALLOCATION_MODE_PURCHASE_ONLY~=nil and mode~=api.SKILL_POINT_ALLOCATION_MODE_PURCHASE_ONLY then reasons[#reasons+1]='mode' end
        if dirty then reasons[#reasons+1]='dirty' end
        if #reasons==0 then reasons[1]='unknown' end
        apiRead('GetSkillRespecCastTimeRemainingMs');apiRead('GetAttributeRespecCastTimeRemainingMs')

        -- Inspect existing native objects only. Never create allocators, reset
        -- hotbars, open scenes or change modes while explaining a refusal.
        local allocation=api.SKILL_POINT_ALLOCATION_MANAGER
        if pending.allocation then inspect('allocation',function()
            if not allocation.AllocatorIterator then field('allocation.details','unavailable');return end
            for index,allocator in allocation:AllocatorIterator()do
                if allocator:IsAnyChangePending()then
                    local skill=allocator:GetSkillData()
                    local key='allocator.'..tostring(index)
                    read(key..'.progressionId',skill,'GetProgressionId')
                    read(key..'.passive',skill,'IsPassive')
                    read(key..'.name',skill,'GetName')
                    read(key..'.actualPurchased',skill,'IsPurchased')
                    read(key..'.pendingPurchased',allocator,'IsPurchased')
                    read(key..'.actualProgression',skill,'GetCurrentSkillProgressionKey')
                    read(key..'.pendingProgression',allocator,'GetSkillProgressionKey')
                end
            end
        end)end
        local bars=api.ACTION_BAR_ASSIGNMENT_MANAGER
        if pending.bars then inspect('bars',function()
            if type(bars.hotbars)~='table' then field('bars.details','unavailable');return end
            local categories={};for category in pairs(bars.hotbars)do categories[#categories+1]=category end;table.sort(categories)
            for _,category in ipairs(categories)do inspect('bar.'..category,function()
                local hotbar=bars.hotbars[category]
                read('bar.'..category..'.submittable',bars,'ShouldSubmitChangesForHotbarCategory',category)
                for slot,assignment in hotbar:SlotIterator()do
                    if hotbar:DoesSlotHavePendingChanges(slot)then
                        local key='bar.'..category..'.slot.'..slot
                        field(key..'.pending',true)
                        local ok,kind=pcall(api.GetSlotType,slot,category);field(key..'.actualType',ok and kind or 'ERROR: '..tostring(kind))
                        local valid,id=pcall(api.GetSlotBoundId,slot,category);field(key..'.actualId',valid and id or 'ERROR: '..tostring(id))
                        read(key..'.pendingType',assignment,'GetActionType')
                        read(key..'.slottableType',assignment,'GetSlottableActionType')
                        read(key..'.pendingId',assignment,'GetActionId')
                        read(key..'.effectiveId',assignment,'GetEffectiveAbilityId')
                        if category==api.HOTBAR_CATEGORY_WEREWOLF then
                            local skill=read(key..'.hasPlayerSkill',assignment,'GetPlayerSkillData')
                            if skill then
                                -- Never persist native objects: use stable scalar identities.
                                rows[#rows]=key..'.hasPlayerSkill=true'
                                read(key..'.skillId',skill,'GetProgressionId')
                                read(key..'.skillPurchased',skill,'IsPurchased')
                                read(key..'.skillUltimate',skill,'IsUltimate')
                            end
                            local ok,rule=pcall(api.GetSkillProgressionIdForHotbarSlotOverrideRule,slot,category)
                            field(key..'.overrideRule',ok and rule or 'ERROR: '..tostring(rule))
                        end
                    end
                end
            end)end
        end)end
        local lines=api.SKILL_LINE_ASSIGNMENT_MANAGER
        if pending.lines then
            for _,name in ipairs({'pendingTrainingLines','pendingActivationLines','pendingDeactivationLines'})do
                -- These native arrays contain line IDs, not manager objects.
                field('lines.'..name,plain(lines[name]))
            end
        end
        -- Slot/allocator iterators may use pairs; sort for stable deduplication.
        table.sort(rows)
        local fingerprint=table.concat(rows,'\n')
        local header={'KanaWardrobe skill block report','addon='..tostring(KW.version or '0.1.0'),'action='..tostring(action)}
        local ok,version=pcall(function()return api.GetAPIVersion()end)
        header[#header+1]='api='..tostring(ok and version or 'unavailable')
        local readable,sceneName=pcall(function()return api.SCENE_MANAGER:GetCurrentSceneName()end)
        header[#header+1]='scene='..tostring(readable and sceneName or 'unavailable')
        header[#header+1]='reasons='..table.concat(reasons,',')
        header[#header+1]=fingerprint
        local text=table.concat(header,'\n')
        storage.skillBlockReport=text
        problem.details=problem.details or {}
        problem.details.nativeReasons=reasons;problem.details.nativeReportSaved=true;problem.details.nativeReport=text
        if not silent and self.lastSkillBlockFingerprint~=fingerprint then
            self.lastSkillBlockFingerprint=fingerprint
            emit(text)
        end
    end
    local function report(j,command,err,note)
        local rows={"KanaWardrobe build probe", "addon="..tostring(KW.version or "0.1.0"),"command="..tostring(command)}
        local ok,meta=xpcall(function()
            local text="api="..tostring(api.GetAPIVersion and api.GetAPIVersion()).."\ncurrentScene="..tostring(api.SCENE_MANAGER and api.SCENE_MANAGER:GetCurrentSceneName())
            if storage.batch then
                text=text.."\nactualSkillsMode="..tostring(api.SKILLS_AND_ACTION_BAR_MANAGER:GetSkillPointAllocationMode())
                    .."\nactualAttributesMode="..tostring(api.STATS:GetAttributePointAllocationMode())
            end
            return text
        end,traceback)
        rows[#rows+1]=ok and meta or "Metadata error:\n"..meta
        if j then
            for _,key in ipairs({"kind","command","scene","entryScene","sendScene","started","restoring","line","progression","morph","original","target","actual","actualMorph","actualLine","actualPurchased","result","phase","verified","matchesOriginal","matchesTarget"})do
                rows[#rows+1]=key.."="..plain(j[key])
            end
        else rows[#rows+1]="no allocation snapshot"end
        if storage.batch then rows[#rows+1]="batch="..plain(storage.batch)end
        if err then rows[#rows+1]="Error:\n"..tostring(err)end
        if note then rows[#rows+1]="Note:\n"..tostring(note)end
        emit(table.concat(rows,"\n"))
    end
    local function fail(j,command,err)
        stop()
        if j then
            j.verified=false
            if j.phase=="waiting" or j.phase=="entry"then j.phase="unknown"end
        end
        report(j,command,err)
    end
    local function need(object,name)
        assert(object and type(object[name])=="function", "missing "..name)
        return object[name]
    end
    local function scene()return need(api.SCENE_MANAGER,"GetCurrentSceneName")(api.SCENE_MANAGER)end
    local function attrs()
        local f=need(api,"GetAttributeSpentPoints")
        return {f(api.ATTRIBUTE_HEALTH),f(api.ATTRIBUTE_MAGICKA),f(api.ATTRIBUTE_STAMINA)}
    end
    local function slots()
        local first,last=need(api,"GetAssignableAbilityBarStartAndEndSlots")()
        local out={}
        for _,bar in ipairs({api.HOTBAR_CATEGORY_PRIMARY,api.HOTBAR_CATEGORY_BACKUP})do
            for index=first,last do
                out[#out+1]={bar=bar,index=index,kind=need(api,"GetSlotType")(index,bar),id=need(api,"GetSlotBoundId")(index,bar)}
            end
        end
        return out
    end
    local function equal(a,b)
        if type(a)~=type(b)then return false end
        if type(a)~="table"then return a==b end
        for k,v in pairs(a)do if not equal(v,b[k])then return false end end
        for k in pairs(b)do if a[k]==nil then return false end end
        return true
    end
    local function selected(j)
        local m=api.SKILLS_DATA_MANAGER
        local s=need(m,"GetSkillDataByProgressionId")(m,j.progression)
        assert(s,"selected skill unavailable")
        return s
    end
    local function actual(j,original)
        if j.kind=="attributes"then return equal(attrs(),original and j.original or j.target)end
        local s=selected(j)
        return need(s,"IsPurchased")(s) and need(s,"GetCurrentMorphSlot")(s)==(original and j.morph or api.MORPH_SLOT_BASE)
            and need(s:GetSkillLineData(),"GetId")(s:GetSkillLineData())==j.line
            and equal(slots(),original and j.original or j.target)
    end
    local function readActual(j)
        if j.kind=="attributes"then j.actual=attrs()
        else
            local skill=selected(j)
            j.actual=slots();j.actualMorph=need(skill,"GetCurrentMorphSlot")(skill)
            j.actualLine=need(skill:GetSkillLineData(),"GetId")(skill:GetSkillLineData())
            j.actualPurchased=need(skill,"IsPurchased")(skill)
        end
        local skillOriginal=j.kind=="attributes" or j.actualPurchased and j.actualLine==j.line and j.actualMorph==j.morph
        local skillTarget=j.kind=="attributes" or j.actualPurchased and j.actualLine==j.line and j.actualMorph==api.MORPH_SLOT_BASE
        j.matchesOriginal=skillOriginal and equal(j.actual,j.original) or false
        j.matchesTarget=skillTarget and equal(j.actual,j.target) or false
        j.verified=j.result==api.RESPEC_RESULT_SUCCESS and j.phase~="unknown" and
            (j.restoring and j.matchesOriginal or not j.restoring and j.matchesTarget) or false
    end
    local function complete(j,reason)
        stop();report(j,j.command,reason)
        if j.restoring and j.verified then storage.journal=nil end
    end
    local function reconcile(j)
        if storage.journal~=j or j.phase~="waiting"then return end
        readActual(j)
        if j.result~=nil and (j.result~=api.RESPEC_RESULT_SUCCESS or j.verified)then
            j.phase="result";complete(j);return
        end
        ticks=ticks+100
        local elapsed=api.GetFrameTimeMilliseconds and api.GetFrameTimeMilliseconds()-j.started or ticks
        if elapsed>=15000 then j.phase="unknown";j.verified=false;complete(j,"timeout; snapshot retained")end
    end
    local function observe(j)
        local ok,err=xpcall(function()if j.phase=="entry" then processEntry(j) else reconcile(j) end end,traceback)
        if not ok then fail(j,j.command,err)end
    end
    local function idle()
        assert(not p.IsSessionIdle or p.IsSessionIdle(),"equipment session is not idle")
        assert(not need(api,"IsUnitInCombat")("player"),"in combat")
        assert(not need(api,"IsUnitDead")("player"),"dead")
        assert(need(api,"GetSkillRespecCastTimeRemainingMs")()==0 and need(api,"GetAttributeRespecCastTimeRemainingMs")()==0,"native respec cast pending")
        local m=api.SKILLS_AND_ACTION_BAR_MANAGER
        assert(not need(m,"HasAnyPendingChanges")(m) and not m.isDirty,"native skill changes pending")
        -- A total of zero can hide one positive and one negative pending delta.
        for _,entry in ipairs({{stats=api.STATS,keyboard=true},{stats=api.GAMEPAD_STATS}})do
            local stats=entry.stats
            if stats then
                -- Native keyboard OnShowing creates attributeControls after setting initialized.
                -- Gamepad deferred initialization precedes ResetAttributeData. Never open either UI.
                local lazy=not stats.attributeControls and not stats.attributeData and
                    (entry.keyboard and not stats.initialized and type(stats.OnShowing)=="function"
                    or not entry.keyboard and not stats.deferredInitialized and type(stats.PerformDeferredInitializationRoot)=="function")
                if not lazy then
                    for _,id in ipairs({api.ATTRIBUTE_HEALTH,api.ATTRIBUTE_MAGICKA,api.ATTRIBUTE_STAMINA})do
                        if stats.attributeControls then
                            local c=stats.attributeControls[id]
                            assert(c and c.pointLimitedSpinner,"native attribute controls unavailable")
                            assert(need(c.pointLimitedSpinner,"GetAllocatedPoints")(c.pointLimitedSpinner)==0,"native attribute changes pending")
                        elseif stats.attributeData then
                            assert(stats.attributeData[id] and stats.attributeData[id].addedPoints==0,"native attribute changes pending")
                        else error("native attribute pending state unavailable")end
                    end
                end
            end
        end
        assert(api.STATS,"missing STATS")
    end
    local function skillPacket(j)
        idle()
        assert(actual(j,not j.restoring),"actual state changed before send; snapshot retained")
        j.sendScene=scene();j.phase="waiting";j.started=api.GetFrameTimeMilliseconds and api.GetFrameTimeMilliseconds() or 0;ticks=0
        api.PrepareSkillPointAllocationRequest(api.SKILL_POINT_ALLOCATION_MODE_FULL,api.RESPEC_PAYMENT_TYPE_GOLD)
        api.AddActiveChangeToAllocationRequest(j.line,j.progression,j.restoring and j.morph or api.MORPH_SLOT_BASE,true)
        for i,s in ipairs(j.original)do
            if s.id~=j.target[i].id then
                local to=j.restoring and s or j.target[i]
                api.AddHotbarSlotChangeToAllocationRequest(to.index,to.bar,to.kind,to.id)
            end
        end
        api.SendSkillPointAllocationRequest()
    end
    processEntry=function(j)
        if storage.journal~=j then return end
        local elapsed=api.GetFrameTimeMilliseconds and api.GetFrameTimeMilliseconds()-j.started or ticks
        ticks=ticks+100
        if elapsed>=5000 then
            j.phase="unknown";j.verified=false;complete(j,"entry timeout; snapshot retained")
        elseif j.entryEvent then
            local m=api.SKILLS_AND_ACTION_BAR_MANAGER
            assert(j.entryMode==api.SKILL_POINT_ALLOCATION_MODE_FULL and j.entryPayment==api.RESPEC_PAYMENT_TYPE_GOLD,"wrong native entry event")
            assert(m:GetSkillPointAllocationMode()==api.SKILL_POINT_ALLOCATION_MODE_FULL and m:GetSkillRespecPaymentType()==api.RESPEC_PAYMENT_TYPE_GOLD,"native entry mode/payment mismatch")
            skillPacket(j)
        end
    end
    local function send(j,restore)
        if j.kind=="attributes"then need(api,"SendAttributePointAllocationRequest")
        else
            for _,n in ipairs({"StartSkillRespecFromUI","PrepareSkillPointAllocationRequest","AddActiveChangeToAllocationRequest","AddHotbarSlotChangeToAllocationRequest","SendSkillPointAllocationRequest"})do need(api,n)end
            need(api.SKILLS_AND_ACTION_BAR_MANAGER,"GetSkillPointAllocationMode")
            need(api.SKILLS_AND_ACTION_BAR_MANAGER,"GetSkillRespecPaymentType")
            assert(api.EVENT_START_SKILL_RESPEC~=nil and api.SKILL_POINT_ALLOCATION_MODE_FULL~=nil,"missing native skill entry constants")
        end
        need(api.EVENT_MANAGER,"RegisterForEvent");need(api.EVENT_MANAGER,"RegisterForUpdate");need(api.EVENT_MANAGER,"UnregisterForUpdate")
        assert(api.RESPEC_PAYMENT_TYPE_GOLD~=nil and api.RESPEC_RESULT_SUCCESS~=nil,"missing respec constants")
        assert(api[j.kind=="attributes" and "EVENT_ATTRIBUTE_RESPEC_RESULT" or "EVENT_SKILL_RESPEC_RESULT"]~=nil,"missing result event")
        local callerScene=scene() -- Validate before touching an existing restore journal.
        j.restoring=restore or false;j.phase=j.kind=="skills" and "entry" or "waiting";j.result=nil;j.verified=nil;j.scene=callerScene
        j.entryScene=j.kind=="skills" and j.scene or nil;j.sendScene=nil;j.entryEvent=nil;j.entryMode=nil;j.entryPayment=nil
        sending=true;storage.journal=j
        j.command=restore and "restore" or j.kind
        j.started=api.GetFrameTimeMilliseconds and api.GetFrameTimeMilliseconds() or 0;ticks=0
        api.EVENT_MANAGER:RegisterForUpdate(timer,100,function()observe(j)end)
        if j.kind=="attributes"then
            local from=restore and j.target or j.original;local to=restore and j.original or j.target
            api.SendAttributePointAllocationRequest(api.RESPEC_PAYMENT_TYPE_GOLD,to[1]-from[1],to[2]-from[2],to[3]-from[3])
        else api.StartSkillRespecFromUI() end
    end
    if api.EVENT_START_SKILL_RESPEC and api.EVENT_MANAGER and api.EVENT_MANAGER.RegisterForEvent then
        api.EVENT_MANAGER:RegisterForEvent(KW.name.."BuildProbeEntry",api.EVENT_START_SKILL_RESPEC,function(_,mode,payment)
            local j=storage.journal
            if j and j.kind=="skills" and j.phase=="entry" then
                j.entryEvent=true;j.entryMode=mode;j.entryPayment=payment
            end
        end)
    end
    -- Registration performs no allocations or mode changes; absent APIs do not break initialization.
    for _,kind in ipairs({"skills","attributes"})do
        local event=api[kind=="skills" and "EVENT_SKILL_RESPEC_RESULT" or "EVENT_ATTRIBUTE_RESPEC_RESULT"]
        if event and api.EVENT_MANAGER and api.EVENT_MANAGER.RegisterForEvent then
            api.EVENT_MANAGER:RegisterForEvent(KW.name.."BuildProbe"..kind,event,function(_,result)
                local j=storage.journal
                if not j or j.kind~=kind or j.phase~="waiting"then return end
                -- A native success can precede the corresponding getters. Keep observing.
                local ok,err=xpcall(function()j.result=result;reconcile(j)end,traceback)
                if not ok then fail(j,j.command,err)end
            end)
        end
    end
    if storage.journal and (storage.journal.phase=="waiting" or storage.journal.phase=="entry")then storage.journal.phase="unknown"end
    function p:Recover()
        if recovered or not storage.journal then return end
        recovered=true
        local j=storage.journal
        local ok,err=xpcall(function()readActual(j);report(j,"recovery")end,traceback)
        if not ok then fail(j,"recovery",err)end
    end
    function p:Run(command)
        -- Reopen the captured evidence even if the scene/state has since
        -- changed, or a separate allocation recovery journal still exists.
        if command=='blocked' then
            emit(storage.skillBlockReport or KW.Text('SKILL_BLOCK_NO_REPORT'))
            return true
        end
        sending=false
        local ok,err=xpcall(function()
            local j=storage.journal
            if command=="status"then
                if j then
                    readActual(j)
                    if j.phase=="waiting" and j.verified then j.phase="result";stop()end
                end
                report(j,command)
                if j and j.restoring and j.verified then storage.journal=nil end
                return
            end
            if j then
                assert(command=="restore" or command=="reset","snapshot exists; use status or restore")
                assert(j.phase~="waiting" and j.phase~="entry","request uncertain; use status")
                idle()
                if actual(j,true)then readActual(j);report(j,command,nil,"Original actual state confirmed; snapshot cleared without sending.");storage.journal=nil;return end
                assert(command=="restore" and not j.restoring and j.phase=="result" and j.result==api.RESPEC_RESULT_SUCCESS,"unknown/failed outcome; manual restoration required")
                assert(actual(j,false),"restore conflict; snapshot retained; manual restoration required")
                send(j,true);return
            end
            idle()
            if command=="attributes"then
                local original=attrs();local target=KW.Copy(original);local donor
                for i=1,3 do if original[i]>0 then donor=i;break end end
                assert(donor,"no spent attribute point")
                target[donor]=target[donor]-1;local receiver=donor%3+1;target[receiver]=target[receiver]+1
                send({kind="attributes",original=original,target=target},false)
            elseif command=="skills"then
                local original=slots();local chosen
                local m=api.SKILLS_DATA_MANAGER
                for _,s in ipairs(original)do
                    if s.kind==api.ACTION_TYPE_ABILITY then
                        local data=need(m,"GetProgressionDataByAbilityId")(m,s.id)
                        local skill=data and data:GetSkillData()
                        if skill and not skill:IsCraftedAbility() and not skill:IsPassive() and not skill:IsUltimate() and skill:IsPurchased() and skill:GetCurrentMorphSlot()~=api.MORPH_SLOT_BASE then chosen=skill;break end
                    end
                end
                assert(chosen,"no bought morphed ordinary active on normal bars")
                local line=chosen:GetSkillLineData();assert(line:IsActive(),"selected line not active")
                local progression=chosen:GetProgressionId();local morph=chosen:GetCurrentMorphSlot()
                local base=chosen:GetMorphData(api.MORPH_SLOT_BASE):GetAbilityId();local target=KW.Copy(original)
                for i,s in ipairs(original)do
                    if s.kind==api.ACTION_TYPE_ABILITY then
                        local d=m:GetProgressionDataByAbilityId(s.id)
                        if d and d:GetSkillData()==chosen then target[i].id=base end
                    end
                end
                send({kind="skills",original=original,target=target,line=line:GetId(),progression=progression,morph=morph},false)
            elseif command=="batch" or command=="reset"then
                local m,stats=api.SKILLS_AND_ACTION_BAR_MANAGER,api.STATS
                scene() -- Validate reporting API before changing either native mode.
                need(m,"SetSkillPointAllocationMode");need(stats,"SetAttributePointAllocationMode")
                need(m,"GetSkillPointAllocationMode");need(stats,"GetAttributePointAllocationMode")
                if command=="batch"then
                    assert(not storage.batch,"batch snapshot exists; use reset")
                    assert(api.SKILL_POINT_ALLOCATION_MODE_FULL and api.ATTRIBUTE_POINT_ALLOCATION_MODE_FULL,"missing batch modes")
                    storage.batch={skills=m:GetSkillPointAllocationMode(),attributes=stats:GetAttributePointAllocationMode()}
                    m:SetSkillPointAllocationMode(api.SKILL_POINT_ALLOCATION_MODE_FULL);stats:SetAttributePointAllocationMode(api.ATTRIBUTE_POINT_ALLOCATION_MODE_FULL)
                else
                    assert(storage.batch,"no batch snapshot")
                    m:SetSkillPointAllocationMode(storage.batch.skills);stats:SetAttributePointAllocationMode(storage.batch.attributes);storage.batch=nil
                end
                report(nil,command)
            else error("use attributes | skills | restore | status | blocked | batch | reset")end
        end,traceback)
        if ok then return true end
        local j=storage.journal
        if sending or command=="status"then fail(j,command,err)else report(j,command,err)end
        return nil,KW.Problem("buildProbeRefused",{reason=tostring(err)})
    end
    return p
end
