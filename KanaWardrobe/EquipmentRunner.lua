local KW=KanaWardrobe
local Runner={}; KW.EquipmentRunner=Runner
local Instance={}; Instance.__index=Instance
local function readiness(self)
    local api=self.inventory.api
    if api.IsUnitInCombat("player") then return KW.Problem("inCombat") end
    if api.IsUnitDeadOrReincarnating("player") then return KW.Problem("dead") end
    if api.IsBlockActive() then return KW.Problem("blocking") end
end
local function same(a,b)
    return a and b and a.kind==b.kind and (a.kind~="item" or a.uid==b.uid)
end
local function isWeapon(slot)
    return slot==EQUIP_SLOT_MAIN_HAND or slot==EQUIP_SLOT_OFF_HAND
        or slot==EQUIP_SLOT_BACKUP_MAIN or slot==EQUIP_SLOT_BACKUP_OFF
end
function Instance:Diagnostics(op)
    local api=self.inventory.api
    local out={wieldAttempt=KW.Copy(op.wieldAttempt),slots={}}
    for _,name in ipairs({'ArePlayerWeaponsSheathed','IsPlayerInWerewolfForm','GetActiveWeaponPairInfo','GetInteractionType'}) do
        if type(api[name])=='function' then local ok,v=pcall(api[name]);if ok then out[name]=v end end
    end
    if type(api.GetWornItemInfo)=='function' then
        for _,step in ipairs(op.active and op.active.batch or {}) do
            if isWeapon(step.equipSlot) then
                local ok,hasItem,_,heldSlot,heldNow,locked=pcall(api.GetWornItemInfo,api.BAG_WORN,step.equipSlot)
                if ok then out.slots[step.equipSlot]={hasItem=hasItem,heldSlot=heldSlot,heldNow=heldNow,locked=locked} end
            end
        end
    end
    return out
end
function Runner.New(inventory,events,clock)
    return setmetatable({inventory=inventory,events=events,clock=clock,generation=0},Instance)
end
function Instance:IsBusy() return self.operation~=nil end
function Instance:Finish(op,status,problem,state)
    if self.operation~=op then return end
    self.operation=nil
    for handle in pairs(op.timers) do self.clock:Cancel(handle) end
    for _,handle in ipairs(op.listeners) do self.events:Unsubscribe(handle) end
    local result={status=status,problem=problem,actual=KW.Copy((state or self.inventory:Capture(false)).worn),
        pending=KW.Copy(op.active),diagnostics=status~='success' and self:Diagnostics(op) or nil}
    if op.onDone then op.onDone(result) end
end
function Instance:Later(op,delay,callback)
    local handle
    handle=self.clock:Schedule(delay,function()
        op.timers[handle]=nil
        if self.operation==op then callback() end
    end)
    op.timers[handle]=true
    return handle
