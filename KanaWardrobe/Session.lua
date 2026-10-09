local KW=KanaWardrobe
local Session={}; KW.Session=Session
local Instance={}; Instance.__index=Instance
local Slots=KW.Slots
local states={confirming=true,applying=true,preparingEdit=true,editing=true,restoring=true,recovery=true}
local function valueValid(v)
    return type(v)=="table" and (v.kind=="empty" or v.kind=="item" and type(v.uid)=="string" and v.uid~="" and v.uid~="0" and type(v.link)=="string")
end
local function mapValid(map,full)
    if type(map)~="table" then return false end
    local seen={}
    for slot,v in pairs(map) do
        if not Slots.IsSupported(slot) or not valueValid(v) then return false end
        if v.kind=="item" then if seen[v.uid] then return false end; seen[v.uid]=true end
    end
    if full then for _,slot in ipairs(Slots.Order) do if not map[slot] then return false end end end
    return true
end
local function available(state,v)
    local loc=v.kind=="item" and state.byUid[v.uid]
    return v.kind=="empty" or loc and (loc.bagId==BAG_BACKPACK or loc.bagId==BAG_WORN)
end
local function readiness(inventory)
    local api=inventory.api
    if api.IsUnitInCombat("player") then return KW.Problem("inCombat") end
    if api.IsUnitDeadOrReincarnating("player") then return KW.Problem("dead") end
    if api.IsBlockActive() then return KW.Problem("blocking") end
end
local function committedCandidate(repo,j)
    local candidate=j.commitCandidate
    if type(candidate)~="table" then return nil end
    local stored=repo:Get(j.presetId)
    if stored and stored.revision==j.revision+1 and stored.name==candidate.name
        and Slots.Equal(stored.slots,candidate.slots) then return stored end
end
local function journalValid(j)
    if type(j)~="table" or j.version~=1 or not states[j.state] or not mapValid(j.original,true)
        or (j.kind~="apply" and j.kind~="edit" and j.kind~="new") or type(j.selected)~="table"
        or not mapValid(j.missing,false) or type(j.name)~="string" or type(j.presetId)~="string"
        or type(j.revision)~="number" or j.revision<0 or j.revision%1~=0 then return false end
    for slot,v in pairs(j.selected) do if not Slots.IsSupported(slot) or type(v)~="boolean" then return false end end
    local function pendingValid(p,member)
        if p==nil then return true end
        if type(p)~="table" or (p.kind~="equip" and p.kind~="unequip") or not Slots.IsSupported(p.equipSlot)
            or type(p.uid)~="string" or p.uid=="" or p.uid=="0" then return false end
        if p.before~=nil and not mapValid(p.before,true) or p.expected~=nil and not mapValid(p.expected,true) then return false end
        if p.source~=nil and (type(p.source)~="table" or type(p.source.bagId)~="number"
            or type(p.source.slotIndex)~="number" or p.source.uid~=p.uid) then return false end
        if p.batch~=nil then
            if member or type(p.batch)~="table" or #p.batch==0 or #p.batch>#Slots.Order then return false end
            local slots={}
            for _,step in ipairs(p.batch) do
                if not pendingValid(step,true) or slots[step.equipSlot] then return false end
                slots[step.equipSlot]=true
            end
        end
        return true
    end
    if not pendingValid(j.pending) then return false end
    if j.unresolvedRequests~=nil then
        if type(j.unresolvedRequests)~="table" then return false end
        for _,p in pairs(j.unresolvedRequests) do if not pendingValid(p) then return false end end
    end
    if j.kind~="new" and (type(j.originalPreset)~="table" or not mapValid(j.originalPreset.slots,false)) then return false end
    return true
end
function Session.New(repo,inventory,planner,runner,protection,savedCharacter,capabilities,emit,services)
    local self=setmetatable({repo=repo,inventory=inventory,planner=planner,runner=runner,protection=protection,
        saved=savedCharacter,services=services,capabilities=capabilities or {},emit=emit or function() end},Instance)
    if services and services.operations then return KW.OperationSession.Attach(self)end
    if savedCharacter.journal~=nil then
        if services and type(savedCharacter.journal)=="table" and savedCharacter.journal.version==2 then
            local j,problem=KW.BuildJournal.Read(savedCharacter.journal,repo)
            if j and states[j.state] then
                self.journal=j
                self.loadedJournal=j
                if j.phase=='committing' and j.commitCandidate and not j.saveCommitted then
                    local stored=repo:Get(j.presetId)
                    if stored and stored.name==j.name and stored.revision==j.revision+1 and
                        KW.BuildModel.Matches(stored,j.commitCandidate) and KW.BuildModel.Matches(j.commitCandidate,stored) then
                        j.saveCommitted=true;j.committedRevision=stored.revision;j.revision=stored.revision
                    end
                end
                j.state='recovery';j.paused=true;j.problem=KW.Problem('recoveryRequired');self:Persist()
            else self.invalidJournal=true;self.problem=problem or KW.Problem('invalidJournal') end
        elseif journalValid(savedCharacter.journal) then
            self.journal=KW.Copy(savedCharacter.journal)
            local j=self.journal
            -- A synchronous repository observer may reload between its write
            -- and Save returning. Reconcile the exact candidate, never Save twice.
            if j.phase=="committing" and j.commitCandidate and not j.saveCommitted then
                local stored=committedCandidate(repo,j)
                if stored then
                    j.saveCommitted=true; j.committedRevision=stored.revision
                end
            end
            j.resumeState=j.state; j.state="recovery"; j.paused=true; j.problem=KW.Problem("recoveryRequired")
            self:Persist()
        else self.invalidJournal=true; self.problem=KW.Problem("invalidJournal") end
    end
    return self
end
function Instance:Persist()
    if self.invalidJournal then return true end
    if self.journal and self.journal.version==2 then
        local ok,problem=KW.BuildJournal.Write(self.saved,self.journal)
        if not ok then error(problem.code)end -- synchronous progress failure vetoes dispatch
        return true
    end
    self.saved.journal=self.journal and KW.Copy(self.journal) or nil
    return true
