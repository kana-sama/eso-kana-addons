local Fake=dofile(ROOT..'/tests/support/fake_eso.lua')
local BuildFake=dofile(ROOT..'/tests/support/build_fixture.lua')
local function setup(specs)
    local kw=Fake.Load({'Core.lua','Slots.lua','lang/en.lua','BuildModel.lua','SkillState.lua','SkillAdapter.lua'})
    local f=BuildFake.InstallSkills(BuildFake.New(),specs)
    assert(kw.SkillState and kw.SkillAdapter,'Missing skill catalogue/adapter')
    f.events=kw.Core.NewEvents()
    return kw,f,kw.SkillAdapter.New(f.api,f.events,f.clock)
end
local function active(id,extra)
    local s={lineId=10,kind='active',id=id,purchased=true,morph=0}
    for k,v in pairs(extra or {}) do s[k]=v end
    return s
end
local function draftSetup(specs)
    local kw,f,adapter=setup(specs)
    BuildFake.InstallSkillDrafts(f)
    return kw,f,adapter
end
return {
 discard_after_native_cancel_releases_callbacks_without_resetting_again=function()
    local _,f,a=draftSetup({active(51,{morph=1})})
    local target={skills={['10:active:51']={kind='active',purchased=true,morph=2}}}
    local changed=0
    assert(a:MountDraft(target,function()changed=changed+1 end))
    local global=f.api.SKILLS_AND_ACTION_BAR_MANAGER
    global:ResetInterface()
    global.ResetRespecState=function()error('native editor is already reset')end
    local ok,err=a:DiscardDraft();assert(ok,err and err.code)
    assert(not a:GetNativeOwnership())
    local callbacks=changed
    f.api.SKILL_POINT_ALLOCATION_MANAGER:FireCallbacks('PurchasedChanged',f.skillObjects[1]:GetPointAllocator())
    assert(changed==callbacks,'cancelled editor retained change callbacks')
    assert(a:DiscardDraft(),'repeat cleanup must be harmless')
    global:OnUpdate();assert(#f.requests.skills==0 and f.skillObjects[1]:GetCurrentMorphSlot()==1)
    assert(a:MountDraft(target),'cancelled editor could not reopen')
 end,
 discard_after_native_cancel_preserves_pending_edits_and_changed_actual=function()
    for _,reason in ipairs({'pending','actual','cast'})do
        local _,f,a=draftSetup({active(51,{morph=1})})
        assert(a:MountDraft({skills={['10:active:51']={kind='active',purchased=true,morph=2}}}))
        local global=f.api.SKILLS_AND_ACTION_BAR_MANAGER;global:ResetInterface()
        if reason=='pending' then f.foreignPending=true
        elseif reason=='actual' then f.skillObjects[1].spec.morph=2
        else f.castRemaining=100 end
        global.ResetRespecState=function()error('must preserve native state')end
        local ok,err=a:DiscardDraft()
        assert(not ok and err and a:GetNativeOwnership())
        assert(#f.requests.skills==0 and global.mode==0)
        if reason=='pending' then assert(f.foreignPending)
        elseif reason=='actual' then assert(f.skillObjects[1]:GetCurrentMorphSlot()==2)end
    end
 end,
 werewolf_reassignment_moves_only_an_unselected_duplicate_source=function()
    local _,f,a=draftSetup({active(51,{werewolf=true})})
    f.actualBars[3][3]={type=1,id=510};f.api.ACTION_BAR_ASSIGNMENT_MANAGER:ResetPlayerHotbars()
    local req,err=a:Prepare(a:Capture(),{bars={werewolf={[2]={kind='skill',skillKey='10:active:51',expectedMorph=0}}}})
    assert(req,err and err.code)
    assert(req.target.bars.werewolf[1].kind=='empty' and req.target.bars.werewolf[2].skillKey=='10:active:51')
    assert(#req.barChanges==2)
    local bad,problem=a:Prepare(a:Capture(),{bars={werewolf={
        [1]={kind='skill',skillKey='10:active:51',expectedMorph=0},[2]={kind='skill',skillKey='10:active:51',expectedMorph=0}}}})
    assert(not bad and problem.code=='duplicateBarSkill')
 end,
 werewolf_bar_rejects_other_skill_lines_before_sending=function()
    local _,f,a=draftSetup({active(51)})
    f.skillLines[10].IsWerewolf=function()return false end
    local req,err=a:Prepare(a:Capture(),{bars={werewolf={[1]={kind='skill',skillKey='10:active:51',expectedMorph=0}}}})
    assert(not req and err.code=='skillWerewolfOnly')
    assert(#f.requests.skills==0)
 end,
 werewolf_partial_bar_request_preserves_unselected_slots_and_restores_checked_empty=function()
    local k,f,a=draftSetup({active(51,{werewolf=true}),active(52,{werewolf=true})})
    f.actualBars[3][4]={type=1,id=520};f.actualBars[3][5]={type=1,id=510}
    f.api.ACTION_BAR_ASSIGNMENT_MANAGER:ResetPlayerHotbars()
    local current=a:Capture();assert(current.bars.werewolf,'werewolf bar not captured')
    local target={bars={werewolf={[1]={kind='skill',skillKey='10:active:51',expectedMorph=0},[3]={kind='empty'}}}}
    local req,err=a:Prepare(current,target);assert(req,err and err.code)
    assert(req.target.bars.werewolf[2].skillKey=='10:active:52' and req.target.bars.werewolf[3].kind=='empty')
    assert(#req.skillChanges==0 and #req.barChanges==2 and #req.auxiliaryChanges==0)
    assert(a:Submit(req));f:Advance(1)
    local packet=f.requests.skills[1];assert(packet and #packet.bars==2)
    for _,c in ipairs(packet.bars)do assert(c.bar==3 and (c.slot==3 or c.slot==5))end
    for _,c in ipairs(packet.bars)do f.actualBars[c.bar][c.slot]={type=c.kind,id=c.id} end
    f.api.ACTION_BAR_ASSIGNMENT_MANAGER:ResetPlayerHotbars()
    assert(k.BuildModel.Matches({abilities=a:Capture()},{abilities=target}))
 end,
 full_respec_preserves_unchanged_werewolf_slots_in_packet=function()
    local _,f,a=draftSetup({active(51,{morph=1}),active(52,{werewolf=true})})
    f.actualBars[3][3]={type=1,id=520};f.api.ACTION_BAR_ASSIGNMENT_MANAGER:ResetPlayerHotbars()
    local req=assert(a:Prepare(a:Capture(),{skills={['10:active:51']={kind='active',purchased=true,morph=2}}}))
    assert(a:Submit(req));f:SkillEntryReady();f:Advance(1)
    local count=0
    for _,c in ipairs(f.requests.skills[1].bars)do if c.bar==3 and c.slot==3 then assert(c.id==520 and c.kind==1);count=count+1 end end
    assert(count==1,'full allocation omitted or duplicated unchanged werewolf skill')
 end,
 werewolf_draft_can_save_slots_and_discard_without_live_changes=function()
    local _,f,a=draftSetup({active(51,{werewolf=true})})
    local target={bars={werewolf={[2]={kind='skill',skillKey='10:active:51',expectedMorph=0}}}}
    assert(a:MountDraft(target));local draft=assert(a:CaptureDraft())
    assert(draft.bars.werewolf[2].skillKey=='10:active:51')
    assert(f.api.GetSlotBoundId(4,3)==0 and #f.requests.skills==0)
    assert(a:DiscardDraft());assert(f.api.GetSlotBoundId(4,3)==0 and #f.requests.skills==0)
 end,
 display_reads_saved_skill_identity_without_cost_unlock_or_auxiliary_checks=function()
    local kw,f,adapter=setup({active(51,{morph=1}),{lineId=10,kind='passive',id=52,purchased=true,rank=2}})
    f.actualBars[0][3]={type=1,id=511}
    f.skillObjects[1].GetSkillPointCostMultiplier=function()error('cost read during display')end
    f.skillObjects[1].GetMorphData=function()error('unlock read during display')end
    f.api.ACTION_BAR_ASSIGNMENT_MANAGER.ShouldSubmitChangesForHotbarCategory=function()error('auxiliary check during display')end
    assert(type(kw.SkillState.ReadDisplay)=='function','missing lightweight actual-state read')
    local c=kw.SkillState.ReadDisplay(f.api)
    assert(c.available,c.problem and c.problem.details.error)
    assert(c.abilities.skills['10:active:51'].morph==1 and c.abilities.skills['10:passive:521'].rank==2)
    assert(c.abilities.bars.front[1].skillKey=='10:active:51' and c.abilities.bars.front[1].expectedMorph==1)
    assert(c.byKey['10:active:51'].native==f.skillObjects[1])
    assert(not c.auxiliaryBars and not c.byKey['10:active:51'].morphUnlocked)
    -- The operational read still requires all safety data, even after display succeeds.
    assert(not adapter:Catalogue().available)
 end,
 unknown_auxiliary_catalogue_blocks_skill_changes_but_known_empty_is_supported=function()
    local _,_,adapter=draftSetup({active(51,{morph=1})})
    local catalogue=adapter:Catalogue();local target={skills={['10:active:51']={kind='active',purchased=true,morph=2}}}
    catalogue.auxiliaryBars=nil
    local request,problem=adapter:Prepare(catalogue.abilities,target,catalogue)
    assert(not request and problem.code=='buildCapabilityUnavailable' and problem.details.name=='auxiliaryBars')
    -- An unchanged skill has no dependency mutation; unknown auxiliaries do not disable that no-op.
    assert(adapter:Prepare(catalogue.abilities,{skills={['10:active:51']={kind='active',purchased=true,morph=1}}},catalogue))
    catalogue.auxiliaryBars={}
    request=assert(adapter:Prepare(catalogue.abilities,target,catalogue))
    assert(#request.skillChanges==1 and #request.auxiliaryChanges==0)
 end,
 foreign_attribute_or_subclass_context_during_entry_and_dispatch_never_sends=function()
    for _,stage in ipairs({'entry','dispatching'}) do for _,kind in ipairs({'cast','keyboard','gamepad','subclass'}) do
        local _,f,adapter=draftSetup({active(51,{morph=1})})
        local values={1,-1,0}
        local function foreign()
            if kind=='cast' then f.api.GetAttributeRespecCastTimeRemainingMs=function()return 5 end
            elseif kind=='keyboard' then
                f.api.STATS={initialized=true,attributeControls={}}
                for id=1,3 do local index=id;f.api.STATS.attributeControls[id]={pointLimitedSpinner={GetAllocatedPoints=function()return values[index] end}} end
            elseif kind=='gamepad' then f.api.GAMEPAD_STATS={attributeData={{addedPoints=1},{addedPoints=-1},{addedPoints=0}}}
            else f.api.SKILL_LINE_ASSIGNMENT_MANAGER={IsAnyChangePending=function()return true end} end
        end
        f.events:Subscribe('SkillSubmissionChanged',function(state)if stage=='dispatching' and state.phase=='dispatching' then foreign() end end)
        local request=assert(adapter:Prepare(adapter:Capture(),{skills={['10:active:51']={kind='active',purchased=true,morph=2}}}))
        assert(adapter:Submit(request));if stage=='entry' then foreign() end
        f:SkillEntryReady();f:Advance(1)
        assert(#f.requests.skills==0 and not f.packetPrepareCalls,stage..':'..kind)
        if kind=='keyboard' then assert(f.api.STATS.attributeControls[1].pointLimitedSpinner:GetAllocatedPoints()==1)
        elseif kind=='subclass' then assert(f.api.SKILL_LINE_ASSIGNMENT_MANAGER:IsAnyChangePending() and f.api.SKILLS_AND_ACTION_BAR_MANAGER.mode==3) end
    end end
 end,

 absent_or_lazy_attribute_component_keeps_skill_only_submission_supported=function()
    for _,kind in ipairs({'absent','lazy'}) do
        local _,f,adapter=draftSetup({active(51,{morph=1})})
        if kind=='lazy' then
            f.api.STATS={OnShowing=function()error('must not initialize Stats')end}
            f.api.GAMEPAD_STATS={PerformDeferredInitializationRoot=function()error('must not initialize gamepad')end}
        end
        local request=assert(adapter:Prepare(adapter:Capture(),{skills={['10:active:51']={kind='active',purchased=true,morph=2}}}))
        assert(adapter:Submit(request));f:SkillEntryReady();f:Advance(1);assert(#f.requests.skills==1)
    end
 end,
 dispatching_journal_is_before_prepare_and_observer_stop_or_throw_vetoes=function()
    for _,full in ipairs({true,false}) do for _,action in ipairs({'persist','stop','throw','actual','budget','availability','aux'}) do
        local _,f,adapter=draftSetup({active(51,{morph=1})})
        local target=full and {skills={['10:active:51']={kind='active',purchased=true,morph=2}}} or
            {bars={front={[1]={kind='skill',skillKey='10:active:51',expectedMorph=1}}}}
        local request=assert(adapter:Prepare(adapter:Capture(),target));local persisted
        f.events:Subscribe('SkillSubmissionChanged',function(state)
            if state.phase~='dispatching' then return end
            assert(not state.sent and state.token and state.original and state.target and not f.packet and not f.packetPrepareCalls)
            persisted=state
            assert(not adapter:Submit(request)) -- dispatching is locked
            if action=='stop' then adapter:CancelSubmission()
            elseif action=='throw' then error('journal failed')
            elseif action=='actual' then f.skillObjects[1].spec.morph=0
            elseif action=='budget' then f.skillPoints=f.skillPoints+1
            elseif action=='availability' then f.skillObjects[1].spec.available=false
            elseif action=='aux' then f.actualBars[2][3]={type=1,id=511};f.api.ACTION_BAR_ASSIGNMENT_MANAGER:ResetPlayerHotbars() end
        end)
        adapter:Submit(request)
        if full then f:SkillEntryReady();f:Advance(1) end
        assert(persisted)
        if action=='persist' then assert(#f.requests.skills==1 and f.packetPrepareCalls==1)
        else assert(#f.requests.skills==0 and not f.packetPrepareCalls and f.api.SKILLS_AND_ACTION_BAR_MANAGER.mode==0) end
    end end
 end,
 dispatching_foreign_pending_is_preserved_on_refusal=function()
    local _,f,adapter=draftSetup({active(51,{morph=1})})
    local request=assert(adapter:Prepare(adapter:Capture(),{skills={['10:active:51']={kind='active',purchased=true,morph=2}}}))
    f.events:Subscribe('SkillSubmissionChanged',function(state)if state.phase=='dispatching' then f.foreignPending=true end end)
    assert(adapter:Submit(request));f:SkillEntryReady();f:Advance(1)
    assert(#f.requests.skills==0 and not f.packetPrepareCalls and f.foreignPending and f.api.SKILLS_AND_ACTION_BAR_MANAGER.mode==3)
 end,
 catalogue_display_name_is_plain_actual_progression_and_optional=function()
    local _,f,adapter=draftSetup({active(51,{morph=1,names={[1]='Actual name',[2]='Pending name'}}),active(52)})
    f.skillObjects[1]:GetPointAllocator().morph=2
    local catalogue=adapter:Catalogue()
    assert(catalogue.byKey['10:active:51'].name=='Actual name')
    assert(catalogue.byKey['10:active:52'].name==nil)
 end,
 auxiliary_sell_and_remorph_are_explicit_runtime_packet_changes=function()
    local _,f,adapter=draftSetup({active(51,{morph=1}),active(52),active(53)})
    f.actualBars[2][3]={type=1,id=511};f.actualBars[3][4]={type=1,id=520}
    f.actualBars[2][5]={type=1,id=530};f.actualBars[4][3]={type=1,id=511};f.actualBars[5][3]={type=1,id=511}
    f.api.ACTION_BAR_ASSIGNMENT_MANAGER:ResetPlayerHotbars()
    local request=assert(adapter:Prepare(adapter:Capture(),{skills={
        ['10:active:51']={kind='active',purchased=true,morph=2},['10:active:52']={kind='active',purchased=false}}}))
    assert(#request.auxiliaryChanges==1 and request.target.bars.overload==nil)
    assert(request.auxiliaryOriginal[2][3].expectedMorph==1 and request.auxiliaryTarget[2][3].expectedMorph==2)
    assert(request.target.bars.werewolf[2].kind=='empty' and request.auxiliaryTarget[2][5]==nil)
    assert(adapter:Submit(request));f:SkillEntryReady();f:Advance(1)
    local extra={};for _,change in ipairs(f.requests.skills[1].bars) do if change.bar>=2 then extra[#extra+1]=change end end
    local changed={}
    for _,c in ipairs(extra)do changed[c.bar..':'..c.slot]=c end
    assert(#extra==7 and changed['2:3'].id==512)
    assert(changed['3:4'].kind==0 and changed['3:4'].id==0)
    -- Result and normal/skill actual can agree while auxiliary actual is stale.
    f.skillObjects[1].spec.morph=2;f.skillObjects[2].spec.purchased=false
    f.api.SKILLS_AND_ACTION_BAR_MANAGER:ResetRespecState();f.events:Emit('NativeSkillRespecResult',{result=0})
    assert(not adapter:Matches(request.target,request))
    assert(not adapter:ResolveSubmission(0,adapter:GetSubmissionState().token))
    f.actualBars[2][3]={type=1,id=512};f.actualBars[3][4]=nil
    f.api.ACTION_BAR_ASSIGNMENT_MANAGER:ResetPlayerHotbars()
    assert(adapter:Matches(request.target,request))
    assert(adapter:ResolveSubmission(0,adapter:GetSubmissionState().token))
    assert(f.actualBars[2][5].id==530 and f.actualBars[4][3].id==511 and f.actualBars[5][3].id==511)
 end,
 bound_werewolf_morph_sends_native_binding_and_verifies_actual_slot=function()
    for _,morphs in ipairs({{0,2},{1,2},{2,0}}) do
        local before,after=morphs[1],morphs[2]
        local _,f,adapter=draftSetup({active(152,{lineId=50,ultimate=true,morph=before})})
        local category=f.api.HOTBAR_CATEGORY_WEREWOLF
        f.actualBars[category][8]={type=1,id=1520+before}
        f.overrides={[category..':8']=f.skillObjects[1]}
        f.api.ACTION_BAR_ASSIGNMENT_MANAGER:ResetPlayerHotbars()
        local request,problem=adapter:Prepare(adapter:Capture(),{
            skills={['50:active:152']={kind='active',purchased=true,morph=after}},
            bars={back={[6]={kind='skill',skillKey='50:active:152',expectedMorph=after}}}})
        assert(request,problem and problem.code)
        assert(#request.skillChanges==1 and #request.auxiliaryChanges==0)
        assert(request.werewolfOriginal[6].expectedMorph==before)
        assert(request.target.bars.werewolf[6].expectedMorph==after)
        assert(adapter:Submit(request));f:SkillEntryReady();f:Advance(1)
        assert(#f.requests.skills==1)
        local packet=f.requests.skills[1]
        assert(#packet.skills==1 and packet.skills[1].id==152 and packet.skills[1].morph==after)
        local assigned,forced=false,false
        for _,change in ipairs(packet.bars) do
            if change.bar==category and change.slot==8 then
                assert(change.slot==8 and change.kind==1 and change.id==1520+after);forced=true
            end
            if change.bar==1 and change.slot==8 then
                assert(change.kind==1 and change.id==1520+after);assigned=true
            end
        end
        assert(assigned,'ordinary preset bar still needs the selected morph')
        assert(forced,'native allocation message includes the forced binding too')
        f.skillObjects[1].spec.morph=after;f.actualBars[1][8]={type=1,id=1520+after}
        f.api.SKILLS_AND_ACTION_BAR_MANAGER:ResetRespecState()
        f.events:Emit('NativeSkillRespecResult',{result=0})
        local token=adapter:GetSubmissionState().token
        assert(not adapter:Matches(request.target,request),'stale forced slot is not confirmed')
        assert(not adapter:ResolveSubmission(0,token))
        f.actualBars[category][8]={type=1,id=1520+after}
        f.api.ACTION_BAR_ASSIGNMENT_MANAGER:ResetPlayerHotbars()
        assert(adapter:Matches(request.target,request))
        assert(adapter:ResolveSubmission(0,token) and not adapter:SubmissionLocked())
        assert(#f.requests.skills==1)
    end
 end,
 bound_morph_on_ordinary_bar_is_included_in_allocation_message=function()
    local _,f,adapter=draftSetup({active(51,{ultimate=true})})
    f.actualBars[0][8]={type=1,id=510};f.overrides={['0:8']=f.skillObjects[1]}
    f.api.ACTION_BAR_ASSIGNMENT_MANAGER:ResetPlayerHotbars()
    local request,problem=adapter:Prepare(adapter:Capture(),{skills={['10:active:51']={kind='active',purchased=true,morph=2}}})
    assert(request,problem and problem.code)
    assert(#request.barChanges==1 and request.target.bars.front[6].expectedMorph==2)
    assert(adapter:Submit(request));f:SkillEntryReady();f:Advance(1)
    assert(#f.requests.skills==1 and f.requests.skills[1].skills[1].morph==2)
    local count=0
    for _,change in ipairs(f.requests.skills[1].bars) do
        if change.bar==0 and change.slot==8 then assert(change.id==512);count=count+1 end
    end
    assert(count==1)
 end,
 bound_morph_draft_can_be_edited_and_discarded_without_sending=function()
    local _,f,adapter=draftSetup({active(152,{lineId=50,ultimate=true})})
    local category=f.api.HOTBAR_CATEGORY_WEREWOLF
    f.actualBars[category][8]={type=1,id=1520};f.overrides={[category..':8']=f.skillObjects[1]}
    f.api.ACTION_BAR_ASSIGNMENT_MANAGER:ResetPlayerHotbars()
    local ok,problem=adapter:MountDraft({skills={['50:active:152']={kind='active',purchased=true,morph=2}},
        bars={back={[6]={kind='skill',skillKey='50:active:152',expectedMorph=2}}}})
    assert(ok,problem and problem.code)
    local draft=assert(adapter:CaptureDraft())
    assert(draft.skills['50:active:152'].morph==2 and draft.bars.back[6].expectedMorph==2)
    assert(adapter:DiscardDraft());f.api.SKILLS_AND_ACTION_BAR_MANAGER:OnUpdate()
    assert(#f.requests.skills==0 and f.actualBars[category][8].id==1520)
    assert(f.skillObjects[1]:GetCurrentMorphSlot()==0 and not adapter.mounted)
 end,
 bound_skill_replacement_removal_and_conflicting_override_still_refuse=function()
    local _,f,adapter=draftSetup({active(51,{ultimate=true}),active(52,{ultimate=true})})
    f.actualBars[0][8]={type=1,id=510};f.overrides={['0:8']=f.skillObjects[1]}
    f.api.ACTION_BAR_ASSIGNMENT_MANAGER:ResetPlayerHotbars()
    for _,ref in ipairs({{kind='empty'},{kind='skill',skillKey='10:active:52',expectedMorph=0}}) do
        local request,problem=adapter:Prepare(adapter:Capture(),{bars={front={[6]=ref}}})
        assert(not request and problem.code=='skillBarOverride')
    end
    f.actualBars[0][8]=nil;f.overrides=nil
    local category=f.api.HOTBAR_CATEGORY_WEREWOLF
    f.actualBars[category][8]={type=1,id=510};f.overrides={[category..':8']=f.skillObjects[1]}
    f.api.ACTION_BAR_ASSIGNMENT_MANAGER:ResetPlayerHotbars()
    local request,problem=adapter:Prepare(adapter:Capture(),{skills={['10:active:51']={kind='active',purchased=false}}})
    assert(not request and problem.code=='skillBarOverride')
    local target={skills={['10:active:51']={kind='active',purchased=true,morph=2}}}
    for _,field in ipairs({'override','runtimeOverride'}) do
        for _,key in ipairs({'10:active:52',false}) do
            local catalogue=adapter:Catalogue()
            catalogue.auxiliaryBars[category][8][field]=key or nil
            request,problem=adapter:Prepare(catalogue.abilities,target,catalogue)
            assert(not request and problem.code=='skillBarOverride')
        end
    end
    assert(#f.requests.skills==0)
 end,
 auxiliary_stale_ref_before_send_refuses_without_resend=function()
    local _,f,adapter=draftSetup({active(51,{morph=1}),active(52)})
    f.actualBars[2][3]={type=1,id=511};f.api.ACTION_BAR_ASSIGNMENT_MANAGER:ResetPlayerHotbars()
    local request=assert(adapter:Prepare(adapter:Capture(),{skills={['10:active:51']={kind='active',purchased=true,morph=2}}}))
    assert(adapter:Submit(request));f:SkillEntryReady()
    f.actualBars[2][3]={type=1,id=520};f.api.ACTION_BAR_ASSIGNMENT_MANAGER:ResetPlayerHotbars()
    f:Advance(1);assert(#f.requests.skills==0 and adapter:GetSubmissionState().problem.code=='buildStateChanged')
 end,
 auxiliary_failure_requires_original_and_unknown_descriptor_is_detached=function()
    local _,f,adapter=draftSetup({active(51,{morph=1})})
    f.actualBars[2][3]={type=1,id=511};f.api.ACTION_BAR_ASSIGNMENT_MANAGER:ResetPlayerHotbars()
    local request=assert(adapter:Prepare(adapter:Capture(),{skills={['10:active:51']={kind='active',purchased=true,morph=2}}}))
    assert(adapter:Submit(request));f:SkillEntryReady();f:Advance(1)
    local token=adapter:GetSubmissionState().token
    adapter:CancelSubmission();f.events:Emit('NativeSkillRespecResult',{result=14})
    local state=adapter:GetSubmissionState()
    assert(state.auxiliaryOriginal[2][3].expectedMorph==1 and state.auxiliaryTarget[2][3].expectedMorph==2)
    state.auxiliaryOriginal[2][3].expectedMorph=2;request.auxiliaryOriginal[2][3].expectedMorph=2
    f.actualBars[2][3]={type=1,id=512};f.api.SKILLS_AND_ACTION_BAR_MANAGER:ResetRespecState()
    assert(not adapter:ResolveSubmission(14,token))
    f.actualBars[2][3]={type=1,id=511};f.api.ACTION_BAR_ASSIGNMENT_MANAGER:ResetPlayerHotbars()
    assert(adapter:ResolveSubmission(14,token))
 end,
 auxiliary_prepared_dependency_stale_before_submit_or_entry_refuses=function()
    local _,f,adapter=draftSetup({active(51,{morph=1}),active(52)})
    f.actualBars[3][3]={type=1,id=511};f.api.ACTION_BAR_ASSIGNMENT_MANAGER:ResetPlayerHotbars()
    local request=assert(adapter:Prepare(adapter:Capture(),{skills={['10:active:51']={kind='active',purchased=true,morph=2}}}))
    f.actualBars[3][3]={type=1,id=520};f.api.ACTION_BAR_ASSIGNMENT_MANAGER:ResetPlayerHotbars()
    local ok,problem=adapter:Submit(request);assert(not ok and problem.code=='buildStateChanged' and not f.nativeEntryCalls)
    f.actualBars[3][3]={type=1,id=511};f.api.ACTION_BAR_ASSIGNMENT_MANAGER:ResetPlayerHotbars()
    assert(adapter:Submit(request));f:SkillEntryReady();f.werewolfAvailable=false;f:Advance(1)
    assert(#f.requests.skills==0 and adapter:GetSubmissionState().problem.code=='skillAuxiliaryBarUnavailable')
 end,
 auxiliary_matches_requires_descriptor_when_supplied=function()
    local _,f,adapter=setup({active(51)})
    assert(not adapter:Matches(adapter:Capture(),{}))
    f.actualBars[2][3]={type=1,id=510}
    local catalogue=adapter:Catalogue();assert(catalogue.auxiliaryBars[2][3].ref.skillKey=='10:active:51')
    assert(catalogue.auxiliaryBars[4]==nil and catalogue.auxiliaryBars[5]==nil and catalogue.auxiliaryBars[6]==nil)
 end,
 auxiliary_locked_or_ineligible_dependencies_refuse_but_unrelated_bars_do_not=function()
    local _,f,adapter=setup({active(51,{morph=1}),active(52)})
    f.actualBars[3][3]={type=1,id=511};f.werewolfAvailable=false
    local target={skills={['10:active:51']={kind='active',purchased=false}}}
    local request,problem=adapter:Prepare(adapter:Capture(),target)
    assert(not request and problem.code=='skillAuxiliaryBarUnavailable')
    f.actualBars[3][3]={type=1,id=520};assert(adapter:Prepare(adapter:Capture(),target))
    f.actualBars[2][3]={type=1,id=511};f.lockedSlots={['2:3']=true}
    request,problem=adapter:Prepare(adapter:Capture(),target);assert(not request and problem.code=='skillBarLocked')
    f.lockedSlots=nil;f.immutableSlots={['2:3']=true}
    request,problem=adapter:Prepare(adapter:Capture(),target);assert(not request and problem.code=='skillBarOverride')
    local context=assert(problem.details.slotContext,'missing refusal snapshot')
    assert(context.category==2 and context.nativeSlot==3 and context.explicit==false)
    assert(context.before.skillKey=='10:active:51' and context.target.kind=='empty')
    assert(context.mutable==false and context.beforeAbility.id==511)
    assert(context.skillChanges[1].target.purchased==false)
 end,

 bar_override_refusal_records_exact_requested_slot_without_native_handles=function()
    local kw,f,adapter=setup({active(51,{name='Original',morph=1}),active(52,{name='Forced'})})
    f.actualBars[1][4]={type=1,id=511};f.overrides={['1:4']=f.skillObjects[2]}
    local target={bars={back={[2]={kind='empty'}}}}
    local request,problem=adapter:Prepare(adapter:Capture(),target)
    assert(not request and problem.code=='skillBarOverride')
    local context=assert(problem.details.slotContext,'missing refusal snapshot')
    assert(context.bar=='back' and context.slot==2 and context.nativeSlot==4 and context.category==1 and context.explicit)
    assert(context.beforeAbility.id==511 and context.beforeAbility.name=='Original')
    assert(context.overrideAbility.id==520 and context.runtimeOverrideAbility.id==520)
    assert(context.override=='10:active:52' and context.runtimeOverride=='10:active:52')
    assert(context.before.expectedMorph==1 and context.target.kind=='empty')
    target.bars.back[2].kind='changed';assert(context.target.kind=='empty')
    local function serializable(value)
        assert(type(value)~='function' and type(value)~='userdata')
        if type(value)=='table' then for _,v in pairs(value)do serializable(v)end end
    end
    serializable(context);assert(#f.requests.skills==0)
 end,

 pending_override_purchase_and_unpurchase_never_change_actual_bars=function()
    local kw,f,adapter=draftSetup({active(51,{ultimate=true}),active(52,{ultimate=true,purchased=false})})
    f.actualBars[0][8]={type=1,id=510};f.overrides={['0:8']=f.skillObjects[2]}
    local original=adapter:Capture()
    assert(original.bars.front[6].skillKey=='10:active:51')
    f.skillObjects[2]:GetPointAllocator().purchased=true
    assert(f.hotbars[0]:GetOverrideSkillDataForSlot(8)==f.skillObjects[2])
    assert(adapter:Matches(original) and adapter:Capture().bars.front[6].skillKey=='10:active:51')
    local metadata=kw.SkillState.Read(f.api).barMetadata.front[6]
    assert(metadata.override==nil and metadata.runtimeOverride=='10:active:52')
    -- Only actual confirmation changes the captured assignment.
    f.skillObjects[2].spec.purchased=true;f.actualBars[0][8]={type=1,id=520}
    local confirmed=adapter:Capture();assert(confirmed.bars.front[6].skillKey=='10:active:52')
    f.skillObjects[2]:GetPointAllocator().purchased=false
    assert(f.hotbars[0]:GetOverrideSkillDataForSlot(8)==nil)
    assert(adapter:Matches(confirmed) and adapter:Capture().bars.front[6].skillKey=='10:active:52')
    metadata=kw.SkillState.Read(f.api).barMetadata.front[6]
    assert(metadata.override=='10:active:52' and metadata.runtimeOverride==nil)
    local request,problem=adapter:Prepare(confirmed,{bars={front={[6]={kind='empty'}}}})
    assert(not request and problem.code=='skillBarOverride')
    f.skillObjects[2].spec.purchased=false;f.actualBars[0][8]={type=1,id=510}
    assert(adapter:Capture().bars.front[6].skillKey=='10:active:51')
 end,
 native_result_reset_never_autosends_in_either_bridge_order=function()
    for _,result in ipairs({0,14}) do
        for _,bridgeFirst in ipairs({true,false}) do
            local _,f,adapter=draftSetup({active(51,{morph=1})})
            local request=assert(adapter:Prepare(adapter:Capture(),{skills={['10:active:51']={kind='active',purchased=true,morph=2}}}))
            assert(adapter:Submit(request));local token=adapter:GetSubmissionState().token
            f:SkillEntryReady();f:Advance(1)
            local global=f.api.SKILLS_AND_ACTION_BAR_MANAGER
            -- A later ordinary native callback dirties the manager after an
            -- adapter observer; purchase-mode OnUpdate genuinely sends.
            global:RegisterCallback('SkillPointAllocationModeChanged',function(mode)
                if mode==0 then global.isDirty=true end
            end)
            if bridgeFirst then f.events:Emit('NativeSkillRespecResult',{result=result}) end
            global:ResetInterface();global:OnUpdate()
            if not bridgeFirst then f.events:Emit('NativeSkillRespecResult',{result=result}) end
            assert(#f.requests.skills==1)
            if result==0 then f.skillObjects[1].spec.morph=2 end
            assert(adapter:ResolveSubmission(result,token))
            global:OnUpdate();assert(#f.requests.skills==1 and global.mode==0 and not global.isDirty)
            -- The resolved adapter must stop freezing ordinary native mode
            -- changes or clearing another owner's later callback dirtiness.
            global:SetSkillPointAllocationMode(3);global:SetSkillPointAllocationMode(0)
            assert(global.mode==0 and global.isDirty)
        end
    end
 end,
 result_before_actual_does_not_release_request_until_resolved=function()
    local _,f,adapter=draftSetup({active(51,{morph=1})})
    local request=assert(adapter:Prepare(adapter:Capture(),{skills={['10:active:51']={kind='active',purchased=true,morph=2}}}))
    assert(adapter:Submit(request));local token=adapter:GetSubmissionState().token
    f:SkillEntryReady();f:Advance(1);f.events:Emit('NativeSkillRespecResult',{result=0})
    f.api.SKILLS_AND_ACTION_BAR_MANAGER:ResetRespecState()
    local ok,problem=adapter:Submit(request);assert(not ok and problem.code=='skillSubmissionActive')
    ok,problem=adapter:ResolveSubmission(0,token);assert(not ok and problem.code=='skillSubmissionUncertain')
    f.skillObjects[1].spec.morph=2
    ok,problem=adapter:ResolveSubmission(0,token+1);assert(not ok and problem.code=='skillSubmissionTokenMismatch')
    f.castRemaining=1;assert(not adapter:ResolveSubmission(0,token))
    f.castRemaining=0;assert(adapter:ResolveSubmission(0,token))
    local back=assert(adapter:Prepare(adapter:Capture(),{skills={['10:active:51']={kind='active',purchased=true,morph=1}}}))
    assert(adapter:Submit(back) and adapter:GetSubmissionState().token~=token)
 end,
 confirmed_failure_can_resolve_original_and_allow_next_request=function()
    local _,f,adapter=draftSetup({active(51,{morph=1})})
    local request=assert(adapter:Prepare(adapter:Capture(),{skills={['10:active:51']={kind='active',purchased=true,morph=2}}}))
    assert(adapter:Submit(request));local token=adapter:GetSubmissionState().token
    f:SkillEntryReady();f:Advance(1);f.events:Emit('NativeSkillRespecResult',{result=14})
    f.api.SKILLS_AND_ACTION_BAR_MANAGER:ResetRespecState()
    assert(adapter:ResolveSubmission(14,token))
    assert(adapter:Submit(request));f:SkillEntryReady();f:Advance(1)
    assert(#f.requests.skills==2)
 end,
 sent_cancel_preserves_unknown_request_and_never_resends=function()
    local _,f,adapter=draftSetup({active(51,{morph=1})})
    local request=assert(adapter:Prepare(adapter:Capture(),{skills={['10:active:51']={kind='active',purchased=true,morph=2}}}))
    assert(adapter:Submit(request));local token=adapter:GetSubmissionState().token
    f:SkillEntryReady();f:Advance(1);assert(adapter:CancelSubmission())
    assert(adapter:GetSubmissionState().phase=='unknown' and adapter:GetSubmissionState().sent and f.cancelRequests==1)
    f.api.SKILLS_AND_ACTION_BAR_MANAGER:ResetRespecState()
    assert(not adapter:Submit(request));f:Advance(100);assert(#f.requests.skills==1)
    assert(not adapter:ResolveSubmission(nil,token))
    f.events:Emit('NativeSkillRespecResult',{result=14});assert(adapter:ResolveSubmission(14,token))
    assert(adapter:Submit(request))
 end,
 native_nil_rank_rejection_aborts_without_retrying_transaction=function()
    local _,f,adapter=draftSetup({{lineId=10,kind='passive',id=61,purchased=true,rank=2}})
    local manager=f.api.SKILL_POINT_ALLOCATION_MANAGER
    local original=manager.GetSkillPointAllocatorForSkillData
    local calls=0
    manager.GetSkillPointAllocatorForSkillData=function(self,skill)
        local allocator=original(self,skill)
        allocator.DecreaseRank=function()
            calls=calls+1
            if calls==1 then return nil end
            return false
        end
        return allocator
    end
    local ok,problem=adapter:MountDraft({skills={['10:passive:611']={kind='passive',rank=1}}})
    assert(not ok and problem.code=='skillDraftFailed' and calls==1 and #f.requests.skills==0)
 end,
 native_userdata_draft_managers_mount_and_cleanup_without_hooks=function()
    local _,f,adapter=draftSetup({active(51,{purchased=false})})
    f.api.SKILLS_AND_ACTION_BAR_MANAGER=Fake.Control(f.api.SKILLS_AND_ACTION_BAR_MANAGER)
    f.api.SKILL_POINT_ALLOCATION_MANAGER=Fake.Control(f.api.SKILL_POINT_ALLOCATION_MANAGER)
    f.api.ACTION_BAR_ASSIGNMENT_MANAGER=Fake.Control(f.api.ACTION_BAR_ASSIGNMENT_MANAGER)
    assert(adapter:MountDraft({skills={['10:active:51']={kind='active',purchased=true,morph=0}}}))
    assert(adapter:DiscardDraft());f.api.SKILLS_AND_ACTION_BAR_MANAGER:OnUpdate()
    assert(#f.requests.skills==0 and #f.api.securePostHooks==0)
 end,
 async_target_is_detached_from_callers_request=function()
    local _,f,adapter=draftSetup({active(51,{morph=1})})
    local request=assert(adapter:Prepare(adapter:Capture(),{skills={['10:active:51']={kind='active',purchased=true,morph=2}}}))
    assert(adapter:Submit(request));request.target.skills['10:active:51'].morph=0
    f:SkillEntryReady();f:Advance(1)
    assert(f.requests.skills[1].skills[1].morph==2)
 end,
 changed_actual_or_foreign_cast_during_entry_blocks_send=function()
    local _,f,adapter=draftSetup({active(51,{morph=1})})
    local request=assert(adapter:Prepare(adapter:Capture(),{skills={['10:active:51']={kind='active',purchased=true,morph=2}}}))
    f.castRemaining=1
    local ok,problem=adapter:Submit(request);assert(not ok and problem.code=='skillCastPending' and not f.entryRequests)
    f.castRemaining=0;assert(adapter:Submit(request));f:SkillEntryReady()
    f.skillObjects[1].spec.morph=0;f:Advance(1)
    assert(#f.requests.skills==0 and adapter:GetSubmissionState().problem.code=='buildStateChanged')
    f.api.SKILLS_AND_ACTION_BAR_MANAGER:ResetRespecState()
    assert(adapter:Submit(request));f:SkillEntryReady();f.castRemaining=1;f:Advance(1)
    assert(#f.requests.skills==0 and adapter:GetSubmissionState().problem.code=='skillCastPending')
 end,
 combat_during_entry_and_cancelled_result_never_report_actual_success=function()
    local _,f,adapter=draftSetup({active(51,{morph=1})})
    local request=assert(adapter:Prepare(adapter:Capture(),{skills={['10:active:51']={kind='active',purchased=true,morph=2}}}))
    assert(adapter:Submit(request));f:SkillEntryReady();f.api.combat=true;f:Advance(1)
    assert(#f.requests.skills==0 and adapter:GetSubmissionState().problem.code=='inCombat')
    f.api.combat=false;f.api.SKILLS_AND_ACTION_BAR_MANAGER:ResetRespecState()
    assert(adapter:Submit(request));f:SkillEntryReady();f:Advance(1)
    f.events:Emit('NativeSkillRespecResult',{result=14})
    assert(adapter:GetSubmissionState().phase=='result' and adapter:GetSubmissionState().result==14)
 end,
 cleanup_with_no_mode_reset_freezes_and_draft_callbacks_stay_frozen=function()
    local _,f,adapter=draftSetup({active(51,{purchased=false})})
    local changed=0
    assert(adapter:MountDraft({skills={['10:active:51']={kind='active',purchased=true,morph=0}}},function()changed=changed+1 end))
    f.api.SKILLS_AND_ACTION_BAR_MANAGER.ResetRespecState=function()f.allocators={} end
    local ok,problem=adapter:DiscardDraft()
    assert(not ok and problem.code=='skillDraftCleanupFailed')
    f.api.SKILL_POINT_ALLOCATION_MANAGER:FireCallbacks('PurchasedChanged',f.skillObjects[1]:GetPointAllocator())
    assert(changed==0)
 end,
 mount_draft_does_not_autopurchase_or_autofill=function()
    local _,f,adapter=draftSetup({active(51,{purchased=false})})
    local changed=0
    assert(adapter:MountDraft({skills={['10:active:51']={kind='active',purchased=true,morph=0}}},function()changed=changed+1 end))
    assert(#f.requests.skills==0 and changed==0)
    local draft=assert(adapter:CaptureDraft())
    assert(draft.skills['10:active:51'].purchased and draft.bars.front[1].kind=='empty' and draft.bars.front[2].kind=='empty')
    local actual=adapter:Capture();assert(not actual.skills['10:active:51'].purchased)
    f.api.SKILLS_AND_ACTION_BAR_MANAGER:OnUpdate();assert(#f.requests.skills==0)
 end,
 mount_refunds_before_buying_and_capture_includes_unselected_experiments=function()
    local _,f,adapter=draftSetup({active(51,{morph=1}),active(52,{purchased=false}),active(53,{purchased=false})})
    f.skillPoints=0
    local changed=0
    assert(adapter:MountDraft({skills={['10:active:51']={kind='active',purchased=false},['10:active:52']={kind='active',purchased=true,morph=0}}},function()changed=changed+1 end))
    assert(f.draftOperations[1]=='Unmorph' and f.draftOperations[2]=='Sell')
    assert(f.skillObjects[3]:GetPointAllocator():Purchase())
    local draft=adapter:CaptureDraft()
    assert(draft.skills['10:active:53'].purchased and changed>0 and #f.requests.skills==0)
 end,
 discard_and_unmount_clear_owned_dirty_even_reset_callback_marks_dirty=function()
    local _,f,adapter=draftSetup({active(51,{purchased=false})})
    f.resetCallbackMarksDirty=true
    assert(adapter:MountDraft({skills={['10:active:51']={kind='active',purchased=true,morph=0}}}))
    local saved=assert(adapter:UnmountDraft())
    assert(saved.skills['10:active:51'].purchased)
    f.api.SKILLS_AND_ACTION_BAR_MANAGER:OnUpdate()
    assert(#f.requests.skills==0 and not f.api.SKILLS_AND_ACTION_BAR_MANAGER:HasAnyPendingChanges())
    assert(adapter:MountDraft({skills={['10:active:51']={kind='active',purchased=true,morph=0}}}))
    assert(adapter:DiscardDraft());f.api.SKILLS_AND_ACTION_BAR_MANAGER:OnUpdate()
    assert(#f.requests.skills==0 and adapter:CaptureDraft()==nil)
 end,
 foreign_pending_refuses_mount_and_submit_without_touching_it=function()
    local _,f,adapter=draftSetup({active(51,{purchased=false})})
    f.foreignPending=true;f.api.SKILLS_AND_ACTION_BAR_MANAGER.isDirty=true
    local actual=adapter:Capture()
    local request=assert(adapter:Prepare(actual,{skills={['10:active:51']={kind='active',purchased=true,morph=0}}}))
    local ok,problem=adapter:MountDraft(request.target)
    assert(not ok and problem.code=='foreignSkillDraft')
    ok,problem=adapter:Submit(request)
    assert(not ok and problem.code=='foreignSkillDraft' and f.foreignPending and f.api.SKILLS_AND_ACTION_BAR_MANAGER.isDirty)
    assert(adapter:DiscardDraft() and f.foreignPending and f.api.SKILLS_AND_ACTION_BAR_MANAGER.isDirty)
    assert(not f.entryRequests and #f.requests.skills==0)
 end,
 uncertain_cleanup_freezes_batch_and_never_autosends=function()
    local _,f,adapter=draftSetup({active(51,{purchased=false})})
    assert(adapter:MountDraft({skills={['10:active:51']={kind='active',purchased=true,morph=0}}}))
    f.retainPendingOnReset=true
    local ok,problem=adapter:DiscardDraft()
    assert(not ok and problem.code=='skillDraftCleanupFailed')
    assert(f.api.SKILLS_AND_ACTION_BAR_MANAGER:GetSkillPointAllocationMode()==f.api.SKILL_POINT_ALLOCATION_MODE_FULL)
    f.api.SKILLS_AND_ACTION_BAR_MANAGER:OnUpdate();assert(#f.requests.skills==0)
 end,
 asynchronous_entry_sends_once_after_callbacks_and_three_bars=function()
    local _,f,adapter=draftSetup({active(51,{morph=1})})
    local request=assert(adapter:Prepare(adapter:Capture(),{skills={['10:active:51']={kind='active',purchased=true,morph=2}}}))
    assert(adapter:Submit(request));assert(adapter:GetSubmissionState().phase=='entry' and #f.requests.skills==0)
    f:SkillEntryReady();f:SkillEntryReady();assert(#f.requests.skills==0)
    f:Advance(1)
    assert(#f.requests.skills==1 and adapter:GetSubmissionState().phase=='waiting')
    local packet=f.requests.skills[1];assert(packet.mode==3 and #packet.skills==1 and packet.skills[1].morph==2 and #packet.bars==18)
    f:SkillEntryReady();f:Advance(1);assert(#f.requests.skills==1)
    f.events:Emit('NativeSkillRespecResult',{result=0})
    assert(adapter:GetSubmissionState().phase=='result' and adapter:GetSubmissionState().result==0)
    assert(not adapter:Matches(request.target)) -- acceptance/result is not actual-state verification
 end,
 second_skill_apply_reuses_native_interaction_without_waiting_for_another_start_event=function()
    local _,f,adapter=draftSetup({active(51,{morph=1})})
    local interaction=0;f.api.INTERACTION_SKILL_RESPEC=99
    f.api.GetInteractionType=function()return interaction end
    f.api.StartSkillRespecFromUI=function()
        f.entryRequests=(f.entryRequests or 0)+1
        if interaction~=99 then interaction=99;f:SkillEntryReady()end
    end
    local function request(morph)return assert(adapter:Prepare(adapter:Capture(),{skills={['10:active:51']={kind='active',purchased=true,morph=morph}}}))end
    assert(adapter:Submit(request(2)));f:Advance(1)
    assert(#f.requests.skills==1 and f.entryRequests==1)
    f.skillObjects[1].spec.morph=2
    f.api.SKILLS_AND_ACTION_BAR_MANAGER:ResetRespecState()
    f.events:Emit('NativeSkillRespecResult',{result=0})
    assert(adapter:ResolveSubmission(0,adapter:GetSubmissionState().token))
    assert(interaction==99 and f.api.SKILLS_AND_ACTION_BAR_MANAGER.mode==0)
    assert(adapter:Submit(request(1)));f:Advance(1)
    assert(f.entryRequests==1,'native UI reuses an active respec interaction')
    assert(#f.requests.skills==2 and f.requests.skills[2].skills[1].morph==1,'second apply waited for a start event which will not fire')
    f:Advance(5000);assert(#f.requests.skills==2,'late entry timer must not duplicate send')
 end,
 cancelled_and_timed_out_entry_never_send_on_late_readiness=function()
    local _,f,adapter=draftSetup({active(51,{morph=1})})
    local request=assert(adapter:Prepare(adapter:Capture(),{skills={['10:active:51']={kind='active',purchased=true,morph=2}}}))
    assert(adapter:Submit(request));assert(adapter:CancelSubmission())
    f:SkillEntryReady();f:Advance(1);assert(#f.requests.skills==0 and adapter:GetSubmissionState().phase=='cancelled')
    f.api.SKILLS_AND_ACTION_BAR_MANAGER:ResetRespecState()
    assert(adapter:Submit(request));f:Advance(5000)
    assert(adapter:GetSubmissionState().phase=='failed' and adapter:GetSubmissionState().problem.code=='skillEntryTimeout')
    f:SkillEntryReady();f:Advance(1);assert(#f.requests.skills==0)
 end,
 bar_only_submit_does_not_enter_full_or_activate_native_draft=function()
    local _,f,adapter=draftSetup({active(51)})
    local request=assert(adapter:Prepare(adapter:Capture(),{bars={back={[2]={kind='skill',skillKey='10:active:51',expectedMorph=0}}}}))
    assert(adapter:Submit(request))
    assert(not f.entryRequests and f.api.SKILLS_AND_ACTION_BAR_MANAGER.mode==0)
    assert(#f.requests.skills==1 and f.requests.skills[1].mode==0 and #f.requests.skills[1].bars==1)
    assert(f.requests.skills[1].bars[1].slot==4 and f.requests.skills[1].bars[1].bar==1)
 end,
 foreign_edits_during_entry_are_preserved_and_block_send=function()
    local _,f,adapter=draftSetup({active(51,{morph=1})})
    local request=assert(adapter:Prepare(adapter:Capture(),{skills={['10:active:51']={kind='active',purchased=true,morph=2}}}))
    assert(adapter:Submit(request));f:SkillEntryReady();f.foreignPending=true
    f:Advance(1)
    assert(#f.requests.skills==0 and f.foreignPending and adapter:GetSubmissionState().problem.code=='foreignSkillDraft')
 end,
 disabled_crafted_script_rejects_bar_target_without_rescribing=function()
    local _,f,adapter=setup({{lineId=10,kind='crafted',id=71,purchased=true}})
    f.disabledScripts={[101]=true}
    local request,problem=adapter:Prepare(adapter:Capture(),{bars={front={[1]={kind='skill',skillKey='10:crafted:71'}}}})
    assert(not request and problem.code=='skillUnavailable' and #f.requests.skills==0)
 end,
 capture_ignores_pending_hotbar_and_allocator_state=function()
    local _,f,adapter=setup({active(51,{morph=1})})
    f.actualBars[0][3]={type=1,id=511}
    f.api.ACTION_BAR_ASSIGNMENT_MANAGER.GetHotbar=function()
        return {IsSlotLocked=function()return false end,IsSlotMutable=function()return true end,
            GetOverrideSkillDataForSlot=function()return nil end,
            GetSlotData=function()error('pending hotbar must not be read by actual Capture')end}
    end
    f.skillObjects[1].GetPointAllocator=function()error('pending allocator must not be read by actual Capture')end
    local actual,budgets=adapter:Capture()
    assert(actual.skills['10:active:51'].morph==1)
    assert(actual.bars.front[1].expectedMorph==1 and budgets.skills==10)
 end,
 native_userdata_managers_are_read_without_secure_hooks=function()
    local _,f,adapter=setup({active(51)})
    f.api.SKILLS_DATA_MANAGER=Fake.Control(f.api.SKILLS_DATA_MANAGER)
    f.api.ACTION_BAR_ASSIGNMENT_MANAGER=Fake.Control(f.api.ACTION_BAR_ASSIGNMENT_MANAGER)
    local actual=assert(adapter:Capture())
    assert(actual.skills['10:active:51'].purchased and #f.api.securePostHooks==0)
 end,
 capture_revision_tracks_cost_changes_and_unresolved_slots_report_unavailability=function()
    local _,f,adapter=setup({active(51)})
    local _,_,before=adapter:Capture()
    local _,_,same=adapter:Capture();assert(before==same)
    f.skillObjects[1].spec.cost=2
    local _,_,after=adapter:Capture();assert(after>before)
    f.actualBars[0][3]={type=1,id=99999}
    local actual,problem=adapter:Capture()
    assert(not actual and problem.code=='buildCapabilityUnavailable')
 end,
 auto_granted_upgrade_keeps_minimum_rank_and_morph_cost_only=function()
    local _,_,adapter=setup({active(51,{autoGrant=true}),{lineId=10,kind='passive',id=61,purchased=true,autoGrant=true,rank=1}})
    local current=adapter:Capture()
    local request=assert(adapter:Prepare(current,{skills={['10:active:51']={kind='active',purchased=true,morph=1},['10:passive:611']={kind='passive',rank=2}}}))
    assert(request.pointDelta==2)
    local invalid,problem=adapter:Prepare(current,{skills={['10:passive:611']={kind='passive',rank=0}}})
    assert(not invalid and problem.code=='skillImmutable')
 end,
 mastery_transaction_threshold_survives_net_affordability=function()
    local _,_,adapter=setup({{lineId=20,kind='passive',id=61,purchased=true,rank=2,mastery=true,masteryPoints=3,masterySpent=2,masteryCost=2},{lineId=20,kind='passive',id=62,purchased=false,mastery=true}})
    local current=adapter:Capture()
    local request,problem=adapter:Prepare(current,{skills={['20:passive:611']={kind='passive',rank=2},['20:passive:621']={kind='passive',rank=1}}})
    assert(not request and problem.code=='insufficientMasteryPoints')
    request=assert(adapter:Prepare(current,{skills={['20:passive:611']={kind='passive',rank=0},['20:passive:621']={kind='passive',rank=2}}}))
    assert(request.masteryDelta[20]==0)
 end,
 duplicate_same_bar_rejected_but_cross_bar_permitted=function()
    local _,_,adapter=setup({active(51)})
    local ref={kind='skill',skillKey='10:active:51',expectedMorph=0}
    local request,problem=adapter:Prepare(adapter:Capture(),{bars={front={[1]=ref,[2]=ref}}})
    assert(not request and problem.code=='duplicateBarSkill')
 end,
 skill_keys_survive_list_reordering=function()
    local kw,f=setup({active(51),{lineId=10,kind='passive',id=61,purchased=true,rank=2}})
    local before=kw.SkillState.Read(f.api)
    local line=f.skillLines[10];line.skills[1],line.skills[2]=line.skills[2],line.skills[1]
    local after=kw.SkillState.Read(f.api)
    assert(before.byKey['10:active:51'] and after.byKey['10:active:51'])
    assert(before.byKey['10:passive:611'] and after.byKey['10:passive:611'])
 end,
 passive_target_is_purchased_rank_not_xp=function()
    local _,f,adapter=setup({{lineId=10,kind='passive',id=61,purchased=false,rank=1}})
    local current=adapter:Capture()
    assert(current.skills['10:passive:611'].rank==0)
    local request=assert(adapter:Prepare(current,{skills={['10:passive:611']={kind='passive',rank=2}}}))
    assert(request.pointDelta==2 and request.target.skills['10:passive:611'].rank==2)
    assert(#f.requests.skills==0)
 end,
 subclass_cost_and_mastery_are_separate=function()
    local _,_,adapter=setup({active(51,{purchased=false,cost=2}),active(52,{purchased=false,cost=2}),{lineId=20,kind='passive',id=61,purchased=false,mastery=true}})
    local current=adapter:Capture()
    local request=assert(adapter:Prepare(current,{skills={['10:active:51']={kind='active',purchased=true,morph=0},['10:active:52']={kind='active',purchased=true,morph=0},['20:passive:611']={kind='passive',rank=1}}}))
    assert(request.pointDelta==4 and request.masteryDelta[20]==1)
 end,
 insufficient_budget_and_locked_morph_reject_before_requests=function()
    local _,f,adapter=setup({active(51,{purchased=false,cost=2,morphUnlocked=false})})
    f.skillPoints=1
    local current=adapter:Capture()
    local request,problem=adapter:Prepare(current,{skills={['10:active:51']={kind='active',purchased=true,morph=0}}})
    assert(not request and problem.code=='insufficientSkillPoints')
    f.skillPoints=10
    request,problem=adapter:Prepare(current,{skills={['10:active:51']={kind='active',purchased=true,morph=1}}})
    assert(not request and problem.code=='skillMorphLocked' and #f.requests.skills==0)
 end,
 refunds_fund_purchases_and_precede_them=function()
    local _,f,adapter=setup({active(51,{morph=1}),active(52,{purchased=false})})
    f.skillPoints=0
    local request=assert(adapter:Prepare(adapter:Capture(),{skills={['10:active:51']={kind='active',purchased=false},['10:active:52']={kind='active',purchased=true,morph=1}}}))
    assert(request.pointDelta==0 and request.requiresRespec and request.skillChanges[1].key=='10:active:51')
 end,
 logical_bar_slots_use_native_indices_and_allow_same_skill_on_two_bars=function()
    local _,_,adapter=setup({active(51)})
    local ref={kind='skill',skillKey='10:active:51',expectedMorph=0}
    local request=assert(adapter:Prepare(adapter:Capture(),{bars={front={[1]=ref},back={[1]=ref}}}))
    assert(not request.requiresRespec and #request.barChanges==2)
    assert(request.barChanges[1].nativeSlot==3 and request.barChanges[2].nativeSlot==3)
    assert(request.target.bars.front[2].kind=='empty')
 end,
 locked_backup_and_ultimate_override_only_reject_changes=function()
    local _,f,adapter=setup({active(51),active(52,{ultimate=true})})
    f.lockedSlots={['1:3']=true};f.overrides={['0:8']=f.skillObjects[2]}
    f.actualBars[0][8]={type=1,id=520}
    local current=adapter:Capture()
    local request,problem=adapter:Prepare(current,{bars={back={[1]={kind='skill',skillKey='10:active:51',expectedMorph=0}}}})
    assert(not request and problem.code=='skillBarLocked')
    request,problem=adapter:Prepare(current,{bars={front={[6]={kind='empty'}}}})
    assert(not request and problem.code=='skillBarOverride')
    assert(adapter:Prepare(current,{bars={back={[1]={kind='empty'}}}}))
 end,
 unavailable_crafted_scripts_are_not_changed=function()
    local _,f,adapter=setup({{lineId=10,kind='crafted',id=71,purchased=false}})
    local current=adapter:Capture()
    assert(current.skills['10:crafted:71']==nil)
    local request,problem=adapter:Prepare(current,{bars={front={[1]={kind='skill',skillKey='10:crafted:71'}}}})
    assert(not request and problem.code=='skillUnavailable' and #f.requests.skills==0)
 end,
 unpurchase_clears_existing_bar_references_and_morph_updates_both_bars=function()
    local _,f,adapter=setup({active(51,{morph=1})})
    f.actualBars[0][3]={type=1,id=511};f.actualBars[1][3]={type=1,id=511}
    local current=adapter:Capture()
    local morph=assert(adapter:Prepare(current,{skills={['10:active:51']={kind='active',purchased=true,morph=2}}}))
    assert(morph.target.bars.front[1].expectedMorph==2 and morph.target.bars.back[1].expectedMorph==2)
    local sold=assert(adapter:Prepare(current,{skills={['10:active:51']={kind='active',purchased=false}}}))
    assert(sold.target.bars.front[1].kind=='empty' and sold.target.bars.back[1].kind=='empty')
 end,
 immutable_auto_grants_excluded_but_bar_references_remain_available=function()
    local _,f,adapter=setup({active(51,{autoGrant=true,morphUnlocked=false})})
    f.actualBars[0][3]={type=1,id=510}
    local current=adapter:Capture()
    assert(current.skills['10:active:51']==nil and current.bars.front[1].skillKey=='10:active:51')
    local request,problem=adapter:Prepare(current,{skills={['10:active:51']={kind='active',purchased=false}}})
    assert(not request and problem.code=='skillImmutable')
 end,
}
