local Fake=dofile(ROOT.."/tests/support/fake_eso.lua")
local function setup()
    local KW=Fake.Load(); local api=Fake.New(); local events=KW.Core.NewEvents()
    local function emit(n,p) events:Emit(n,p) end
    local saved={}; local repo=KW.Presets.New(saved,"EU","acct","one","One",emit)
    local inventory=KW.Inventory.New(api,emit)
    api.lockRequests={}
    function api.CanItemBePlayerLocked(b,s) local i=api.bags[b][s]; return i and not i.unLockable end
    function api.IsItemPlayerLocked(b,s) local i=api.bags[b][s]; return i and i.locked==true end
    function api.SetItemIsPlayerLocked(b,s,value)
        api.lockRequests[#api.lockRequests+1]={b,s,value}
        if not api.ignoreLock then api.bags[b][s].locked=value end
        if api.onLock then api.onLock(b,s,value) end
    end
    local file=io.open(ROOT.."/Protection.lua","r")
    if file then file:close(); dofile(ROOT.."/Protection.lua") end
    assert(KW.Protection,"Protection implementation missing")
    local protection=KW.Protection.New(repo,inventory)
    api.bags[BAG_BACKPACK][0]={uid="ring-1",link="ring"}
    return KW,api,repo,inventory,protection,events,saved
end
local function slot(uid) return {[EQUIP_SLOT_RING1]={kind="item",uid=uid or "ring-1",link="ring"}} end
local function save(repo,name,uid)
    local p=repo:NewDraft(); p.name=name; p.slots=slot(uid); return assert(repo:Save(p,0))
end
return {
    protection_refresh_does_not_rescan_or_describe_bags_per_saved_item=function()
        local _,api,repo,inventory,p=setup()
        for n=1,180 do api.bags[BAG_BACKPACK][n]={uid="item"..n,link="ring",locked=true}end
        for n=1,14 do save(repo,"Preset"..n,"item"..n)end
        local scans,metadata=0,0
        local capture=inventory.Capture;inventory.Capture=function(self,...)scans=scans+1;return capture(self,...)end
        local describe=inventory.Metadata;inventory.Metadata=function(self,...)metadata=metadata+1;return describe(self,...)end
        assert(p:RefreshAccessible())
        assert(scans<=1,"protection repeatedly scanned entire bags: "..scans)
        assert(metadata==0,"lock checks must not generate set descriptions: "..metadata)
    end,
    ensure_verifies_lock_before_commit=function()
        local _,api,repo,_,p=setup(); api.ignoreLock=true
        local ok,problem=p:Ensure(slot()); assert(not ok and problem.code=="lockFailed")
        assert(#repo:List()==0)
        api.ignoreLock=false; assert(p:Ensure(slot())); assert(api.bags[1][0].locked)
    end,
    cannot_lock_or_missing_fails_before_commit=function()
        local _,api,repo,_,p=setup(); api.bags[1][0].unLockable=true
        local ok,problem=p:Ensure(slot()); assert(not ok and problem.code=="cannotLock")
        ok,problem=p:Ensure(slot("missing")); assert(not ok and problem.code=="itemMissing")
        assert(#repo:List()==0 and #api.lockRequests==0)
    end,
    last_reference_keeps_lock=function()
        local _,api,repo,inventory,p,events=setup(); p:Attach(events)
        local a=save(repo,"A"); local b=save(repo,"B")
        assert(#p:Explain("ring-1")==2 and inventory:IsLocked(inventory:Resolve("ring-1",false)))
        assert(repo:Delete(a.id,a.revision)); assert(#p:Explain("ring-1")==1)
        assert(repo:Delete(b.id,b.revision)); assert(#repo:Memberships("ring-1","all")==0)
        assert(inventory:IsLocked(inventory:Resolve("ring-1",false)))
        for _,r in ipairs(api.lockRequests) do assert(r[3]==true) end
        assert(#api.lockRequests==1)
    end,
    manual_locks_are_preserved=function()
        local _,api,repo,_,p=setup(); api.bags[1][0].locked=true
        assert(p:Ensure(slot())); local a=save(repo,"A"); repo:Delete(a.id,a.revision); p:RefreshAccessible()
        assert(api.bags[1][0].locked and #api.lockRequests==0)
    end,
    another_character_and_newly_accessible_bank_are_protected=function()
        local KW,api,repo,_,p,events,saved=setup(); p:Attach(events)
        local other=KW.Presets.New(saved,"EU","acct","two","Two")
        save(other,"Other"); api.bags[BAG_BANK][4]=api.bags[1][0]; api.bags[1][0]=nil
        assert(p:RefreshAccessible()); assert(not api.bags[BAG_BANK][4].locked)
        api.bankOpen=true; events:Emit("InventoryChanged")
        assert(api.bags[BAG_BANK][4].locked and p:Explain("ring-1")[1].characterName=="Two")
    end,
    external_unlock_gets_bounded_recovery_even_with_reentrant_events=function()
        local _,api,repo,_,p,events=setup(); local problems={}
        p:Attach(events,function(problem) problems[#problems+1]=problem end)
        api.onLock=function() events:Emit("InventoryChanged") end
        save(repo,"A"); assert(#api.lockRequests==1)
        api.bags[1][0].locked=false; events:Emit("InventoryChanged"); assert(#api.lockRequests==2)
        api.bags[1][0].locked=false
        for _=1,8 do events:Emit("InventoryChanged") end
        assert(#api.lockRequests==2 and #problems==1 and problems[1].code=="lockConflict")
        local ok,problem=p:Ensure(slot()); assert(not ok and problem.code=="lockConflict")
    end,
    stale_inventory_location_never_locks_replacement=function()
        local _,api,_,inventory=setup(); local old=inventory:Resolve("ring-1",false)
        api.bags[1][0]={uid="other",link="ring"}
        assert(not inventory:CanLock(old)); assert(not inventory:IsLocked(old)); assert(not inventory:SetLocked(old,true))
        assert(#api.lockRequests==0)
    end,
    duplicate_uid_is_locked_once=function()
        local _,api,_,_,p=setup(); local slots=slot(); slots[EQUIP_SLOT_RING2]=slots[EQUIP_SLOT_RING1]
        assert(p:Ensure(slots)); assert(#api.lockRequests==1)
    end,
}
