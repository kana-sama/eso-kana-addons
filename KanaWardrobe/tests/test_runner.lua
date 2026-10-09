local Fake=dofile(ROOT.."/tests/support/fake_eso.lua")
local function setup()
    local k=Fake.Load()
    for _,name in ipairs({"EquipmentPlan.lua","EquipmentRunner.lua"}) do
        local f=io.open(ROOT.."/"..name,"r"); if f then f:close(); dofile(ROOT.."/"..name) end
    end
    assert(k.EquipmentRunner,"EquipmentRunner module missing")
    local a=Fake.New(); a.sheathed=true; a.toggles=0
    function a.IsUnitDeadOrReincarnating() return a.dead or false end
    function a.ArePlayerWeaponsSheathed() return a.sheathed end
    function a.TogglePlayerWield() a.toggles=a.toggles+1 end
    local clock={now=0,next=0,timers={}}
    function clock:NowMs() return self.now end
    function clock:Schedule(delay,callback) self.next=self.next+1; self.timers[self.next]={at=self.now+delay,callback=callback}; return self.next end
    function clock:Cancel(id) self.timers[id]=nil end
    function clock:Advance(delta)
        local limit=self.now+delta
        while true do
            local id,at
            for n,t in pairs(self.timers) do if t.at<=limit and (not at or t.at<at or (t.at==at and n<id)) then id,at=n,t.at end end
            if not id then break end
            local t=self.timers[id]; self.timers[id]=nil; self.now=at; t.callback()
        end
        self.now=limit
    end
    local events=k.Core.NewEvents(); local inv=k.Inventory.New(a,function(n,p) events:Emit(n,p) end)
    local f={k=k,a=a,clock=clock,events=events,inv=inv,done={},progress={}}
    f.runner=k.EquipmentRunner.New(inv,events,clock)
    function f:Add(uid,bag,slot,kind)
        local v={uid=uid,link="link:"..uid}; a.bags[bag][slot]=v; a.descriptions[v.link]={equipType=kind or EQUIP_TYPE_RING}
        return {kind="item",uid=uid,link=v.link}
    end
    function f:Plan(intent) return assert(k.EquipmentPlan.Build(inv:Capture(),intent,"apply",{})) end
    function f:Start(plan,progress)
        return self.runner:Start(plan,function(p) self.progress[#self.progress+1]=p; if progress then progress(p) end end,function(r) self.done[#self.done+1]=r end)
    end
    function f:ApplyRequest(index,emit)
        local q=a.requests[index]; assert(q,"request missing")
        dofile(ROOT..'/tests/support/gear_ack.lua')(a,a.requests[index],index)
        if emit~=false then inv:Refresh() end
    end
    return f
end
local tests={}
function tests.stalled_weapon_gets_one_wield_attempt_without_resending_equipment()
    local f=setup();f.a.sheathed=false
    local hat=f:Add('hat',BAG_BACKPACK,1,EQUIP_TYPE_HEAD)
    local sword=f:Add('sword',BAG_BACKPACK,2,EQUIP_TYPE_ONE_HAND)
    f.a.TogglePlayerWield=function()
        f.a.toggles=f.a.toggles+1
        -- Model a native weapon request waiting for the wield animation.
        -- Its actual result is authoritative even if the global flag lags.
        f:ApplyRequest(2)
    end
    f:Start(f:Plan({[EQUIP_SLOT_HEAD]=hat,[EQUIP_SLOT_MAIN_HAND]=sword}))
    assert(#f.a.requests==2 and f.a.toggles==0)
    f:ApplyRequest(1);f.clock:Advance(1401);assert(f.a.toggles==0)
    f.clock:Advance(200)
    assert(f.a.toggles==1 and f.done[1] and f.done[1].status=='success')
    assert(#f.a.requests==2 and next(f.clock.timers)==nil)
end
function tests.weapon_assist_is_bounded_and_timeout_identifies_only_missing_item()
    local f=setup();f.a.sheathed=false
    local hat=f:Add('hat',BAG_BACKPACK,1,EQUIP_TYPE_HEAD)
    local sword=f:Add('sword',BAG_BACKPACK,2,EQUIP_TYPE_ONE_HAND)
    f.a.GetWornItemInfo=function(_,slot)return slot==EQUIP_SLOT_MAIN_HAND,'icon',true,true,false end
    f:Start(f:Plan({[EQUIP_SLOT_HEAD]=hat,[EQUIP_SLOT_MAIN_HAND]=sword}))
    f:ApplyRequest(1);f.clock:Advance(5001)
    assert(f.a.toggles==1 and #f.a.requests==2,'ignored wield must neither loop nor replay moves')
    local r=assert(f.done[1]);assert(r.problem.code=='requestTimeout')
    assert(#r.problem.details.items==1 and r.problem.details.items[1].uid=='sword')
    assert(r.diagnostics.wieldAttempt and r.diagnostics.wieldAttempt.at==1500)
    assert(r.diagnostics.slots[EQUIP_SLOT_MAIN_HAND].heldNow==true)
    assert(next(f.clock.timers)==nil and next(f.events.listeners)==nil)
end
function tests.pending_armor_never_sheathes_already_confirmed_weapon()
    local f=setup();f.a.sheathed=false
    local hat=f:Add('hat',BAG_BACKPACK,1,EQUIP_TYPE_HEAD)
    local sword=f:Add('sword',BAG_BACKPACK,2,EQUIP_TYPE_ONE_HAND)
    f:Start(f:Plan({[EQUIP_SLOT_HEAD]=hat,[EQUIP_SLOT_MAIN_HAND]=sword}))
    f:ApplyRequest(2);f.clock:Advance(5001)
    assert(f.a.toggles==0 and f.done[1].problem.details.items[1].uid=='hat')
end
function tests.two_removals_never_reserve_the_same_backpack_cell()
    for _,oldPlan in ipairs({false,true}) do
        local f=setup()
        f:Add('main',BAG_WORN,EQUIP_SLOT_MAIN_HAND,EQUIP_TYPE_ONE_HAND)
        f:Add('off',BAG_WORN,EQUIP_SLOT_OFF_HAND,EQUIP_TYPE_ONE_HAND)
        -- Native unequip chooses a free destination when requested, not when
        -- acknowledged. A second outstanding removal can pick the same cell.
        f.a.RequestUnequipItem=function(bag,slot)
            local cell=0;while f.a.bags[BAG_BACKPACK][cell]do cell=cell+1 end
            f.a.requests[#f.a.requests+1]={'unequip',bag,slot,cell}
        end
        local plan=f:Plan({[EQUIP_SLOT_MAIN_HAND]={kind='empty'},[EQUIP_SLOT_OFF_HAND]={kind='empty'}})
        if oldPlan then for _,step in ipairs(plan.steps)do step.batchId=1 end end
        f:Start(plan)
        assert(#f.a.requests==1,'removals raced for an unreserved backpack cell')
        for i=1,2 do
            local q=assert(f.a.requests[i]);local old=f.a.bags[BAG_BACKPACK][q[4]]
            f.a.bags[BAG_BACKPACK][q[4]]=f.a.bags[BAG_WORN][q[3]]
            f.a.bags[BAG_WORN][q[3]]=old
            f.inv:Refresh();f.clock:Advance(1)
        end
        assert(f.done[1].status=='success' and f.a.requests[1][4]~=f.a.requests[2][4])
        assert(not f.a.bags[BAG_WORN][EQUIP_SLOT_MAIN_HAND] and not f.a.bags[BAG_WORN][EQUIP_SLOT_OFF_HAND])
    end
end
function tests.empty_weapon_slot_uses_native_equip_even_when_sheath_toggle_is_ignored()
    for _,slot in ipairs({EQUIP_SLOT_MAIN_HAND,EQUIP_SLOT_OFF_HAND,EQUIP_SLOT_BACKUP_MAIN,EQUIP_SLOT_BACKUP_OFF})do
        local f=setup();f.a.sheathed=false
        local wanted=f:Add("weapon",BAG_BACKPACK,3,EQUIP_TYPE_ONE_HAND)
        f:Start(f:Plan({[slot]=wanted}))
        assert(#f.a.requests==1 and f.a.requests[1][1]=="equip" and f.a.requests[1][5]==slot,
            "an empty weapon slot must issue the native equip request, not wait for sheathing")
        assert(f.a.toggles==0 and not f.done[1])
        f:ApplyRequest(1);f.clock:Advance(1)
        assert(f.done[1].status=="success" and f.done[1].actual[slot].uid=="weapon")
        assert(next(f.clock.timers)==nil and next(f.events.listeners)==nil)
    end
end
function tests.mixed_loadout_with_drawn_weapons_dispatches_together()
    local f=setup(); f.a.sheathed=false
    local hat=f:Add("hat",BAG_BACKPACK,1,EQUIP_TYPE_HEAD)
    local sword=f:Add("sword",BAG_BACKPACK,2,EQUIP_TYPE_ONE_HAND)
    f:Start(f:Plan({[EQUIP_SLOT_HEAD]=hat,[EQUIP_SLOT_MAIN_HAND]=sword}))
    assert(#f.a.requests==2 and f.a.toggles==0)
    f.clock:Advance(100);assert(#f.a.requests==2,"do not resend outstanding requests")
    f:ApplyRequest(1);f.clock:Advance(1);assert(not f.done[1])
    f:ApplyRequest(2);f.clock:Advance(1)
    assert(f.done[1].status=="success" and f.a.toggles==0)
end

function tests.rejected_first_native_request_does_not_partially_apply_mixed_loadout()
    local f=setup();f.a.sheathed=false
    f:Add("old-hat",BAG_WORN,EQUIP_SLOT_HEAD,EQUIP_TYPE_HEAD)
    f:Add("old-sword",BAG_WORN,EQUIP_SLOT_MAIN_HAND,EQUIP_TYPE_ONE_HAND)
    local hat=f:Add("hat",BAG_BACKPACK,1,EQUIP_TYPE_HEAD)
    local sword=f:Add("sword",BAG_BACKPACK,2,EQUIP_TYPE_ONE_HAND)
    local plan=f:Plan({[EQUIP_SLOT_HEAD]=hat,[EQUIP_SLOT_MAIN_HAND]=sword})
    f.a.IsEquipable=function()return false,123 end
    f:Start(plan)
    assert(#f.a.requests==0 and f.done[1].problem.code=="notEquipable")
    assert(f.a.bags[BAG_WORN][EQUIP_SLOT_HEAD].uid=="old-hat" and not f.runner:IsBusy())
end

function tests.independent_requests_are_sent_together_and_confirmed_in_any_order()
    local f=setup(); local a=f:Add("hat",BAG_BACKPACK,3,EQUIP_TYPE_HEAD); local b=f:Add("ring",BAG_BACKPACK,5)
    local id=f:Start(f:Plan({[EQUIP_SLOT_HEAD]=a,[EQUIP_SLOT_RING1]=b}),function(p)
        if p.phase=="requesting" then assert(#f.a.requests==p.stepId-1); assert(p.pending.uid~=nil) end
    end)
    assert(id and #f.a.requests==2 and f.runner:IsBusy()); f.clock:Advance(200); assert(#f.a.requests==2)
    f:ApplyRequest(2); f.clock:Advance(1); assert(#f.a.requests==2 and #f.done==0)
    f:ApplyRequest(1); f.clock:Advance(1); assert(#f.done==1 and f.done[1].status=="success" and not f.runner:IsBusy())
    assert(next(f.clock.timers)==nil and next(f.events.listeners)==nil)
end
function tests.timeout_keeps_unconfirmed_request()
    local f=setup(); local v=f:Add("weapon-1",BAG_BACKPACK,3,EQUIP_TYPE_ONE_HAND)
    f:Start(f:Plan({[EQUIP_SLOT_MAIN_HAND]=v})); f.clock:Advance(5001)
    local r=f.done[1]; assert(r and r.status=="uncertain" and r.pending.uid=="weapon-1")
    f:ApplyRequest(1); f.clock:Advance(10000); assert(#f.a.requests==1 and #f.done==1)
end
function tests.wrong_uid_in_target_never_confirms()
    local f=setup(); local v=f:Add("wanted",BAG_BACKPACK,3)
    f:Start(f:Plan({[EQUIP_SLOT_RING1]=v})); f:Add("other",BAG_WORN,EQUIP_SLOT_RING1); f.inv:Refresh(); f.clock:Advance(1)
    assert(#f.done==1 and f.done[1].status~="success" and f.done[1].pending.uid=="wanted")
end
function tests.noop_finishes_without_events_or_sheathing()
    local f=setup(); f.a.sheathed=false; local v=f:Add("weapon",BAG_WORN,EQUIP_SLOT_MAIN_HAND,EQUIP_TYPE_ONE_HAND)
    local id=f:Start(f:Plan({[EQUIP_SLOT_MAIN_HAND]=v}))
    assert(id and #f.done==1 and f.done[1].status=="success" and #f.a.requests==0 and f.a.toggles==0)
end
function tests.missing_events_are_recovered_by_polling_and_new_source_is_resolved()
    local f=setup(); local a=f:Add("hat",BAG_BACKPACK,3,EQUIP_TYPE_HEAD); local b=f:Add("ring",BAG_BACKPACK,5)
    f:Start(f:Plan({[EQUIP_SLOT_HEAD]=a,[EQUIP_SLOT_RING1]=b}),function(p)
        if p.phase=="requesting" and p.stepId==2 then
            f.a.bags[BAG_BACKPACK][8]=f.a.bags[BAG_BACKPACK][5]; f.a.bags[BAG_BACKPACK][5]=nil
        end
    end)
    f:ApplyRequest(1,false)
    f.clock:Advance(100); assert(#f.a.requests==2 and f.a.requests[2][3]==8)
    f:ApplyRequest(2,false); f.clock:Advance(100); assert(f.done[1].status=="success")
end
function tests.synchronous_duplicate_events_do_not_reenter_request()
    local f=setup(); local a=f:Add("hat",BAG_BACKPACK,3,EQUIP_TYPE_HEAD); local b=f:Add("ring",BAG_BACKPACK,5)
    local original=f.a.RequestEquipItem; local depth,maxDepth=0,0
    f.a.RequestEquipItem=function(...)
        depth=depth+1; maxDepth=math.max(depth,maxDepth); original(...); f:ApplyRequest(#f.a.requests)
        f.inv:Refresh(); f.inv:Refresh(); depth=depth-1
    end
    f:Start(f:Plan({[EQUIP_SLOT_HEAD]=a,[EQUIP_SLOT_RING1]=b})); f.clock:Advance(10)
    assert(maxDepth==1 and #f.a.requests==2 and #f.done==1 and f.done[1].status=="success")
end
function tests.start_rejects_busy_combat_death_and_block_without_queue()
    for _,flag in ipairs({"combat","dead","blocking"}) do
        local f=setup(); local v=f:Add("ring",BAG_BACKPACK,3); local p=f:Plan({[EQUIP_SLOT_RING1]=v}); f.a[flag]=true
        local id,e=f:Start(p); assert(not id and e and #f.a.requests==0 and not f.runner:IsBusy())
        f.a[flag]=false; f.clock:Advance(6000); assert(#f.a.requests==0)
    end
    local f=setup(); local v=f:Add("ring",BAG_BACKPACK,3); local p=f:Plan({[EQUIP_SLOT_RING1]=v})
    assert(f:Start(p)); local id,e=f:Start(p); assert(not id and e.code=="busy" and #f.a.requests==1)
end
function tests.combat_death_and_block_interrupt_without_auto_resume()
    for _,flag in ipairs({"combat","dead","blocking"}) do
        local f=setup(); local a=f:Add("hat",BAG_BACKPACK,3,EQUIP_TYPE_HEAD); local b=f:Add("ring",BAG_BACKPACK,5)
        f:Start(f:Plan({[EQUIP_SLOT_HEAD]=a,[EQUIP_SLOT_RING1]=b})); f.a[flag]=true
        f.events:Emit("PlayerStateChanged"); f.clock:Advance(100)
        assert(#f.done==1 and f.done[1].status=="interrupted" and f.done[1].pending)
        f.a[flag]=false; f:ApplyRequest(1); f.clock:Advance(1000); assert(#f.a.requests==2)
    end
end
function tests.external_change_in_ignored_slot_stops_entire_chain()
    local f=setup(); local a=f:Add("hat",BAG_BACKPACK,3,EQUIP_TYPE_HEAD); local b=f:Add("ring",BAG_BACKPACK,5)
    f:Start(f:Plan({[EQUIP_SLOT_HEAD]=a,[EQUIP_SLOT_RING1]=b})); f:ApplyRequest(1)
    f:Add("outside",BAG_WORN,EQUIP_SLOT_NECK,EQUIP_TYPE_NECK); f.inv:Refresh(); f.clock:Advance(1)
    assert(#f.a.requests==2 and f.done[1].problem.code=="externalChange" and f.done[1].status~="success")
end
function tests.ignored_weapon_equip_times_out_without_repeating_or_losing_request_evidence()
    local f=setup();f.a.sheathed=false;local weapon=f:Add("weapon",BAG_BACKPACK,3,EQUIP_TYPE_ONE_HAND)
    f:Start(f:Plan({[EQUIP_SLOT_MAIN_HAND]=weapon}))
    assert(#f.a.requests==1 and not f.done[1])
    f.clock:Advance(15001)
    assert(f.done[1].status=="uncertain" and f.done[1].problem.code=="requestTimeout")
    assert(f.done[1].pending.uid=="weapon" and f.done[1].actual[EQUIP_SLOT_MAIN_HAND].kind=="empty")
    assert(#f.a.requests==1 and f.a.toggles==1 and not f.runner:IsBusy())
end

function tests.weapon_replacement_is_confirmed_by_items_not_global_wield_state()
    local f=setup();f.a.sheathed=false
    f:Add("old-sword",BAG_WORN,EQUIP_SLOT_MAIN_HAND,EQUIP_TYPE_ONE_HAND)
    local wanted=f:Add("weapon",BAG_BACKPACK,1,EQUIP_TYPE_ONE_HAND)
    f:Start(f:Plan({[EQUIP_SLOT_MAIN_HAND]=wanted}))
    assert(#f.a.requests==1 and not f.done[1] and f.a.toggles==0)
    f.a.sheathed=true;f.clock:Advance(100)
    assert(not f.done[1],"an animation flag cannot confirm equipment")
    f.a.sheathed=false;f:ApplyRequest(1);f.clock:Advance(1)
    assert(f.done[1].status=="success" and f.done[1].actual[EQUIP_SLOT_MAIN_HAND].uid=="weapon")
    assert(f.a.bags[BAG_BACKPACK][1].uid=="old-sword")
end

function tests.manual_sheathing_during_equip_does_not_cause_addon_to_toggle_weapons()
    local f=setup(); f.a.sheathed=false
    local weapon=f:Add("weapon",BAG_BACKPACK,1,EQUIP_TYPE_ONE_HAND)
    f:Start(f:Plan({[EQUIP_SLOT_MAIN_HAND]=weapon}))
    f.clock:Advance(900); f.a.sheathed=true
    f.clock:Advance(200)
    assert(f.a.toggles==0 and #f.a.requests==1)
    f:ApplyRequest(1); f.clock:Advance(3000)
    assert(f.a.toggles==0 and f.done[1].status=="success")
end
function tests.drawing_weapons_between_equipment_confirmations_does_not_block_next_request()
    local f=setup(); f.a.sheathed=false; f.a.free=0
    f:Add("old-sword",BAG_WORN,EQUIP_SLOT_MAIN_HAND,EQUIP_TYPE_ONE_HAND)
    local hat=f:Add("hat",BAG_BACKPACK,1,EQUIP_TYPE_HEAD)
    local sword=f:Add("sword",BAG_BACKPACK,2,EQUIP_TYPE_ONE_HAND)
    f:Start(f:Plan({[EQUIP_SLOT_HEAD]=hat,[EQUIP_SLOT_MAIN_HAND]=sword}))
    f.a.sheathed=true; f.clock:Advance(100)
    assert(#f.a.requests==1)
    f.clock:Advance(3300)
    f.a.sheathed=false; f.a.free=1; f:ApplyRequest(1); f.clock:Advance(1)
    assert(not f.done[1] and f.a.toggles==0 and #f.a.requests==2,"next request must not wait for an animation flag")
    f.a.sheathed=true; f.clock:Advance(100)
    assert(#f.a.requests==2)
    f:ApplyRequest(2); f.clock:Advance(1)
    assert(f.done[1].status=="success")
end
function tests.weapon_and_armor_equip_do_not_toggle_wield_state()
    local f=setup(); f.a.sheathed=false; local a=f:Add("weapon",BAG_BACKPACK,3,EQUIP_TYPE_ONE_HAND)
    f:Start(f:Plan({[EQUIP_SLOT_MAIN_HAND]=a})); f.a.sheathed=true; f.clock:Advance(100); assert(#f.a.requests==1)
    f:ApplyRequest(1); f.clock:Advance(1); assert(f.done[1].status=="success" and f.a.toggles==0)
    f=setup(); f.a.sheathed=false; a=f:Add("hat",BAG_BACKPACK,3,EQUIP_TYPE_HEAD)
    f:Start(f:Plan({[EQUIP_SLOT_HEAD]=a})); assert(#f.a.requests==1 and f.a.toggles==0)
end
function tests.stop_invalidates_captured_callbacks_before_next_generation()
    local f=setup(); local v=f:Add("ring",BAG_BACKPACK,3); local p=f:Plan({[EQUIP_SLOT_RING1]=v})
    local first=f:Start(p); local stale={}
    for _,t in pairs(f.clock.timers) do stale[#stale+1]=t.callback end
    for h in pairs(f.events.listeners) do stale[#stale+1]=h.callback end
    f.runner:Stop("cancelled"); assert(#f.done==1 and f.done[1].pending.uid=="ring")
    local second=f:Start(p); assert(second~=first and #f.a.requests==2)
    for _,callback in ipairs(stale) do callback() end
    assert(#f.a.requests==2 and #f.done==1); f.runner:Stop("cancelled"); assert(#f.done==2)
end
function tests.pre_request_failure_is_definite_and_progress_can_cancel()
    local f=setup(); local v=f:Add("ring",BAG_BACKPACK,3); local p=f:Plan({[EQUIP_SLOT_RING1]=v}); f.a.bags[BAG_BACKPACK][3].unusable=true
    f:Start(p); assert(f.done[1].status=="failed" and not f.done[1].pending and #f.a.requests==0)
    f=setup(); v=f:Add("ring",BAG_BACKPACK,3)
    f:Start(f:Plan({[EQUIP_SLOT_RING1]=v}),function(p) if p.phase=="requesting" then f.runner:Stop("cancelled") end end)
    assert(#f.a.requests==0 and #f.done==1 and not f.done[1].pending)
end
function tests.direct_worn_transfer_requires_both_source_release_and_target_ack()
    local f=setup();local v=f:Add("ring",BAG_WORN,EQUIP_SLOT_RING1)
    f:Start(f:Plan({[EQUIP_SLOT_RING2]=v}));assert(#f.a.requests==1 and f.a.requests[1][1]=="equip")
    f.a.bags[BAG_WORN][EQUIP_SLOT_RING2]=f.a.bags[BAG_WORN][EQUIP_SLOT_RING1]
    f.inv:Refresh();f.clock:Advance(1);assert(not f.done[1],"transient duplicate UID is not a complete transfer")
    f.a.bags[BAG_WORN][EQUIP_SLOT_RING1]=nil;f.inv:Refresh();f.clock:Advance(1)
    assert(f.done[1].status=="success" and #f.a.requests==1)
end

function tests.replacement_tolerates_transient_empty_target_but_requires_displaced_uid()
    local f=setup(); f:Add("old",BAG_WORN,EQUIP_SLOT_RING1); local v=f:Add("new",BAG_BACKPACK,3)
    f:Start(f:Plan({[EQUIP_SLOT_RING1]=v}))
    local old=f.a.bags[BAG_WORN][EQUIP_SLOT_RING1]; f.a.bags[BAG_WORN][EQUIP_SLOT_RING1]=nil
    f.inv:Refresh(); f.clock:Advance(1); assert(#f.done==0)
    f.a.bags[BAG_WORN][EQUIP_SLOT_RING1]=f.a.bags[BAG_BACKPACK][3]; f.a.bags[BAG_BACKPACK][3]=nil
    f.inv:Refresh(); f.clock:Advance(1); assert(#f.done==0)
    f.a.bags[BAG_BACKPACK][8]=old; f.inv:Refresh(); f.clock:Advance(1); assert(f.done[1].status=="success")
end
function tests.equip_confirmation_requires_original_source_release()
    local f=setup(); local v=f:Add("ring",BAG_BACKPACK,3); f:Start(f:Plan({[EQUIP_SLOT_RING1]=v}))
    f.a.bags[BAG_WORN][EQUIP_SLOT_RING1]=f.a.bags[BAG_BACKPACK][3]; f.inv:Refresh(); f.clock:Advance(1)
    assert(#f.done==0); f.a.bags[BAG_BACKPACK][3]=nil; f.inv:Refresh(); f.clock:Advance(1)
    assert(f.done[1].status=="success")
end
function tests.stop_inside_native_request_keeps_pending_and_prevents_next_dispatch()
    local f=setup(); local v=f:Add("ring",BAG_BACKPACK,3); local request=f.a.RequestEquipItem
    f.a.RequestEquipItem=function(...) request(...); f.runner:Stop("cancelled"); f:ApplyRequest(1); f.inv:Refresh() end
    f:Start(f:Plan({[EQUIP_SLOT_RING1]=v})); f.clock:Advance(1000)
    assert(#f.a.requests==1 and #f.done==1 and f.done[1].pending.uid=="ring" and not f.runner:IsBusy())
end
function tests.request_exception_is_uncertain_and_does_not_retry()
    local f=setup(); local v=f:Add("ring",BAG_BACKPACK,3); local request=f.a.RequestEquipItem
    f.a.RequestEquipItem=function(...) request(...); error("native boundary raised") end
    f:Start(f:Plan({[EQUIP_SLOT_RING1]=v})); f.clock:Advance(6000)
    assert(#f.a.requests==1 and f.done[1].status=="uncertain" and f.done[1].pending.uid=="ring")
end
function tests.stale_plan_rejected_and_detached_target_verification_is_complete()
    local f=setup(); local v=f:Add("ring",BAG_BACKPACK,3); local p=f:Plan({[EQUIP_SLOT_RING1]=v})
    f:Add("external",BAG_WORN,EQUIP_SLOT_HEAD,EQUIP_TYPE_HEAD)
    local id,e=f:Start(p); assert(not id and e.code=="stalePlan" and #f.a.requests==0)
    f.a.bags[BAG_WORN][EQUIP_SLOT_HEAD]=nil; f:Start(p); p.target[EQUIP_SLOT_RING1].uid="changed"
    f:ApplyRequest(1); f.clock:Advance(1); assert(f.done[1].status=="success")
end
function tests.progress_can_move_source_and_readiness_is_rechecked()
    local f=setup(); local v=f:Add("ring",BAG_BACKPACK,3)
    f:Start(f:Plan({[EQUIP_SLOT_RING1]=v}),function(p)
        if p.phase=="requesting" then f.a.bags[BAG_BACKPACK][7]=f.a.bags[BAG_BACKPACK][3]; f.a.bags[BAG_BACKPACK][3]=nil end
    end)
    assert(f.a.requests[1][3]==7); f:ApplyRequest(1); f.clock:Advance(1); assert(f.done[1].status=="success")
    f=setup(); v=f:Add("ring",BAG_BACKPACK,3)
    f:Start(f:Plan({[EQUIP_SLOT_RING1]=v}),function(p) if p.phase=="requesting" then f.a.dead=true end end)
    assert(#f.a.requests==0 and f.done[1].status=="interrupted" and not f.done[1].pending)
end
function tests.duplicate_events_coalesce_and_callback_mutation_does_not_corrupt_pending()
    local f=setup(); local v=f:Add("ring",BAG_BACKPACK,3)
    f:Start(f:Plan({[EQUIP_SLOT_RING1]=v}),function(p) if p.pending then p.pending.uid="observer-edit" end end)
    local captures=0; local capture=f.inv.Capture
    f.inv.Capture=function(...) captures=captures+1; return capture(...) end
    for i=1,20 do f.events:Emit("InventoryChanged") end
    f.clock:Advance(1); assert(captures==1 and #f.a.requests==1)
    f.clock:Advance(5000); assert(f.done[1].pending.uid=="ring")
end
local function assertFinished(f,status,code,requests)
    f.clock:Advance(6000)
    assert(#f.done==1 and f.done[1].status==status and f.done[1].problem.code==code)
    assert(#f.a.requests==requests and not f.runner:IsBusy())
    assert(next(f.clock.timers)==nil and next(f.events.listeners)==nil)
end
function tests.final_confirmed_observer_external_change_uses_fresh_snapshot()
    local f=setup(); local v=f:Add("ring",BAG_BACKPACK,3)
    f:Start(f:Plan({[EQUIP_SLOT_RING1]=v}),function(p)
        if p.phase=="confirmed" then f:Add("external",BAG_WORN,EQUIP_SLOT_NECK,EQUIP_TYPE_NECK); f.inv:Refresh() end
    end)
    f:ApplyRequest(1); f.clock:Advance(1)
    assertFinished(f,"interrupted","externalChange",1)
    assert(f.done[1].actual[EQUIP_SLOT_NECK].uid=="external" and not f.done[1].pending)
end
function tests.final_confirmed_observer_readiness_change_prevents_success()
    for _,pair in ipairs({{"combat","inCombat"},{"dead","dead"},{"blocking","blocking"}}) do
        local f=setup(); local v=f:Add("ring",BAG_BACKPACK,3)
        f:Start(f:Plan({[EQUIP_SLOT_RING1]=v}),function(p) if p.phase=="confirmed" then f.a[pair[1]]=true end end)
        f:ApplyRequest(1); f.clock:Advance(1); assertFinished(f,"interrupted",pair[2],1)
        assert(not f.done[1].pending)
    end
end
function tests.noop_step_observer_cannot_hide_final_external_change()
    local f=setup(); local v=f:Add("ring",BAG_BACKPACK,3); local plan=f:Plan({[EQUIP_SLOT_RING1]=v})
    plan.steps[2]={kind="equip",uid="ring",equipSlot=EQUIP_SLOT_RING1}
    f:Start(plan,function(p)
        if p.phase=="confirmed" and p.stepId==2 then f:Add("external",BAG_WORN,EQUIP_SLOT_NECK,EQUIP_TYPE_NECK); f.inv:Refresh() end
    end)
    f:ApplyRequest(1); f.clock:Advance(1); assertFinished(f,"interrupted","externalChange",1)
    assert(f.done[1].actual[EQUIP_SLOT_NECK].uid=="external")
end
function tests.progress_errors_complete_once_without_unconfirmed_pending_or_leaks()
    for _,phase in ipairs({"requesting","confirmed"}) do
        local f=setup(); local v=f:Add("weapon",BAG_BACKPACK,3,EQUIP_TYPE_ONE_HAND)
        f.a.sheathed=false
        f:Start(f:Plan({[EQUIP_SLOT_MAIN_HAND]=v}),function(p)
            if p.phase==phase then f.events:Emit("InventoryChanged"); error("journal observer failed") end
        end)
        if phase=="confirmed" then f:ApplyRequest(1); f.clock:Advance(1) end
        assertFinished(f,"failed","progressObserverError",phase=="confirmed" and 1 or 0)
        assert(f.done[1].problem.details.phase==phase and not f.done[1].pending)
        assert(f.a.toggles==0)
    end
end
function tests.weapon_request_observer_rechecks_readiness_and_external_changes_before_dispatch()
    for _,kind in ipairs({"combat","external"}) do
        local f=setup(); f.a.sheathed=false; local v=f:Add("weapon",BAG_BACKPACK,3,EQUIP_TYPE_ONE_HAND)
        f:Start(f:Plan({[EQUIP_SLOT_MAIN_HAND]=v}),function(p)
            if p.phase=="requesting" then
                if kind=="combat" then f.a.combat=true else f:Add("external",BAG_WORN,EQUIP_SLOT_NECK,EQUIP_TYPE_NECK) end
                f.inv:Refresh()
            end
        end)
        assertFinished(f,"interrupted",kind=="combat" and "inCombat" or "externalChange",0)
        assert(f.a.toggles==0 and not f.done[1].pending)
    end
end
function tests.weapon_request_observer_wield_change_does_not_draw_again()
    local f=setup(); f.a.sheathed=false; local v=f:Add("weapon",BAG_BACKPACK,3,EQUIP_TYPE_ONE_HAND)
    f:Start(f:Plan({[EQUIP_SLOT_MAIN_HAND]=v}),function(p) if p.phase=="requesting" then f.a.sheathed=true end end)
    f.clock:Advance(100); assert(f.a.toggles==0 and #f.a.requests==1)
    f:ApplyRequest(1); f.clock:Advance(1); assert(#f.done==1 and f.done[1].status=="success")
    assert(next(f.clock.timers)==nil and next(f.events.listeners)==nil)
end
function tests.batch_reports_only_actually_confirmed_items_as_progress()
    local f=setup();local a=f:Add('hat',BAG_BACKPACK,3,EQUIP_TYPE_HEAD);local b=f:Add('ring',BAG_BACKPACK,5)
    f:Start(f:Plan({[EQUIP_SLOT_HEAD]=a,[EQUIP_SLOT_RING1]=b}))
    assert(#f.a.requests==2,'independent items must be dispatched without waiting for acknowledgements')
    f.clock:Advance(300);assert(#f.a.requests==2)
    assert(f.progress[1].completed==0 and f.progress[1].total==2)
    f:ApplyRequest(1);f.clock:Advance(1);assert(#f.a.requests==2)
    local last=f.progress[#f.progress];assert(last.completed==1 and last.total==2)
    f:ApplyRequest(2);f.clock:Advance(1)
    assert(f.done[1].status=='success' and f.progress[#f.progress].completed==2)
end
function tests.slow_weapon_equip_waits_for_actual_acknowledgement()
    local f=setup();f.a.sheathed=false;local v=f:Add('weapon',BAG_BACKPACK,3,EQUIP_TYPE_ONE_HAND)
    f:Start(f:Plan({[EQUIP_SLOT_MAIN_HAND]=v}));f.clock:Advance(4000)
    assert(not f.done[1] and #f.a.requests==1,'a slow equipment acknowledgement must not be inferred from wield state')
    f.a.sheathed=true;f.clock:Advance(100);assert(#f.a.requests==1)
    f:ApplyRequest(1);f.clock:Advance(1);assert(f.done[1].status=='success')
end
function tests.bag_space_freed_by_pending_equip_is_not_spent_early()
    local f=setup(); f.a.free=0
    local a=f:Add("hat",BAG_BACKPACK,3,EQUIP_TYPE_HEAD); local b=f:Add("ring",BAG_BACKPACK,5)
    f:Add("old",BAG_WORN,EQUIP_SLOT_RING1)
    f:Start(f:Plan({[EQUIP_SLOT_HEAD]=a,[EQUIP_SLOT_RING1]=b}))
    assert(#f.a.requests==1)
    f:ApplyRequest(1); f.a.free=1; f.clock:Advance(1)
    assert(#f.a.requests==2)
    f:ApplyRequest(2); f.clock:Advance(1); assert(f.done[1].status=="success")
end
function tests.complete_loadout_dispatches_together_without_set_metadata()
    local f=setup(); f.a.free=20
    local types={EQUIP_TYPE_HEAD,EQUIP_TYPE_CHEST,EQUIP_TYPE_SHOULDERS,EQUIP_TYPE_HAND,
        EQUIP_TYPE_WAIST,EQUIP_TYPE_LEGS,EQUIP_TYPE_FEET,EQUIP_TYPE_NECK,EQUIP_TYPE_RING,EQUIP_TYPE_RING,
        EQUIP_TYPE_ONE_HAND,EQUIP_TYPE_OFF_HAND,EQUIP_TYPE_ONE_HAND,EQUIP_TYPE_OFF_HAND}
    local slots={EQUIP_SLOT_HEAD,EQUIP_SLOT_CHEST,EQUIP_SLOT_SHOULDERS,EQUIP_SLOT_HAND,
        EQUIP_SLOT_WAIST,EQUIP_SLOT_LEGS,EQUIP_SLOT_FEET,EQUIP_SLOT_NECK,EQUIP_SLOT_RING1,EQUIP_SLOT_RING2,
        EQUIP_SLOT_MAIN_HAND,EQUIP_SLOT_OFF_HAND,EQUIP_SLOT_BACKUP_MAIN,EQUIP_SLOT_BACKUP_OFF}
    local intent={}
    for i,slot in ipairs(slots) do
        f:Add("old"..i,BAG_WORN,slot,types[i]); intent[slot]=f:Add("new"..i,BAG_BACKPACK,i,types[i])
    end
    local plan=f:Plan(intent)
    f.a.GetItemLinkSetInfo=function() error("runner must not load set descriptions") end
    f:Start(plan); assert(#f.a.requests==14 and f.clock.now==0 and #f.done==0)
    for i=14,1,-1 do f:ApplyRequest(i);f.clock:Advance(1)end
    assert(f.done[1].status=="success")
end
function tests.outgoing_mythic_and_unique_item_must_confirm_before_incoming()
    for _,kind in ipairs({"mythic","unique"}) do
        local f=setup(); f:Add("exclusive-old",BAG_WORN,EQUIP_SLOT_RING1)
        local normal=f:Add("normal",BAG_BACKPACK,1); local incoming=f:Add("exclusive-new",BAG_BACKPACK,2)
        for _,uid in ipairs({"exclusive-old","exclusive-new"}) do
            local d=f.a.descriptions["link:"..uid]
            if kind=="mythic" then d.quality=ITEM_DISPLAY_QUALITY_MYTHIC_OVERRIDE else d.uniqueEquipped=true; d.itemId=500 end
        end
        f:Start(f:Plan({[EQUIP_SLOT_RING1]=normal,[EQUIP_SLOT_RING2]=incoming}))
        assert(#f.a.requests==1 and f.a.requests[1][5]==EQUIP_SLOT_RING1)
        f:ApplyRequest(1); f.clock:Advance(1); assert(#f.a.requests==2)
        f:ApplyRequest(2); f.clock:Advance(1); assert(f.done[1].status=="success")
    end
end
function tests.two_handed_to_dual_wield_dispatches_main_before_off_in_one_turn()
    local f=setup(); f:Add("greatsword",BAG_WORN,EQUIP_SLOT_MAIN_HAND,EQUIP_TYPE_TWO_HAND)
    local sword=f:Add("sword",BAG_BACKPACK,1,EQUIP_TYPE_ONE_HAND)
    local dagger=f:Add("dagger",BAG_BACKPACK,2,EQUIP_TYPE_ONE_HAND)
    f:Start(f:Plan({[EQUIP_SLOT_MAIN_HAND]=sword,[EQUIP_SLOT_OFF_HAND]=dagger}))
    assert(#f.a.requests==2 and f.a.requests[1][5]==EQUIP_SLOT_MAIN_HAND and f.a.requests[2][5]==EQUIP_SLOT_OFF_HAND)
    f:ApplyRequest(1); f.clock:Advance(1); assert(not f.done[1])
    f:ApplyRequest(2); f.clock:Advance(1); assert(f.done[1].status=="success")
end
function tests.rejected_second_request_keeps_the_first_unconfirmed_request()
    local f=setup();local hat=f:Add('hat',BAG_BACKPACK,1,EQUIP_TYPE_HEAD);local ring=f:Add('ring',BAG_BACKPACK,2)
    f:Start(f:Plan({[EQUIP_SLOT_HEAD]=hat,[EQUIP_SLOT_RING1]=ring}),function(p)
        if p.phase=='requesting' and p.stepId==2 then f.a.bags[BAG_BACKPACK][2].unusable=true end
    end)
    local result=f.done[1]
    assert(#f.a.requests==1 and result.status=='failed' and #result.pending.batch==1)
    assert(result.pending.batch[1].uid=='hat' and not f.runner:IsBusy())
    assert(not f.k.EquipmentRunner.IsPendingConfirmed(f.inv,result.pending,f.inv:Capture(false)))
    f:ApplyRequest(1);f.clock:Advance(1)
    assert(f.k.EquipmentRunner.IsPendingConfirmed(f.inv,result.pending,f.inv:Capture(false)))
end
function tests.cancel_before_second_dispatch_does_not_claim_it_was_sent()
    local f=setup(); local hat=f:Add("hat",BAG_BACKPACK,1,EQUIP_TYPE_HEAD); local ring=f:Add("ring",BAG_BACKPACK,2)
    f:Start(f:Plan({[EQUIP_SLOT_HEAD]=hat,[EQUIP_SLOT_RING1]=ring}),function(p)
        if p.phase=="requesting" and p.stepId==2 then f.runner:Stop("cancelled") end
    end)
    assert(#f.a.requests==1 and f.done[1].status=="interrupted" and #f.done[1].pending.batch==1)
    assert(f.done[1].pending.batch[1].uid=="hat")
end
function tests.ring_exchange_has_no_temporary_backpack_space_requirement()
    local f=setup();f.a.free=0
    local a=f:Add('a',BAG_WORN,EQUIP_SLOT_RING1);local b=f:Add('b',BAG_WORN,EQUIP_SLOT_RING2)
    f:Start(f:Plan({[EQUIP_SLOT_RING1]=b,[EQUIP_SLOT_RING2]=a}))
    assert(#f.a.requests==1 and f.a.requests[1][1]=='equip' and f.a.requests[1][2]==BAG_WORN)
    f:ApplyRequest(1);f.clock:Advance(1)
    assert(f.done[1].status=='success' and f.a.bags[BAG_WORN][EQUIP_SLOT_RING1].uid=='b'
        and f.a.bags[BAG_WORN][EQUIP_SLOT_RING2].uid=='a')
end

function tests.explicit_removals_wait_for_destination_ack_even_with_free_space()
    local f=setup();f.a.free=2
    f:Add('a',BAG_WORN,EQUIP_SLOT_RING1);f:Add('b',BAG_WORN,EQUIP_SLOT_RING2)
    f:Start(f:Plan({[EQUIP_SLOT_RING1]={kind='empty'},[EQUIP_SLOT_RING2]={kind='empty'}}))
    assert(#f.a.requests==1)
    f:ApplyRequest(1);f.clock:Advance(1);assert(#f.a.requests==2 and not f.done[1])
    f:ApplyRequest(2);f.clock:Advance(1);assert(f.done[1].status=='success')
end
function tests.pending_replacements_reserve_temporary_bag_space()
    local f=setup();f.a.free=1
    f:Add('old1',BAG_WORN,EQUIP_SLOT_RING1);f:Add('old2',BAG_WORN,EQUIP_SLOT_RING2)
    local a=f:Add('a',BAG_BACKPACK,1);local b=f:Add('b',BAG_BACKPACK,2)
    f:Start(f:Plan({[EQUIP_SLOT_RING1]=a,[EQUIP_SLOT_RING2]=b}))
    assert(#f.a.requests==1)
    f:ApplyRequest(1);f.clock:Advance(1);assert(#f.a.requests==2)
    f:ApplyRequest(2);f.clock:Advance(1);assert(f.done[1].status=='success')
end
function tests.exception_inside_second_send_retains_both_possible_requests_and_stops_the_batch()
    local f=setup()
    local hat=f:Add('hat',BAG_BACKPACK,1,EQUIP_TYPE_HEAD)
    local a=f:Add('a',BAG_BACKPACK,2);local b=f:Add('b',BAG_BACKPACK,3)
    local request=f.a.RequestEquipItem
    f.a.RequestEquipItem=function(...)
        request(...)
        if #f.a.requests==2 then error('native call failed after dispatch') end
    end
    f:Start(f:Plan({[EQUIP_SLOT_HEAD]=hat,[EQUIP_SLOT_RING1]=a,[EQUIP_SLOT_RING2]=b}))
    local result=f.done[1]
    assert(result.status=='uncertain' and #result.pending.batch==2 and #f.a.requests==2)
    f:ApplyRequest(2);f.clock:Advance(6000)
    assert(not f.k.EquipmentRunner.IsPendingConfirmed(f.inv,result.pending,f.inv:Capture(false)))
    f:ApplyRequest(1)
    assert(f.k.EquipmentRunner.IsPendingConfirmed(f.inv,result.pending,f.inv:Capture(false)))
    assert(#f.a.requests==2 and not f.runner:IsBusy() and next(f.clock.timers)==nil)
end
return tests
