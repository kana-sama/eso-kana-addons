local Fake=dofile(ROOT.."/tests/support/fake_eso.lua")
local function setup()
    local k=Fake.Load()
    for _,name in ipairs({"EquipmentPlan.lua","EquipmentRunner.lua","Protection.lua","Session.lua"}) do
        local file=io.open(ROOT.."/"..name,"r"); if file then file:close(); dofile(ROOT.."/"..name) end
    end
    assert(k.Session,"Session module missing")
    local a=Fake.New(); a.sheathed=true
    function a.IsUnitDeadOrReincarnating() return a.dead or false end
    function a.ArePlayerWeaponsSheathed() return a.sheathed end
    function a.TogglePlayerWield() a.sheathed=true end
    function a.CanItemBePlayerLocked(b,s) return not a.bags[b][s].unLockable end
    function a.IsItemPlayerLocked(b,s) return a.bags[b][s].locked==true end
    function a.SetItemIsPlayerLocked(b,s,v) if not a.ignoreLock then a.bags[b][s].locked=v end; if a.onLock then a.onLock() end end
    local clock={now=0,next=0,timers={}}
    function clock:NowMs() return self.now end
    function clock:Schedule(delay,cb) self.next=self.next+1; self.timers[self.next]={at=self.now+delay,cb=cb}; return self.next end
    function clock:Cancel(id) self.timers[id]=nil end
    function clock:Advance(delta)
        local limit=self.now+delta
        while true do
            local id,at
            for n,t in pairs(self.timers) do if t.at<=limit and (not at or t.at<at or t.at==at and n<id) then id,at=n,t.at end end
            if not id then break end
            local t=self.timers[id]; self.timers[id]=nil; self.now=at; t.cb()
        end
        self.now=limit
    end
    local events=k.Core.NewEvents(); local function emit(n,p) events:Emit(n,p) end
    local inv=k.Inventory.New(a,emit); local repo=k.Presets.New({},"EU","a","c","Char",emit)
    local f={k=k,a=a,inv=inv,repo=repo,saved=repo.character,clock=clock,events=events,applied=0,notifications={}}
    f.protection=k.Protection.New(repo,inv)
    function f:Reload()
        self.runner=k.EquipmentRunner.New(inv,events,clock)
        self.session=k.Session.New(repo,inv,k.EquipmentPlan,self.runner,self.protection,self.saved,{},function(n,p)
            self.notifications[#self.notifications+1]={n,p}; if self.observe then self.observe(n,p) end
        end)
    end
    function f:Add(uid,bag,slot,equip)
        local v={uid=uid,link="link:"..uid}; a.bags[bag][slot]=v; a.descriptions[v.link]={equipType=equip or EQUIP_TYPE_RING}
        return {kind="item",uid=uid,link=v.link}
    end
    function f:Preset(slots,name) local p=repo:NewDraft(); p.slots=slots; p.name=name or "Test"; return assert(repo:Save(p,0)) end
    function f:ApplyRequest(index)
        local q=a.requests[index]; assert(q,"missing request")
        dofile(ROOT..'/tests/support/gear_ack.lua')(a,a.requests[index],index)
        inv:Refresh()
    end
    function f:Drain()
        local limit=0
        while self.applied<#a.requests do
            limit=limit+1; assert(limit<100,"request loop")
            self.applied=self.applied+1; self:ApplyRequest(self.applied); clock:Advance(1)
        end
    end
    f:Reload(); return f
end
local function fails(ok,p,code) assert(not ok and p and p.code==code,"expected "..code..", got "..tostring(p and p.code)) end
local tests={}
function tests.failure_diagnostics_survive_successful_rollback_and_are_bounded()
    local f=setup(); f.a.sheathed=false
    f.a.IsEquipable=function()return false,123 end
    f.a.IsPlayerInWerewolfForm=function()return true end
    local weapon=f:Add("weapon",BAG_BACKPACK,1,EQUIP_TYPE_ONE_HAND)
    local p=f:Preset({[EQUIP_SLOT_MAIN_HAND]=weapon})
    for _=1,7 do
        assert(f.session:Apply(p.id)); f.clock:Advance(15001)
        assert(f.session:GetView().state=="idle" and #f.a.requests==0)
    end
    local log=f.saved.equipmentFailures
    assert(log and #log==5,"keep a bounded persistent failure history")
    local last=log[#log]
    assert(last.problem.code=="notEquipable" and last.state=="applying" and last.phase=="requesting")
    assert(last.werewolf and not last.sheathed and last.elapsedMs==0)
    assert(last.target[EQUIP_SLOT_MAIN_HAND].uid=="weapon" and last.locations.weapon.bagId==BAG_BACKPACK)
    assert(not last.pending and f.saved.journal==nil,"successful recovery must not erase diagnostic evidence")
end
function tests.new_checkbox_does_not_equip_and_cancel_leaves_no_preset()
    local f=setup(); f:Add("old",BAG_WORN,EQUIP_SLOT_RING1); local original=f.inv:Capture().worn
    assert(f.session:BeginNew()); local v=f.session:GetView(); assert(v.isEditor and v.selected[EQUIP_SLOT_RING1] and not v.selected[EQUIP_SLOT_RING2])
    assert(f.session:SetSelected(EQUIP_SLOT_RING2,true)); assert(#f.a.requests==0)
    f:Add("hat",BAG_WORN,EQUIP_SLOT_HEAD,EQUIP_TYPE_HEAD)
    assert(f.session:Cancel()); f:Drain(); assert(f.k.Slots.Equal(f.inv:Capture().worn,original)); assert(#f.repo:List()==0 and f.saved.journal==nil)
end
function tests.save_reads_actual_locks_then_restores_all_slots()
    local f=setup(); local old=f:Add("old",BAG_WORN,EQUIP_SLOT_RING1); local original=f.inv:Capture().worn
    local preset=f:Preset({[EQUIP_SLOT_RING1]=old}); assert(f.session:BeginEdit(preset.id))
    f.a.bags[BAG_BACKPACK][1]=f.a.bags[BAG_WORN][EQUIP_SLOT_RING1]; f:Add("new",BAG_WORN,EQUIP_SLOT_RING1)
    f:Add("hat",BAG_WORN,EQUIP_SLOT_HEAD,EQUIP_TYPE_HEAD)
    assert(f.session:SetName("Changed")); assert(f.session:Save()); assert(f.repo:Get(preset.id).slots[EQUIP_SLOT_RING1].uid=="new")
    assert(f.a.bags[BAG_WORN][EQUIP_SLOT_RING1].locked); f:Drain()
    assert(f.k.Slots.Equal(f.inv:Capture().worn,original) and f.saved.journal==nil and f.repo:Get(preset.id).revision==2)
end
function tests.zero_selected_rejected_but_explicit_empty_saved()
    local f=setup(); assert(f.session:BeginNew()); local ok,p=f.session:Save(); fails(ok,p,"noSlotsSelected")
    assert(f.session:SetSelected(EQUIP_SLOT_RING1,true)); assert(f.session:Save()); assert(f.repo:List()[1].slots[EQUIP_SLOT_RING1].kind=="empty")
    assert(f.saved.journal==nil and f.session:GetView().state=="idle")
end
function tests.busy_session_rejects_second_entry_and_noop_does_not_resurrect()
    local f=setup(); local r=f:Add("r",BAG_WORN,EQUIP_SLOT_RING1); local p=f:Preset({[EQUIP_SLOT_RING1]=r})
    assert(f.session:BeginNew()); for _,call in ipairs({function() return f.session:Apply(p.id) end,function() return f.session:BeginEdit(p.id) end,function() return f.session:BeginNew() end}) do local ok,e=call(); fails(ok,e,"busy") end
    assert(f.session:Cancel()); assert(f.session:Apply(p.id)); assert(f.session:GetView().state=="idle" and f.saved.journal==nil and #f.a.requests==0)
end
function tests.confirmation_requires_current_revision_and_extra_identity()
    local f=setup(); local r=f:Add("r",BAG_WORN,EQUIP_SLOT_RING2); local p=f:Preset({[EQUIP_SLOT_RING1]=r})
    assert(f.session:Apply(p.id)); local key=f.session:GetView().confirmation.plan.extraKey; assert(#f.a.requests==0)
    local changed=f.repo:Get(p.id); changed.name="Changed"; f.repo:Save(changed,changed.revision)
    local ok,e=f.session:Confirm(key); fails(ok,e,"confirmationChanged"); assert(#f.a.requests==0)
    key=f.session:GetView().confirmation.plan.extraKey; assert(f.session:Confirm(key)); f:Drain(); assert(f.session:GetView().state=="idle")
end
function tests.reject_confirmation_preserves_equipment_and_editor_extras_not_selected()
    local f=setup(); local r=f:Add("r",BAG_WORN,EQUIP_SLOT_RING2); local original=f.inv:Capture().worn; local p=f:Preset({[EQUIP_SLOT_RING1]=r})
    assert(f.session:BeginEdit(p.id)); assert(f.session:GetView().isEditor); assert(f.session:RejectConfirmation()); assert(#f.a.requests==0)
    assert(f.session:BeginEdit(p.id)); assert(f.session:Confirm(f.session:GetView().confirmation.plan.extraKey)); f:Drain()
    assert(not f.session:GetView().selected[EQUIP_SLOT_RING2]); assert(f.session:Cancel()); f:Drain(); assert(f.k.Slots.Equal(f.inv:Capture().worn,original))
end
function tests.missing_ghost_requires_explicit_choice_and_cancel_preserves_reference()
    local f=setup(); f:Add("old",BAG_WORN,EQUIP_SLOT_RING1); local p=f:Preset({[EQUIP_SLOT_RING1]={kind="item",uid="gone",link="gone"}})
    local ok,e=f.session:Apply(p.id); fails(ok,e,"itemMissing"); assert(#f.a.requests==0)
    assert(f.session:BeginEdit(p.id,true)); f:Drain(); assert(f.session:GetView().missing[EQUIP_SLOT_RING1].uid=="gone")
    assert(f.session:SetSelected(EQUIP_SLOT_RING1,false)); assert(f.session:SetSelected(EQUIP_SLOT_RING1,true)); ok,e=f.session:Save(); fails(ok,e,"unresolvedMissing")
    assert(f.session:Cancel()); f:Drain(); assert(f.repo:Get(p.id).slots[EQUIP_SLOT_RING1].uid=="gone" and f.inv:Capture().worn[EQUIP_SLOT_RING1].uid=="old")
end
function tests.missing_choices_replace_empty_omit()
    for _,choice in ipairs({"replace","empty","omit"}) do
        local f=setup(); local p=f:Preset({[EQUIP_SLOT_RING1]={kind="item",uid="gone",link="gone"},[EQUIP_SLOT_RING2]={kind="empty"}})
        assert(f.session:BeginEdit(p.id,true)); if choice=="replace" then f:Add("new",BAG_WORN,EQUIP_SLOT_RING1) end
        assert(f.session:ResolveMissing(EQUIP_SLOT_RING1,choice)); assert(f.session:Save()); f:Drain(); local value=f.repo:Get(p.id).slots[EQUIP_SLOT_RING1]
        assert(choice=="omit" and value==nil or choice=="empty" and value.kind=="empty" or choice=="replace" and value.uid=="new")
    end
end
function tests.return_capacity_and_lock_failure_leave_old_preset_and_editor()
    for _,kind in ipairs({"capacity","lock"}) do
        local f=setup(); local p=f:Preset({[EQUIP_SLOT_RING1]={kind="empty"}}); assert(f.session:BeginEdit(p.id)); f:Add("new",BAG_WORN,EQUIP_SLOT_RING1)
        if kind=="capacity" then f.a.free=0 else f.a.ignoreLock=true end
        local ok,e=f.session:Save(); assert(not ok and e); assert(f.repo:Get(p.id).revision==1 and f.session:GetView().state=="editing" and #f.a.requests==0)
    end
end
function tests.journal_pending_is_written_before_mutation()
    local f=setup(); local r=f:Add("r",BAG_BACKPACK,1); local p=f:Preset({[EQUIP_SLOT_RING1]=r}); local native=f.a.RequestEquipItem
    f.a.RequestEquipItem=function(...) assert(f.saved.journal and f.saved.journal.pending.uid=="r" and f.saved.journal.phase=="requesting"); native(...) end
    assert(f.session:Apply(p.id)); f:Drain(); assert(f.saved.journal==nil)
end
function tests.reload_after_commit_restores_once()
    local f=setup(); f:Add("old",BAG_WORN,EQUIP_SLOT_RING1); local original=f.inv:Capture().worn
    assert(f.session:BeginNew()); f.a.bags[BAG_BACKPACK][1]=f.a.bags[BAG_WORN][EQUIP_SLOT_RING1]; f:Add("new",BAG_WORN,EQUIP_SLOT_RING1)
    assert(f.session:Save()); local p=f.repo:List()[1]; local revision=p.revision; assert(f.saved.journal.saveCommitted)
    f.runner:Stop("reload"); f:ApplyRequest(1); f.applied=1; f:Reload(); assert(#f.a.requests==1 and f.session:GetView().state=="recovery")
    assert(f.session:Recover("restore")); f:Drain(); assert(f.repo:Get(p.id).revision==revision and f.k.Slots.Equal(f.inv:Capture().worn,original) and f.saved.journal==nil)
end
function tests.pause_requires_resume_and_reports_external_change()
    local f=setup(); f:Add("r",BAG_WORN,EQUIP_SLOT_RING1); assert(f.session:BeginNew()); assert(f.session:Pause("sceneChanged"))
    f.clock:Advance(6000); assert(#f.a.requests==0 and f.session:GetView().paused)
    f:Add("hat",BAG_WORN,EQUIP_SLOT_HEAD,EQUIP_TYPE_HEAD); local ok,e=f.session:Resume(); fails(ok,e,"externalChange")
    assert(f.session:GetView().state=="recovery"); assert(f.session:Recover("keepCurrent")); assert(f.saved.journal==nil)
end
function tests.partial_recovery_keeps_missing_reference()
    local f=setup(); f:Add("lost",BAG_WORN,EQUIP_SLOT_RING1); f:Add("oldhat",BAG_WORN,EQUIP_SLOT_HEAD,EQUIP_TYPE_HEAD); assert(f.session:BeginNew())
    f.a.bags[BAG_WORN][EQUIP_SLOT_RING1]=nil; f.a.bags[BAG_BACKPACK][3]=f.a.bags[BAG_WORN][EQUIP_SLOT_HEAD]; f:Add("newhat",BAG_WORN,EQUIP_SLOT_HEAD,EQUIP_TYPE_HEAD)
    f:Reload(); local ok,e=f.session:Recover("restore"); assert(not ok and e and #f.a.requests==0)
    assert(f.session:Recover("restoreAvailable")); f:Drain(); assert(f.saved.journal.original[EQUIP_SLOT_RING1].uid=="lost")
    assert(f.session:GetView().state=="recovery" and f.inv:Capture().worn[EQUIP_SLOT_HEAD].uid=="oldhat")
    assert(f.session:Recover("keepCurrent")); assert(f.saved.journal==nil)
end
function tests.timeout_keeps_pending_and_late_confirmation_can_be_recovered()
    local f=setup(); local r=f:Add("r",BAG_BACKPACK,1); local p=f:Preset({[EQUIP_SLOT_RING1]=r}); assert(f.session:Apply(p.id)); f.clock:Advance(5001)
    assert(f.session:GetView().state=="recovery" and f.saved.journal.pending.uid=="r" and #f.a.requests==1)
    f:ApplyRequest(1); f.applied=1; assert(f.session:Recover("restore")); f:Drain(); assert(f.inv:Capture().worn[EQUIP_SLOT_RING1].kind=="empty" and f.saved.journal==nil)
end
function tests.external_change_never_launches_automatic_rollback()
    local f=setup(); local r=f:Add("r",BAG_BACKPACK,1); local p=f:Preset({[EQUIP_SLOT_RING1]=r}); assert(f.session:Apply(p.id))
    f:Add("external",BAG_WORN,EQUIP_SLOT_HEAD,EQUIP_TYPE_HEAD); f.inv:Refresh(); f.clock:Advance(1)
    assert(f.session:GetView().state=="recovery" and #f.a.requests==1 and f.saved.journal~=nil)
end
function tests.invalid_journal_blocks_equipping_until_explicit_keep()
    local f=setup(); f.saved.journal={version=1,kind="edit",original={[EQUIP_SLOT_RING1]={kind="item",uid="oops",link="bad"}}}; f:Reload()
    assert(f.session:GetView().state=="recovery" and f.session:GetView().problem.code=="invalidJournal")
    local ok,e=f.session:Recover("restore"); fails(ok,e,"invalidJournal"); assert(#f.a.requests==0); assert(f.session:Recover("keepCurrent"))
end
function tests.confirm_bag_moves_do_not_repeat_but_changed_extra_does()
    local f=setup(); local weapon=f:Add("greatsword",BAG_BACKPACK,1,EQUIP_TYPE_TWO_HAND); f:Add("shield",BAG_WORN,EQUIP_SLOT_OFF_HAND,EQUIP_TYPE_OFF_HAND)
    local p=f:Preset({[EQUIP_SLOT_MAIN_HAND]=weapon}); assert(f.session:Apply(p.id)); local key=f.session:GetView().confirmation.plan.extraKey
    f.a.bags[BAG_BACKPACK][2]=f.a.bags[BAG_BACKPACK][1]; f.a.bags[BAG_BACKPACK][1]=nil
    f.a.bags[BAG_BACKPACK][3]=f.a.bags[BAG_WORN][EQUIP_SLOT_OFF_HAND]; f:Add("shield2",BAG_WORN,EQUIP_SLOT_OFF_HAND,EQUIP_TYPE_OFF_HAND)
    local ok,e=f.session:Confirm(key); fails(ok,e,"confirmationChanged"); assert(#f.a.requests==0)
    local newKey=f.session:GetView().confirmation.plan.extraKey; assert(newKey~=key)
    f.a.bags[BAG_BACKPACK][4]=f.a.bags[BAG_BACKPACK][2]; f.a.bags[BAG_BACKPACK][2]=nil
    assert(f.session:Confirm(newKey)); f:Drain(); assert(f.inv:Capture().worn[EQUIP_SLOT_MAIN_HAND].uid=="greatsword")
end
function tests.confirm_keeps_session_original_snapshot()
    local f=setup(); local r=f:Add("r",BAG_WORN,EQUIP_SLOT_RING2); local original=f.inv:Capture().worn; local p=f:Preset({[EQUIP_SLOT_RING1]=r})
    assert(f.session:BeginEdit(p.id)); f:Add("externalhat",BAG_WORN,EQUIP_SLOT_HEAD,EQUIP_TYPE_HEAD)
    assert(f.session:Confirm(f.session:GetView().confirmation.plan.extraKey)); f:Drain(); assert(f.session:Cancel()); f:Drain()
    assert(f.k.Slots.Equal(f.inv:Capture().worn,original),"confirmation must not replace original session baseline")
end
function tests.save_combat_cannot_commit_even_before_core_pause()
    local f=setup(); f:Add("r",BAG_WORN,EQUIP_SLOT_RING1); assert(f.session:BeginNew()); f.a.combat=true
    local ok,e=f.session:Save(); fails(ok,e,"inCombat"); assert(#f.repo:List()==0 and #f.a.requests==0)
end
function tests.pause_after_lock_does_not_commit_and_reload_can_restore()
    local f=setup(); f:Add("r",BAG_WORN,EQUIP_SLOT_RING1); assert(f.session:BeginNew())
    f.a.onLock=function() f.session:Pause("sceneChanged") end
    local ok,e=f.session:Save(); fails(ok,e,"paused"); assert(#f.repo:List()==0 and f.saved.journal and not f.saved.journal.saveCommitted)
    f:Reload(); assert(#f.a.requests==0); assert(f.session:Recover("restore")); assert(f.saved.journal==nil)
end
function tests.pause_inside_repo_commit_then_reload_never_repeats_save()
    local f=setup(); f:Add("r",BAG_WORN,EQUIP_SLOT_RING1); assert(f.session:BeginNew())
    f.events:Subscribe("PresetsChanged",function() f.session:Pause("sceneChanged") end)
    assert(f.session:Save()); local p=f.repo:List()[1]; assert(f.saved.journal.saveCommitted and f.session:GetView().state=="recovery")
    f:Reload(); assert(f.session:Recover("restore")); assert(f.repo:Get(p.id).revision==1 and f.saved.journal==nil)
end
function tests.reload_from_preparation_keeps_editor_and_requires_explicit_restore()
    local f=setup(); local r=f:Add("r",BAG_BACKPACK,1); local p=f:Preset({[EQUIP_SLOT_RING1]=r}); assert(f.session:BeginEdit(p.id))
    local durable=f.k.Copy(f.saved.journal); f.runner:Stop("reload"); f.saved.journal=durable; f:Reload()
    assert(f.session:GetView().isEditor and f.session:GetView().state=="recovery" and #f.a.requests==1)
    f:ApplyRequest(1); f.applied=1; assert(f.session:Recover("restore")); f:Drain(); assert(f.saved.journal==nil and f.repo:Get(p.id).revision==1)
end
function tests.explicit_restore_works_with_unobserved_old_request_but_retains_evidence()
    local f=setup(); local hat=f:Add("hat",BAG_BACKPACK,1,EQUIP_TYPE_HEAD); local ring=f:Add("ring",BAG_BACKPACK,2)
    local p=f:Preset({[EQUIP_SLOT_HEAD]=hat,[EQUIP_SLOT_RING1]=ring}); assert(f.session:Apply(p.id)); f:ApplyRequest(1); f.applied=1; f.clock:Advance(1)
    assert(#f.a.requests==2); f.clock:Advance(5001); assert(f.session:GetView().state=="recovery")
    assert(f.session:Recover("restore")); assert(#f.a.requests==3); f.applied=3; f:ApplyRequest(3); f.clock:Advance(1)
    assert(f.inv:Capture().worn[EQUIP_SLOT_HEAD].kind=="empty" and f.session:GetView().state=="recovery")
    assert(f.saved.journal.unresolvedRequests[1].uid=="ring" and f.session:GetView().problem.code=="pendingRequest")
    f:ApplyRequest(2); assert(f.session:Recover("restore")); f:Drain(); assert(f.saved.journal==nil)
end
function tests.progress_observer_error_requires_recovery_without_rollback()
    local f=setup(); local r=f:Add("r",BAG_BACKPACK,1); local p=f:Preset({[EQUIP_SLOT_RING1]=r})
    f.observe=function() if f.saved.journal and f.saved.journal.phase=="requesting" then error("journal observer failure") end end
    assert(f.session:Apply(p.id)); assert(f.session:GetView().state=="recovery" and f.session:GetView().problem.code=="progressObserverError")
    assert(#f.a.requests==0 and not f.runner:IsBusy() and f.saved.journal~=nil)
end
function tests.safe_adapter_failure_rolls_back_confirmed_steps()
    local f=setup();f:Add("old-mythic",BAG_WORN,EQUIP_SLOT_HEAD,EQUIP_TYPE_HEAD)
    local incoming=f:Add("new-mythic",BAG_BACKPACK,1,EQUIP_TYPE_NECK)
    f.a.descriptions['link:old-mythic'].quality=99;f.a.descriptions['link:new-mythic'].quality=99
    local p=f:Preset({[EQUIP_SLOT_NECK]=incoming});local original=f.inv:Capture().worn
    assert(f.session:Apply(p.id));assert(f.session:Confirm(f.session:GetView().confirmation.plan.extraKey))
    f:ApplyRequest(1);f.applied=1;f.a.bags[BAG_BACKPACK][1].unusable=true
    local request=f.inv.Request
    f.inv.Request=function(self,step)
        local ok,problem=request(self,step)
        if not ok then f.a.bags[BAG_BACKPACK][1].unusable=false end
        return ok,problem
    end
    f.clock:Advance(1);f:Drain()
    assert(f.k.Slots.Equal(original,f.inv:Capture().worn) and f.saved.journal==nil and f.session:GetView().problem~=nil)
end

function tests.reload_committing_window_reconciles_existing_candidate()
    local f=setup(); f:Add("r",BAG_WORN,EQUIP_SLOT_RING1); assert(f.session:BeginNew()); local snapshot
    f.events:Subscribe("PresetsChanged",function() snapshot=f.k.Copy(f.saved.journal) end)
    assert(f.session:Save()); assert(snapshot.phase=="committing" and not snapshot.saveCommitted)
    f.saved.journal=snapshot; f:Reload(); assert(f.session:GetView().saved); assert(f.session:Recover("restore")); assert(f.repo:List()[1].revision==1)
end
function tests.lock_observer_external_equipment_change_cannot_commit_stale_candidate()
    local f=setup(); f:Add("r",BAG_WORN,EQUIP_SLOT_RING1); assert(f.session:BeginNew())
    f.a.onLock=function() f:Add("hat",BAG_WORN,EQUIP_SLOT_HEAD,EQUIP_TYPE_HEAD) end
    local ok,e=f.session:Save(); fails(ok,e,"externalChange"); assert(#f.repo:List()==0 and f.session:GetView().state=="editing")
end
function tests.recovery_preview_lists_missing_on_reload_and_binds_partial_consent()
    local f=setup(); f:Add("r",BAG_WORN,EQUIP_SLOT_RING1); f:Add("h",BAG_WORN,EQUIP_SLOT_HEAD,EQUIP_TYPE_HEAD); assert(f.session:BeginNew())
    f.a.bags[BAG_WORN][EQUIP_SLOT_RING1]=nil; f:Reload(); local view=f.session:GetView()
    assert(view.recoveryMissing[EQUIP_SLOT_RING1].uid=="r" and type(view.recoveryKey)=="string")
    f.a.bags[BAG_WORN][EQUIP_SLOT_HEAD]=nil
    local ok,e=f.session:Recover("restoreAvailable",view.recoveryKey); fails(ok,e,"recoveryChanged"); assert(#f.a.requests==0)
    local updated=f.session:GetView(); assert(updated.recoveryMissing[EQUIP_SLOT_HEAD].uid=="h")
    assert(f.session:Recover("restoreAvailable",updated.recoveryKey)); assert(f.saved.journal and f.session:GetView().state=="recovery")
end
function tests.reentrant_save_during_lock_or_commit_cannot_create_second_revision()
    local f=setup(); f:Add("r",BAG_WORN,EQUIP_SLOT_RING1); assert(f.session:BeginNew()); local calls=0
    local function reenter() calls=calls+1; local ok=f.session:Save(); assert(not ok) end
    f.a.onLock=reenter; f.events:Subscribe("PresetsChanged",reenter)
    assert(f.session:Save()); assert(calls==2 and #f.repo:List()==1 and f.repo:List()[1].revision==1)
end
function tests.pause_during_requesting_keeps_journal_without_sending()
    local f=setup(); local r=f:Add("r",BAG_BACKPACK,1); local p=f:Preset({[EQUIP_SLOT_RING1]=r}); local paused=false
    f.observe=function() if not paused and f.saved.journal and f.saved.journal.phase=="requesting" then paused=true; f.session:Pause("sceneChanged") end end
    assert(f.session:BeginEdit(p.id)); assert(f.saved.journal and f.session:GetView().paused and f.session:GetView().isEditor and #f.a.requests==0)
end
function tests.pending_equip_source_release_required_across_reload_and_explicit_restore()
    local f=setup(); local r=f:Add("r",BAG_BACKPACK,1); local p=f:Preset({[EQUIP_SLOT_RING1]=r})
    assert(f.session:Apply(p.id)); f:Add("r",BAG_WORN,EQUIP_SLOT_RING1); f.clock:Advance(5001)
    assert(f.saved.journal.pending and f.session:GetView().problem.code=="requestTimeout")
    f:Reload(); assert(f.session:Recover("restore"))
    assert(#f.saved.journal.unresolvedRequests==1,"occupied original source must retain pending evidence")
    f.a.bags[BAG_WORN][EQUIP_SLOT_RING1]=nil; f.inv:Refresh(); f.clock:Advance(1)
    assert(f.session:GetView().state=="recovery" and f.saved.journal.unresolvedRequests[1].uid=="r")
    assert(f.session:GetView().problem.code=="pendingRequest" and f.a.bags[BAG_BACKPACK][1].uid=="r")
    assert(f.session:Recover("keepCurrent")); assert(f.saved.journal==nil)
end
function tests.pending_equip_requires_displaced_item_arrival_before_reconciliation()
    local f=setup(); f:Add("old",BAG_WORN,EQUIP_SLOT_RING1); local r=f:Add("new",BAG_BACKPACK,1)
    local p=f:Preset({[EQUIP_SLOT_RING1]=r}); assert(f.session:Apply(p.id))
    f.a.bags[BAG_BACKPACK][1]=nil; f:Add("new",BAG_WORN,EQUIP_SLOT_RING1); f.clock:Advance(5001)
    local ok,e=f.session:Recover("restore"); fails(ok,e,"originalItemsMissing")
    assert(#f.saved.journal.unresolvedRequests==1,"unobserved displaced UID must retain pending evidence")
    f:Add("old",BAG_BACKPACK,2); assert(f.session:Recover("restore")); f.applied=1; f:Drain()
    assert(f.saved.journal==nil and f.inv:Capture().worn[EQUIP_SLOT_RING1].uid=="old")
end
function tests.pending_equip_requires_whole_expected_snapshot()
    local f=setup(); local r=f:Add("r",BAG_BACKPACK,1); local p=f:Preset({[EQUIP_SLOT_RING1]=r})
    assert(f.session:Apply(p.id)); f:ApplyRequest(1); f.applied=1
    f:Add("external",BAG_WORN,EQUIP_SLOT_HEAD,EQUIP_TYPE_HEAD); f.clock:Advance(1)
    assert(f.session:GetView().problem.code=="externalChange")
    assert(f.session:Recover("restore")); assert(#f.saved.journal.unresolvedRequests==1)
    f:Drain(); assert(f.saved.journal and f.session:GetView().state=="recovery")
end
function tests.commit_observer_exception_reports_saved_and_keeps_explicit_recovery_usable()
    for _,action in ipairs({"restore","keepCurrent"}) do
        local f=setup(); f:Add("original",BAG_WORN,EQUIP_SLOT_RING1); local original=f.inv:Capture().worn
        assert(f.session:BeginNew()); f.a.bags[BAG_BACKPACK][3]=f.a.bags[BAG_WORN][EQUIP_SLOT_RING1]; f:Add("new",BAG_WORN,EQUIP_SLOT_RING1)
        f.events:Subscribe("PresetsChanged",function() error("observer failed after actual write") end)
        local returned,accepted,problem=pcall(function() return f.session:Save() end)
        assert(returned,"repository observer error must not escape the commit guard")
        fails(accepted,problem,"commitObserverError")
        local preset=f.repo:List()[1]; assert(preset.revision==1 and preset.slots[EQUIP_SLOT_RING1].uid=="new")
        assert(not f.session.committing and f.saved.journal.saveCommitted and f.session:GetView().saved)
        assert(f.session:GetView().state=="recovery" and #f.a.requests==0)
        assert(f.session:Recover(action)); f:Drain(); assert(f.repo:Get(preset.id).revision==1 and f.saved.journal==nil)
        if action=="restore" then assert(f.k.Slots.Equal(f.inv:Capture().worn,original)) end
    end
end
function tests.pending_worn_slot_move_restore_reload_keeps_valid_uncertain_evidence()
    local f=setup();local ring=f:Add("r",BAG_WORN,EQUIP_SLOT_RING2);local original=f.inv:Capture().worn
    local preset=f:Preset({[EQUIP_SLOT_RING1]=ring});assert(f.session:Apply(preset.id))
    assert(f.session:Confirm(f.session:GetView().confirmation.plan.extraKey));assert(#f.a.requests==1)
    f.clock:Advance(5001);assert(f.session:GetView().problem.code=="requestTimeout")
    local source=f.k.Copy(f.saved.journal.pending.source)
    assert(source.bagId==BAG_WORN and source.slotIndex==EQUIP_SLOT_RING2)
    assert(f.session:Recover("restore"));assert(#f.a.requests==1 and f.saved.journal.unresolvedRequests[1].uid=='r')
    f:Reload();assert(f.session:GetView().problem.code~='invalidJournal')
    assert(f.session:Recover('restore'));assert(#f.saved.journal.unresolvedRequests==1 and #f.a.requests==1)
    f:ApplyRequest(1);f.applied=1;assert(f.session:Recover('restore'));f:Drain()
    assert(f.k.Slots.Equal(f.inv:Capture().worn,original) and f.saved.journal==nil)
end

function tests.reload_mid_sequence_preserves_pending_source_and_restores_originals()
    local f=setup(); local original=f.inv:Capture().worn
    local hat=f:Add("hat",BAG_BACKPACK,1,EQUIP_TYPE_HEAD); local ring=f:Add("ring",BAG_BACKPACK,2)
    local p=f:Preset({[EQUIP_SLOT_HEAD]=hat,[EQUIP_SLOT_RING1]=ring})
    assert(f.session:BeginEdit(p.id)); assert(#f.a.requests==2)
    f:ApplyRequest(1);f.clock:Advance(1);assert(#f.a.requests==2)
    local durable=f.k.Copy(f.saved.journal)
    assert(#durable.pending.batch==2 and durable.pending.batch[1].source.slotIndex==1
        and durable.pending.batch[2].source.slotIndex==2)
    f.runner:Stop("reload"); f.saved.journal=durable; f:Reload()
    assert(f.session:GetView().problem.code~="invalidJournal" and #f.a.requests==2)
    f:ApplyRequest(2); f.applied=2
    assert(f.session:Recover("restore")); f:Drain()
    assert(f.saved.journal==nil and f.k.Slots.Equal(f.inv:Capture().worn,original))
end
function tests.timed_out_sequence_never_rolls_back_over_an_unconfirmed_native_request()
    local f=setup(); local hat=f:Add("hat",BAG_BACKPACK,1,EQUIP_TYPE_HEAD); local ring=f:Add("ring",BAG_BACKPACK,2)
    local p=f:Preset({[EQUIP_SLOT_HEAD]=hat,[EQUIP_SLOT_RING1]=ring})
    assert(f.session:Apply(p.id));f.clock:Advance(5001)
    assert(#f.a.requests==2 and f.session:GetView().state=="recovery")
    assert(#f.saved.journal.pending.batch==2)
    f:ApplyRequest(1); f.applied=1
    f.clock:Advance(2)
    assert(f.session:GetView().state=="recovery" and #f.a.requests==2)
    assert(not f.k.EquipmentRunner.IsPendingConfirmed(f.inv,f.saved.journal.pending,f.inv:Capture(false)))
    f:ApplyRequest(2);f.applied=2
    assert(f.session:Recover("restore")); f:Drain(); assert(f.saved.journal==nil)
end
function tests.quick_slot_saves_full_equipment_and_restores_repeatedly_without_list_entry()
    local f=setup(); local ref=f:Add("old",BAG_WORN,EQUIP_SLOT_RING1)
    assert(f.session:QuickSave());local p=f.repo:Get(f.k.Presets.QUICK_ID)
    assert(#f.repo:List()==0 and p.slots[EQUIP_SLOT_RING1].uid==ref.uid)
    assert(p.slots[EQUIP_SLOT_RING2].kind=="empty" and f.a.bags[BAG_WORN][EQUIP_SLOT_RING1].locked)
    assert(#f.repo:Memberships(ref.uid,"all")==1)
    f:Reload()
    f.a.bags[BAG_BACKPACK][1]=f.a.bags[BAG_WORN][EQUIP_SLOT_RING1];f.a.bags[BAG_WORN][EQUIP_SLOT_RING1]=nil
    f:Add("extra",BAG_WORN,EQUIP_SLOT_RING2);f.inv:Refresh()
    assert(f.session:QuickLoad());f:Drain()
    assert(f.a.bags[BAG_WORN][EQUIP_SLOT_RING1].uid=="old" and not f.a.bags[BAG_WORN][EQUIP_SLOT_RING2])
    assert(f.session:GetView().state=="idle")
    assert(f.session:QuickLoad());f:Drain();assert(f.session:GetView().state=="idle")
    f.a.bags[BAG_BACKPACK][2]=f.a.bags[BAG_WORN][EQUIP_SLOT_RING1];f.a.bags[BAG_WORN][EQUIP_SLOT_RING1]=nil
    f:Add("new",BAG_WORN,EQUIP_SLOT_RING1);f.inv:Refresh()
    assert(f.session:QuickSave());assert(f.repo:Get(f.k.Presets.QUICK_ID).revision==2)
    assert(#f.repo:Memberships("old","all")==0 and #f.repo:Memberships("new","all")==1)
    assert(#f.repo:List()==0)
end
function tests.quick_save_is_blocked_during_edit_and_failed_lock_preserves_previous_snapshot()
    local f=setup();f:Add("old",BAG_WORN,EQUIP_SLOT_RING1);assert(f.session:QuickSave())
    assert(f.session:BeginNew())
    local ok,p=f.session:QuickSave();fails(ok,p,"busy")
    ok,p=f.session:QuickLoad();fails(ok,p,"busy")
    assert(f.session:Cancel());f:Drain()
    f.a.bags[BAG_BACKPACK][1]=f.a.bags[BAG_WORN][EQUIP_SLOT_RING1]
    f:Add("new",BAG_WORN,EQUIP_SLOT_RING1);f.inv:Refresh();f.a.ignoreLock=true
    ok,p=f.session:QuickSave();fails(ok,p,"lockFailed")
    assert(f.repo:Get(f.k.Presets.QUICK_ID).slots[EQUIP_SLOT_RING1].uid=="old")
end
function tests.legacy_gear_journal_with_ninth_services_keeps_original_recovery_contract()
    local f=setup();local item=f:Add("next",BAG_BACKPACK,1);local preset=f:Preset({[EQUIP_SLOT_RING1]=item})
    assert(f.session:Apply(preset.id));assert(f.saved.journal.version==1)
    local calls=0;local services={capture=function()calls=calls+1;error("legacy journal must not read build capture")end}
    local recovered=f.k.Session.New(f.repo,f.inv,f.k.EquipmentPlan,f.runner,f.protection,f.saved,{},nil,services)
    assert(recovered:GetView().state=="recovery" and recovered.journal.version==1 and not recovered.journal.original.abilities and calls==0)
end
function tests.build_journal_legacy_reader_keeps_equipment_and_blocks_broken_original()
 local f=setup();dofile(ROOT..'/BuildJournal.lua');assert(f.session:BeginNew())
 local read=assert(f.k.BuildJournal.Read(f.saved.journal,f.repo));assert(read.version==1 and not read.original.attributes and not read.original.abilities)
 local broken=f.k.Copy(f.saved.journal);broken.original[EQUIP_SLOT_HEAD]=nil
 assert(not f.k.BuildJournal.Read(broken,f.repo) and f.saved.journal.original[EQUIP_SLOT_HEAD])
end

return tests