end
function Instance:Progress(op,phase,state)
    if op.onProgress then
        local ok=pcall(op.onProgress,{operationId=op.id,stepId=phase=="confirmed" and op.confirmedIndex or op.index,phase=phase,completed=op.completed or 0,total=#op.plan.steps,actual=KW.Copy(state.worn),pending=KW.Copy(op.pending)})
        if self.operation~=op then return nil end
        if not ok then
            self:Finish(op,"failed",KW.Problem("progressObserverError",{phase=phase}))
            return nil
        end
    end
    -- Observers persist the journal, but can also synchronously change live
    -- inventory/readiness. Never reuse their incoming snapshot to dispatch or
    -- report success after the observer returns.
    if self.operation~=op then return nil end
    state=self.inventory:Capture(false)
    local problem=readiness(self)
    if problem then self:Finish(op,"interrupted",problem,state); return nil end
    if not self:Compatible(op,state) then
        self:Finish(op,"interrupted",KW.Problem("externalChange"),state); return nil
    end
    return state
end
function Instance:QueueCheck(op)
    if self.operation~=op or op.checkTimer then return end
    op.checkTimer=self:Later(op,1,function() op.checkTimer=nil; self:Check(op) end)
end
-- Requests in a batch touch distinct slots. Each can independently be old,
-- temporarily empty, or final; untouched slots must stay exactly unchanged.
function Instance:Compatible(op,state)
    local active=op.active
    if not active then return KW.Slots.Equal(state.worn,op.expected) end
    local touched={}
    for _,step in ipairs(active.batch) do touched[step.equipSlot]=true end
    for _,slot in ipairs(KW.Slots.Order) do
        local actual=state.worn[slot]
        if touched[slot] then
            if not actual or actual.kind~="empty" and not same(actual,active.before[slot])
                and not same(actual,op.expected[slot]) then return false end
        elseif not same(actual,op.expected[slot]) then return false end
    end
    return true
end
local function memberReleased(self,active,step,state)
    if step.kind=="unequip" then
        local location=state.byUid[step.uid]
        if not location or location.bagId~=self.inventory.api.BAG_BACKPACK then return false end
    else
        if step.source then
            local source=self.inventory:ReadSlot(step.source.bagId,step.source.slotIndex)
            if source and source.uid==step.uid then return false end
        end
        local displaced=active.before[step.equipSlot]
        if displaced.kind=="item" and displaced.uid~=step.uid then
            local location=state.byUid[displaced.uid]
            if not location or location.bagId~=self.inventory.api.BAG_BACKPACK then return false end
        end
    end
    return true
end
local function released(self,active,state)
    for _,step in ipairs(active.batch) do
        if not memberReleased(self,active,step,state) then return false end
    end
    return true
end
-- Like WW's first recovery step, nudge a stalled weapon request once. Do not
-- gate dispatch on the global sheathing flag or replay an unacknowledged move:
-- a late swap could otherwise move the displaced item back into the slot.
function Instance:AssistWeapon(op,state)
    if op.wieldAttempt or self.clock:NowMs()-op.requestAt<1500 then return false end
    local api=self.inventory.api
    if type(api.ArePlayerWeaponsSheathed)~='function' or type(api.TogglePlayerWield)~='function'
        or api.ArePlayerWeaponsSheathed() then return false end
    for _,step in ipairs(op.active.batch) do
        if isWeapon(step.equipSlot) and not same(state.worn[step.equipSlot],op.expected[step.equipSlot]) then
            op.wieldAttempt={at=self.clock:NowMs(),equipSlot=step.equipSlot}
            op.issuing=true
            local ok,err=pcall(api.TogglePlayerWield)
            op.issuing=false
            op.wieldAttempt.ok=ok
            if not ok then op.wieldAttempt.error=tostring(err) end
            if self.operation~=op then return true end
            op.active.wieldAttempt=KW.Copy(op.wieldAttempt);op.pending=op.active
            if op.stopReason then self:Finish(op,'interrupted',op.stopReason);return true end
            self:Progress(op,'waiting',self.inventory:Capture(false))
            self:QueueCheck(op)
            return true
        end
    end
    return false
end
local function timeoutProblem(self,op,state)
    local items={}
    for _,step in ipairs(op.active.batch) do
        if not same(state.worn[step.equipSlot],op.expected[step.equipSlot]) or not memberReleased(self,op.active,step,state) then
            items[#items+1]={equipSlot=step.equipSlot,uid=step.uid,kind=step.kind,link=step.link,
                actual=KW.Copy(state.worn[step.equipSlot]),source=KW.Copy(state.byUid[step.uid])}
        end
    end
    return KW.Problem('requestTimeout',{items=items})
end
function Runner.IsPendingConfirmed(inventory,pending,state)
    return pending and pending.batch and pending.expected and pending.before
        and KW.Slots.Equal(state.worn,pending.expected) and released({inventory=inventory},pending,state) or false
end
-- The planner fences source moves, weapon/mythic conflicts and scarce bag
-- space. Independent requests in one batch go out without a per-item delay.
-- Older plans without batch IDs retain the conservative single-request path.
function Instance:CanAppend(op,step,state)
    if not op.active then return true end
    -- Also fence older/cached plans: the implicit bag destination of an
    -- unequip request is not reserved against another outstanding move.
    if step.kind=='unequip' then return false end
    if not step.batchId or step.batchId~=op.active.batchId then return false end
    local reserved=step.spaceCost or 0
    for _,member in ipairs(op.active.batch) do
        if member.kind=='unequip' then return false end
        if member.equipSlot==step.equipSlot then return false end
        reserved=reserved+(member.spaceCost or 0)
    end
    return reserved<=math.min(op.active.freeSlots,state.freeSlots)
end
function Instance:Check(op)
    if self.operation~=op then return end
    if op.issuing then self:QueueCheck(op); return end
    local state=self.inventory:Capture(false)
    local problem=readiness(self)
    if problem then self:Finish(op,"interrupted",problem,state); return end
    if not self:Compatible(op,state) then self:Finish(op,"interrupted",KW.Problem("externalChange"),state); return end
    if op.active then
        if KW.Slots.Equal(state.worn,op.expected) and released(self,op.active,state) then
            op.active=nil; op.pending=nil; op.confirmedIndex=op.index-1
            op.completed=op.confirmedIndex
            state=self:Progress(op,"confirmed",state)
            if not state then return end
        elseif self.clock:NowMs()-op.requestAt>=5000 then
            self:Finish(op,"uncertain",timeoutProblem(self,op,state),state); return
        else
            if self:AssistWeapon(op,state) then return end
            local completed=op.confirmedIndex or 0
            for _,member in ipairs(op.active.batch) do
                if same(state.worn[member.equipSlot],op.expected[member.equipSlot])
                    and memberReleased(self,op.active,member,state) then completed=completed+1 end
            end
            if completed>(op.completed or 0) then
                op.completed=completed
                self:Progress(op,"waiting",state)
            end
            return
        end
    end
    while self.operation==op do
        local step=op.plan.steps[op.index]
        if not step then
            if op.active then return end
            if KW.Slots.Equal(state.worn,op.plan.target) then self:Finish(op,"success",nil,state)
            else self:Finish(op,"failed",KW.Problem("targetMismatch"),state) end
            return
        end
        if not self:CanAppend(op,step,state) then return end
        local actual=state.worn[step.equipSlot]
        local done=step.kind=="equip" and actual.kind=="item" and actual.uid==step.uid
            or step.kind=="unequip" and actual.kind=="empty"
        if done then
            if op.active then return end
            op.confirmedIndex=op.index
            op.completed=op.confirmedIndex
            state=self:Progress(op,"confirmed",state)
            if not state then return end
            op.index=op.index+1
        else
            -- RequestEquipItem/RequestUnequipItem are the native inventory
            -- actions. Do not gate them on the global wield/animation state:
            -- it can stay false even while filling an empty weapon slot is
            -- permitted. The actual slot/source acknowledgement below decides
            -- whether the move completed, never a sheathing animation flag.
            local previous=op.active
            local pending=previous and KW.Copy(previous) or KW.Copy(step)
            pending.before=pending.before or KW.Copy(state.worn)
            pending.expected=KW.Copy(op.expected)
            pending.expected[step.equipSlot]=step.kind=="equip" and {kind="item",uid=step.uid,link=""} or {kind="empty"}
            pending.batch=pending.batch or {}
            pending.batch[#pending.batch+1]=KW.Copy(step)
            local member=pending.batch[#pending.batch]
            member.source=step.kind=="equip" and self.inventory:Resolve(step.uid,true,false) or nil
            if #pending.batch==1 then pending.source=KW.Copy(member.source) end
            op.pending=pending
            state=self:Progress(op,"requesting",state)
            if not state then return end
            if previous and not self:CanAppend(op,step,state) then op.pending=previous; return end
            if not previous and (step.spaceCost or 0)>state.freeSlots then
                op.pending=nil
                self:Finish(op,"failed",KW.Problem("bagFull"),state); return
            end
            pending.freeSlots=pending.freeSlots or state.freeSlots
            -- An observer may have moved the same UID in the backpack. Keep
            -- the actual request's source for acknowledgement, too.
            member.source=step.kind=="equip" and self.inventory:Resolve(step.uid,true,false) or nil
            if #pending.batch==1 then pending.source=KW.Copy(member.source) end
            op.requestAt=self.clock:NowMs()
            op.active=pending; op.expected=KW.Copy(pending.expected); op.issuing=true
            local ok,accepted,failure=pcall(self.inventory.Request,self.inventory,step)
            op.issuing=false
            if not ok then
                self:Finish(op,"uncertain",KW.Problem("requestError",{error=tostring(accepted),uid=step.uid,equipSlot=step.equipSlot}),self.inventory:Capture(false)); return
            end
            if not accepted then
                op.active=previous; op.pending=previous
                op.expected=KW.Copy(previous and previous.expected or pending.before)
                self:Finish(op,"failed",failure or KW.Problem("requestRejected")); return
            end
            op.index=op.index+1
            if op.stopReason then self:Finish(op,"interrupted",op.stopReason); return end
            if not previous then self:Later(op,5000,function() self:Check(op) end) end
            self:QueueCheck(op)
            state=self.inventory:Capture(false)
            local blocked=readiness(self)
            if blocked then self:Finish(op,"interrupted",blocked,state); return end
            if not self:Compatible(op,state) then self:Finish(op,"interrupted",KW.Problem("externalChange"),state); return end
            -- Continue through the independent batch in this turn. The next
            -- batch waits for all destination AND source acknowledgements.
        end
    end
end
function Instance:Start(plan,onProgress,onDone)
    if self.operation then return nil,KW.Problem("busy") end
    local problem=readiness(self); if problem then return nil,problem end
    if type(plan)~="table" or type(plan.before)~="table" or type(plan.target)~="table" or type(plan.steps)~="table" then
        return nil,KW.Problem("invalidPlan")
    end
    local state=self.inventory:Capture(false)
    if not KW.Slots.Equal(state.worn,plan.before) and not KW.Slots.Equal(state.worn,plan.target) then
        return nil,KW.Problem("stalePlan")
    end
    self.generation=self.generation+1
    local op={id=self.generation,plan=KW.Copy(plan),index=1,expected=KW.Copy(state.worn),timers={},listeners={},onProgress=onProgress,onDone=onDone}
    self.operation=op
    if KW.Slots.Equal(state.worn,plan.target) then self:Finish(op,"success",nil,state); return op.id end
    for _,name in ipairs({"InventoryChanged","PlayerStateChanged"}) do
        op.listeners[#op.listeners+1]=self.events:Subscribe(name,function() self:QueueCheck(op) end)
    end
    local function poll()
        self:Check(op)
        if self.operation==op then self:Later(op,100,poll) end
    end
    self:Later(op,100,poll)
    self:Check(op)
    return op.id
end
function Instance:Stop(reason)
    local op=self.operation; if not op then return end
    local problem=type(reason)=="table" and reason or KW.Problem(reason or "stopped")
    if op.issuing then op.stopReason=problem; return end
    self:Finish(op,"interrupted",problem)
end