end
function Instance:MissingOriginal(state)
    local missing,parts={},{}
    for _,slot in ipairs(Slots.Order) do
        local v=self.journal.original[slot]
        if not available(state,v) then
            missing[slot]=KW.Copy(v)
            parts[#parts+1]=tostring(slot)..":"..tostring(#v.uid)..":"..v.uid
        end
    end
    return missing,table.concat(parts,"|")
end
-- Hot-path filters need only this flag, not a deep copy of the recovery journal.
function Instance:IsEditorActive()
    return self.invalidJournal==true or self.journal~=nil and self.journal.kind~="apply"
end
-- Overlay refreshes query one scalar; never copy a view or capture native state.
function Instance:GetSelected(domain,key)
    local j=self.journal
    if self.invalidJournal or not j or j.kind=="apply" then return false end
    if type(domain)=="number" then key=domain;domain="equipment" end
    if domain=="bars" and type(key)=="table" then domain,key=key.bar,key.slot end
    if j.version~=2 then
        return domain=="equipment" and Slots.IsSupported(key) and j.selected and j.selected[key]==true or false
    end
    local selection=j.selection
    if type(selection)~="table" then return false end
    if domain=="equipment" then
        return j.component=="equipment" and Slots.IsSupported(key) and selection.equipment and selection.equipment[key]==true or false
    elseif domain=="appearance" then
        return j.component=="appearance" and selection.appearance and selection.appearance[key]==true or false
    elseif domain=="skills" then
        return j.component=="abilities" and type(key)=="string" and selection.skills and selection.skills[key]==true or false
    elseif domain=="front" or domain=="back" or domain=="werewolf" then
        return j.component=="abilities" and type(key)=="number" and key%1==0 and key>=1 and key<=6
            and selection.bars and selection.bars[domain] and selection.bars[domain][key]==true or false
    end
    return false
end
function Instance:GetView()
    local j=self.journal
    if not j then
        return {state=self.invalidJournal and "recovery" or "idle",paused=self.invalidJournal==true,
            isEditor=self.invalidJournal==true,selected={},missing={},saved=false,problem=KW.Copy(self.problem)}
    end
    local missing,key=j.recoveryMissing or {},nil
    if j.state=="recovery" then missing,key=self:MissingOriginal(self.inventory:Capture("equipment")) end
    return KW.Copy({state=j.state,paused=j.paused==true,kind=j.kind,name=j.name,selected=j.selected,missing=j.missing,
        saved=j.saveCommitted==true,problem=j.problem,confirmation=j.confirmation,isEditor=j.kind~="apply",
        recoveryMissing=missing,recoveryKey=key,presetId=j.presetId,progress=j.progress})
end
function Instance:Notify()
    self.recoveryInspection=nil
    self.viewRevision=(self.viewRevision or 0)+1
    self:Persist(); self.emit("SessionChanged",self:GetView())
end
function Instance:GetRecoveryView()return self:GetView()end
function Instance:Fail(problem)
    if self.journal then self.journal.problem=problem else self.problem=problem end
    self:Notify(); return nil,problem
end
function Instance:IdleRequired()
    if self.journal or self.invalidJournal or self.runner:IsBusy() or self.committing then return nil,KW.Problem("busy") end
    return true
end
function Instance:Editable()
    local j=self.journal
    if not j or j.state~="editing" or j.kind=="apply" or self.committing then return nil,KW.Problem("invalidState") end
    if j.paused then return nil,KW.Problem("paused") end
    return j
end
function Instance:Finish(outcome,problem)
    local j=self.journal
    local result={kind=j and j.kind,presetId=j and j.presetId,saved=j and j.saveCommitted==true or false,outcome=outcome,problem=problem}
    self.journal=nil; self.invalidJournal=nil; self.problem=problem
    self:Notify(); self.emit("SessionFinished",result)
end
function Instance:NewJournal(kind,preset,state)
    local selected={}
    for slot in pairs(preset.slots) do selected[slot]=true end
    local j={version=1,kind=kind,state="editing",phase="editing",presetId=preset.id,revision=preset.revision,
        original=KW.Copy(state.worn),originalPreset=kind~="new" and KW.Copy(preset) or nil,
        name=preset.name,selected=selected,missing={},saveCommitted=false,paused=false,unresolvedRequests={}}
    self.journal=j; self.problem=nil; self:Persist(); return j
end
function Instance:Preparation(preset,state,allowMissing)
    local intent=KW.Copy(preset.slots); local missing={}
    for slot,v in pairs(intent) do
        if v.kind=="item" and not available(state,v) then
            missing[slot]=KW.Copy(v)
            if allowMissing then intent[slot]={kind="empty"} end
        end
    end
    local plan,p=self.planner.Build(state,intent,allowMissing and "prepareEdit" or "apply",self.capabilities)
    if not plan then return nil,p,missing end
    return plan,nil,missing
end
function Instance:Begin(kind,id,allowMissing)
    local ok,p=self:IdleRequired(); if not ok then return nil,p end
    local preset=self.repo:Get(id); if not preset then return self:Fail(KW.Problem("presetMissing")) end
    local state=self.inventory:Capture("equipment")
    local plan,problem,missing=self:Preparation(preset,state,kind=="edit" and allowMissing)
    if not plan then return self:Fail(problem) end
    local j=self:NewJournal(kind,preset,state); j.allowMissing=allowMissing==true; j.missing=missing
    if #plan.extras>0 then
        j.state="confirming"; j.phase="confirming"; j.confirmation={plan=plan,presetName=preset.name,revision=preset.revision}; self:Notify(); return true
    end
    return self:Run(plan,kind=="apply" and "applying" or "preparingEdit")
end
function Instance:Apply(id) return self:Begin("apply",id,false) end
function Instance:BeginEdit(id,allowMissing) return self:Begin("edit",id,allowMissing) end
-- The quick slot uses the same apply journal/runner and item protection as a
-- named preset, but never participates in the editable preset list.
function Instance:QuickSave()
    local ok,p=self:IdleRequired(); if not ok then return nil,p end
    local blocked=readiness(self.inventory); if blocked then return self:Fail(blocked) end
    local captured=self.inventory:Capture("equipment")
    self.committing=true
    local success,locked,problem=pcall(self.protection.Ensure,self.protection,captured.worn)
    self.committing=false
    if not success then return self:Fail(KW.Problem("lockFailed")) end
    if not locked then return self:Fail(problem) end
    blocked=readiness(self.inventory); if blocked then return self:Fail(blocked) end
    if not Slots.Equal(captured.worn,self.inventory:Capture("equipment").worn)then
        return self:Fail(KW.Problem("externalChange"))
    end
    local stored,err=self.repo:SaveQuick(captured.worn)
    if not stored then return self:Fail(err) end
    self.problem=nil; self:Notify()
    self.emit("SessionFinished",{outcome="quickSaved",saved=true})
    return true
end
function Instance:QuickLoad()
    return self:Apply(KW.Presets.QUICK_ID)
end
function Instance:BeginNew()
    local ok,p=self:IdleRequired(); if not ok then return nil,p end
    local state=self.inventory:Capture("equipment"); local draft=self.repo:NewDraft()
    for slot,v in pairs(state.worn) do if v.kind=="item" then draft.slots[slot]=KW.Copy(v) end end
    self:NewJournal("new",draft,state); self:Notify(); return true
end
function Instance:Confirm(extraKey)
    local j=self.journal
    if not j or j.state~="confirming" or j.paused then return nil,KW.Problem("invalidState") end
    local preset=self.repo:Get(j.presetId); if not preset then return self:Fail(KW.Problem("presetMissing")) end
    local plan,p,missing=self:Preparation(preset,self.inventory:Capture("equipment"),j.kind=="edit" and j.allowMissing)
    if not plan then return self:Fail(p) end
    if extraKey~=j.confirmation.plan.extraKey or plan.extraKey~=extraKey or preset.revision~=j.confirmation.revision then
        j.confirmation={plan=plan,presetName=preset.name,revision=preset.revision}; j.revision=preset.revision; j.name=preset.name
        j.originalPreset=KW.Copy(preset); j.missing=missing; j.selected={}; for slot in pairs(preset.slots) do j.selected[slot]=true end
        return self:Fail(KW.Problem("confirmationChanged"))
    end
    -- Consent covers fresh extras; bag-cell moves alone leave extraKey stable.
    j.missing=missing; j.confirmation=nil
    return self:Run(plan,j.kind=="apply" and "applying" or "preparingEdit")
end
function Instance:RejectConfirmation()
    local j=self.journal
    if not j or j.state~="confirming" then return nil,KW.Problem("invalidState") end
    self:Finish("cancelled"); return true
end
-- Retain the cause even if a subsequent rollback succeeds. This is written
-- only on failure, never on inventory polling, and contains equipment only.
function Instance:RecordEquipmentFailure(plan,state,startedAt,result)
    local api=self.inventory.api
    local snapshot=self.inventory:Capture(false)
    local locations={}
    local function locate(value)
        if value and value.kind=="item" then
            locations[value.uid]=KW.Copy(snapshot.byUid[value.uid] or {missing=true})
        end
    end
    for _,slot in ipairs(Slots.Order) do locate(plan.before[slot]); locate(plan.target[slot]) end
    local entries=self.saved.equipmentFailures or {}
    self.saved.equipmentFailures=entries
    entries[#entries+1]={state=state,phase=self.journal and self.journal.phase,
        presetId=self.journal and self.journal.presetId,status=result.status,problem=KW.Copy(result.problem),
        elapsedMs=self.runner.clock:NowMs()-startedAt,
        timestamp=api.GetTimeStamp and api.GetTimeStamp() or nil,
        sheathed=api.ArePlayerWeaponsSheathed and api.ArePlayerWeaponsSheathed(),werewolf=api.IsPlayerInWerewolfForm and api.IsPlayerInWerewolfForm() or false,
        combat=api.IsUnitInCombat("player"),dead=api.IsUnitDeadOrReincarnating("player"),blocking=api.IsBlockActive(),
        freeSlots=snapshot.freeSlots,actual=KW.Copy(result.actual or snapshot.worn),
        before=KW.Copy(plan.before),target=KW.Copy(plan.target),pending=KW.Copy(result.pending),locations=locations,
        confirmed=KW.Copy(result.confirmed),diagnostics=KW.Copy(result.diagnostics)}
    while #entries>5 do table.remove(entries,1) end
end
function Instance:Run(plan,state)
    local j=self.journal; j.state=state; j.phase=state; j.problem=nil; j.paused=false; j.confirmation=nil
    j.runState=state; j.runBefore=KW.Copy(plan.before); j.runTarget=KW.Copy(plan.target)
    self:Notify()
    -- A notification observer may deliberately pause/close before Start.
    if self.journal~=j or j.paused or j.state~=state then return true end
    local token={}; self.runToken=token
    local finished=false
    local startedAt=self.runner.clock:NowMs()
    local id,p=self.runner:Start(plan,function(progress)
        if self.journal~=j or self.runToken~=token then error("stale session progress") end
        j.operationId=progress.operationId; j.phase=progress.phase
        j.actual=KW.Copy(progress.actual)
        j.progress={operationId=progress.operationId,stage=progress.phase,completed=progress.completed,total=progress.total}
        if progress.phase=="requesting" then
            j.pending=KW.Copy(progress.pending); j.pendingBefore=KW.Copy(progress.actual)
            -- New runners supply the whole in-flight batch; legacy single-step
            -- journals/runners remain readable with the original boundary.
            j.pending.before=j.pending.before or KW.Copy(progress.actual)
            if not j.pending.expected then
                j.pending.expected=KW.Copy(progress.actual)
                j.pending.expected[j.pending.equipSlot]=j.pending.kind=="equip"
                    and {kind="item",uid=j.pending.uid,link=""} or {kind="empty"}
            end
            local pending=j.pending.batch and j.pending.batch[#j.pending.batch] or j.pending
            pending.source=pending.kind=="equip" and self.inventory:Resolve(pending.uid,true,"equipment") or nil
            if j.pending.batch and #j.pending.batch==1 then j.pending.source=KW.Copy(pending.source) end
        elseif progress.phase=="confirmed" then
            j.lastConfirmedStep=progress.stepId; j.pending=nil; j.pendingBefore=nil
        end
        self:Notify() -- requesting is durable in SavedVariables BEFORE native call
        if progress.phase=="requesting" and self.journal==j and self.runToken==token and j.pending then
            -- Observers may move a bag cell. The runner resolves its source after
            -- returning from this callback, so persist that same fresh location.
            local pending=j.pending.batch and j.pending.batch[#j.pending.batch] or j.pending
            pending.source=pending.kind=="equip" and self.inventory:Resolve(pending.uid,true,"equipment") or nil
            if j.pending.batch and #j.pending.batch==1 then j.pending.source=KW.Copy(pending.source) end
            self:Persist()
        end
    end,function(result)
        finished=true
        if self.journal~=j or self.runToken~=token then return end
        if result.status~="success" then self:RecordEquipmentFailure(plan,state,startedAt,result) end
        self.runToken=nil
        local pendingEvidence=j.pending
        j.pending=result.pending and KW.Copy(result.pending.batch and result.pending or pendingEvidence or result.pending) or nil
        if not j.pending then j.pendingBefore=nil end
        j.actual=KW.Copy(result.actual)
        if result.status=="success" then
            if state=="applying" then self:Finish("applied")
            elseif state=="preparingEdit" then j.state="editing"; j.phase="editing"; self:Notify()
            elseif j.partialRestore or #(j.unresolvedRequests or {})>0 then
                -- A separately verified restore may legitimately change the
                -- other slots while an older native request is unresolved.
                -- Advance only those observed slots; its destination, source
                -- release and displaced-item evidence remain outstanding.
                for _,pending in ipairs(j.unresolvedRequests or {}) do
                    if pending.expected then
                        local advanced=KW.Copy(pending.expected)
                        for _,slot in ipairs(Slots.Order) do
                            if slot~=pending.equipSlot then advanced[slot]=KW.Copy(result.actual[slot]) end
                        end
                        -- Restore may put this same UID back in another worn
                        -- slot. Keep the earlier valid boundary in that case:
                        -- duplicating it at the old destination would create an
                        -- impossible snapshot and invalidate the saved journal.
                        if mapValid(advanced,true) then pending.expected=advanced end
                    end
                end
                j.state="recovery"; j.phase="recovery"; j.paused=false
                j.problem=KW.Problem(j.partialRestore and "partialRestore" or "pendingRequest",{missing=j.recoveryMissing}); self:Notify()
            else self:Finish(j.saveCommitted and "saved" or "cancelled",j.failureProblem) end
        else
            j.state="recovery"; j.phase="recovery"; j.problem=result.problem or KW.Problem("recoveryRequired")
            self:Notify()
            -- Never undo external actions or speculative/unconfirmed requests.
            if result.status=="failed" and not result.pending and state~="restoring"
                and j.problem.code~="progressObserverError" and j.problem.code~="externalChange" and not j.paused then
                j.failureProblem=j.problem
                local restore=self:RestorePlan(false)
                if restore then self:Run(restore,"restoring") end
            end
        end
    end)
    -- Start may invoke onDone before returning. Do not resurrect its journal.
    if not id and not finished and self.journal==j then
        self:RecordEquipmentFailure(plan,state,startedAt,{status="rejected",problem=p})
        self.runToken=nil; j.state="recovery"; j.phase="recovery"; return self:Fail(p)
    end
    return true
end
function Instance:SetSelected(slot,value)
    local j,p=self:Editable(); if not j then return nil,p end
    if not Slots.IsSupported(slot) or type(value)~="boolean" then return nil,KW.Problem("invalidSlot",{slot=slot}) end
    j.selected[slot]=value; self:Notify(); return true
end
function Instance:SetName(name)
    local j,p=self:Editable(); if not j then return nil,p end
    local normalized,problem=KW.Presets.NormalizeName(name); if not normalized then return self:Fail(problem) end
    j.name=normalized; self:Notify(); return true
end
function Instance:ResolveMissing(slot,choice)
    local j,p=self:Editable(); if not j then return nil,p end
    if not j.missing[slot] then return nil,KW.Problem("invalidSlot",{slot=slot}) end
    local actual=self.inventory:Capture("equipment").worn[slot]
    if choice=="replace" then
        if actual.kind~="item" then return self:Fail(KW.Problem("replacementRequired",{slot=slot})) end
        j.selected[slot]=true
    elseif choice=="empty" then
        if actual.kind~="empty" then return self:Fail(KW.Problem("emptyRequired",{slot=slot})) end
        j.selected[slot]=true
    elseif choice=="omit" then j.selected[slot]=false
    else return self:Fail(KW.Problem("invalidMissingChoice")) end
    j.missing[slot]=nil; self:Notify(); return true
end
function Instance:RestorePlan(partial)
    local j=self.journal; local state=self.inventory:Capture("equipment"); local target=KW.Copy(j.original)
    local missing=self:MissingOriginal(state)
    j.recoveryMissing=missing
    if next(missing) and not partial then return nil,KW.Problem("originalItemsMissing",{missing=missing}) end
    if partial then
        -- Complete target for restore mode: preserve current contents of missing
        -- original slots, then overlay every available original and explicit empty.
        for slot in pairs(missing) do target[slot]=KW.Copy(state.worn[slot]) end
        -- If an available original currently occupies a missing original's slot,
        -- restoring it moves it away; don't request the same UID twice.
        local desired={}
        for slot,v in pairs(j.original) do if not missing[slot] and v.kind=="item" then desired[v.uid]=slot end end
        for slot in pairs(missing) do local v=target[slot]; if v.kind=="item" and desired[v.uid] then target[slot]={kind="empty"} end end
    end
    local plan,p=self.planner.Build(state,target,"restore",self.capabilities)
    if plan then j.partialRestore=next(missing)~=nil end
    return plan,p
end
function Instance:Save()
    local j,p=self:Editable(); if not j then return nil,p end
    local blocked=readiness(self.inventory); if blocked then return self:Fail(blocked) end
    for slot in pairs(j.missing) do if j.selected[slot] then return self:Fail(KW.Problem("unresolvedMissing",{slot=slot})) end end
    local name,problem=KW.Presets.NormalizeName(j.name); if not name then return self:Fail(problem) end
    if self.repo:NameExists(name,j.presetId) then return self:Fail(KW.Problem("duplicateName")) end
    local current=self.repo:Get(j.presetId)
    if (current and current.revision or 0)~=j.revision then return self:Fail(KW.Problem("revisionConflict")) end
    local captured=self.inventory:Capture("equipment"); local candidate={id=j.presetId,name=name,slots={}}
    for slot,selected in pairs(j.selected) do if selected then candidate.slots[slot]=KW.Copy(captured.worn[slot]) end end
    if not next(candidate.slots) then return self:Fail(KW.Problem("noSlotsSelected")) end
    local plan; plan,problem=self:RestorePlan(false); if not plan then return self:Fail(problem) end
    j.phase="locking"; j.commitCandidate=KW.Copy(candidate); self:Persist(); self.committing=true
    local locked,lockProblem=self.protection:Ensure(candidate.slots)
    self.committing=false
    if not locked then j.phase="editing"; return self:Fail(lockProblem) end
    if j.paused or self.journal~=j then return nil,KW.Problem("paused") end
    blocked=readiness(self.inventory); if blocked then j.phase="editing"; return self:Fail(blocked) end
    if not Slots.Equal(self.inventory:Capture("equipment").worn,captured.worn) then j.phase="editing"; return self:Fail(KW.Problem("externalChange")) end
    plan,problem=self:RestorePlan(false); if not plan then j.phase="editing"; return self:Fail(problem) end
    j.phase="committing"; self:Persist(); self.committing=true
    local completed,stored,saveProblem=pcall(self.repo.Save,self.repo,candidate,j.revision)
    self.committing=false
    if not completed then
        -- PresetsChanged is synchronous and fires after the repository write.
        -- An observer exception therefore cannot be interpreted as no commit.
        local committed=committedCandidate(self.repo,j)
        if committed then j.saveCommitted=true; j.committedRevision=committed.revision end
        j.state="recovery"; j.phase="recovery"
        return self:Fail(KW.Problem("commitObserverError",{saveCommitted=j.saveCommitted==true}))
    end
    if not stored then j.phase="editing"; return self:Fail(saveProblem) end
    j.saveCommitted=true; j.committedRevision=stored.revision; self:Persist()
    if j.paused then j.state="recovery"; self:Notify(); return true end
    return self:Run(plan,"restoring")
end
function Instance:Cancel()
    local j=self.journal
    if self.committing then return nil,KW.Problem("busy") end
    if not j then return nil,KW.Problem("invalidState") end
    if j.state=="confirming" then return self:RejectConfirmation() end
    if j.state~="editing" then return nil,KW.Problem("recoveryRequired") end
    local plan,p=self:RestorePlan(false); if not plan then return self:Fail(p) end
    return self:Run(plan,"restoring")
end
function Instance:Pause(reason)
    local j=self.journal
    if not j then return nil,KW.Problem("invalidState") end
    j.paused=true; j.resumeState=j.state; j.pauseActual=self.inventory:Capture("equipment").worn
    j.problem=KW.Problem(reason or "paused"); self:Persist()
    if self.runner:IsBusy() then self.runner:Stop(reason or "paused") end
    self:Notify(); return true
end
function Instance:Resume()
    local j=self.journal
    if not j or not j.paused or self.committing then return nil,KW.Problem("invalidState") end
    if j.pauseActual and not Slots.Equal(j.pauseActual,self.inventory:Capture("equipment").worn) then
        j.state="recovery"; return self:Fail(KW.Problem("externalChange"))
    end
    if j.state=="editing" or j.state=="confirming" then j.paused=false; j.problem=nil; self:Notify(); return true end
    return self:Recover("restore")
end
function Instance:ReconcilePending()
    local j=self.journal; local state=self.inventory:Capture("equipment"); local remaining={}
    local all=KW.Copy(j.unresolvedRequests or {})
    if j.pending then all[#all+1]=KW.Copy(j.pending); j.pending=nil; j.pendingBefore=nil end
    local requests={}
    for _,pending in ipairs(all) do
        if pending.batch then
            local compatible=pending.before~=nil and pending.expected~=nil
            local touched={}
            for _,member in ipairs(pending.batch) do for slot in pairs(member.effects or {[member.equipSlot]=true})do touched[slot]=true end end
            if compatible then
                for _,slot in ipairs(Slots.Order) do
                    local v=state.worn[slot]
                    local function same(other) return v.kind==other.kind and (v.kind=="empty" or v.uid==other.uid) end
                    if not same(pending.expected[slot]) and not (touched[slot] and
                        (v.kind=="empty" or same(pending.before[slot]))) then compatible=false; break end
                end
            end
            for _,member in ipairs(pending.batch) do
                local step=KW.Copy(member)
                step.before=KW.Copy(pending.before); step.expected=KW.Copy(pending.expected)
                if compatible then
                    -- Independent requests may finish in any order. Observe
                    -- each destination/source pair against the current state
                    -- of its siblings, retaining incomplete requests only.
                    local expected=KW.Copy(state.worn)
                    for slot,value in pairs(step.effects or {[step.equipSlot]=pending.expected[step.equipSlot]})do expected[slot]=KW.Copy(value)end
                    if mapValid(expected,true) then step.expected=expected end
                end
                requests[#requests+1]=step
            end
        else requests[#requests+1]=pending end
    end
    for _,step in ipairs(requests) do
        -- Destination-only observation is insufficient: the transfer may still
        -- be waiting for the source release or displaced item's backpack update.
        -- Legacy evidence without a complete boundary remains conservative.
        local observed=step.expected and step.before and Slots.Equal(state.worn,step.expected)
        if observed then
            observed=KW.EquipmentRunner.IsPendingConfirmed(self.inventory,
                {before=step.before,expected=step.expected,batch={step}},state)
        end
        if not observed then remaining[#remaining+1]=step end
    end
    j.unresolvedRequests=remaining; self:Persist()
end
-- A timeout stops dispatching, but does not cancel a native request. Accept
-- its eventual complete result without starting another equip/restore chain.
function Instance:CheckLateCompletion()
    local j=self.journal
    if not j or j.kind~="apply" or j.runState~="applying" or j.state~="recovery"
        or j.paused or self.committing or self.runner:IsBusy() then return end
    local code=j.problem and j.problem.code
    if code~="requestTimeout" and code~="requestError" then return end
    local actual=self.inventory:Capture(false).worn
    if not j.runTarget or not Slots.Equal(actual,j.runTarget) then return end
    self:ReconcilePending()
    if #j.unresolvedRequests==0 then self:Finish("applied") end
end
function Instance:Recover(action,expectedMissingKey)
    if self.committing or self.runner:IsBusy() then return nil,KW.Problem("busy") end
    if not self.journal and not self.invalidJournal then return nil,KW.Problem("invalidState") end
    if action=="keepCurrent" then self:Finish("keptCurrent"); return true end
    if self.invalidJournal then return nil,KW.Problem("invalidJournal") end
    if action~="restore" and action~="restoreAvailable" then return self:Fail(KW.Problem("invalidRecoveryAction")) end
    if action=="restoreAvailable" and expectedMissingKey~=nil then
        local _,key=self:MissingOriginal(self.inventory:Capture("equipment"))
        if key~=expectedMissingKey then return self:Fail(KW.Problem("recoveryChanged")) end
    end
    self:ReconcilePending()
    local plan,p=self:RestorePlan(action=="restoreAvailable")
    if not plan then return self:Fail(p) end
    return self:Run(plan,"restoring")
end


-- Explicit build services opt in to segmented sessions. Version1 gear journals
-- continue through the untouched legacy methods until their operation finishes.
local B={}
-- After reload, settled equipment work or a verified native refusal has no
-- request left to resume. Retain diagnostics and let the next click plan afresh.
-- Never replay paid operations or discard an editor draft during this cleanup.
function B:OnPlayerActivated()
 local j=self.journal
 if not j or j~=self.loadedJournal or j.kind~='apply' or j.state~='recovery'
  or self.committing or self.runner:IsBusy() or self.services.buildRunner:IsBusy()then return false end
 local pending=j.pending;local refusal
 local equipment=not j.maySent and (pending and (pending.kind=='equip' or pending.kind=='unequip') or j.phase=='equipment')
 local unsentEntry=j.maySent==false and j.requestStage=='entry' and pending and pending.sent==false
  and (pending.phase=='entry' or pending.phase=='cancelled' or pending.phase=='failed')
  and pending.original and (pending.original.skills or pending.original.bars)
 if not equipment and not unsentEntry then
  -- Older versions kept a confirmed attribute refusal as an unresolved send.
  -- Release only with the persisted server result AND unchanged live values.
  if not pending or pending.phase~='failed' or type(pending.result)~='number'
   or self.inventory.api.RESPEC_RESULT_SUCCESS==nil
   or pending.result==self.inventory.api.RESPEC_RESULT_SUCCESS
   or not pending.original or pending.original.health==nil then return false end
  local actual=self.services.attributes:Capture()
  if not actual or not KW.BuildModel.Matches({attributes=actual},{attributes=pending.original})then return false end
  refusal=KW.Problem('nativeRespecRefused',{domain='attributes',result=pending.result})
 end
 local api=self.inventory.api
 for _,name in ipairs({'GetSkillRespecCastTimeRemainingMs','GetAttributeRespecCastTimeRemainingMs'})do
  if type(api[name])=='function' and api[name]()~=0 then return false end
 end
 for _,domain in ipairs({'skills','attributes'})do
  if self.services[domain]:GetNativeOwnership()then return false end
 end
 self.saved.lastInterruptedBuild=KW.Copy(j)
 self.loadedJournal=nil
 self:Finish('interruptedApply',refusal)
 return true
end
function B:CaptureComponent(component)
 if type(self.services.capture)~='function'then return nil,nil,KW.Problem('invalidBuildSnapshot')end
 local snapshot,catalogue,problem=self.services.capture(component)
 if not snapshot then return nil,nil,problem or catalogue or KW.Problem('invalidBuildSnapshot')end
 return snapshot,catalogue
end
function B:IdleRequired(scope)
 if self.journal or self.invalidJournal or self.runner:IsBusy() or self.services.buildRunner:IsBusy() or self.committing then return nil,KW.Problem('busy')end
 if type(self.services.checkDrafts)~='function'then return nil,KW.Problem('buildCapabilityUnavailable')end
 return self.services.checkDrafts(scope)
end
function B:GetView()
 local j=self.journal
 if not j then return {state=self.invalidJournal and 'recovery' or 'idle',page=self.activePage,selected={},selection={},missing={},isEditor=self.invalidJournal==true,problem=KW.Copy(self.problem)}end
 local recovery,key
 if j.state=='recovery'then
  -- Page/layout readers must never run recovery preflight. Expose the action
  -- immediately; detailed choices are inspected only when that action is opened.
  local inspection=self.recoveryInspection
  if inspection and inspection.journal==j then recovery,key=inspection.recovery,inspection.key
  else recovery={needsInspection=true}end
 end
 return KW.Copy({recovery=recovery,recoveryKey=key,state=j.state,kind=j.kind,page=j.page or self.activePage,component=j.component,selection=j.selection,selected=j.selection and j.selection.equipment or {},draft=j.experiment,attributesEnabled=j.selection and j.selection.attributes,
  includedGroups=KW.BuildDraft.IncludedGroups(j.component,j.selection,j.originalPreset,j.clearedGroups),
  progress=j.progress,isEditor=j.kind~='apply',name=j.name,presetId=j.presetId,paused=j.paused,problem=j.problem,confirmation=j.confirmation,saved=j.saveCommitted==true,missing=j.missing or {}})
end
function B:GetRecoveryView()
 local j=self.journal;local revision=self.viewRevision
 if not j or j.state~='recovery'then return self:GetView()end
 local recovery,key,problem=self:RecoveryDetails()
 if not recovery then return nil,problem end
 if self.journal~=j or self.viewRevision~=revision then return nil,KW.Problem('recoveryChanged')end
 self.recoveryInspection={journal=j,recovery=recovery,key=key}
 return self:GetView()
end
function B:NewBuildJournal(kind,preset,snapshot,page,draft)
 local j={version=2,operation=kind=='apply' and 'apply' or 'editor',kind=kind,state='editing',phase='editing',page=page,component=kind~='apply' and KW.BuildDraft.Component(page) or nil,presetId=preset and preset.id,revision=preset and preset.revision,name=preset and preset.name,
  original=KW.BuildModel.Normalize(snapshot),originalPreset=preset and KW.BuildModel.Normalize(preset),saveCommitted=false,paused=false,selection=draft and draft:GetSelection(),experiment=draft and draft:GetBuild(),missing={}}
 j.target=draft and draft:GetBuild();self.draft=draft;self.journal=j;self.problem=nil;self:Persist();return j
end
function B:SyncDraft()
 local j=self.journal;local draft=self.draft;if not j or not draft then return nil,KW.Problem('invalidState')end
 local value,problem
 if j.component=='equipment'then value=self.inventory:Capture('equipment').worn
 else value,problem=self.services[j.component=='abilities' and 'skills' or 'attributes']:CaptureDraft()end
 if not value then return nil,problem or KW.Problem('nativeDraftUnavailable')end
 local ok;ok,problem=draft:Replace(value);if not ok then return nil,problem end
 j.experiment=draft:GetBuild();j.target=KW.Copy(j.experiment);j.selection=draft:GetSelection();return true
end
function B:DiscardOwned()
 local j=self.journal
 if j.component=='equipment' or j.component=='appearance'then return true end
 local adapter=self.services[j.component=='abilities' and 'skills' or 'attributes']
 local owner=adapter:GetNativeOwnership()
 if owner and owner.phase=='editor' and owner.token~=j.ownerToken then return nil,KW.Problem('recoveryChanged')end
 return adapter:DiscardDraft()
end
function B:RunBuild(plan,state,done)
 local j=self.journal;j.target=KW.Copy(plan.target);j.verification=KW.Copy(plan.verification);j.confirmed=KW.Copy(plan.confirmed or j.confirmed);j.budgets=nil;j.state=state;j.phase=state;j.problem=nil;j.progress=nil;self:Notify()
 if self.journal~=j or j.paused then return nil,KW.Problem('paused')end
 local accepted,problem=self.services.buildRunner:Start(plan,function(progress)
  if self.journal~=j or j.paused then error('stale build session progress')end
  j.progress={operationId=progress.operationId,phase=progress.phase,stage=progress.stage,completed=progress.completed,total=progress.total,ratio=progress.ratio}
  j.phase=progress.phase;j.pending=KW.Copy(progress.pending);j.confirmed=KW.Copy(progress.confirmed)
  -- dispatching is a conservative may-send checkpoint even while sent=false.
  j.requestStage=progress.stage;j.maySent=progress.stage=='dispatching' or progress.stage=='requesting' and progress.phase=='attributes' or progress.pending and progress.pending.sent==true or false
  local function persistSource()
   if progress.phase=='equipment' and progress.stage=='requesting' and j.pending and j.pending.batch then
    local member=j.pending.batch[#j.pending.batch]
    member.source=member.kind=='equip' and self.inventory:Resolve(member.uid,true,false)or nil
    if #j.pending.batch==1 then j.pending.source=KW.Copy(member.source)end
   end
  end
  j.actual=KW.Copy(progress.actual);persistSource();self:Persist();self.emit('SessionChanged',self:GetView())
  if self.journal==j and not j.paused then persistSource();self:Persist()end
 end,function(result)
  if self.journal~=j then return end
  if result.equipmentFailure then
   local f=result.equipmentFailure
   self:RecordEquipmentFailure(f.plan,state,f.startedAt,f.result)
  end
  j.pending=KW.Copy(result.pending);j.actual=KW.Copy(result.actual);j.confirmed=KW.Copy(result.confirmed);j.problem=result.problem
  if result.status=='applied'then if done then done()else self:Finish(state=='applying' and 'applied' or 'restored')end
  elseif state=='applying' and (j.kind=='apply' or j.saveCommitted and not self.draft)
   and result.pending and result.pending.resolved then
   -- Either the server result is verified or this request was never sent and
   -- local cleanup completed. No unresolved work remains to lock the session.
   self.saved.lastInterruptedBuild=KW.Copy(j)
   self:Finish('failed',result.problem)
  elseif state=='applying' and plan.requested.equipment and not plan.requested.abilities and not plan.requested.attributes
   and not result.pending and result.actual then
   -- All sent moves are settled. Keep their actual result, report the failure,
   -- and let the next click plan afresh instead of locking the whole addon.
   self:Finish('failed',result.problem)
  elseif result.status=='failed' and not result.pending and not next(result.confirmed or {})
   and result.actual and KW.BuildModel.Matches(result.actual,j.original)
   and (state=='applying' or state=='preparingEdit')then
   -- No unresolved native request and no changed actual: nothing to recover.
   self.draft=nil;self:Finish('failed',result.problem)
  else j.state='recovery';j.phase='recovery';j.paused=true;self:Notify()end
 end)
 if not accepted and self.journal==j then j.state='recovery';j.problem=problem;self:Notify()end
 return accepted,problem
end
function B:MountEditor()
 local j=self.journal
 if j.component=='equipment'then j.state='editing';j.phase='editing';self:Notify();return true end
 local adapter=self.services[j.component=='abilities' and 'skills' or 'attributes']
 local ok,problem=adapter:MountDraft(j.editorPlan.target[j.component],function(value,issue)
  if self.journal~=j then return end
  if not value then j.problem=issue;self:Notify();return end
  local replaced,err=self.draft:Replace(value);if not replaced then j.problem=err end
  j.experiment=self.draft:GetBuild();j.target=KW.Copy(j.experiment);self:Notify()
 end)
 if not ok then j.state='recovery';j.problem=problem;self:Notify();return nil,problem end
 j.ownerToken=adapter:GetNativeOwnership().token
 j.state='editing';j.phase='editing';self:Notify();return true
end
function B:BeginComponent(preset,page,kind,allowMissing)
 page=page or 'inventory';local component=KW.BuildDraft.Component(page);if not component then return self:Fail(KW.Problem('invalidEditorPage'))end
 local ok,problem=self:IdleRequired(component);if not ok then return nil,problem end
 local snapshot,catalogue;snapshot,catalogue,problem=self:CaptureComponent(component);if not snapshot then return self:Fail(problem)end
 local draft;draft,problem=KW.BuildDraft.New(snapshot,preset,page);if not draft then return self:Fail(problem)end
 local missing={}
 local intent={[component]=preset[component] or draft:GetBuild()[component]}
 if component=='equipment' and allowMissing then
  intent.equipment=KW.Copy(intent.equipment)
  for slot,ref in pairs(intent.equipment)do if ref.kind=='item' and not available(snapshot.equipmentState,ref)then missing[slot]=KW.Copy(ref);intent.equipment[slot]={kind='empty'}end end
 end
 if component=='abilities' and preset.id and preset.abilities and catalogue and catalogue.available then
  intent.abilities=KW.Copy(intent.abilities)
  local function unresolved(domain,key,ref,skillKey,id)
   local record=catalogue.byKey[skillKey]
   if not record or not record.available then
    missing[id]={domain=domain,key=key,ref=KW.Copy(ref),skillKey=skillKey,problem=KW.Problem('skillUnavailable',{skillKey=skillKey})}
    return true
   end
  end
  for key,ref in pairs(intent.abilities.skills or {})do
   if unresolved('skills',key,ref,key,'skill:'..key)then intent.abilities.skills[key]=nil end
  end
  for _,bar in ipairs({'front','back','werewolf'})do for slot,ref in pairs(intent.abilities.bars and intent.abilities.bars[bar]or {})do
   if ref.kind=='skill' and unresolved(bar,slot,ref,ref.skillKey,'bar:'..bar..':'..slot)then intent.abilities.bars[bar][slot]=nil end
  end end
  draft.unresolved=missing
 end
 if component=='abilities'then intent.abilities=KW.BuildDraft.AbilitiesForEditor(intent.abilities,catalogue)end
 local plan;plan,problem=self.services.buildPlanner.Build(snapshot,intent,catalogue,self.capabilities);if not plan then return self:Fail(problem)end
 draft:Replace(plan.target[component])
 self:NewBuildJournal(kind,preset,snapshot,page,draft)
 self.journal.missing=missing
 self.journal.editorPlan=KW.Copy(plan)
 self.journal.verification=KW.Copy(plan.verification)
 if #plan.extras>0 then self.journal.state='confirming';self.journal.confirmation={plan=KW.Copy(plan),action='mount',presetName=preset.name};self:Notify();return true end
 if component=='equipment' then return self:RunBuild(plan,'preparingEdit',function()self:SyncDraft();self:MountEditor()end)end
 return self:MountEditor()
end
function B:BeginNew(page)
 local name=KW.Text('NEW_PRESET');local index=2;while self.repo:NameExists(name)do name=KW.Text('NEW_PRESET')..' '..index;index=index+1 end
 return self:BeginComponent({name=name},page,'new')
end
function B:BeginEdit(id,allowMissing,page)
 local preset=self.repo:Get(id);if not preset then return self:Fail(KW.Problem('presetMissing'))end
 return self:BeginComponent(preset,page,'edit',allowMissing)
end
function B:Apply(id)
 local preset=self.repo:Get(id);if not preset then return self:Fail(KW.Problem('presetMissing'))end
 local ok,problem=self:IdleRequired(preset);if not ok then return nil,problem end
 local snapshot,catalogue;snapshot,catalogue,problem=self:CaptureComponent(preset);if not snapshot then return self:Fail(problem)end
 local plan;plan,problem=self.services.buildPlanner.Build(snapshot,preset,catalogue,self.capabilities);if not plan then return self:Fail(problem)end
 self:NewBuildJournal('apply',preset,snapshot,nil,nil)
 self.journal.target=KW.Copy(plan.target);self.journal.verification=KW.Copy(plan.verification)
 if #plan.extras>0 then self.journal.state='confirming';self.journal.confirmation={plan=KW.Copy(plan),action='apply',presetName=preset.name};self:Notify();return true end
 return self:RunBuild(plan,'applying')
end
function B:SetSelected(domain,key,value)
 local j,problem=self:Editable();if not j then return nil,problem end
 if type(domain)=='number'then value=key;key=domain;domain='equipment'end
 local ok;ok,problem=self.draft:SetSelected(domain,key,value);if not ok then return nil,problem end
 j.selection=self.draft:GetSelection();self:Notify();return true
end
function B:SetAttributesEnabled(value)
 local j,problem=self:Editable();if not j then return nil,problem end
 local ok;ok,problem=self.draft:SetAttributesEnabled(value);if not ok then return nil,problem end
 j.selection=self.draft:GetSelection();self:Notify();return true
end
function B:ClearPresetGroup(group)
 local j,problem=self:Editable();if not j then return nil,problem end
 local ok;ok,problem=self.draft:ClearSelection(group);if not ok then return nil,problem end
 j.clearedGroups=j.clearedGroups or {};j.clearedGroups[group]=true
 j.selection=self.draft:GetSelection();self:Notify();return true
end
function B:ResolveMissing(slot,choice)
 local j,problem=self:Editable();if not j then return nil,problem end
 if j.component~='equipment' or not j.missing[slot]then return nil,KW.Problem('invalidSlot')end
 local ref=self.inventory:Capture('equipment').worn[slot]
 if choice=='replace' and ref.kind~='item'then return self:Fail(KW.Problem('replacementRequired'))end
 if choice=='empty' and ref.kind~='empty'then return self:Fail(KW.Problem('emptyRequired'))end
 if choice~='replace' and choice~='empty' and choice~='omit'then return nil,KW.Problem('invalidMissingChoice')end
 self.draft:SetSelected('equipment',slot,choice~='omit');j.selection=self.draft:GetSelection();j.missing[slot]=nil;self:Notify();return true
end
function B:ResolveMissingAbility(id,choice,replacementKey)
 local j,problem=self:Editable();if not j then return nil,problem end
 local entry=j.component=='abilities' and j.missing[id]
 if not entry then return nil,KW.Problem('invalidMissingChoice')end
 if choice~='omit' and choice~='replace'then return nil,KW.Problem('invalidMissingChoice')end
 local native;native,problem=self.services.skills:CaptureDraft();if not native then return self:Fail(problem)end
 local domain,key=entry.domain,entry.key
 if choice=='replace'then
  if domain=='skills'then key=replacementKey end
  local value=domain=='skills' and native.skills and native.skills[key] or domain~='skills' and native.bars and native.bars[domain]and native.bars[domain][key]
  if not value or domain~='skills' and value.kind~='skill'then return self:Fail(KW.Problem('replacementRequired'))end
  local catalogue=self.services.skills:Catalogue();local record=catalogue.byKey[domain=='skills' and key or value.skillKey]
  if not record or not record.available then return self:Fail(KW.Problem('skillUnavailable'))end
 end
 self.draft:SetSelected(entry.domain,entry.key,false)
 j.missing[id]=nil;self.draft.unresolved=j.missing
 local ok;ok,problem=self.draft:Replace(native);if not ok then return self:Fail(problem)end
 if choice=='replace'then self.draft:SetSelected(domain,key,true)end
 j.experiment=self.draft:GetBuild();j.target=KW.Copy(j.experiment);j.selection=self.draft:GetSelection();self:Notify();return true
end
function B:EndEditor(outcome)
 local j=self.journal;local ok,problem=self:DiscardOwned()
 if not ok then j.state='recovery';j.paused=true;return self:Fail(problem)end
 if j.component=='equipment'then
  local snapshot,catalogue;snapshot,catalogue,problem=self:CaptureComponent('equipment');if not snapshot then return self:Fail(problem)end
  local plan;plan,problem=self.services.buildPlanner.Build(snapshot,{equipment=j.original.equipment},catalogue,self.capabilities);if not plan then return self:Fail(problem)end
  return self:RunBuild(plan,'restoring',function()self.draft=nil;self:Finish(outcome)end)
 end
 self.draft=nil;self:Finish(outcome);return true
end
function B:CommitComponent(apply)
 local j,problem=self:Editable();if not j then return nil,problem end
 local blocked=readiness(self.inventory);if blocked then return self:Fail(blocked)end
 local ok;ok,problem=self:SyncDraft();if not ok then return self:Fail(problem)end
 local snapshot,catalogue;snapshot,catalogue,problem=self:CaptureComponent(j.component);if not snapshot then return self:Fail(problem)end
 local experiment=self.draft:GetBuild();local plan
 for slot,entry in pairs(j.missing or {})do
  local selected=j.component=='abilities' and (entry.domain=='skills' and j.selection.skills[entry.key] or entry.domain~='skills' and j.selection.bars[entry.domain][entry.key]) or j.component=='equipment' and j.selection.equipment[slot]
  if selected then return self:Fail(KW.Problem('unresolvedMissing',{slot=slot}))end
 end
 -- Unchecked unavailable references remain visible for repair until completion,
 -- but are not part of the native experiment that Save and Apply can submit.
 local applyExperiment=experiment
 if apply and j.component=='abilities' and next(j.missing)then
  local native;native,problem=self.services.skills:CaptureDraft();if not native then return self:Fail(problem)end
  applyExperiment={abilities=native}
 end
 local name;name,problem=KW.Presets.NormalizeName(j.name);if not name then return self:Fail(problem)end
 j.name=name
 if not apply and j.component=='equipment'then
  local restore;restore,problem=self.services.buildPlanner.Build(snapshot,{equipment=j.original.equipment},catalogue,self.capabilities)
  if not restore then return self:Fail(problem)end
 end
 if apply then plan,problem=self.services.buildPlanner.Build(snapshot,applyExperiment,catalogue,self.capabilities);if not plan then return self:Fail(problem)end end
 local selected=self.draft:GetPresetBuild()
 for slot,ref in pairs(selected.equipment or {})do if ref.kind=='item' and not snapshot.equipmentState.byUid[ref.uid]then return self:Fail(KW.Problem('unresolvedMissing',{slot=slot}))end end
 local normalized;normalized,problem=KW.BuildDraft.PresetCandidate(j.originalPreset,j.component,selected,j.clearedGroups)
 if not normalized or not KW.BuildModel.HasParts(normalized)then return self:Fail(problem or KW.Problem('invalidPreset'))end
 normalized.name=j.name
 local patches={}
 for _,part in ipairs({'equipment','abilities','attributes'})do patches[part]=normalized[part] and {op='replace',value=normalized[part]}or {op='remove'}end
 if self.repo:NameExists(j.name,j.presetId)then return self:Fail(KW.Problem('duplicateName'))end
 local current=j.presetId and self.repo:Get(j.presetId);if current and current.revision~=j.revision then return self:Fail(KW.Problem('revisionConflict'))end
 j.commitCandidate=KW.Copy(normalized);j.phase='locking';self:Persist();self.committing=true
 local protected,lockProblem=self.protection:EnsureBuild(normalized);self.committing=false
 if not protected then j.phase='editing';return self:Fail(lockProblem)end
 if self.journal~=j or j.paused then return nil,KW.Problem('paused')end
 local before=experiment;ok,problem=self:SyncDraft();if not ok then return self:Fail(problem)end
 if not KW.BuildModel.Matches(j.experiment,before) or not KW.BuildModel.Matches(before,j.experiment)then return self:Fail(KW.Problem('externalChange'))end
 blocked=readiness(self.inventory);if blocked then return self:Fail(blocked)end
 if apply then
  local fresh,cat;fresh,cat,problem=self:CaptureComponent(j.component);if not fresh then return self:Fail(problem)end
  local checked;checked,problem=self.services.buildPlanner.Build(fresh,applyExperiment,cat,self.capabilities)
  if not checked then return self:Fail(problem)end
  if checked.fingerprint~=plan.fingerprint then return self:Fail(KW.Problem('buildStateChanged'))end
  plan=checked
 end
 j.phase='committing';self:Persist();self.committing=true
 local completed,stored,err=pcall(self.repo.PatchComponents,self.repo,j.presetId,patches,j.name,j.revision,function(canonical)
  j.presetId=canonical.id;j.revision=canonical.revision;j.committedRevision=canonical.revision;j.commitCandidate=KW.Copy(canonical);j.saveCommitted=true;self:Persist()
 end)
 self.committing=false
 if not completed then j.state='recovery';j.paused=true;return self:Fail(KW.Problem('commitObserverError',{saveCommitted=j.saveCommitted}))end
 if not stored then j.phase='editing';return self:Fail(err)end
 if self.journal~=j or j.paused then return true end
 if not apply then return self:EndEditor('saved')end
 ok,problem=self:DiscardOwned();if not ok then j.state='recovery';j.paused=true;return self:Fail(problem)end
 self.draft=nil
 if #plan.extras>0 then j.state='confirming';j.confirmation={action='saveApply',plan=KW.Copy(plan),presetName=j.name};self:Notify();return true end
 return self:RunBuild(plan,'applying')
end
function B:Save()return self:CommitComponent(false)end
function B:SaveAndApply()return self:CommitComponent(true)end
function B:Cancel()
 if self.committing then return nil,KW.Problem('busy')end
 local j=self.journal;if not j then return nil,KW.Problem('invalidState')end
 if j.state~='editing' and j.state~='confirming'then return nil,KW.Problem('recoveryRequired')end
 if j.kind=='apply'then self:Finish('cancelled');return true end
 return self:EndEditor('cancelled')
end
function B:Confirm(key)
 local j=self.journal;if not j or j.state~='confirming' or j.paused then return nil,KW.Problem('invalidState')end
 if j.presetId then
  local stored=self.repo:Get(j.presetId)
  if not stored then return self:Fail(KW.Problem('presetMissing'))end
  if stored.revision~=j.revision then return self:Fail(KW.Problem('revisionConflict'))end
 end
 local old=j.confirmation.plan;local snapshot,catalogue,problem=self:CaptureComponent(j.component or old.requested)
 if not snapshot then return self:Fail(problem)end
 local plan
 if old.confirmed then plan,problem=self.services.buildPlanner.RevalidateRemaining(old,snapshot,catalogue,old.confirmed)
 else plan,problem=self.services.buildPlanner.Revalidate(old,snapshot,catalogue)end
 if not plan then return self:Fail(problem)end
 if key~=old.extraKey or plan.fingerprint~=old.fingerprint then j.confirmation.plan=KW.Copy(plan);return self:Fail(KW.Problem('confirmationChanged'))end
 local action=j.confirmation.action;j.confirmation=nil
 if action=='mount'then
  if j.component=='equipment'then return self:RunBuild(plan,'preparingEdit',function()self:SyncDraft();self:MountEditor()end)end
  return self:MountEditor()
 end
 return self:RunBuild(plan,'applying')
end
function B:RejectConfirmation()return self:Cancel()end
function B:QuickSave()
 local ok,problem=self:IdleRequired();if not ok then return nil,problem end
 local snapshot,catalogue;snapshot,catalogue,problem=self:CaptureComponent();if not snapshot then return self:Fail(problem)end
 if not snapshot.equipment or not snapshot.abilities or not snapshot.attributes then return self:Fail(KW.Problem('buildCapabilityUnavailable',{component='fullQuickCapture'}))end
 self.committing=true;local locked,err=self.protection:EnsureBuild(snapshot);self.committing=false;if not locked then return self:Fail(err)end
 local fresh;fresh,catalogue,problem=self:CaptureComponent();if not fresh then return self:Fail(problem)end
 if not KW.BuildModel.Matches(snapshot,fresh) or not KW.BuildModel.Matches(fresh,snapshot)then return self:Fail(KW.Problem('externalChange'))end
 local build;build,problem=KW.BuildModel.Normalize(snapshot);if not build then return self:Fail(problem)end
 -- The werewolf ultimate is a native binding, not a user-assignable slot.
 -- Keep editable WW slots in quick saves without turning native locks into
 -- preset assertions (or including this bar on a non-werewolf character).
 local wolf=build.abilities.bars and build.abilities.bars.werewolf
 if wolf then
  for slot,metadata in pairs(catalogue.barMetadata.werewolf or {})do
   if metadata.eligible==false or metadata.locked or not metadata.mutable or metadata.override or metadata.runtimeOverride then wolf[slot]=nil end
  end
  if not next(wolf)then build.abilities.bars.werewolf=nil end
 end
 ok,problem=self:IdleRequired();if not ok then return self:Fail(problem)end
 self.committing=true
 local completed,stored,saveProblem=pcall(self.repo.SaveQuick,self.repo,build)
 self.committing=false
 if not completed then return self:Fail(KW.Problem('commitObserverError'))end
 if not stored then return self:Fail(saveProblem)end
 self:Notify();self.emit('SessionFinished',{outcome='quickSaved',saved=true});return true
end
function B:Pause(reason)
 local j=self.journal;if not j then return nil,KW.Problem('invalidState')end
 j.paused=true;j.state='recovery';j.problem=KW.Problem(reason or 'paused');self:Persist()
 if self.services.buildRunner:IsBusy()then self.services.buildRunner:Stop(reason)end
 self:Notify();return true
end
function B:CheckLateCompletion()
 local j=self.journal
 if not j or j.state~='recovery' or self.committing or self.runner:IsBusy() or self.services.buildRunner:IsBusy()then return end
 local code=j.problem and j.problem.code
 if code=='sheathTimeout' and not j.pending and not next(j.confirmed or {})then
  local state=self.inventory:Capture(false)
  if j.original.equipment and Slots.Equal(state.worn,j.original.equipment)then self.draft=nil;self:Finish('failed',j.problem)end
  return
 end
 -- Only resume a pure equipment Apply. Never infer paid native allocation
 -- outcomes from item events, or silently finish a partially mounted editor.
 if j.kind~='apply' or not j.target.equipment or j.target.abilities or j.target.attributes then return end
 local state=self.inventory:Capture(false)
 if not KW.EquipmentRunner.IsPendingConfirmed(self.inventory,j.pending,state)then return end
 j.pending=nil;j.paused=false
 -- A later request in a batch may be rejected while earlier ones are still
 -- arriving. Once those settle, release Apply without retrying the rejection.
 if code~='requestTimeout' and code~='requestError'then self:Finish('failed',j.problem);return true end
 if Slots.Equal(state.worn,j.target.equipment)then self:Finish('applied');return true end
 local snapshot,catalogue,problem=self:CaptureComponent('equipment')
 if not snapshot then return self:Fail(problem)end
 local plan;plan,problem=self.services.buildPlanner.Build(snapshot,{equipment=j.target.equipment},catalogue,self.capabilities)
 if not plan then return self:Fail(problem)end
 if #plan.extras>0 then return self:Fail(KW.Problem('confirmationChanged'))end
 return self:RunBuild(plan,'applying')
end
function B:Resume()return nil,KW.Problem('recoveryRequired')end
local function pendingDomain(j)
 local p=j.pending
 if not p then return end
 if p.original and (p.original.skills or p.original.bars)then return 'skills','abilities'end
 if p.original and p.original.health~=nil then return 'attributes','attributes'end
 if j.phase=='skills' or p.domain=='skills'then return 'skills','abilities'end
 if j.phase=='attributes' or p.domain=='attributes'then return 'attributes','attributes'end
end
function B:RecoveryDetails()
 local j,problem=KW.BuildJournal.Read(self.journal,self.repo)
 if not j then return nil,nil,problem end
 local ok,snapshot,catalogue,issue=pcall(self.CaptureComponent,self,j.component or j.target)
 if not ok or not snapshot then return nil,nil,issue or KW.Problem('invalidBuildSnapshot')end
 local actual=KW.BuildModel.Normalize(snapshot);if not actual then return nil,nil,KW.Problem('invalidBuildSnapshot')end
 local reconciliation=KW.BuildJournal.Reconcile(j,actual)
 local domain=pendingDomain(j);local facts
 if domain then
  facts,problem=self.services[domain]:GetRecoveryFacts(j.pending)
  if not facts then return nil,nil,problem end
 end
 local aux=j.verification and j.verification.auxiliaryTarget or j.pending and j.pending.auxiliaryTarget
 local auxiliary
 if aux and next(aux)then
  auxiliary=self.services.skills:GetRecoveryFacts({auxiliaryTarget=aux})
  if not auxiliary or KW.BuildJournal.Key(auxiliary.auxiliaryActual)~=KW.BuildJournal.Key(aux)then
   reconciliation.confirmed.abilities=nil;reconciliation.remaining.abilities=KW.Copy(j.target and j.target.abilities)
  end
 end
 reconciliation.actions={'confirmActualTarget','acceptCurrent'}
 if not reconciliation.unresolved then
  reconciliation.actions[#reconciliation.actions+1]='remaining'
  if j.original.equipment then reconciliation.actions[#reconciliation.actions+1]='restore'end
 end
 if domain=='skills' and not j.resolution then
  local state=self.services.skills:GetSubmissionState()
  if not state.sent and not state.resolved and state.cancelledGeneration and state.token==j.pending.token then
   reconciliation.actions[#reconciliation.actions+1]='relinquishUnsent'
  end
 end
 local key=KW.BuildJournal.Key({journal=j,actual=actual,budgets=snapshot.budgets,facts=facts,auxiliary=auxiliary})
 return reconciliation,key,nil,{snapshot=snapshot,catalogue=catalogue,actual=actual,facts=facts,auxiliary=auxiliary,reconciliation=reconciliation,journal=j,domain=domain}
end
function B:Recover(action,expectedKey)
 if self.committing or self.runner:IsBusy() or self.services.buildRunner:IsBusy()then return nil,KW.Problem('busy')end
 if self.invalidJournal then return nil,KW.Problem('invalidJournal')end
 local j=self.journal;if not j or j.state~='recovery'then return nil,KW.Problem('invalidState')end
 local recovery,key,problem,context=self:RecoveryDetails()
 if not recovery then return self:Fail(problem)end
 if expectedKey~=key then return nil,KW.Problem('recoveryChanged')end
 local stored,invalid=KW.BuildJournal.Read(self.saved.journal,self.repo)
 if not stored or KW.BuildJournal.Key(stored)~=KW.BuildJournal.Key(context.journal)then return nil,invalid or KW.Problem('recoveryChanged')end
 local storageKey=KW.BuildJournal.Key(stored)
 if action=='remaining' or action=='restore' then
  if recovery.unresolved then return self:Fail(KW.Problem('buildSubmissionUnresolved'))end
  local blocked=readiness(self.inventory);if blocked then return self:Fail(blocked)end
  local clean,issue=self.services.checkDrafts();if not clean then return self:Fail(issue)end
  local wanted=action=='restore' and {equipment=j.original.equipment} or recovery.remaining
  if action=='restore' and not wanted.equipment then return self:Fail(KW.Problem('invalidRecoveryAction'))end
  local plan;plan,problem=self.services.buildPlanner.Build(context.snapshot,wanted,context.catalogue,self.capabilities)
  if not plan then return self:Fail(problem)end
  if action=='remaining'then
   local confirmed=KW.Copy(j.confirmed or {})
   if confirmed.abilities then confirmed.skills=true;confirmed.abilities=nil end
   for component,done in pairs(recovery.confirmed)do
    if done then confirmed[component=='abilities' and 'skills' or component]=true end
   end
   for phase,done in pairs(confirmed)do
    if done then
     local component=phase=='skills' and 'abilities' or phase
     if not recovery.confirmed[component] or not j.target or not j.target[component]then return self:Fail(KW.Problem('confirmedBuildMismatch',{domain=component}))end
     plan.requested[component]=KW.Copy(j.target[component]);plan.target[component]=KW.Copy(j.target[component])
    end
   end
   plan.confirmed=confirmed
   if confirmed.skills then
    plan.verification=plan.verification or {}
    plan.verification.auxiliaryTarget=KW.Copy(j.verification and j.verification.auxiliaryTarget or j.pending and j.pending.auxiliaryTarget or {})
   end
   plan,problem=self.services.buildPlanner.RevalidateRemaining(plan,context.snapshot,context.catalogue,confirmed)
   if not plan then return self:Fail(problem)end
  end
  local _,freshKey=self:RecoveryDetails()
  if self.journal~=j or freshKey~=key or KW.BuildJournal.Key(self.saved.journal)~=storageKey then return nil,KW.Problem('recoveryChanged')end
  -- A deliberate new operation gets a fresh journal and fresh request tokens.
  self.draft=nil;self:NewBuildJournal('apply',{name=j.name,id=j.presetId,revision=j.revision},context.snapshot,nil,nil)
  self.journal.target=KW.Copy(plan.target);self.journal.verification=KW.Copy(plan.verification);self.journal.confirmed=KW.Copy(plan.confirmed)
  if #plan.extras>0 then self.journal.state='confirming';self.journal.confirmation={plan=KW.Copy(plan),action='apply',presetName=j.name};self:Notify();return true end
  return self:RunBuild(plan,'applying')
 end
 if action~='confirmActualTarget' and action~='acceptCurrent' and action~='relinquishUnsent'then return self:Fail(KW.Problem('invalidRecoveryAction'))end
 local resolution;self.committing=true
 local succeeded,err,refusal=pcall(function()
  if context.domain and not j.resolution then
   local adapter=self.services[context.domain]
   if action=='relinquishUnsent'then
    if context.domain~='skills'then return nil,KW.Problem('invalidRecoveryAction')end
    return adapter:RelinquishUnsentDraft(j.pending)
   end
   return adapter:ReconcileSubmission(j.pending,action=='confirmActualTarget' and 'actualTarget' or 'acceptCurrent',context.facts)
  end
  if action=='relinquishUnsent'then return nil,KW.Problem('invalidRecoveryAction')end
  if action=='confirmActualTarget' and next(recovery.remaining)then return nil,KW.Problem('buildSubmissionUnresolved')end
  if self.draft then
   local released,issue=self:DiscardOwned();if not released then return nil,issue end
  elseif j.component and j.component~='equipment' then
   local adapter=self.services[j.component=='abilities' and 'skills' or 'attributes']
   local descriptor={original=j.original[j.component],target=(j.target or j.experiment or j.original)[j.component],auxiliaryTarget=j.verification and j.verification.auxiliaryTarget}
   local facts,issue=adapter:GetRecoveryFacts(descriptor);if not facts then return nil,issue end
   return adapter:ReconcileSubmission(descriptor,action=='confirmActualTarget' and 'actualTarget' or 'acceptCurrent',facts)
  elseif j.target and (j.target.abilities or j.target.attributes) then
   local clean,issue=self.services.attributes:RecoveryGuard();if not clean then return nil,issue end
   local blocked=self.services.skills:RecoveryGuard();if blocked then return nil,blocked end
   local global=self.services.skills.api.SKILLS_AND_ACTION_BAR_MANAGER
   if global and (KW.SkillState.HasPendingChanges(self.services.skills.api) or global.isDirty)then return nil,KW.Problem('foreignSkillDraft')end
  else
   local api=self.inventory.api
   for _,name in ipairs({'GetSkillRespecCastTimeRemainingMs','GetAttributeRespecCastTimeRemainingMs'})do
    if type(api[name])=='function' and api[name]()~=0 then return nil,KW.Problem('buildSubmissionUnresolved')end
   end
  end
  return {resolution=action,nativeOutcome='unknown',released=true}
 end)
 self.committing=false
 if not succeeded then return self:Fail(KW.Problem('buildSubmissionUnresolved',{reason=tostring(err)}))end
 resolution=err
 if not resolution then
  return self:Fail(refusal or KW.Problem('buildSubmissionUnresolved'))
 end
 local _,freshKey,issue,fresh=self:RecoveryDetails()
 if self.journal~=j or freshKey~=key or KW.BuildJournal.Key(self.saved.journal)~=storageKey then
  if self.journal==j then
   j.resolution=resolution;j.state='recovery';j.paused=true
   if KW.BuildJournal.Key(self.saved.journal)==storageKey then self:Notify()
   else self.emit('SessionChanged',self:GetView())end
  end
  return nil,issue or KW.Problem('recoveryChanged')
 end
 j.resolution=resolution;j.relinquished=resolution.retainedForeignDraft==true;j.paused=true;self.draft=nil
 local reconciled=fresh.reconciliation;j.confirmed=j.confirmed or {}
 for component,done in pairs(reconciled.confirmed)do if done then j.confirmed[component]=true end end
 if j.confirmed.abilities then j.confirmed.skills=true;j.confirmed.abilities=nil end
 local remaining=reconciled.remaining
 if action=='relinquishUnsent'then j.problem=KW.Problem('recoveryRequired');self:Notify();return true end
 if action=='acceptCurrent' or not next(remaining)then self:Finish('reconciled');return true end
 j.problem=KW.Problem('recoveryRequired');self:Notify();return true
end
function B:GetNativeOwnership()
 local out={}
 for _,domain in ipairs({'skills','attributes'})do
  local adapter=self.services[domain]
  local owner=adapter and adapter:GetNativeOwnership()
  if owner then out[domain]=owner end
 end
 local j=self.journal
 if j and not self.invalidJournal and j.version==2 and j.maySent and not j.resolution and not j.relinquished then
  local domain=pendingDomain(j)
  if domain and not out[domain]then out[domain]={token=j.pending.token,phase='recovery',page=domain=='skills' and 'skills' or 'stats',possibleSent=true}end
 end
 return out
end
function B:SwitchPage(page)
 if not KW.BuildDraft.Component(page)then return nil,KW.Problem('invalidEditorPage')end
 if self.committing then return nil,KW.Problem('busy')end
 if type(self.services.requestPage)~='function'then return nil,KW.Problem('buildCapabilityUnavailable')end
 return self.services.requestPage(page)
end
function B:OnNativePageState(page,state)
 if not KW.BuildDraft.Component(page)then return nil,KW.Problem('invalidEditorPage')end
 local j=self.journal
 if state=='showing'then self.activePage=page;self:Notify();return true end
 if state~='hiding' or not j or j.kind=='apply' or j.page~=page then return true end
 if j.state=='editing' or j.state=='confirming'then
  if j.component~='equipment' then
   local adapter=self.services[j.component=='abilities' and 'skills' or 'attributes']
   local owner=adapter:GetNativeOwnership()
   if owner and owner.phase=='editor' then
    local api=adapter.api
    local native=j.component=='abilities' and api.SKILLS_AND_ACTION_BAR_MANAGER or api.STATS
    local mode=j.component=='abilities' and native:GetSkillPointAllocationMode() or native:GetAttributePointAllocationMode()
    local purchase=j.component=='abilities' and api.SKILL_POINT_ALLOCATION_MODE_PURCHASE_ONLY or api.ATTRIBUTE_POINT_ALLOCATION_MODE_PURCHASE_ONLY
    if mode==purchase then
     local clean,problem=adapter:ReleaseAfterNativeExit(j.ownerToken,j.original[j.component])
     if not clean then j.state='recovery';j.paused=true;return self:Fail(problem)end
    end
   end
  end
  if j.component=='equipment'then return self:Pause('recoveryRequired')end
  return self:Cancel()
 end
 return true
end
for name,method in pairs(B)do
 local legacy=Instance[name]
 Instance[name]=function(self,...)
  if self.services and (not self.journal or self.journal.version==2)then return method(self,...)end
  if legacy then return legacy(self,...)end
  return nil,KW.Problem('buildCapabilityUnavailable')
 end
end
