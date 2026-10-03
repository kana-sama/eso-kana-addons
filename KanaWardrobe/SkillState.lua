local KW = KanaWardrobe
local SkillState = {}
KW.SkillState = SkillState

-- A selected Class Mastery line is a complete allocation of its own points.
-- Older presets store only enabled passives, so materialize the omitted ones
-- as refunds before planning affordability. Other skill lines stay partial.
-- This uses the supplied catalogue, including its lightweight display form.
function SkillState.ExpandMasterySelection(abilities,catalogue)
    if not abilities or not abilities.skills or not catalogue or not catalogue.available then return abilities end
    local selectedLines={}
    for key in pairs(abilities.skills) do
        local record=catalogue.byKey[key]
        if record and record.mastery then selectedLines[record.lineId]=true end
    end
    if not next(selectedLines) then return abilities end
    local result=KW.Copy(abilities)
    for key,record in pairs(catalogue.byKey) do
        if record.mastery and selectedLines[record.lineId] and record.mutable
            and record.kind=='passive' and not result.skills[key] then
            result.skills[key]={kind='passive',rank=record.minimumRank or 0}
        end
    end
    return result
end

-- ResetSlot populates the werewolf ultimate from its override rule even when
-- the actual slot is empty. Prove that this is the already purchased actual
-- skill/morph, not a pending purchase, reassignment or allocator selection.
local function isAutomaticWerewolfBinding(api,category,slot,hotbar,action)
    if category~=api.HOTBAR_CATEGORY_WEREWOLF
        or action:GetSlottableActionType()~=api.ZO_SLOTTABLE_ACTION_TYPE_PLAYER_SKILL then return false end
    local _,last=api.GetAssignableAbilityBarStartAndEndSlots()
    if slot~=last then return false end
    local progressionId=api.GetSkillProgressionIdForHotbarSlotOverrideRule(slot,category)
    if type(progressionId)~='number' or progressionId<=0 then return false end
    local skill=api.SKILLS_DATA_MANAGER:GetSkillDataByProgressionId(progressionId)
    return skill~=nil and skill:IsPurchased() and skill:IsUltimate()
        and hotbar:GetOverrideSkillDataForSlot(slot)==skill and action:GetPlayerSkillData()==skill
        and action:GetActionId()==skill:GetCurrentProgressionData():GetAbilityId()
end

-- Staff elements and other chained variants have different ability IDs for
-- the same learned morph. ESO maps them through GetProgressionDataByAbilityId.
-- Compare all three IDs with that map, so a different skill/morph or an
-- unreadable binding still counts as a real pending edit.
local function isSamePlayerSkillBinding(api,action,actualId,selectedId,effectiveId)
    if type(selectedId)~='number' or selectedId<=0 then return false end
    if action:GetSlottableActionType()~=api.ZO_SLOTTABLE_ACTION_TYPE_PLAYER_SKILL then return false end
    local skill=action:GetPlayerSkillData()
    if not skill or not skill:IsPurchased() or skill:IsCraftedAbility() then return false end
    local morph=skill:GetCurrentMorphSlot()
    for _,id in ipairs({actualId,selectedId,effectiveId})do
        local progression=api.SKILLS_DATA_MANAGER:GetProgressionDataByAbilityId(id)
        if not progression or progression:GetSkillData()~=skill or progression:GetMorphSlot()~=morph then return false end
    end
    return true
end

