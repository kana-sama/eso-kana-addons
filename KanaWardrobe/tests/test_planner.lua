local Fake = dofile(ROOT .. "/tests/support/fake_eso.lua")
local function setup(free)
    local kw = Fake.Load()
    local f = io.open(ROOT .. "/EquipmentPlan.lua", "r")
    if f then f:close(); dofile(ROOT .. "/EquipmentPlan.lua") end
    local state={worn={},byUid={},freeSlots=free or 10,version=1}
    for _,slot in ipairs(kw.Slots.Order) do state.worn[slot]={kind="empty"} end
    return kw,state
end
local function add(s,uid,slot,equipType,options)
    local m={valid=true,availableToEquip=true,staticEquipable=true,equipType=equipType,twoHanded=equipType==EQUIP_TYPE_TWO_HAND,mythic=false}
    for k,v in pairs(options or {}) do m[k]=v end
    s.byUid[uid]={uid=uid,link="link:"..uid,bagId=slot and BAG_WORN or BAG_BACKPACK,slotIndex=slot or 100,metadata=m}
    if slot then s.worn[slot]={kind="item",uid=uid,link="link:"..uid} end
    return {kind="item",uid=uid,link="saved:"..uid}
end
local function build(kw,s,intent,caps,mode)
    assert(kw.EquipmentPlan,"EquipmentPlan module missing")
    local p,e=kw.EquipmentPlan.Build(s,intent,mode or "apply",caps or {})
    assert(p,e and e.code or "missing plan"); return p
end
-- Independent step replay checks source identity, conservative capacity and every
-- intermediate weapon/mythic invariant, rather than only checking step counts.
local function replay(kw,s,p,caps)
    local worn,bag,free={}, {},s.freeSlots
    for slot,v in pairs(s.worn) do if v.kind=="item" then worn[slot]=v.uid end end
    for uid,l in pairs(s.byUid) do if l.bagId==BAG_BACKPACK then bag[uid]=true end end
    for _,step in ipairs(p.steps) do
        if step.kind=="unequip" then
            assert(worn[step.equipSlot]==step.uid); assert(free>=1,"unequip overflow")
            bag[step.uid]=true; worn[step.equipSlot]=nil; free=free-1
        else
            local from
            for slot,id in pairs(worn)do if id==step.uid then from=slot end end
            local old=worn[step.equipSlot]
            if from then worn[from]=old
            else
                assert(bag[step.uid],"source item unavailable")
                if old then assert(free>=((caps and caps.fullBagEquipSwap)and 0 or 1),"unverified full bag swap");bag[old]=true else free=free+1 end
                bag[step.uid]=nil
            end
            worn[step.equipSlot]=step.uid
            if s.byUid[step.uid].metadata.twoHanded then
                for _,bar in ipairs({kw.Slots.Front,kw.Slots.Back})do if step.equipSlot==bar.main and worn[bar.off]then
                    assert(free>=1);bag[worn[bar.off]]=true;worn[bar.off]=nil;free=free-1
                end end
            end
        end
        local myths=0
        for _,uid in pairs(worn) do if s.byUid[uid].metadata.mythic then myths=myths+1 end end
        assert(myths<=1,"intermediate mythic conflict")
        for _,bar in ipairs({kw.Slots.Front,kw.Slots.Back}) do
            if worn[bar.main] and s.byUid[worn[bar.main]].metadata.twoHanded then assert(not worn[bar.off],"intermediate weapon conflict") end
        end
    end
    for slot,v in pairs(p.target) do assert(worn[slot]==(v.kind=="item" and v.uid or nil),"wrong final slot "..slot) end
