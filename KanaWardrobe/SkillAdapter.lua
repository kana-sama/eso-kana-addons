local KW = KanaWardrobe
local SkillAdapter = {}
KW.SkillAdapter = SkillAdapter
local Adapter = {}
Adapter.__index = Adapter

function SkillAdapter.New(api,events,clock)
    api=api or _G
    return setmetatable({api=api,events=events or KW.Core.NewEvents(),clock=clock or KW.Core.NewClock(api),
        catalogueRevision=0,generation=0,submission={phase='idle',token=0,sent=false}},Adapter)
end

-- A sorted representation tracks changes in availability/costs as well as state.
-- Native handles are intentionally excluded from the revision fingerprint.
local function fingerprint(value)
    if type(value)~='table' then return type(value)..':'..tostring(value) end
    local keys={}
    for key in pairs(value) do if key~='native' then keys[#keys+1]=key end end
    table.sort(keys,function(a,b)return tostring(a)<tostring(b) end)
    local parts={}
    for _,key in ipairs(keys) do parts[#parts+1]=fingerprint(key)..'='..fingerprint(value[key]) end
    return '{'..table.concat(parts,';')..'}'
end

function Adapter:Catalogue()
    local catalogue=KW.SkillState.Read(self.api)
    local signature=fingerprint(catalogue)
    if signature~=self.catalogueSignature then
        self.catalogueSignature=signature
        self.catalogueRevision=self.catalogueRevision+1
    end
    catalogue.revision=self.catalogueRevision
    return catalogue
end

function Adapter:Capture()
    local catalogue=self:Catalogue()
    if not catalogue.available then return nil,catalogue.problem end
    return KW.Copy(catalogue.abilities),KW.Copy(catalogue.budgets),catalogue.revision
end

local function points(state,record)
    if record.kind=='passive' then return math.max(0,state.rank-(record.autoGrant and 1 or 0)) end
    if not state.purchased then return 0 end
    return (record.autoGrant and 0 or 1)+(state.morph~=0 and 1 or 0)
end

local function problem(code,key,extra)
    local details=extra or {};details.skillKey=key
    return nil,KW.Problem(code,details)
end

-- Temporary refusal evidence: copy the exact planning inputs, not native
-- objects or a later recapture. Gathering it never changes the refusal.
local function barOverrideProblem(key,metadata,before,target,explicit,request,catalogue,bar,slot)
    local context={bar=bar,slot=slot,category=metadata.category,nativeSlot=metadata.nativeSlot,
        locked=metadata.locked,mutable=metadata.mutable,override=metadata.override,
        runtimeOverride=metadata.runtimeOverride,explicit=explicit~=nil,
        before=KW.Copy(before),target=KW.Copy(target),skillChanges=KW.Copy(request.skillChanges),
        catalogueRevision=catalogue.revision}
    local function describe(ref)
        local record=ref and catalogue.byKey[ref.skillKey]
        if not record then return end
        local value={key=record.key,name=record.name,lineId=record.lineId,kind=record.kind,
            purchased=record.purchased,state=KW.Copy(record.state)}
        local ok,id=pcall(function()
            if record.kind=='active' then
                return record.native:GetMorphData(ref.expectedMorph or record.state.morph or 0):GetAbilityId()
            elseif record.kind=='crafted' then return record.native:GetCraftedAbilityId() end
        end)
        if ok then value.id=id else value.readError=tostring(id) end
        return value
    end
    context.beforeAbility=describe(before);context.targetAbility=describe(target)
    context.overrideAbility=describe({skillKey=metadata.override})
    context.runtimeOverrideAbility=describe({skillKey=metadata.runtimeOverride})
    return problem('skillBarOverride',key,{bar=bar,slot=slot,category=metadata.category,
        nativeSlot=metadata.nativeSlot,slotContext=context})
end

-- A forced binding follows its skill's morph through the native allocator.
-- The allocation message must include that resulting binding, just as native
-- AddChangesToMessage does, without calling AssignSkillToSlot on a forced slot.
local function isBoundSkillMorphChange(metadata,before,target)
    return before.kind=='skill' and target.kind=='skill'
        and before.skillKey==target.skillKey and before.expectedMorph~=target.expectedMorph
        and metadata.override==before.skillKey and metadata.runtimeOverride==before.skillKey
end

function Adapter:Prepare(current,target,catalogue)
    catalogue=catalogue or self:Catalogue()
    if not catalogue.available then return nil,catalogue.problem end
    local normalized,err=KW.BuildModel.Normalize({abilities=target})
    if not normalized then return nil,err end
    normalized.abilities=KW.SkillState.ExpandMasterySelection(normalized.abilities,catalogue)
    local merged=KW.BuildModel.Merge({abilities=current},{abilities=normalized.abilities}).abilities
    local request={werewolfOriginal=KW.Copy(current.bars and current.bars.werewolf),target=merged,skillChanges={},barChanges={},pointDelta=0,masteryDelta={},
        requiresRespec=false,catalogueRevision=catalogue.revision,auxiliaryOriginal={},auxiliaryTarget={},auxiliaryChanges={}}
    local explicitSkills=normalized.abilities and normalized.abilities.skills or {}
    for key,wanted in pairs(explicitSkills) do
        local record=catalogue.byKey[key]
        if not record then return problem('skillUnavailable',key) end
        local before=current.skills and current.skills[key] or record.state
        if not record.mutable then return problem('skillImmutable',key) end
        if not before then return problem('skillUnavailable',key) end
        local isChange=not KW.BuildModel.Matches({abilities={skills={[key]=before}}},{abilities={skills={[key]=wanted}}})
        if isChange then
            if not record.available then return problem('skillUnavailable',key) end
            if record.autoGrant and ((wanted.kind=='active' and not wanted.purchased) or (wanted.kind=='passive' and wanted.rank<record.minimumRank)) then
                return problem('skillImmutable',key)
            end
            if wanted.kind=='active' and wanted.purchased then
                if not record.purchaseUnlocked then return problem('skillUnavailable',key) end
                if not record.morphUnlocked[wanted.morph] then return problem('skillMorphLocked',key) end
            elseif wanted.kind=='passive' and wanted.rank>0 then
                if wanted.rank>record.maxRank or not record.rankUnlocked[wanted.rank] then return problem('skillRankLocked',key) end
            end
            local oldPoints,newPoints=points(before,record),points(wanted,record)
            local delta=newPoints-oldPoints
            local costDelta=delta*(record.mastery and 1 or record.cost)
            request.skillChanges[#request.skillChanges+1]={key=key,before=KW.Copy(before),target=KW.Copy(wanted),delta=costDelta}
            if record.mastery then request.masteryDelta[record.lineId]=(request.masteryDelta[record.lineId] or 0)+costDelta
            else request.pointDelta=request.pointDelta+costDelta end
            if newPoints<oldPoints or (before.kind=='active' and before.purchased and wanted.purchased and before.morph~=0 and before.morph~=wanted.morph) then request.requiresRespec=true end
        end
    end
    table.sort(request.skillChanges,function(a,b)
        if (a.delta<0)~=(b.delta<0) then return a.delta<0 end
        return a.key<b.key
    end)
    if request.pointDelta>catalogue.budgets.skills then return problem('insufficientSkillPoints',nil,{required=request.pointDelta,available=catalogue.budgets.skills}) end
    for lineId,delta in pairs(request.masteryDelta) do
        if delta>(catalogue.budgets.mastery[lineId] or 0) then return problem('insufficientMasteryPoints',nil,{lineId=lineId,required=delta,available=catalogue.budgets.mastery[lineId] or 0}) end
    end
    local masteryAvailable=KW.Copy(catalogue.budgets.mastery)
    -- The native allocator subtracts one mastery point per bought rank, but
    -- tests a potentially higher line-specific threshold for each transaction.
    for _,change in ipairs(request.skillChanges) do
        local record=catalogue.byKey[change.key]
        if record.mastery and change.delta<0 then
            masteryAvailable[record.lineId]=masteryAvailable[record.lineId]-change.delta
        end
    end
    for _,change in ipairs(request.skillChanges) do
        local record=catalogue.byKey[change.key]
        if record.mastery and change.delta>0 then
            for _=1,change.delta do
                local available=masteryAvailable[record.lineId]
                if available<record.masteryTransactionCost then
                    return problem('insufficientMasteryPoints',change.key,{lineId=record.lineId,required=record.masteryTransactionCost,available=available})
                end
                masteryAvailable[record.lineId]=available-1
            end
        end
    end
    -- Every retained reference follows its changed skill's final morph/purchase.
    -- Explicit bar refs remain assertions and must agree with that final state.
    merged.bars=merged.bars or {}
    for _,bar in ipairs({'front','back','werewolf'}) do
        if current.bars and current.bars[bar] or normalized.abilities.bars and normalized.abilities.bars[bar] then
            merged.bars[bar]=merged.bars[bar] or {}
            local seen={}
            local selected=normalized.abilities.bars and normalized.abilities.bars[bar] or {}
            local destinations={}
            for slot,ref in pairs(selected)do
                if ref.kind=='skill' then
                    if destinations[ref.skillKey] then return problem('duplicateBarSkill',ref.skillKey,{bar=bar,slot=slot}) end
                    destinations[ref.skillKey]=slot
                end
            end
            -- Native assignment moves an existing same-bar skill. An omitted
            -- source has no preset constraint; explicit duplicates remain invalid.
            for slot,ref in pairs(merged.bars[bar])do
                if not selected[slot] and ref.kind=='skill' and destinations[ref.skillKey] and destinations[ref.skillKey]~=slot then
                    merged.bars[bar][slot]={kind='empty'}
                end
            end
            for slot=1,6 do
                local ref=merged.bars[bar][slot] or {kind='empty'}
                local explicit=normalized.abilities and normalized.abilities.bars and normalized.abilities.bars[bar] and normalized.abilities.bars[bar][slot]
                local metadata=catalogue.barMetadata[bar] and catalogue.barMetadata[bar][slot]
                if not metadata then return problem('skillBarLocked',ref.skillKey,{bar=bar,slot=slot}) end
                local forced=catalogue.byKey[metadata.override]
                local automatic=bar=='werewolf' and slot==6 and forced and forced.kind=='active' and forced.ultimate
                    and forced.purchased and metadata.runtimeOverride==forced.key
                    and (current.bars[bar][slot] or {}).kind=='empty'
                    and (ref.kind=='empty' or ref.kind=='skill' and ref.skillKey==forced.key)
                if automatic and metadata.eligible then ref={kind='skill',skillKey=forced.key,expectedMorph=(merged.skills and merged.skills[forced.key] or forced.state).morph} end
                if ref.kind=='skill' then
                    local record=catalogue.byKey[ref.skillKey]
                    if not record or not record.available or record.kind=='passive' then return problem('skillUnavailable',ref.skillKey) end
                    if bar=='werewolf' and record.werewolf==false then return problem('skillWerewolfOnly',ref.skillKey,{bar=bar,slot=slot}) end
                    local final=merged.skills and merged.skills[ref.skillKey] or record.state
                    local purchased=record.kind=='crafted' and record.purchased or final and final.purchased
                    if record.kind=='crafted' and not record.craftedReady then return problem('skillUnavailable',ref.skillKey) end
                    if not purchased then
                        if explicit then return problem('skillUnavailable',ref.skillKey) end
                        ref={kind='empty'}
                    elseif record.kind=='active' then
                        if explicit and ref.expectedMorph~=final.morph then return problem('skillMorphMismatch',ref.skillKey) end
                        ref=KW.Copy(ref);ref.expectedMorph=final.morph
                    end
                    if ref.kind=='skill' and record.ultimate~=(slot==6) then return problem('skillBarType',ref.skillKey,{bar=bar,slot=slot}) end
                    if ref.kind=='skill' then
                        if seen[ref.skillKey] then return problem('duplicateBarSkill',ref.skillKey,{bar=bar,slot=slot}) end
                        seen[ref.skillKey]=true
                    end
                end
                merged.bars[bar][slot]=ref
                local old=current.bars and current.bars[bar] and current.bars[bar][slot] or {kind='empty'}
                if not KW.BuildModel.Matches({abilities={bars={front={[1]=old}}}},{abilities={bars={front={[1]=ref}}}}) then
                    if metadata.eligible==false then return problem('skillAuxiliaryBarUnavailable',ref.skillKey,{bar=bar,category=metadata.category,nativeSlot=metadata.nativeSlot}) end
                    if metadata.locked then return problem('skillBarLocked',ref.skillKey,{bar=bar,slot=slot}) end
                    local boundMorph=isBoundSkillMorphChange(metadata,old,ref) or automatic
                    if not metadata.mutable or ((metadata.override or metadata.runtimeOverride) and not boundMorph) then
                        return barOverrideProblem(ref.skillKey,metadata,old,ref,explicit,request,catalogue,bar,slot)
                    end
                    request.barChanges[#request.barChanges+1]={bar=bar,slot=slot,nativeSlot=metadata.nativeSlot,category=metadata.category,target=KW.Copy(ref)}
                end
            end
        end
    end
    if #request.skillChanges>0 and type(catalogue.auxiliaryBars)~='table' then
        return nil,KW.Problem('buildCapabilityUnavailable',{component='skills',name='auxiliaryBars'})
    end
    local changed={}
    for _,change in ipairs(request.skillChanges) do changed[change.key]=change.target end
    local categories={};for category in pairs(catalogue.auxiliaryBars or {}) do
        if category~=self.api.HOTBAR_CATEGORY_WEREWOLF or not current.bars or not current.bars.werewolf then categories[#categories+1]=category end
    end
    table.sort(categories)
    for _,category in ipairs(categories) do
        local slots=catalogue.auxiliaryBars[category]
        local indices={};for slot in pairs(slots) do indices[#indices+1]=slot end;table.sort(indices)
        for _,slot in ipairs(indices) do
            local metadata=slots[slot];local before=metadata.ref
            local after=KW.Copy(before)
            local forced=catalogue.byKey[metadata.override]
            local automatic=before.kind=='empty' and category==self.api.HOTBAR_CATEGORY_WEREWOLF
                and slot==catalogue.nativeSlots[6] and forced and forced.kind=='active' and forced.ultimate
                and forced.purchased and metadata.runtimeOverride==forced.key
            if automatic then after={kind='skill',skillKey=forced.key,expectedMorph=forced.state.morph} end
            local final=after.kind=='skill' and changed[after.skillKey]
            if final and final.kind=='active' then
                if not final.purchased then after={kind='empty'} else after.expectedMorph=final.morph end
            end
            if fingerprint(before)~=fingerprint(after) then
                if not metadata.eligible then return problem('skillAuxiliaryBarUnavailable',before.skillKey,{category=category,nativeSlot=slot}) end
                if metadata.locked then return problem('skillBarLocked',before.skillKey,{category=category,nativeSlot=slot}) end
                local boundMorph=isBoundSkillMorphChange(metadata,before,after) or automatic
                if not metadata.mutable or ((metadata.override or metadata.runtimeOverride) and not boundMorph) then
                    return barOverrideProblem(before.skillKey,metadata,before,after,nil,request,catalogue)
                end
                request.auxiliaryOriginal[category]=request.auxiliaryOriginal[category] or {}
                request.auxiliaryTarget[category]=request.auxiliaryTarget[category] or {}
                request.auxiliaryOriginal[category][slot]=KW.Copy(before)
                request.auxiliaryTarget[category][slot]=KW.Copy(after)
                request.auxiliaryChanges[#request.auxiliaryChanges+1]={category=category,nativeSlot=slot,
                    before=KW.Copy(before),target=KW.Copy(after),automatic=boundMorph or nil}
            end
        end
    end
    return request
end

local function auxiliaryMatches(catalogue,expected)
    if not catalogue.available then return false end
    for category,slots in pairs(expected or {}) do
        for slot,ref in pairs(slots) do
            local actual=catalogue.auxiliaryBars and catalogue.auxiliaryBars[category] and catalogue.auxiliaryBars[category][slot]
            if not actual or fingerprint(actual.ref)~=fingerprint(ref) then return false end
        end
    end
    return true
end
function Adapter:Matches(target,request)
    if request and (type(request)~='table' or type(request.auxiliaryTarget)~='table') then return false end
    local catalogue=self:Catalogue()
    return catalogue.available and KW.BuildModel.Matches({abilities=catalogue.abilities},{abilities=target}) and
        (not request or auxiliaryMatches(catalogue,request.auxiliaryTarget))
end

local function nativeUnavailable(name)
    return nil,KW.Problem('buildCapabilityUnavailable',{component='skills',name=name})
end

function Adapter:NativeManagers()
    local global=self.api.SKILLS_AND_ACTION_BAR_MANAGER
    local allocation=self.api.SKILL_POINT_ALLOCATION_MANAGER
    local bars=self.api.ACTION_BAR_ASSIGNMENT_MANAGER
    if not global or type(global.HasAnyPendingChanges)~='function'
        or type(global.SetSkillPointAllocationMode)~='function' then return nativeUnavailable('SKILLS_AND_ACTION_BAR_MANAGER') end
    if not allocation or type(allocation.GetSkillPointAllocatorForSkillData)~='function' then return nativeUnavailable('SKILL_POINT_ALLOCATION_MANAGER') end
    if not bars or type(bars.GetHotbar)~='function' then return nativeUnavailable('ACTION_BAR_ASSIGNMENT_MANAGER') end
    return global,allocation,bars
end

function Adapter:ForeignDraftProblem(global)
    if global:GetSkillPointAllocationMode()~=self.api.SKILL_POINT_ALLOCATION_MODE_PURCHASE_ONLY
        or global.isDirty or KW.SkillState.HasPendingChanges(self.api) then return KW.Problem('foreignSkillDraft') end
end

function Adapter:OwnedDraftProblem(global)
    if global:GetSkillPointAllocationMode()~=self.api.SKILL_POINT_ALLOCATION_MODE_FULL then return KW.Problem('foreignSkillDraft') end
    local lines=self.api.SKILL_LINE_ASSIGNMENT_MANAGER
    if lines and lines:IsAnyChangePending() then return KW.Problem('foreignSkillDraft') end
end

function Adapter:ReadinessProblem()
    local api=self.api
    if type(api.IsUnitInCombat)=='function' and api.IsUnitInCombat('player') then return KW.Problem('inCombat') end
    if type(api.IsUnitDeadOrReincarnating)=='function' and api.IsUnitDeadOrReincarnating('player') then return KW.Problem('dead') end
    if type(api.IsBlockActive)=='function' and api.IsBlockActive() then return KW.Problem('blocking') end
    if type(api.GetSkillRespecCastTimeRemainingMs)~='function' then return KW.Problem('buildCapabilityUnavailable',{component='skills',name='GetSkillRespecCastTimeRemainingMs'}) end
    if api.GetSkillRespecCastTimeRemainingMs()>0 then return KW.Problem('skillCastPending') end
    if type(api.GetAttributeRespecCastTimeRemainingMs)=='function' and api.GetAttributeRespecCastTimeRemainingMs()>0 then return KW.Problem('attributeCastPending') end
    -- An absent unrelated UI is harmless; an initialized but unreadable one
    -- cannot prove that a foreign draft is clear. Check every signed delta.
    for name,stats in pairs({keyboard=api.STATS,gamepad=api.GAMEPAD_STATS}) do
        local data=name=='keyboard' and stats.attributeControls or stats.attributeData
        if not data then
            local lazy=name=='keyboard' and not stats.initialized and type(stats.OnShowing)=='function' or
                name=='gamepad' and not stats.deferredInitialized and type(stats.PerformDeferredInitializationRoot)=='function'
            if not lazy then return KW.Problem('buildCapabilityUnavailable',{component='skills',name='attributePendingState'}) end
        else
            local count=0
            for _,row in pairs(data) do
                count=count+1
                local value
                if name=='keyboard' then
                    local spinner=row.pointLimitedSpinner
                    if not spinner or type(spinner.GetAllocatedPoints)~='function' then return KW.Problem('buildCapabilityUnavailable',{component='skills',name='attributePendingState'}) end
                    value=spinner:GetAllocatedPoints()
                else value=row.addedPoints end
                if type(value)~='number' then return KW.Problem('buildCapabilityUnavailable',{component='skills',name='attributePendingState'}) end
                if value~=0 then return KW.Problem('foreignAttributeDraft') end
            end
            if count~=3 then return KW.Problem('buildCapabilityUnavailable',{component='skills',name='attributePendingState'}) end
        end
    end
end

function Adapter:CaptureDraft()
    if not self.mounted then return nil end
    if self.mounted.frozen then return nil,KW.Problem('skillDraftCleanupFailed') end
    local global,allocation,bars=self:NativeManagers()
    if not global then return nil,allocation end
    local blocked=self:OwnedDraftProblem(global)
    if blocked then return nil,blocked end
    local catalogue=self:Catalogue()
    if not catalogue.available then return nil,catalogue.problem end
    local result={skills={},bars={}}
    for key,record in pairs(catalogue.byKey) do
        if record.mutable then
            local allocator=allocation:GetSkillPointAllocatorForSkillData(record.native)
            if record.kind=='passive' then
                result.skills[key]={kind='passive',rank=allocator:IsPurchased() and allocator:GetRank() or 0}
            else
                result.skills[key]={kind='active',purchased=allocator:IsPurchased(),
                    morph=allocator:IsPurchased() and allocator:GetMorphSlot() or nil}
            end
        end
    end
    for _,bar in ipairs({'front','back','werewolf'}) do
        local captured={};result.bars[bar]=captured
        for slot=1,6 do
            local metadata=catalogue.barMetadata[bar][slot]
            local action=bars:GetHotbar(metadata.category):GetSlotData(metadata.nativeSlot)
            local skill=action and not action:IsEmpty() and action:GetPlayerSkillData()
            if not action or (not action:IsEmpty() and not skill) then return nativeUnavailable('unresolvedDraftBarAction') end
            if skill then
                captured[slot]={kind='skill',skillKey=KW.SkillState.Key(skill),
                    expectedMorph=not skill:IsCraftedAbility() and allocation:GetSkillPointAllocatorForSkillData(skill):GetMorphSlot() or nil}
            else captured[slot]={kind='empty'} end
        end
    end
    return result
end

local function checked(allocator,name,...)
    local result=allocator[name](allocator,...)
    if result~=true then error('Native skill allocator rejected '..name) end
end

local function changeAllocator(allocator,wanted,refundOnly)
    if wanted.kind=='passive' then
        local desired=wanted.rank
        if refundOnly then
            while allocator:IsPurchased() and allocator:GetRank()>math.max(1,desired) do checked(allocator,'DecreaseRank') end
            if desired==0 and allocator:IsPurchased() then checked(allocator,'Sell') end
        elseif desired>0 then
            if not allocator:IsPurchased() then checked(allocator,'Purchase') end
            while allocator:GetRank()<desired do checked(allocator,'IncreaseRank') end
        end
    elseif refundOnly then
        if allocator:IsPurchased() and allocator:GetMorphSlot()~=0 and (not wanted.purchased or wanted.morph==0) then checked(allocator,'Unmorph') end
        if not wanted.purchased and allocator:IsPurchased() then checked(allocator,'Sell') end
    elseif wanted.purchased then
        if not allocator:IsPurchased() then checked(allocator,'Purchase') end
        if wanted.morph~=0 and allocator:GetMorphSlot()~=wanted.morph then checked(allocator,'Morph',wanted.morph) end
    end
end

function Adapter:Hydrate(request,catalogue,allocation,bars)
    for _,change in ipairs(request.skillChanges) do
        changeAllocator(allocation:GetSkillPointAllocatorForSkillData(catalogue.byKey[change.key].native),change.target,true)
    end
    for _,change in ipairs(request.skillChanges) do
        changeAllocator(allocation:GetSkillPointAllocatorForSkillData(catalogue.byKey[change.key].native),change.target,false)
    end
    -- Rebuild exact desired positions after purchase callbacks have autofilled.
    -- Clear differences first so native same-bar relocation cannot erase swaps.
    for _,bar in ipairs({'front','back','werewolf'}) do
        for slot=1,6 do
            local metadata=catalogue.barMetadata[bar][slot]
            if metadata.eligible~=false and not metadata.locked and metadata.mutable and not metadata.override and not metadata.runtimeOverride then
                local hotbar=bars:GetHotbar(metadata.category)
                local action=hotbar:GetSlotData(metadata.nativeSlot)
                local wanted=request.target.bars[bar][slot]
                local skill=action and not action:IsEmpty() and action:GetPlayerSkillData()
                if skill and (wanted.kind=='empty' or KW.SkillState.Key(skill)~=wanted.skillKey) then
                    hotbar:ClearSlot(metadata.nativeSlot)
                    if not hotbar:GetSlotData(metadata.nativeSlot):IsEmpty() then error('Native hotbar rejected clear') end
                end
            end
        end
    end
    for _,bar in ipairs({'front','back','werewolf'}) do
        for slot=1,6 do
            local wanted=request.target.bars[bar][slot]
            local metadata=catalogue.barMetadata[bar][slot]
            if wanted.kind=='skill' and metadata.eligible~=false and not metadata.locked and metadata.mutable and not metadata.override and not metadata.runtimeOverride then
                local hotbar=bars:GetHotbar(metadata.category)
                local native=catalogue.byKey[wanted.skillKey].native
                hotbar:AssignSkillToSlot(metadata.nativeSlot,native)
                if not hotbar:GetSlotData(metadata.nativeSlot):EqualsSkillData(native) then error('Native hotbar rejected assignment') end
            end
        end
    end
end

function Adapter:DraftCallbacks(allocation,bars,changed)
    local callback=function()
        if self.mounted and not self.mounted.frozen and not self.hydrating and changed then
            local captured,err=self:CaptureDraft()
            changed(captured,err)
        end
    end
    self.draftCallbacks={}
    for _,entry in ipairs({{allocation,'PurchasedChanged'},{allocation,'SkillProgressionKeyChanged'},{bars,'SlotUpdated'}}) do
        entry[1]:RegisterCallback(entry[2],callback)
        self.draftCallbacks[#self.draftCallbacks+1]={object=entry[1],name=entry[2],callback=callback}
    end
end

function Adapter:RemoveDraftCallbacks()
    for _,entry in ipairs(self.draftCallbacks or {}) do entry.object:UnregisterCallback(entry.name,entry.callback) end
    self.draftCallbacks=nil
end

function Adapter:MountDraft(abilities,changed)
    if self.mounted or self:SubmissionLocked() then return nil,KW.Problem('skillDraftActive') end
    local global,allocation,bars=self:NativeManagers()
    if not global then return nil,allocation end
    local blocked=self:ForeignDraftProblem(global) or self:ReadinessProblem()
    if blocked then return nil,blocked end
    local current,err=self:Capture()
    if not current then return nil,err end
    local catalogue=self:Catalogue()
    local request;request,err=self:Prepare(current,abilities,catalogue)
    if not request then return nil,err end
    self.mountGeneration=(self.mountGeneration or 0)+1
    self.mounted={frozen=false,token=self.mountGeneration,original=KW.Copy(current),auxiliaryOriginal={}}
    for category,slots in pairs(catalogue.auxiliaryBars or {}) do
        self.mounted.auxiliaryOriginal[category]={}
        for slot,metadata in pairs(slots) do self.mounted.auxiliaryOriginal[category][slot]=KW.Copy(metadata.ref) end
    end
    self.hydrating=true
    local ok,reason=pcall(function()
        global:SetSkillPointAllocationMode(self.api.SKILL_POINT_ALLOCATION_MODE_FULL)
        self:DraftCallbacks(allocation,bars,changed)
        self:Hydrate(request,catalogue,allocation,bars)
        local captured,captureProblem=self:CaptureDraft()
        if not captured or not KW.BuildModel.Matches({abilities=captured},{abilities=request.target}) then
            error(captureProblem and captureProblem.code or 'Native skill draft differs from requested state')
        end
    end)
    self.hydrating=false
    if not ok then
        local cleaned,cleanupProblem=self:DiscardDraft()
        if not cleaned then return nil,cleanupProblem end
        return nil,KW.Problem('skillDraftFailed',{error=tostring(reason)})
    end
    return true
end

function Adapter:CleanOwnedNative(global)
    self.hydrating=true
    global.isDirty=false
    local ok,reason=pcall(function() global:ResetRespecState() end)
    global.isDirty=false
    local verified,pending=pcall(function()
        return KW.SkillState.HasPendingChanges(self.api) or global:GetSkillPointAllocationMode()~=self.api.SKILL_POINT_ALLOCATION_MODE_PURCHASE_ONLY
    end)
    if not ok or not verified or pending then
        -- Freeze in batch rather than let OnUpdate submit uncertain leftovers.
        pcall(function() global:SetSkillPointAllocationMode(self.api.SKILL_POINT_ALLOCATION_MODE_FULL) end)
        global.isDirty=false
        if self.mounted then self.mounted.frozen=true end
        self.hydrating=false
        return nil,KW.Problem('skillDraftCleanupFailed',{error=tostring(reason or pending)})
    end
    self.hydrating=false
    return true
end

function Adapter:UnmountDraft()
    if not self.mounted then return true end
    local captured,err=self:CaptureDraft()
    if not captured then return nil,err end
    local global=self.api.SKILLS_AND_ACTION_BAR_MANAGER
    local ok;ok,err=self:CleanOwnedNative(global)
    if not ok then return nil,err end
    self:RemoveDraftCallbacks();self.mounted=nil
    return captured
end

function Adapter:DiscardDraft()
    if not self.mounted then return true end
    local global,err=self:NativeManagers()
    if not global then return nil,err end
    local blocked=self:OwnedDraftProblem(global) or self:RecoveryGuard()
    if blocked then return nil,blocked end
    local actual;actual,err=self:Capture()
    if not actual then return nil,err end
    if fingerprint(actual)~=fingerprint(self.mounted.original) or not auxiliaryMatches(self:Catalogue(),self.mounted.auxiliaryOriginal)then return nil,KW.Problem('recoveryChanged')end
    local ok;ok,err=self:CleanOwnedNative(global)
    if not ok then return nil,err end
    self:RemoveDraftCallbacks();self.mounted=nil
    return true
end

function Adapter:GetSubmissionState() return KW.Copy(self.submission) end

function Adapter:SubmissionLocked()
    return self.submission.phase=='entry' or self.submission.phase=='dispatching' or self.submission.phase=='waiting' or self.submission.phase=='unknown'
        or (self.submission.sent and not self.submission.resolved)
end

function Adapter:SubmissionState(phase,err)
    self.submission.phase=phase;self.submission.problem=err
    self.events:Emit('SkillSubmissionChanged',self:GetSubmissionState())
end

function Adapter:ClearSubmissionListeners()
    for _,handle in ipairs(self.submissionListeners or {}) do self.events:Unsubscribe(handle) end
    self.submissionListeners=nil
    if self.entryTimer then self.clock:Cancel(self.entryTimer);self.entryTimer=nil end
    if self.readyTimer then self.clock:Cancel(self.readyTimer);self.readyTimer=nil end
    if self.submissionModeCallback then
        local entry=self.submissionModeCallback
        entry.object:UnregisterCallback('SkillPointAllocationModeChanged',entry.callback)
        self.submissionModeCallback=nil
    end
end

function Adapter:GuardSubmissionMode(global,token)
    local callback=function(mode)
        if self.generation~=token or not self.submission.sent or self.submission.resolved
            or mode~=self.api.SKILL_POINT_ALLOCATION_MODE_PURCHASE_ONLY then return end
        -- Native reset may precede/follow the result bridge, and a later reset
        -- callback may dirty the manager. FULL prevents OnUpdate from sending
        -- regardless that ordering until actual facts resolve this own request.
        global.isDirty=false
        local ok,reason=pcall(function() global:SetSkillPointAllocationMode(self.api.SKILL_POINT_ALLOCATION_MODE_FULL) end)
        global.isDirty=false
        if not ok then self:SubmissionState('unknown',KW.Problem('skillDraftCleanupFailed',{error=tostring(reason)})) end
    end
    global:RegisterCallback('SkillPointAllocationModeChanged',callback)
    self.submissionModeCallback={object=global,callback=callback}
end

function Adapter:CleanUnsentSubmission()
    local state=self.submission
    local global=self.api.SKILLS_AND_ACTION_BAR_MANAGER
    if state.sent or not state.full or global:GetSkillPointAllocationMode()~=self.api.SKILL_POINT_ALLOCATION_MODE_FULL then return true end
    -- Never reset edits another observer/user introduced while ENTRY waited.
    if global.isDirty or KW.SkillState.HasPendingChanges(self.api) then return nil,KW.Problem('foreignSkillDraft') end
    return self:CleanOwnedNative(global)
end

function Adapter:FailSubmission(err)
    if self.submission.sent then self:SubmissionState('unknown',err)
    else
        self:ClearSubmissionListeners()
        local cleaned,cleanup=self:CleanUnsentSubmission()
        self.submission.resolved=cleaned==true
        self:SubmissionState(cleaned and 'failed' or 'unknown',cleaned and err or cleanup)
    end
    return nil,err
end

function Adapter:AddBarMessage(ref,metadata,catalogue)
    local kind,id=self.api.ACTION_TYPE_NOTHING,0
    if ref.kind=='skill' then
        local record=catalogue.byKey[ref.skillKey]
        if record.kind=='crafted' then kind=self.api.ACTION_TYPE_CRAFTED_ABILITY;id=record.native:GetCraftedAbilityId()
        else kind=self.api.ACTION_TYPE_ABILITY;id=record.native:GetMorphData(ref.expectedMorph):GetAbilityId() end
    end
    self.api.AddHotbarSlotChangeToAllocationRequest(metadata.nativeSlot,metadata.category,kind,id)
end

function Adapter:SendPrepared(request,catalogue,full)
    local api=self.api
    local token=self.generation
    local signature=fingerprint(catalogue)
    self:SubmissionState('dispatching') -- synchronous durable may-send boundary
    if self.generation~=token or self.submission.phase~='dispatching' then return end
    local global=self.api.SKILLS_AND_ACTION_BAR_MANAGER
    local blocked=self:ReadinessProblem()
    if blocked then return self:FailSubmission(blocked) end
    local mode=full and api.SKILL_POINT_ALLOCATION_MODE_FULL or api.SKILL_POINT_ALLOCATION_MODE_PURCHASE_ONLY
    if global:GetSkillPointAllocationMode()~=mode or global.isDirty or KW.SkillState.HasPendingChanges(self.api) then return self:FailSubmission(KW.Problem('foreignSkillDraft')) end
    if full and global:GetSkillRespecPaymentType()~=api.RESPEC_PAYMENT_TYPE_GOLD then return self:FailSubmission(KW.Problem('skillEntryNotReady')) end
    local fresh=self:Catalogue()
    if not fresh.available then return self:FailSubmission(fresh.problem) end
    if fingerprint(fresh)~=signature or fingerprint(fresh.abilities)~=fingerprint(self.submission.original) then return self:FailSubmission(KW.Problem('buildStateChanged')) end
    local rechecked,problem=self:Prepare(fresh.abilities,request.target,fresh)
    if not rechecked then return self:FailSubmission(problem) end
    if fingerprint(rechecked)~=fingerprint(request) then return self:FailSubmission(KW.Problem('buildStateChanged')) end
    request=rechecked;catalogue=fresh
    api.PrepareSkillPointAllocationRequest(full and api.SKILL_POINT_ALLOCATION_MODE_FULL or api.SKILL_POINT_ALLOCATION_MODE_PURCHASE_ONLY,api.RESPEC_PAYMENT_TYPE_GOLD)
    for _,change in ipairs(request.skillChanges) do
        local record=catalogue.byKey[change.key]
        if record.kind=='active' then
            api.AddActiveChangeToAllocationRequest(record.lineId,record.native:GetProgressionId(),change.target.morph or 0,change.target.purchased)
        else
            local removal=change.target.rank==0
            local rank=removal and change.before.rank or change.target.rank
            api.AddPassiveChangeToAllocationRequest(record.lineId,record.native:GetRankData(rank):GetAbilityId(),removal)
        end
    end
    if full then
        for _,bar in ipairs({'front','back','werewolf'}) do
            for slot=1,6 do
                local metadata=catalogue.barMetadata[bar][slot]
                local wanted=request.target.bars[bar][slot]
                local boundMorph=isBoundSkillMorphChange(metadata,catalogue.abilities.bars[bar][slot],wanted)
                if metadata.eligible~=false and not metadata.locked and metadata.mutable
                    and (boundMorph or bar=='werewolf' and metadata.override==wanted.skillKey and metadata.runtimeOverride==wanted.skillKey
                        or not metadata.override and not metadata.runtimeOverride) then
                    self:AddBarMessage(wanted,metadata,catalogue)
                end
            end
        end
    else
        for _,change in ipairs(request.barChanges) do self:AddBarMessage(change.target,catalogue.barMetadata[change.bar][change.slot],catalogue) end
    end
    for _,change in ipairs(request.auxiliaryChanges or {}) do
        self:AddBarMessage(change.target,catalogue.auxiliaryBars[change.category][change.nativeSlot],catalogue)
    end
    self.submission.sent=true
    self.submission.sentAt=self.clock:NowMs()
    self.submission.phase='waiting'
    api.SendSkillPointAllocationRequest()
    self.events:Emit('SkillSubmissionChanged',self:GetSubmissionState())
end

function Adapter:Submit(request)
    if self.mounted then return nil,KW.Problem('skillDraftActive') end
    if self:SubmissionLocked() then return nil,KW.Problem('skillSubmissionActive') end
    local global,err=self:NativeManagers()
    if not global then return nil,err end
    local blocked=self:ForeignDraftProblem(global) or self:ReadinessProblem()
    if blocked then return nil,blocked end
    for _,name in ipairs({'PrepareSkillPointAllocationRequest','AddActiveChangeToAllocationRequest',
        'AddPassiveChangeToAllocationRequest','AddHotbarSlotChangeToAllocationRequest','SendSkillPointAllocationRequest','StartSkillRespecFromUI'}) do
        if type(self.api[name])~='function' then return nativeUnavailable(name) end
    end
    if type(request)~='table' or type(request.target)~='table' then return nil,KW.Problem('invalidPreset') end
    local desiredTarget=KW.Copy(request.target)
    local current;current,err=self:Capture()
    if not current then return nil,err end
    if request.werewolfOriginal and fingerprint(request.werewolfOriginal)~=fingerprint(current.bars and current.bars.werewolf) then return nil,KW.Problem('buildStateChanged') end
    local catalogue=self:Catalogue()
    local capturedSignature=fingerprint(current)
    local prepared;prepared,err=self:Prepare(current,desiredTarget,catalogue)
    if not prepared then return nil,err end
    if fingerprint(request.auxiliaryOriginal or {})~=fingerprint(prepared.auxiliaryOriginal) or
        fingerprint(request.auxiliaryTarget or {})~=fingerprint(prepared.auxiliaryTarget) then return nil,KW.Problem('buildStateChanged') end
    self.generation=self.generation+1
    local token=self.generation
    self.submission={phase='idle',token=token,sent=false,full=#prepared.skillChanges>0,
        original=KW.Copy(current),target=KW.Copy(prepared.target),
        auxiliaryOriginal=KW.Copy(prepared.auxiliaryOriginal),auxiliaryTarget=KW.Copy(prepared.auxiliaryTarget)}
    self.submissionListeners={self.events:Subscribe('NativeSkillRespecResult',function(payload)
        if self.generation~=token or not self.submission.sent or self.submission.resolved then return end
        self.submission.result=payload.result
        self:SubmissionState('result')
    end)}
    if #prepared.skillChanges==0 then
        if #prepared.barChanges==0 and #prepared.auxiliaryChanges==0 then
            self.submission.resolved=true;self:ClearSubmissionListeners();self:SubmissionState('resolved');return true
        end
        local ok,reason=pcall(function() self:SendPrepared(prepared,catalogue,false) end)
        if not ok then return self:FailSubmission(KW.Problem('skillSubmissionFailed',{error=tostring(reason)})) end
        return true
    end
    self:GuardSubmissionMode(global,token)
    self:SubmissionState('entry')
    local scheduled=false
    local function entryReady(allocationMode,paymentType)
        if self.generation~=token or self.submission.phase~='entry' or scheduled then return end
        if allocationMode~=self.api.SKILL_POINT_ALLOCATION_MODE_FULL or paymentType~=self.api.RESPEC_PAYMENT_TYPE_GOLD then return end
        scheduled=true
        self.readyTimer=self.clock:Schedule(1,function()
            self.readyTimer=nil
            if self.generation~=token or self.submission.phase~='entry' then return end
            if global:GetSkillPointAllocationMode()~=self.api.SKILL_POINT_ALLOCATION_MODE_FULL or global:GetSkillRespecPaymentType()~=self.api.RESPEC_PAYMENT_TYPE_GOLD then
                self:FailSubmission(KW.Problem('skillEntryNotReady'));return
            end
            if global.isDirty or KW.SkillState.HasPendingChanges(self.api) then self:FailSubmission(KW.Problem('foreignSkillDraft'));return end
            local readinessProblem=self:ReadinessProblem()
            if readinessProblem then self:FailSubmission(readinessProblem);return end
            local actual,readProblem=self:Capture()
            if not actual then self:FailSubmission(readProblem);return end
            if fingerprint(actual)~=capturedSignature then self:FailSubmission(KW.Problem('buildStateChanged'));return end
            local liveCatalogue=self:Catalogue()
            local liveRequest,prepareProblem=self:Prepare(actual,desiredTarget,liveCatalogue)
            if not liveRequest then self:FailSubmission(prepareProblem);return end
            if fingerprint(liveRequest.auxiliaryOriginal)~=fingerprint(prepared.auxiliaryOriginal) or
                fingerprint(liveRequest.auxiliaryTarget)~=fingerprint(prepared.auxiliaryTarget) then self:FailSubmission(KW.Problem('buildStateChanged'));return end
            if self.entryTimer then self.clock:Cancel(self.entryTimer);self.entryTimer=nil end
            local ok,reason=pcall(function() self:SendPrepared(liveRequest,liveCatalogue,true) end)
            if not ok then self:FailSubmission(KW.Problem('skillSubmissionFailed',{error=tostring(reason)})) end
        end)
    end
    self.submissionListeners[#self.submissionListeners+1]=self.events:Subscribe('NativeSkillRespecStarted',function(payload)
        entryReady(payload.allocationMode,payload.paymentType)
    end)
    self.entryTimer=self.clock:Schedule(5000,function()
        self.entryTimer=nil
        if self.generation==token and self.submission.phase=='entry' then self:FailSubmission(KW.Problem('skillEntryTimeout')) end
    end)
    local ok,reason=pcall(function()
        local api=self.api
        local interaction=type(api.GetInteractionType)=='function' and api.GetInteractionType() or nil
        local existing=api.INTERACTION_SKILL_RESPEC~=nil and interaction==api.INTERACTION_SKILL_RESPEC
        self.submission.entryContext={interaction=interaction,mode=global:GetSkillPointAllocationMode(),
            payment=global:GetSkillRespecPaymentType(),path=existing and 'existingInteraction' or 'startInteraction'}
        -- Match the native Skills respec keybind. A successful apply resets the
        -- allocation mode, but may leave the interaction active. Starting that
        -- interaction again produces no new EVENT_START_SKILL_RESPEC.
        if existing then
            global:SetSkillPointAllocationMode(api.SKILL_POINT_ALLOCATION_MODE_FULL)
            entryReady(global:GetSkillPointAllocationMode(),global:GetSkillRespecPaymentType())
        else api.StartSkillRespecFromUI()end
    end)
    if not ok then return self:FailSubmission(KW.Problem('skillSubmissionFailed',{error=tostring(reason)})) end
    return true -- accepted async ENTRY; actual/result verification belongs to runner
end

function Adapter:CancelSubmission()
    local phase=self.submission.phase
    if self.submission.sent and not self.submission.resolved then
        if phase=='waiting' and not self.submission.cancelRequested and type(self.api.CancelSkillPointAllocationRequest)=='function' then
            self.submission.cancelRequested=true
            local ok,reason=pcall(self.api.CancelSkillPointAllocationRequest)
            if not ok then return self:FailSubmission(KW.Problem('skillSubmissionFailed',{error=tostring(reason)})) end
        end
        self:SubmissionState('unknown',KW.Problem('skillSubmissionUncertain',{reason='cancelled'}))
        return true
    end
    self.generation=self.generation+1
    self.submission.cancelledGeneration=self.generation
    self:ClearSubmissionListeners()
    local cleaned,problem=self:CleanUnsentSubmission()
    self.submission.resolved=cleaned==true
    self:SubmissionState(cleaned and 'cancelled' or 'unknown',problem)
    return cleaned,problem
end

-- A native event has no request ID and can precede actual getters. Only the
-- coordinator's token + observed event + exact actual facts release ownership.
function Adapter:ResolveSubmission(result,token)
    local state=self.submission
    if token~=state.token then return nil,KW.Problem('skillSubmissionTokenMismatch') end
    if state.resolved then return true end
    if not state.sent or type(result)~='number' or state.result==nil or state.result~=result then
        return nil,KW.Problem('skillSubmissionUncertain')
    end
    if type(self.api.GetSkillRespecCastTimeRemainingMs)~='function' or self.api.GetSkillRespecCastTimeRemainingMs()>0 then
        return nil,KW.Problem('skillSubmissionUncertain')
    end
    local actual,err=self:Capture()
    if not actual then return nil,err end
    local expected=result==self.api.RESPEC_RESULT_SUCCESS and state.target or state.original
    if fingerprint(actual)~=fingerprint(expected) then return nil,KW.Problem('skillSubmissionUncertain') end
    local expectedAuxiliary=result==self.api.RESPEC_RESULT_SUCCESS and state.auxiliaryTarget or state.auxiliaryOriginal
    if not auxiliaryMatches(self:Catalogue(),expectedAuxiliary) then return nil,KW.Problem('skillSubmissionUncertain') end
    if state.full then
        local global=self.api.SKILLS_AND_ACTION_BAR_MANAGER
        if KW.SkillState.HasPendingChanges(self.api) then return nil,KW.Problem('foreignSkillDraft') end
        -- Temporarily permit the final native reset; release ownership only
        -- after synchronous callbacks/pending/mode verification succeed.
        state.resolved=true
        local cleaned,cleanupProblem=self:CleanOwnedNative(global)
        if not cleaned then
            state.resolved=false
            self:SubmissionState('unknown',cleanupProblem)
            return nil,cleanupProblem
        end
    end
    state.resolved=true
    self:ClearSubmissionListeners()
    self:SubmissionState('resolved')
    return true
end

-- Explicit local recovery never manufactures a server result or sends a packet.
function Adapter:GetNativeOwnership()
    if self.mounted then return {token=self.mounted.token,phase='editor',page='skills',possibleSent=false} end
    if self:SubmissionLocked() then return {token=self.submission.token,phase=self.submission.phase,page='skills',possibleSent=self.submission.sent==true or self.submission.phase=='dispatching'} end
end
local function recoveryCastProblem(adapter)
    local api=adapter.api
    for _,name in ipairs({'GetSkillRespecCastTimeRemainingMs','GetAttributeRespecCastTimeRemainingMs'}) do
        if type(api[name])=='function' and api[name]()~=0 then return KW.Problem('buildSubmissionUnresolved') end
    end
    if type(api.GetSkillRespecCastTimeRemainingMs)~='function' then return KW.Problem('buildCapabilityUnavailable') end
end
function Adapter:RecoveryGuard()
    local blocked=recoveryCastProblem(self);if blocked then return blocked end
    local api=self.api
    local lines=api.SKILL_LINE_ASSIGNMENT_MANAGER
    if lines and (type(lines.IsAnyChangePending)~='function' or lines:IsAnyChangePending()) then return KW.Problem('foreignSkillDraft') end
    for name,stats in pairs({keyboard=api.STATS,gamepad=api.GAMEPAD_STATS}) do
        local rows=name=='keyboard' and stats.attributeControls or stats.attributeData
        if rows then
            local count=0
            for _,row in pairs(rows) do
                count=count+1
                local value
                if name=='keyboard' then
                    local spinner=row.pointLimitedSpinner
                    if not spinner or type(spinner.GetAllocatedPoints)~='function' then return KW.Problem('buildCapabilityUnavailable') end
                    value=spinner:GetAllocatedPoints()
                else value=row.addedPoints end
                if type(value)~='number' then return KW.Problem('buildCapabilityUnavailable') end
                if value~=0 then return KW.Problem('foreignAttributeDraft') end
            end
            if count~=3 then return KW.Problem('buildCapabilityUnavailable') end
        elseif not (name=='keyboard' and not stats.initialized and type(stats.OnShowing)=='function' or name=='gamepad' and not stats.deferredInitialized and type(stats.PerformDeferredInitializationRoot)=='function') then return KW.Problem('buildCapabilityUnavailable') end
    end
end
function Adapter:GetRecoveryFacts(descriptor)
    local catalogue=self:Catalogue()
    if not catalogue.available then return nil,catalogue.problem end
    local auxiliary={}
    for category,slots in pairs(descriptor and descriptor.auxiliaryTarget or {}) do
        auxiliary[category]={}
        for slot in pairs(slots) do
            local metadata=catalogue.auxiliaryBars and catalogue.auxiliaryBars[category] and catalogue.auxiliaryBars[category][slot]
            if not metadata then return nil,KW.Problem('skillSubmissionUncertain') end
            auxiliary[category][slot]=KW.Copy(metadata.ref)
        end
    end
    return {actual=KW.Copy(catalogue.abilities),auxiliaryActual=auxiliary,budgets=KW.Copy(catalogue.budgets)}
end
function Adapter:RecoveryDescriptorMatches(descriptor)
    local state=self.submission
    if not self:SubmissionLocked() then return true end
    return descriptor and descriptor.token==state.token and fingerprint(descriptor.original)==fingerprint(state.original)
        and fingerprint(descriptor.target)==fingerprint(state.target)
        and fingerprint(descriptor.auxiliaryOriginal or {})==fingerprint(state.auxiliaryOriginal or {})
        and fingerprint(descriptor.auxiliaryTarget or {})==fingerprint(state.auxiliaryTarget or {})
end
function Adapter:ReleaseAfterNativeExit(token,original)
    local owner=self.mounted
    if not owner or token~=owner.token or fingerprint(original)~=fingerprint(owner.original) then return nil,KW.Problem('recoveryChanged') end
    local global=self.api.SKILLS_AND_ACTION_BAR_MANAGER
    local blocked=self:RecoveryGuard()
    if blocked then return nil,blocked end
    if global:GetSkillPointAllocationMode()~=self.api.SKILL_POINT_ALLOCATION_MODE_PURCHASE_ONLY or KW.SkillState.HasPendingChanges(self.api) then return nil,KW.Problem('foreignSkillDraft') end
    local actual,err=self:Capture()
    if not actual then return nil,err end
    if fingerprint(actual)~=fingerprint(original) or not auxiliaryMatches(self:Catalogue(),owner.auxiliaryOriginal) then return nil,KW.Problem('recoveryChanged') end
    global.isDirty=false
    self:RemoveDraftCallbacks();self.mounted=nil
    return true
end
function Adapter:ReconcileSubmission(descriptor,action,expectedFacts)
    if self.mounted or (action~='actualTarget' and action~='acceptCurrent') or not self:RecoveryDescriptorMatches(descriptor) then return nil,KW.Problem('recoveryChanged') end
    local blocked=self:RecoveryGuard();if blocked then return nil,blocked end
    local global,err=self:NativeManagers();if not global then return nil,err end
    if KW.SkillState.HasPendingChanges(self.api) or global.isDirty then return nil,KW.Problem('foreignSkillDraft') end
    local facts;facts,err=self:GetRecoveryFacts(descriptor);if not facts then return nil,err end
    if fingerprint(facts)~=fingerprint(expectedFacts) then return nil,KW.Problem('recoveryChanged') end
    local comparable=KW.Copy(facts.actual)
    if descriptor.target and descriptor.target.bars and not descriptor.target.bars.werewolf then comparable.bars.werewolf=nil end
    if action=='actualTarget' and (fingerprint(comparable)~=fingerprint(descriptor.target) or fingerprint(facts.auxiliaryActual)~=fingerprint(descriptor.auxiliaryTarget or {})) then return nil,KW.Problem('skillSubmissionUncertain') end
    local state=self.submission;local wasResolved=state.resolved;state.resolved=true
    if global:GetSkillPointAllocationMode()==self.api.SKILL_POINT_ALLOCATION_MODE_FULL then
        local cleaned;cleaned,err=self:CleanOwnedNative(global)
        if not cleaned then state.resolved=wasResolved;return nil,err end
    elseif global:GetSkillPointAllocationMode()~=self.api.SKILL_POINT_ALLOCATION_MODE_PURCHASE_ONLY then state.resolved=wasResolved;return nil,KW.Problem('foreignSkillDraft') end
    local fresh;fresh,err=self:GetRecoveryFacts(descriptor)
    blocked=self:RecoveryGuard()
    if not fresh or fingerprint(fresh)~=fingerprint(facts) or blocked or KW.SkillState.HasPendingChanges(self.api) or global.isDirty then
        state.resolved=wasResolved
        global:SetSkillPointAllocationMode(self.api.SKILL_POINT_ALLOCATION_MODE_FULL)
        self:SubmissionState('unknown',blocked or err or KW.Problem('recoveryChanged'))
        return nil,blocked or err or KW.Problem('recoveryChanged')
    end
    self.generation=self.generation+1;self:ClearSubmissionListeners();state.resolved=true
    self:SubmissionState('reconciled')
    return {resolution=action,actual=facts.actual,auxiliaryActual=facts.auxiliaryActual,nativeOutcome=state.result==nil and 'unknown' or state.result,released=true}
end
function Adapter:RelinquishUnsentDraft(descriptor)
    local state=self.submission
    if state.sent or state.resolved or not state.cancelledGeneration or state.cancelledGeneration~=self.generation or not self:RecoveryDescriptorMatches(descriptor) or not descriptor or descriptor.token~=state.token then return nil,KW.Problem('skillSubmissionUncertain') end
    local blocked=recoveryCastProblem(self);if blocked then return nil,blocked end
    self:ClearSubmissionListeners();state.resolved=true;state.relinquished=true
    self:SubmissionState('relinquished')
    return {resolution='relinquished',nativeOutcome='unsent',retainedForeignDraft=true,released=true}
end
