-- Deterministic offline adapter: requests remain pending until explicitly confirmed.
local Fake=dofile(ROOT..'/tests/support/fake_eso.lua')
local BuildFake={}
-- Mirrors player skill data/read-only hotbar APIs; values describe real state,
-- not pending allocator edits. Native setters are added only with draft tests.
function BuildFake.InstallSkills(f, specs)
    local api=f.api
    api.HOTBAR_CATEGORY_PRIMARY=0;api.HOTBAR_CATEGORY_BACKUP=1
    api.HOTBAR_CATEGORY_OVERLOAD=2;api.HOTBAR_CATEGORY_WEREWOLF=3
    api.HOTBAR_CATEGORY_COMPANION=4;api.HOTBAR_CATEGORY_TEMPORARY=5;api.HOTBAR_CATEGORY_DAEDRIC_ARTIFACT=6
    api.ACTION_TYPE_NOTHING=0;api.ACTION_TYPE_ABILITY=1;api.ACTION_TYPE_CRAFTED_ABILITY=2
    api.SKILL_POINT_ALLOCATION_MODE_FULL=3
    api.GetAssignableAbilityBarStartAndEndSlots=function() return 3,8 end
    api.GetAvailableSkillPoints=function() return f.skillPoints or 10 end
    f.skillLines={};f.skillObjects={};f.actualBars={[0]={},[1]={},[2]={},[3]={},[4]={},[5]={},[6]={}}
    local abilityMap={}
    local function iterator(values)
        local i=0
        return function() i=i+1;if values[i] then return i,values[i] end end
    end
    for _,s in ipairs(specs) do
        local line=f.skillLines[s.lineId]
        if not line then
            line={id=s.lineId,skills={},spec=s}
            function line:GetId() return self.id end
            function line:IsAvailable() return self.spec.available~=false end
            function line:IsClassMastery() return self.spec.mastery==true end
            function line:GetNumClassMasteryPoints() return self.spec.masteryPoints or 3 end
            function line:GetNumPointsAllocated() return self.spec.masterySpent or 0 end
            function line:GetClassMasteryCost() return self.spec.masteryCost or 1 end
            function line:SkillIterator() return iterator(self.skills) end
            f.skillLines[s.lineId]=line
        end
        local skill={spec=s,line=line}
        function skill:GetSkillLineData() return self.line end
        function skill:GetIndices() return 1,self.line.id,self.spec.index or self.spec.id end
        function skill:IsCraftedAbility() return self.spec.kind=='crafted' end
        function skill:IsPassive() return self.spec.kind=='passive' end
        function skill:IsPurchased() return self.spec.purchased==true end
        function skill:IsAutoGrant() return self.spec.autoGrant==true end
        function skill:IsUltimate() return self.spec.ultimate==true end
        function skill:MeetsLinePurchaseRequirement() return self.line:IsAvailable() and self.spec.unlocked~=false end
        function skill:GetSkillPointCostMultiplier() return self.spec.cost or 1 end
        function skill:GetProgressionId() return self.spec.id end
        function skill:GetCraftedAbilityId() return self.spec.id end
        function skill:GetCurrentMorphSlot() return self.spec.morph or 0 end
        function skill:IsAtMorph() return self.spec.morphUnlocked~=false end
        function skill:CanPointAllocationsBeAltered()
            if not self:MeetsLinePurchaseRequirement() then return false end
            if self:IsCraftedAbility() then return false end
            if self:IsAutoGrant() and not self:IsPassive() then return self:IsAtMorph() end
            return true
        end
        function skill:GetCurrentRank() return self.spec.rank or 1 end
        function skill:GetNumRanks() return self.spec.maxRank or 3 end
        function skill:GetRankData(rank)
            if rank>self:GetNumRanks() then return nil end
            local progression={skill=self,rank=rank}
            function progression:GetAbilityId() return self.skill.spec.id*10+self.rank end
            function progression:GetName() return self.skill.spec.name end
            function progression:MeetsUnlockRequirement() return self.rank<=(self.skill.spec.unlockedRank or self.skill:GetNumRanks()) end
            function progression:GetSkillData() return self.skill end
            return progression
        end
        function skill:GetMorphData(morph)
            local progression={skill=self,morph=morph}
            function progression:GetAbilityId() return self.skill.spec.id*10+self.morph end
            function progression:GetName() return self.skill.spec.names and self.skill.spec.names[self.morph] or self.skill.spec.name end
            function progression:IsUnlocked() return self.skill:MeetsLinePurchaseRequirement() and (self.morph==0 or self.skill:IsAtMorph()) end
            function progression:GetMorphSlot() return self.morph end
            function progression:GetSkillData() return self.skill end
            return progression
        end
        function skill:GetCurrentProgressionData()
            if self:IsPassive() then return self:GetRankData(self:GetCurrentRank()) end
            return self:GetMorphData(self:GetCurrentMorphSlot())
        end
        line.skills[#line.skills+1]=skill;f.skillObjects[#f.skillObjects+1]=skill
        if not skill:IsPassive() then
            for morph=0,2 do
                local p=skill:GetMorphData(morph);abilityMap[p:GetAbilityId()]=p
                -- Native BuildStaticData maps chained weapon variants to the
                -- same progression/morph, not to separately learned skills.
                for _,id in ipairs(s.chainedAbilityIds and s.chainedAbilityIds[morph] or {})do abilityMap[id]=p end
            end
        end
    end
    local skillType={}
    function skillType:SkillLineIterator()
        local lines={};for _,line in pairs(f.skillLines) do lines[#lines+1]=line end
        table.sort(lines,function(a,b)return a.id<b.id end)
        return iterator(lines)
    end
    api.SKILLS_DATA_MANAGER={}
    function api.SKILLS_DATA_MANAGER:IsDataReady() return true end
    function api.SKILLS_DATA_MANAGER:SkillTypeIterator() return iterator({skillType}) end
    function api.SKILLS_DATA_MANAGER:GetProgressionDataByAbilityId(id) return abilityMap[id] end
    function api.SKILLS_DATA_MANAGER:GetSkillDataByProgressionId(id)
        for _,skill in ipairs(f.skillObjects) do if skill.spec.id==id then return skill end end
    end
    api.GetSkillProgressionIdForHotbarSlotOverrideRule=function(slot,category)
        local skill=f.overrides and f.overrides[category..':'..slot]
        return skill and skill:GetProgressionId() or 0
    end
    api.GetAbilityIdForCraftedAbilityId=function(id)return id*10 end
    local function crafted(id)
        for _,skill in ipairs(f.skillObjects) do if skill:IsCraftedAbility() and skill.spec.id==id then return skill.spec end end
        return {}
    end
    api.IsCraftedAbilityScribed=function(id)return crafted(id).scribed~=false end
    api.IsCraftedAbilityDisabled=function(id)return crafted(id).disabled==true end
    api.GetCraftedAbilityActiveScriptIds=function(id)local s=crafted(id);return s.primaryScript or 101,102,103 end
    api.IsCraftedAbilityScriptDisabled=function(id)return f.disabledScripts and f.disabledScripts[id]==true or false end
    api.GetSlotType=function(slot,bar) local ref=f.actualBars[bar][slot];return ref and ref.type or api.ACTION_TYPE_NOTHING end
    api.GetSlotBoundId=function(slot,bar) local ref=f.actualBars[bar][slot];return ref and ref.id or 0 end
    api.ACTION_BAR_ASSIGNMENT_MANAGER={}
    local hotbars={}
    for category=0,6 do
        local hotbar={category=category}
        function hotbar:IsSlotLocked(slot) return f.lockedSlots and f.lockedSlots[self.category..':'..slot]==true or false end
        function hotbar:IsSlotMutable(slot) return not (f.immutableSlots and f.immutableSlots[self.category..':'..slot]) end
        function hotbar:GetOverrideSkillDataForSlot(slot)
            local skill=f.overrides and f.overrides[self.category..':'..slot]
            if skill and (f.allocators and skill:GetPointAllocator():IsPurchased() or not f.allocators and skill:IsPurchased()) then return skill end
        end
        hotbars[category]=hotbar
    end
    function api.ACTION_BAR_ASSIGNMENT_MANAGER:GetHotbar(category) return hotbars[category] end
    function api.ACTION_BAR_ASSIGNMENT_MANAGER:ShouldSubmitChangesForHotbarCategory(category)
        return category~=api.HOTBAR_CATEGORY_WEREWOLF or f.werewolfAvailable~=false
    end
    f.hotbars=hotbars
    return f
end

-- These doubles preserve native side effects: purchases autofill, assignments
-- relocate duplicate skills, mode resets release allocators/reset bars, and
-- purchase-mode OnUpdate really sends a packet whenever isDirty is set.
function BuildFake.InstallSkillDrafts(f)
    local api=f.api
    api.SKILL_POINT_ALLOCATION_MODE_PURCHASE_ONLY=0
    api.RESPEC_PAYMENT_TYPE_GOLD=0
    api.RESPEC_RESULT_SUCCESS=0
    local function callbacks(object)
        object.callbacks={}
        function object:RegisterCallback(name,callback)
            self.callbacks[name]=self.callbacks[name] or {}
            self.callbacks[name][#self.callbacks[name]+1]={callback=callback,active=true}
        end
        function object:UnregisterCallback(name,callback)
            for _,entry in ipairs(self.callbacks[name] or {}) do if entry.callback==callback then entry.active=false end end
        end
        function object:FireCallbacks(name,...)
            for _,entry in ipairs(self.callbacks[name] or {}) do if entry.active then entry.callback(...) end end
        end
        return object
    end
    local global=callbacks({mode=0,payment=0,isDirty=false})
    api.SKILLS_AND_ACTION_BAR_MANAGER=global
    function global:GetSkillPointAllocationMode() return self.mode end
    function global:GetSkillRespecPaymentType() return self.payment end
    function global:SetSkillRespecPaymentType(payment) self.payment=payment end
    api.SKILL_POINT_ALLOCATION_MANAGER=callbacks({})
    local allocation=api.SKILL_POINT_ALLOCATION_MANAGER
    callbacks(api.ACTION_BAR_ASSIGNMENT_MANAGER)
    local bars=api.ACTION_BAR_ASSIGNMENT_MANAGER
    f.allocators={};f.draftOperations={}
    local function action(skill)
        local value={skill=skill}
        function value:IsEmpty() return self.skill==nil end
        function value:GetPlayerSkillData() return self.skill end
        function value:EqualsSkillData(other) return self.skill==other end
        return value
    end
    function bars:ResetPlayerHotbars()
        for category,hotbar in pairs(f.hotbars) do
            hotbar.slots={}
            for slot=3,8 do
                local override=hotbar:GetOverrideSkillDataForSlot(slot)
                local ref=f.actualBars[category][slot]
                local progression=ref and api.SKILLS_DATA_MANAGER:GetProgressionDataByAbilityId(ref.type==api.ACTION_TYPE_CRAFTED_ABILITY and ref.id*10 or ref.id)
                hotbar.slots[slot]=action(override or progression and progression:GetSkillData())
            end
        end
    end
    for _,hotbar in pairs(f.hotbars) do
        function hotbar:GetSlotData(slot) return self.slots[slot] end
        function hotbar:ClearSlot(slot)
            if self:IsSlotLocked(slot) or not self:IsSlotMutable(slot) or self:GetOverrideSkillDataForSlot(slot) then return false end
            self.slots[slot]=action();global.isDirty=true;bars:FireCallbacks('SlotUpdated',self.category,slot,true)
            -- The actual stock ClearSlot has no success return value.
        end
        function hotbar:AssignSkillToSlot(slot,skill)
            if self:GetSlotData(slot):EqualsSkillData(skill) then return false end
            if self:IsSlotLocked(slot) or not self:IsSlotMutable(slot) or self:GetOverrideSkillDataForSlot(slot) then return false end
            for index,existing in pairs(self.slots) do if existing:EqualsSkillData(skill) then self:ClearSlot(index) end end
            self.slots[slot]=action(skill);global.isDirty=true;bars:FireCallbacks('SlotUpdated',self.category,slot,true)
            return true
        end
    end
    local function nativePoints(allocator)
        if not allocator.purchased then return 0 end
        local skill=allocator.skill
        local raw=skill:IsPassive() and allocator.rank or (allocator.morph==0 and 1 or 2)
        return raw-(skill:IsAutoGrant() and 1 or 0)
    end
    local function budget(skill)
        local mastery=skill:GetSkillLineData():IsClassMastery()
        local spent=0
        for _,allocator in pairs(f.allocators) do
            if allocator.skill:GetSkillLineData():IsClassMastery()==mastery and (not mastery or allocator.skill.line==skill.line) then
                local s=allocator.skill
                local actual=s:IsPurchased() and (s:IsPassive() and s:GetCurrentRank() or (s:GetCurrentMorphSlot()==0 and 1 or 2))-(s:IsAutoGrant() and 1 or 0) or 0
                spent=spent+(nativePoints(allocator)-actual)*(mastery and 1 or s:GetSkillPointCostMultiplier())
            end
        end
        return (mastery and skill.line:GetNumClassMasteryPoints()-skill.line:GetNumPointsAllocated() or api.GetAvailableSkillPoints())-spent
    end
    function allocation:GetSkillPointAllocatorForSkillData(skill)
        if f.allocators[skill] then return f.allocators[skill] end
        local allocator={skill=skill,purchased=skill:IsPurchased(),rank=skill:GetCurrentRank(),morph=skill:IsCraftedAbility() and 0 or skill:GetCurrentMorphSlot()}
        function allocator:IsPurchased() return self.purchased end
        function allocator:GetRank() return self.rank end
        function allocator:GetMorphSlot() return self.morph end
        function allocator:IsAnyChangePending() return self.purchased~=self.skill:IsPurchased() or (self.purchased and (self.skill:IsPassive() and self.rank~=self.skill:GetCurrentRank() or not self.skill:IsPassive() and self.morph~=self.skill:GetCurrentMorphSlot())) end
        local function changed(a,name)
            f.draftOperations[#f.draftOperations+1]=name;global.isDirty=true
            if name=='Purchase' and not a.skill:IsPassive() then
                for slot=3,7 do if f.hotbars[0]:GetSlotData(slot):IsEmpty() then f.hotbars[0]:AssignSkillToSlot(slot,a.skill);break end end
            elseif name=='Sell' and not a.skill:IsPassive() then
                for _,hotbar in pairs(f.hotbars) do for slot=3,8 do if hotbar:GetSlotData(slot):EqualsSkillData(a.skill) then hotbar:ClearSlot(slot) end end end
            end
            allocation:FireCallbacks((name=='Purchase' or name=='Sell') and 'PurchasedChanged' or 'SkillProgressionKeyChanged',a)
        end
        local function canAfford(a) return budget(a.skill)>=(a.skill.line:IsClassMastery() and a.skill.line:GetClassMasteryCost() or a.skill:GetSkillPointCostMultiplier()) end
        function allocator:Purchase() if self.purchased or not canAfford(self) then return false end;self.purchased=true;changed(self,'Purchase');return true end
        function allocator:Sell() if self.skill:IsAutoGrant() or not self.purchased or (self.skill:IsPassive() and self.rank~=1 or not self.skill:IsPassive() and self.morph~=0) then return false end;self.purchased=false;changed(self,'Sell');return true end
        function allocator:DecreaseRank() if self.rank<=1 then return false end;self.rank=self.rank-1;changed(self,'DecreaseRank');return true end
        function allocator:IncreaseRank() if not canAfford(self) or self.rank>=self.skill:GetNumRanks() then return false end;self.rank=self.rank+1;changed(self,'IncreaseRank');return true end
        function allocator:Unmorph() if self.morph==0 then return false end;self.morph=0;changed(self,'Unmorph');return true end
        function allocator:Morph(morph) if self.morph==0 and not canAfford(self) then return false end;self.morph=morph;changed(self,'Morph');return true end
        f.allocators[skill]=allocator;return allocator
    end
    for _,skill in ipairs(f.skillObjects) do function skill:GetPointAllocator() return allocation:GetSkillPointAllocatorForSkillData(self) end end
    function allocation:IsAnyChangePending() for _,a in pairs(f.allocators) do if a:IsAnyChangePending() then return true end end;return false end
    function bars:IsAnyChangePending()
        for category,hotbar in pairs(f.hotbars) do
            if category<=3 and bars:ShouldSubmitChangesForHotbarCategory(category) then
            for slot=3,8 do
                local pending=hotbar:GetSlotData(slot):GetPlayerSkillData()
                local ref=f.actualBars[category][slot]
                local actual=ref and api.SKILLS_DATA_MANAGER:GetProgressionDataByAbilityId(ref.type==api.ACTION_TYPE_CRAFTED_ABILITY and ref.id*10 or ref.id)
                actual=hotbar:GetOverrideSkillDataForSlot(slot) or actual and actual:GetSkillData()
                if pending~=actual then return true end
            end
            end
        end
        return false
    end
    function global:HasAnyPendingChanges()
        local lines=api.SKILL_LINE_ASSIGNMENT_MANAGER
        return f.foreignPending or allocation:IsAnyChangePending() or bars:IsAnyChangePending() or lines and lines:IsAnyChangePending() or false
    end
    function global:SetSkillPointAllocationMode(mode)
        if mode~=self.mode then
            local old=self.mode;self.mode=mode
            if not f.retainPendingOnReset then f.allocators={} end
            bars:ResetPlayerHotbars();self:FireCallbacks('SkillPointAllocationModeChanged',mode,old)
        end
    end
    function global:ResetRespecState()
        self:SetSkillRespecPaymentType(api.RESPEC_PAYMENT_TYPE_GOLD)
        self:SetSkillPointAllocationMode(api.SKILL_POINT_ALLOCATION_MODE_PURCHASE_ONLY)
        if not f.retainPendingOnReset then f.allocators={} end
        bars:ResetPlayerHotbars();self:FireCallbacks('RespecStateReset')
        if f.resetCallbackMarksDirty then self.isDirty=true end
    end
    function global:ResetInterface() self:SetSkillRespecPaymentType(0);self:SetSkillPointAllocationMode(0) end
    function global:OnUpdate() if self.isDirty and self.mode==0 then self:ApplyChanges() end end
    function global:ApplyChanges() api.PrepareSkillPointAllocationRequest(self.mode,self.payment);api.SendSkillPointAllocationRequest();self.isDirty=false end
    api.PrepareSkillPointAllocationRequest=function(mode,payment) f.packetPrepareCalls=(f.packetPrepareCalls or 0)+1;f.packet={mode=mode,payment=payment,skills={},bars={}} end
    api.AddActiveChangeToAllocationRequest=function(line,id,morph,purchased) f.packet.skills[#f.packet.skills+1]={kind='active',line=line,id=id,morph=morph,purchased=purchased} end
    api.AddPassiveChangeToAllocationRequest=function(line,id,removal) f.packet.skills[#f.packet.skills+1]={kind='passive',line=line,id=id,removal=removal} end
    api.AddHotbarSlotChangeToAllocationRequest=function(slot,bar,kind,id) f.packet.bars[#f.packet.bars+1]={slot=slot,bar=bar,kind=kind,id=id} end
    api.SendSkillPointAllocationRequest=function() f.requests.skills[#f.requests.skills+1]=f.packet;f.packet=nil end
    api.CancelSkillPointAllocationRequest=function() f.cancelRequests=(f.cancelRequests or 0)+1 end
    api.GetSkillRespecCastTimeRemainingMs=function()return f.castRemaining or 0 end
    api.StartSkillRespecFromUI=function() f.entryRequests=(f.entryRequests or 0)+1 end
    function f:SkillEntryReady()
        global:SetSkillPointAllocationMode(api.SKILL_POINT_ALLOCATION_MODE_FULL)
        global:SetSkillRespecPaymentType(api.RESPEC_PAYMENT_TYPE_GOLD)
        self.events:Emit('NativeSkillRespecStarted',{allocationMode=global.mode,paymentType=global.payment})
    end
    bars:ResetPlayerHotbars()
    return f
end
-- Opt-in reproduction of ESO's effective-ID pending comparison. The normal
-- fixture compares skill objects; that cannot reproduce an unchanged binding
-- whose effective ability ID differs (the client's 2026-10-02 report).
function BuildFake.InstallEffectiveSlotIds(f, effectiveIds)
    local api=f.api
    api.ZO_SLOTTABLE_ACTION_TYPE_PLAYER_SKILL=2;api.ZO_SLOTTABLE_ACTION_TYPE_COMPANION_SKILL=4
    local bars,global=api.ACTION_BAR_ASSIGNMENT_MANAGER,api.SKILLS_AND_ACTION_BAR_MANAGER
    bars.hotbars=f.hotbars
    global.managers={api.SKILL_POINT_ALLOCATION_MANAGER,bars,
        {IsAnyChangePending=function()return f.foreignPending or false end}}
    local function decorate(hotbar)
        for _,value in pairs(hotbar.slots)do
            function value:GetActionType()
                return not self.skill and api.ACTION_TYPE_NOTHING or self.skill:IsCraftedAbility() and api.ACTION_TYPE_CRAFTED_ABILITY or api.ACTION_TYPE_ABILITY
            end
            function value:GetSlottableActionType()return self.skill and api.ZO_SLOTTABLE_ACTION_TYPE_PLAYER_SKILL or 1 end
            function value:GetActionId()
                if not self.skill then return 0 end
                if self.skill:IsCraftedAbility()then return self.skill:GetCraftedAbilityId()end
                return self.skill:GetMorphData(self.skill:GetPointAllocator():GetMorphSlot()):GetAbilityId()
            end
            function value:GetEffectiveAbilityId()local id=self:GetActionId();return effectiveIds[id] or id end
        end
    end
    local reset=bars.ResetPlayerHotbars
    function bars:ResetPlayerHotbars()reset(self);for _,hotbar in pairs(self.hotbars)do decorate(hotbar)end end
    for _,hotbar in pairs(f.hotbars)do
        function hotbar:SlotIterator()decorate(self);return pairs(self.slots)end
        function hotbar:DoesSlotHavePendingChanges(slot)
            decorate(self);local value=self:GetSlotData(slot)
            local kind=value:GetActionType()
            local id=kind==api.ACTION_TYPE_ABILITY and value:GetEffectiveAbilityId() or value:GetActionId()
            return kind~=api.GetSlotType(slot,self.category) or id~=api.GetSlotBoundId(slot,self.category)
        end
    end
    function bars:IsAnyChangePending()
        for category,hotbar in pairs(self.hotbars)do
            if self:ShouldSubmitChangesForHotbarCategory(category)then
                for slot in hotbar:SlotIterator()do if hotbar:DoesSlotHavePendingChanges(slot)then return true end end
            end
        end
        return false
    end
    bars:ResetPlayerHotbars()
    return f
end
function BuildFake.New(saved)
    local api=Fake.New()
    local f={api=api,requests={equipment=api.requests,skills={},attributes={},bars={}},catalogue={},journal=saved or {},timers={},now=0}
    f.clock={}
    function f.clock:NowMs() return f.now end
    function f.clock:Schedule(delay,callback)
        local token={at=f.now+delay,callback=callback};f.timers[#f.timers+1]=token;return token
    end
    function f.clock:Cancel(token) token.cancelled=true end
    function f:Advance(ms)
        self.now=self.now+ms;self.api.now=self.now
        local ready=self.timers;self.timers={}
        for _,token in ipairs(ready) do
            if not token.cancelled then
                if token.at<=self.now then token.callback() else self.timers[#self.timers+1]=token end
            end
        end
    end
    function f:Request(part,payload)
        local queue=assert(self.requests[part]);local request={payload=KanaWardrobe.Copy(payload),status='pending'}
        queue[#queue+1]=request;return request
    end
    function f:Confirm(request,result) assert(request.status=='pending');request.status='confirmed';request.result=result end
    function f:Fail(request,problem) assert(request.status=='pending');request.status='failed';request.problem=problem end
    function f:Reload() return BuildFake.New(KanaWardrobe.Copy(self.journal)) end
    api.buildFixture=f
    return f
end
return BuildFake