end
local tests={}
function tests.independent_batches_allow_reordering_and_weapon_pairs_preserve_native_send_order()
    for _,free in ipairs({1,3,20}) do
        local k,s=setup(free)
        add(s,'myth-head',EQUIP_SLOT_HEAD,EQUIP_TYPE_HEAD,{mythic=true})
        add(s,'greatsword',EQUIP_SLOT_MAIN_HAND,EQUIP_TYPE_TWO_HAND)
        add(s,'back-sword',EQUIP_SLOT_BACKUP_MAIN,EQUIP_TYPE_ONE_HAND)
        add(s,'back-shield',EQUIP_SLOT_BACKUP_OFF,EQUIP_TYPE_OFF_HAND)
        local a=add(s,'a',EQUIP_SLOT_RING1,EQUIP_TYPE_RING)
        local b=add(s,'b',EQUIP_SLOT_RING2,EQUIP_TYPE_RING)
        local intent={
            [EQUIP_SLOT_HEAD]=add(s,'hat',nil,EQUIP_TYPE_HEAD),
            [EQUIP_SLOT_NECK]=add(s,'myth-neck',nil,EQUIP_TYPE_NECK,{mythic=true}),
            [EQUIP_SLOT_MAIN_HAND]=add(s,'sword',nil,EQUIP_TYPE_ONE_HAND),
            [EQUIP_SLOT_OFF_HAND]=add(s,'dagger',nil,EQUIP_TYPE_ONE_HAND),
            [EQUIP_SLOT_BACKUP_MAIN]=add(s,'staff',nil,EQUIP_TYPE_TWO_HAND),
            [EQUIP_SLOT_BACKUP_OFF]={kind='empty'},[EQUIP_SLOT_RING1]=b,[EQUIP_SLOT_RING2]=a,
        }
        local p=build(k,s,intent)
        replay(k,s,p)
        local groups={}
        for _,step in ipairs(p.steps) do
            assert(step.batchId,'every planned move must belong to a dependency stage')
            groups[step.batchId]=groups[step.batchId] or {}
            table.insert(groups[step.batchId],step)
        end
        for shift=0,#p.steps do
            local reordered=k.Copy(p);reordered.steps={}
            for _,group in ipairs(groups)do
                local ordered=false;for _,step in ipairs(group)do if step.orderedAfter then ordered=true end end
                for i=1,#group do
                    table.insert(reordered.steps,group[ordered and i or ((#group-i+shift)%#group+1)])
                end
            end
            replay(k,s,reordered)
        end
    end
end
function tests.partial_armor_keeps_unspecified_and_copies_input()
    local k,s=setup(); add(s,"old",EQUIP_SLOT_HEAD,EQUIP_TYPE_HEAD); add(s,"ring",EQUIP_SLOT_RING1,EQUIP_TYPE_RING)
    local item=add(s,"new",nil,EQUIP_TYPE_HEAD); local intent={[EQUIP_SLOT_HEAD]=item}; local p=build(k,s,intent)
    assert(p.target[EQUIP_SLOT_RING1].uid=="ring" and #p.extras==0); replay(k,s,p)
    p.intent[EQUIP_SLOT_HEAD].uid="mutated"; assert(intent[EQUIP_SLOT_HEAD].uid=="new")
end
function tests.explicit_empty_and_matching_noop()
    local k,s=setup(); local v=add(s,"head",EQUIP_SLOT_HEAD,EQUIP_TYPE_HEAD)
    assert(#build(k,s,{[EQUIP_SLOT_HEAD]=v}).steps==0)
    local p=build(k,s,{[EQUIP_SLOT_HEAD]={kind="empty"}}); assert(#p.steps==1); replay(k,s,p)
end
function tests.missing_uid_duplicate_uid_and_bank_are_rejected()
    local k,s=setup(); local v=add(s,"ring",nil,EQUIP_TYPE_RING)
    assert(k.EquipmentPlan,"EquipmentPlan module missing")
    for _,intent in ipairs({{[EQUIP_SLOT_RING1]={kind="item",uid="absent"}},{[EQUIP_SLOT_RING1]=v,[EQUIP_SLOT_RING2]=v}}) do assert(k.EquipmentPlan.Build(s,intent,"apply",{})==nil) end
    s.byUid.ring.bagId=BAG_BANK; assert(k.EquipmentPlan.Build(s,{[EQUIP_SLOT_RING1]=v},"apply",{})==nil)
end
function tests.two_handed_requires_precise_extra()
    local k,s=setup(); add(s,"shield-1",EQUIP_SLOT_OFF_HAND,EQUIP_TYPE_OFF_HAND)
    local v=add(s,"staff",nil,EQUIP_TYPE_TWO_HAND); local p=build(k,s,{[EQUIP_SLOT_MAIN_HAND]=v})
    assert(#p.extras==1); assert(p.extras[1].uid=="shield-1"); assert(p.extras[1].reason=="twoHanded")
    assert(p.extras[1].fromSlot==EQUIP_SLOT_OFF_HAND and p.extras[1].toSlot==nil)
    assert(p.intent[EQUIP_SLOT_OFF_HAND]==nil and p.target[EQUIP_SLOT_OFF_HAND].kind=="empty"); replay(k,s,p)
end
function tests.explicit_incompatible_weapon_pair_is_rejected()
    local k,s=setup(); local a=add(s,"staff",nil,EQUIP_TYPE_TWO_HAND); local b=add(s,"shield",nil,EQUIP_TYPE_OFF_HAND)
    assert(k.EquipmentPlan,"EquipmentPlan module missing"); assert(k.EquipmentPlan.Build(s,{[EQUIP_SLOT_MAIN_HAND]=a,[EQUIP_SLOT_OFF_HAND]=b},"apply",{})==nil)
end
function tests.source_move_extras_are_precise()
    local k,s=setup(); local a=add(s,"ring",EQUIP_SLOT_RING1,EQUIP_TYPE_RING)
    local p=build(k,s,{[EQUIP_SLOT_RING2]=a}); assert(#p.extras==1 and p.extras[1].reason=="sourceMove")
    assert(p.extras[1].fromSlot==EQUIP_SLOT_RING1 and p.extras[1].toSlot==EQUIP_SLOT_RING2 and p.target[EQUIP_SLOT_RING1].kind=="empty"); replay(k,s,p)
end
function tests.mythic_extra_removed_before_new_and_two_explicit_rejected()
    local k,s=setup(); local a=add(s,"myth-head",EQUIP_SLOT_HEAD,EQUIP_TYPE_HEAD,{mythic=true})
    local b=add(s,"myth-ring",nil,EQUIP_TYPE_RING,{mythic=true,availableToEquip=false})
    local p=build(k,s,{[EQUIP_SLOT_RING1]=b}); assert(p.extras[1].uid=="myth-head" and p.extras[1].reason=="mythic")
    assert(p.steps[1].kind=="unequip" and p.steps[1].uid=="myth-head"); replay(k,s,p)
    assert(k.EquipmentPlan.Build(s,{[EQUIP_SLOT_HEAD]=a,[EQUIP_SLOT_RING1]=b},"apply",{})==nil)
end
function tests.ring_exchange_uses_one_direct_request_without_backpack_capacity()
    local k,s=setup(2); local a=add(s,"a",EQUIP_SLOT_RING1,EQUIP_TYPE_RING); local b=add(s,"b",EQUIP_SLOT_RING2,EQUIP_TYPE_RING)
    local intent={[EQUIP_SLOT_RING1]=b,[EQUIP_SLOT_RING2]=a}; local p=build(k,s,intent); assert(p.requiredFree==0 and #p.steps==1); replay(k,s,p)
    s.freeSlots=0; local q=build(k,s,intent,{fullBagEquipSwap=true}); assert(q.requiredFree==0 and #q.steps==1); replay(k,s,q,{fullBagEquipSwap=true})
end
function tests.cross_bar_four_weapon_cycle_both_directions()
    for _,reverse in ipairs({false,true}) do
        local k,s=setup(2); local slots={EQUIP_SLOT_MAIN_HAND,EQUIP_SLOT_OFF_HAND,EQUIP_SLOT_BACKUP_MAIN,EQUIP_SLOT_BACKUP_OFF}; local values={}; local intent={}
        for i,slot in ipairs(slots) do values[i]=add(s,"weapon"..i,slot,EQUIP_TYPE_ONE_HAND) end
        for i,slot in ipairs(slots) do intent[slot]=values[((i+(reverse and 2 or 0))%4)+1] end
        local p=build(k,s,intent); assert(#p.extras==0); replay(k,s,p)
    end
end
function tests.full_bag_requires_reported_additional_space()
    local k,s=setup(0); add(s,"old",EQUIP_SLOT_HEAD,EQUIP_TYPE_HEAD); local v=add(s,"new",nil,EQUIP_TYPE_HEAD)
    assert(k.EquipmentPlan,"EquipmentPlan module missing"); local p,e=k.EquipmentPlan.Build(s,{[EQUIP_SLOT_HEAD]=v},"apply",{})
    assert(not p and e.code=="insufficientSpace" and e.details.additionalSlots==1)
    replay(k,s,build(k,s,{[EQUIP_SLOT_HEAD]=v},{fullBagEquipSwap=true}),{fullBagEquipSwap=true})
end
function tests.mythic_removal_needs_space_but_empty_equip_can_free_it()
    local k,s=setup(0); add(s,"myth-old",EQUIP_SLOT_HEAD,EQUIP_TYPE_HEAD,{mythic=true}); local v=add(s,"myth-new",nil,EQUIP_TYPE_RING,{mythic=true})
    assert(k.EquipmentPlan,"EquipmentPlan module missing"); local p,e=k.EquipmentPlan.Build(s,{[EQUIP_SLOT_RING1]=v},"apply",{})
    assert(not p and e.details.additionalSlots==1)
    local boots=add(s,"boots",nil,EQUIP_TYPE_FEET); p=build(k,s,{[EQUIP_SLOT_RING1]=v,[EQUIP_SLOT_FEET]=boots})
    assert(p.requiredFree==0 and p.steps[1].uid=="boots"); replay(k,s,p)
end
function tests.revalidation_changes_consent_for_uid_not_backpack_position()
    local k,s=setup(); add(s,"shield-1",EQUIP_SLOT_OFF_HAND,EQUIP_TYPE_OFF_HAND); local staff=add(s,"staff",nil,EQUIP_TYPE_TWO_HAND)
    local p=build(k,s,{[EQUIP_SLOT_MAIN_HAND]=staff}); s.byUid.staff.slotIndex=222
    local q=assert(k.EquipmentPlan.Revalidate(p,s,{})); assert(q.extraKey==p.extraKey)
    s.byUid["shield-1"]=nil; add(s,"shield-2",EQUIP_SLOT_OFF_HAND,EQUIP_TYPE_OFF_HAND)
    q=assert(k.EquipmentPlan.Revalidate(p,s,{})); assert(q.extraKey~=p.extraKey)
end
function tests.type_static_eligibility_and_restore_snapshot_validation()
    local k,s=setup(); local ring=add(s,"ring",nil,EQUIP_TYPE_RING)
    assert(k.EquipmentPlan,"EquipmentPlan module missing"); assert(k.EquipmentPlan.Build(s,{[EQUIP_SLOT_HEAD]=ring},"apply",{})==nil)
    s.byUid.ring.metadata.staticEquipable=false; assert(k.EquipmentPlan.Build(s,{[EQUIP_SLOT_RING1]=ring},"apply",{})==nil)
    assert(k.EquipmentPlan.Build(s,{},"restore",{})==nil)
    assert(#build(k,s,s.worn,nil,"restore").steps==0)
end
function tests.known_binding_confirmation_is_rejected_before_any_steps()
    local k,s=setup(); add(s,"old",EQUIP_SLOT_HEAD,EQUIP_TYPE_HEAD)
    local item=add(s,"bind",nil,EQUIP_TYPE_RING,{bindingRequired=true})
    local p,e=k.EquipmentPlan.Build(s,{[EQUIP_SLOT_HEAD]={kind="empty"},[EQUIP_SLOT_RING1]=item},"apply",{})
    assert(not p and e.code=="bindingConfirmationRequired")
end
function tests.static_backup_lock_rejected_but_transient_lock_not_used()
    local k,s=setup(); local sword=add(s,"sword",nil,EQUIP_TYPE_ONE_HAND,{equipableNow=false})
    local intent={[EQUIP_SLOT_BACKUP_MAIN]=sword}
    s.slotAvailability={[EQUIP_SLOT_BACKUP_MAIN]={available=false,reason="weaponBarLocked"}}
    local p,e=k.EquipmentPlan.Build(s,intent,"apply",{})
    assert(not p and e.code=="weaponBarLocked")
    s.slotAvailability[EQUIP_SLOT_BACKUP_MAIN].available=true
    replay(k,s,build(k,s,intent))
end
function tests.unique_equipped_same_base_id_conflict_and_precise_extra()
    local k,s=setup(); local a=add(s,"unique-a",EQUIP_SLOT_RING1,EQUIP_TYPE_RING,{uniqueEquipped=true,itemId=123})
    local b=add(s,"unique-b",nil,EQUIP_TYPE_RING,{uniqueEquipped=true,itemId=123})
    local p,e=k.EquipmentPlan.Build(s,{[EQUIP_SLOT_RING1]=a,[EQUIP_SLOT_RING2]=b},"apply",{})
    assert(not p and e.code=="uniqueEquippedConflict")
    p=build(k,s,{[EQUIP_SLOT_RING2]=b}); assert(#p.extras==1 and p.extras[1].uid=="unique-a" and p.extras[1].reason=="uniqueEquipped")
    assert(p.steps[1].kind=="unequip" and p.steps[1].uid=="unique-a"); replay(k,s,p)
    s.byUid["unique-b"].metadata.itemId=124
    p=build(k,s,{[EQUIP_SLOT_RING2]=b}); assert(#p.extras==0)
end
function tests.unique_equipped_replacement_removes_blocker_first()
    local k,s=setup(); add(s,"unique-a",EQUIP_SLOT_RING1,EQUIP_TYPE_RING,{uniqueEquipped=true,itemId=123})
    local b=add(s,"unique-b",nil,EQUIP_TYPE_RING,{uniqueEquipped=true,itemId=123})
    local p=build(k,s,{[EQUIP_SLOT_RING1]=b}); assert(p.steps[1].kind=="unequip" and p.steps[1].uid=="unique-a"); replay(k,s,p)
end
function tests.implicit_source_move_obeys_static_slot_restriction()
    local k,s=setup(); local sword=add(s,"locked-source",EQUIP_SLOT_BACKUP_MAIN,EQUIP_TYPE_ONE_HAND)
    local intent={[EQUIP_SLOT_MAIN_HAND]=sword}; local original=build(k,s,intent)
    s.slotAvailability={[EQUIP_SLOT_BACKUP_MAIN]={available=false,reason="weaponBarLocked"}}
    local p,e=k.EquipmentPlan.Build(s,intent,"apply",{})
    assert(not p and e.code=="weaponBarLocked" and e.details.slot==EQUIP_SLOT_BACKUP_MAIN)
    p,e=k.EquipmentPlan.Revalidate(original,s,{})
    assert(not p and e.code=="weaponBarLocked" and e.details.slot==EQUIP_SLOT_BACKUP_MAIN)
end
function tests.implicit_conflict_removal_obeys_static_slot_restriction()
    local k,s=setup(); add(s,"locked-shield",EQUIP_SLOT_BACKUP_OFF,EQUIP_TYPE_OFF_HAND)
    local staff=add(s,"staff",nil,EQUIP_TYPE_TWO_HAND)
    s.slotAvailability={[EQUIP_SLOT_BACKUP_OFF]={available=false,reason="weaponBarLocked"}}
    local p,e=k.EquipmentPlan.Build(s,{[EQUIP_SLOT_BACKUP_MAIN]=staff},"apply",{})
    assert(not p and e.code=="weaponBarLocked" and e.details.slot==EQUIP_SLOT_BACKUP_OFF)
end
function tests.unchanged_locked_slot_does_not_require_new_equip_eligibility()
    local k,s=setup(); local sword=add(s,"locked-source",EQUIP_SLOT_BACKUP_MAIN,EQUIP_TYPE_ONE_HAND,{staticEquipable=false,equipableNow=false})
    s.slotAvailability={[EQUIP_SLOT_BACKUP_MAIN]={available=false,reason="weaponBarLocked"}}
    assert(#build(k,s,{}).steps==0)
    assert(#build(k,s,{[EQUIP_SLOT_BACKUP_MAIN]=sword}).steps==0)
    local hat=add(s,"hat",nil,EQUIP_TYPE_HEAD); local p=build(k,s,{[EQUIP_SLOT_HEAD]=hat})
    assert(p.target[EQUIP_SLOT_BACKUP_MAIN].uid=="locked-source"); replay(k,s,p)
end
function tests.retained_ignored_slots_require_valid_compatible_metadata()
    local k,s=setup(); add(s,"bad-head",EQUIP_SLOT_HEAD,EQUIP_TYPE_RING)
    local p,e=k.EquipmentPlan.Build(s,{},"apply",{})
    assert(not p and e.code=="incompatibleSlot" and e.details.slot==EQUIP_SLOT_HEAD)
    s.byUid["bad-head"].metadata.equipType=EQUIP_TYPE_HEAD
    s.byUid["bad-head"].metadata.valid=nil
    p,e=k.EquipmentPlan.Build(s,{},"apply",{})
    assert(not p and e.code=="invalidItem" and e.details.slot==EQUIP_SLOT_HEAD)
end
return tests