-- Native pending includes effective-ID aliases and automatic forced bindings.
-- Purchases, morphs, other managers and unreadable state stay protected. This
-- only classifies the pending state; it never resets or submits native edits.
function SkillState.HasPendingChanges(api)
    local ok,pending=pcall(function()
        local global=api.SKILLS_AND_ACTION_BAR_MANAGER
        if not global:HasAnyPendingChanges() then return false end
        local bars=api.ACTION_BAR_ASSIGNMENT_MANAGER
        if not bars or type(global.managers)~='table' or type(bars.hotbars)~='table' then return true end
        local foundBars=false
        for _,manager in ipairs(global.managers)do
            if manager==bars then foundBars=true
            elseif manager:IsAnyChangePending() then return true end
        end
        -- Some manager versions register lazily; don't omit known domains just
        -- because they are not yet present in the aggregate's manager array.
        local allocation=api.SKILL_POINT_ALLOCATION_MANAGER
        if not allocation or allocation:IsAnyChangePending() then return true end
        local lines=api.SKILL_LINE_ASSIGNMENT_MANAGER
        if lines and lines:IsAnyChangePending() then return true end
        if not foundBars or not bars:IsAnyChangePending() then return true end
        local explained=false
        for category,hotbar in pairs(bars.hotbars)do
            if bars:ShouldSubmitChangesForHotbarCategory(category) then
                for slot,action in hotbar:SlotIterator()do
                    if hotbar:DoesSlotHavePendingChanges(slot) then
                        local kind=action:GetActionType()
                        local slottable=action:GetSlottableActionType()
                        if kind~=api.ACTION_TYPE_ABILITY
                            or slottable==nil or (slottable~=api.ZO_SLOTTABLE_ACTION_TYPE_PLAYER_SKILL
                                and slottable~=api.ZO_SLOTTABLE_ACTION_TYPE_COMPANION_SKILL) then return true end
                        local actualType=api.GetSlotType(slot,category)
                        local actualId=api.GetSlotBoundId(slot,category)
                        local selectedId=action:GetActionId()
                        local effectiveId=action:GetEffectiveAbilityId()
                        if type(effectiveId)~='number' or effectiveId<=0 then return true end
                        if actualType==api.ACTION_TYPE_NOTHING and actualId==0 then
                            if not isAutomaticWerewolfBinding(api,category,slot,hotbar,action) then return true end
                        elseif actualType~=kind or type(actualId)~='number' or actualId<=0
                            or effectiveId==actualId then return true
                        elseif actualId~=selectedId and not isSamePlayerSkillBinding(api,action,actualId,selectedId,effectiveId) then return true end
                        explained=true
                    end
                end
            end
        end
        return not explained
    end)
    return not ok or pending,not ok and tostring(pending) or nil
end

-- List indices locate native objects; the persisted identity never uses them.
function SkillState.Key(skill)
    local lineId = skill:GetSkillLineData():GetId()
    if skill:IsCraftedAbility() then
        return lineId .. ':crafted:' .. skill:GetCraftedAbilityId()
    elseif skill:IsPassive() then
        return lineId .. ':passive:' .. skill:GetRankData(1):GetAbilityId()
    end
    return lineId .. ':active:' .. skill:GetProgressionId()
end

local function unavailable(name)
    return {available=false, byKey={}, abilities={skills={},bars={}},
        budgets={skills=0,mastery={}}, problem=KW.Problem('buildCapabilityUnavailable',
            {component='skills',name=name})}
end

local function craftedReady(api,id)
    for _,name in ipairs({'IsCraftedAbilityScribed','IsCraftedAbilityDisabled',
        'GetCraftedAbilityActiveScriptIds','IsCraftedAbilityScriptDisabled'}) do
        if type(api[name])~='function' then return false end
    end
    if not api.IsCraftedAbilityScribed(id) or api.IsCraftedAbilityDisabled(id) then return false end
    local scripts={api.GetCraftedAbilityActiveScriptIds(id)}
    for slot=1,3 do
        local scriptId=scripts[slot]
        if not scriptId or scriptId==0 or api.IsCraftedAbilityScriptDisabled(scriptId) then return false end
    end
    return true
end

local function rawReference(api,manager,nativeSlot,category)
    local skill,progression
    local actionType=api.GetSlotType(nativeSlot,category)
    local actionId=api.GetSlotBoundId(nativeSlot,category)
    if actionType==api.ACTION_TYPE_ABILITY then
        progression=manager:GetProgressionDataByAbilityId(actionId)
    elseif actionType==api.ACTION_TYPE_CRAFTED_ABILITY and type(api.GetAbilityIdForCraftedAbilityId)=='function' then
        progression=manager:GetProgressionDataByAbilityId(api.GetAbilityIdForCraftedAbilityId(actionId))
    elseif actionType~=api.ACTION_TYPE_NOTHING then return nil end
    if actionType~=api.ACTION_TYPE_NOTHING and not progression then return nil end
    skill=progression and progression:GetSkillData()
    if not skill then return {kind='empty'} end
    return {kind='skill',skillKey=SkillState.Key(skill),
        expectedMorph=not skill:IsCraftedAbility() and progression:GetMorphSlot() or nil}
end

local function read(api,displayOnly)
    local manager = api.SKILLS_DATA_MANAGER
    local bars = api.ACTION_BAR_ASSIGNMENT_MANAGER
    if not manager or type(manager.SkillTypeIterator)~='function' or not manager:IsDataReady() then
        return unavailable('SKILLS_DATA_MANAGER')
    end
    local required=displayOnly and {'GetAssignableAbilityBarStartAndEndSlots','GetSlotType','GetSlotBoundId'}
        or {'GetAvailableSkillPoints','GetAssignableAbilityBarStartAndEndSlots','GetSlotType','GetSlotBoundId','GetSkillProgressionIdForHotbarSlotOverrideRule'}
    for _,name in ipairs(required) do
        if type(api[name])~='function' then return unavailable(name) end
    end
    if type(manager.GetSkillDataByProgressionId)~='function' then return unavailable('GetSkillDataByProgressionId') end
    if not bars or type(bars.GetHotbar)~='function' then return unavailable('ACTION_BAR_ASSIGNMENT_MANAGER') end
    local first,last = api.GetAssignableAbilityBarStartAndEndSlots()
    if type(first)~='number' or type(last)~='number' or last-first~=5 then
        return unavailable('GetAssignableAbilityBarStartAndEndSlots')
    end
    local result = {available=true, byKey={}, abilities={skills={},bars={}},
        budgets={skills=not displayOnly and api.GetAvailableSkillPoints() or 0,mastery={}}, nativeSlots={},barMetadata={}}
    for slot=1,6 do result.nativeSlots[slot]=first+slot-1 end
    for _,skillType in manager:SkillTypeIterator() do
        for _,line in skillType:SkillLineIterator() do
            local lineId = line:GetId()
            if not displayOnly and line:IsClassMastery() then
                result.budgets.mastery[lineId]=line:GetNumClassMasteryPoints()-line:GetNumPointsAllocated()
            end
            for _,skill in line:SkillIterator() do
                local key = SkillState.Key(skill)
                local kind = skill:IsCraftedAbility() and 'crafted' or skill:IsPassive() and 'passive' or 'active'
                local record = {key=key,kind=kind,lineId=lineId,native=skill,
                    available=line:IsAvailable(),purchased=skill:IsPurchased(),
                    autoGrant=skill:IsAutoGrant(),mastery=line:IsClassMastery()}
                if not displayOnly then
                    record.ultimate=skill:IsUltimate()
                    record.purchaseUnlocked=skill:MeetsLinePurchaseRequirement()
                    record.cost=skill:GetSkillPointCostMultiplier()
                    record.masteryTransactionCost=line:GetClassMasteryCost()
                end
                -- Native skill names live on actual progression data, not the
                -- pending allocator progression or a parsed localized label.
                local progression=not displayOnly and type(skill.GetCurrentProgressionData)=='function' and skill:GetCurrentProgressionData()
                if progression and type(progression.GetName)=='function' then
                    local name=progression:GetName()
                    if type(name)=='string' and name~='' then record.name=name end
                end
                if kind=='passive' then
                    record.state={kind=kind,rank=record.purchased and skill:GetCurrentRank() or 0}
                    record.maxRank=skill:GetNumRanks()
                    record.minimumRank=record.autoGrant and 1 or 0
                    if not displayOnly then
                        record.rankUnlocked={}
                        for rank=1,record.maxRank do
                            record.rankUnlocked[rank]=skill:GetRankData(rank):MeetsUnlockRequirement()
                        end
                    end
                    record.mutable=not record.autoGrant or record.maxRank>1
                elseif kind=='active' then
                    record.state={kind=kind,purchased=record.purchased,
                        morph=record.purchased and skill:GetCurrentMorphSlot() or nil}
                    if not displayOnly then
                        record.morphUnlocked={}
                        for morph=0,2 do record.morphUnlocked[morph]=skill:GetMorphData(morph):IsUnlocked() end
                    end
                    record.mutable=not record.autoGrant or skill:CanPointAllocationsBeAltered(api.SKILL_POINT_ALLOCATION_MODE_FULL)
                else
                    record.mutable=false
                    record.craftedReady=craftedReady(api,skill:GetCraftedAbilityId())
                end
                if type(line.IsWerewolf)=='function' then record.werewolf=line:IsWerewolf()==true end
                result.byKey[key]=record
                if record.mutable and record.state then result.abilities.skills[key]=KW.Copy(record.state) end
            end
        end
    end
    local categories={front=api.HOTBAR_CATEGORY_PRIMARY,back=api.HOTBAR_CATEGORY_BACKUP,werewolf=api.HOTBAR_CATEGORY_WEREWOLF}
    for _,bar in ipairs({'front','back','werewolf'}) do
        local category=categories[bar]
        if category==nil then return unavailable('HOTBAR_CATEGORY_'..bar) end
        local hotbar=bars:GetHotbar(category)
        local captured={};result.abilities.bars[bar]=captured
        local metadata={};result.barMetadata[bar]=metadata
        for slot=1,6 do
            local nativeSlot=result.nativeSlots[slot]
            -- Native override getter follows the pending point allocator. Keep it
            -- only as runtime editability metadata, never as actual bar truth.
            if not displayOnly then
                local runtimeOverride=hotbar:GetOverrideSkillDataForSlot(nativeSlot)
                local actualOverride
                local id=api.GetSkillProgressionIdForHotbarSlotOverrideRule(nativeSlot,category)
                if id~=0 then
                    local rule=manager:GetSkillDataByProgressionId(id)
                    if not rule then return unavailable('unresolvedBarOverride') end
                    if rule:IsPurchased() then actualOverride=rule end
                end
                metadata[slot]={locked=hotbar:IsSlotLocked(nativeSlot),mutable=hotbar:IsSlotMutable(nativeSlot),
                    override=actualOverride and SkillState.Key(actualOverride) or nil,
                    runtimeOverride=runtimeOverride and SkillState.Key(runtimeOverride) or nil,category=category,nativeSlot=nativeSlot}
            end
            captured[slot]=rawReference(api,manager,nativeSlot,category)
            if not captured[slot] then return unavailable('unresolvedBarAction') end
        end
    end
    -- Presentation is actual identity/state only. No allocator constraints,
    -- auxiliary dependency traversal or recursive catalogue fingerprint.
    if displayOnly then return result end
    -- Keep auxiliary facts for overload and for recovery of older werewolf journals.
    result.auxiliaryBars={}
    if type(bars.ShouldSubmitChangesForHotbarCategory)~='function' then return unavailable('ShouldSubmitChangesForHotbarCategory') end
    for _,name in ipairs({'HOTBAR_CATEGORY_OVERLOAD','HOTBAR_CATEGORY_WEREWOLF'}) do
        local category=api[name]
        if category==nil then return unavailable(name) end
        local hotbar=bars:GetHotbar(category)
        if not hotbar then return unavailable(name) end
        local refs={};result.auxiliaryBars[category]=refs
        local eligible=bars:ShouldSubmitChangesForHotbarCategory(category)==true
        for _,nativeSlot in ipairs(result.nativeSlots) do
            local ref=rawReference(api,manager,nativeSlot,category)
            if not ref then return unavailable('unresolvedAuxiliaryBarAction') end
            local id=api.GetSkillProgressionIdForHotbarSlotOverrideRule(nativeSlot,category)
            local rule=id~=0 and manager:GetSkillDataByProgressionId(id) or nil
            if id~=0 and not rule then return unavailable('unresolvedBarOverride') end
            local runtime=hotbar:GetOverrideSkillDataForSlot(nativeSlot)
            refs[nativeSlot]={ref=ref,category=category,nativeSlot=nativeSlot,
                locked=hotbar:IsSlotLocked(nativeSlot),mutable=hotbar:IsSlotMutable(nativeSlot),eligible=eligible,
                override=rule and rule:IsPurchased() and SkillState.Key(rule) or nil,
                runtimeOverride=runtime and SkillState.Key(runtime) or nil}
            if category==api.HOTBAR_CATEGORY_WEREWOLF then
                for slot,id in ipairs(result.nativeSlots)do if id==nativeSlot then result.barMetadata.werewolf[slot]=refs[nativeSlot]end end
            end
        end
    end
    return result
end

function SkillState.Read(api)
    local ok,result=pcall(read,api or _G)
    if ok then return result end
    local catalogue=unavailable('nativeSkillRead')
    catalogue.problem.details.error=tostring(result)
    return catalogue
end

function SkillState.ReadDisplay(api)
    local ok,result=pcall(read,api or _G,true)
    if ok then return result end
    local catalogue=unavailable('nativeSkillRead')
    catalogue.problem.details.error=tostring(result)
    return catalogue
end
