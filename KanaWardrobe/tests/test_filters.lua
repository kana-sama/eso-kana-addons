local Fake=dofile(ROOT.."/tests/support/fake_eso.lua")
local contexts={"backpack","bankWithdraw","bankDeposit","guildBankWithdraw","guildBankDeposit","houseBankWithdraw","houseBankDeposit","vendorSell","vendorRepair","fenceSell","fenceLaunder","guildStoreSell"}
local layouts={backpack="MENU_BAR",bankDeposit="BANK",guildBankDeposit="GUILD_BANK",houseBankDeposit="HOUSE_BANK",vendorSell="STORE",fenceSell="FENCE",fenceLaunder="LAUNDER",guildStoreSell="TRADING_HOUSE"}
local lfNames={"INVENTORY","BANK_WITHDRAW","BANK_DEPOSIT","GUILDBANK_WITHDRAW","GUILDBANK_DEPOSIT","HOUSE_BANK_WITHDRAW","HOUSE_BANK_DEPOSIT","VENDOR_SELL","VENDOR_REPAIR","FENCE_SELL","FENCE_LAUNDER","GUILDSTORE_SELL"}
local function setup(withLib)
    local KW=Fake.Load(); dofile(ROOT.."/InventoryFilters.lua")
    local api=Fake.New(); local repo=KW.Presets.New({},"EU","acct","one","One")
    local draft=repo:NewDraft(); draft.slots={[EQUIP_SLOT_RING1]={kind="item",uid="saved",link="ring"}}; assert(repo:Save(draft,0))
    local other=KW.Presets.New({servers={EU={accounts={acct={characters=repo.characters}}}}},"EU","acct","two","Two")
    draft=other:NewDraft(); draft.slots={[EQUIP_SLOT_RING1]={kind="item",uid="otherchar",link="ring"}}; assert(other:Save(draft,0))
    local session={view={isEditor=false,state="idle"}}; function session:GetView() return self.view end
    local queue={}; api.zo_callLater=function(fn) queue[#queue+1]=fn end
    function api.flush() local pending=queue; queue={}; for _,fn in ipairs(pending) do fn() end end
    for _,name in ipairs({"BACKPACK","BANK","GUILD_BANK","HOUSE_BANK"}) do api["INVENTORY_"..name]=name end
    for _,name in pairs(layouts) do api["BACKPACK_"..name.."_LAYOUT_FRAGMENT"]={layoutData={}} end
    api.BACKPACK_DEFAULT_LAYOUT_FRAGMENT={layoutData={}}
    local manager={inventories={},updates=0}
    api.PLAYER_INVENTORY=manager
    for _,name in ipairs({"BACKPACK","BANK","GUILD_BANK","HOUSE_BANK"}) do
        manager.inventories[name]={backingBags={BAG_BACKPACK},slots={[BAG_BACKPACK]={}},listView={IsHidden=function() return false end}}
    end
    function manager:ShouldAddEntries() return not self.denied end
    function manager:ShouldAddSlotToList(inv,row)
        if not row or row.stackCount<=0 or row.searchFail or row.categoryFail or row.stolenFail or row.lockFail then return false end
        if inv.additionalFilter and not inv.additionalFilter(row) then return false end
        if self.appliedLayout and self.appliedLayout.additionalFilter and not self.appliedLayout.additionalFilter(row) then return false end
        return not row.thirdPartyFail
    end
    function manager:UpdateList(kind)
        self.updates=self.updates+1; local inv=self.inventories[kind]
        -- Native UpdateList skips uninitialized/closed house-bank storage.
        if not inv.slots then return end
        inv.visible={}
        if self:ShouldAddEntries(kind) then
            for _,bag in ipairs(inv.backingBags) do for _,row in pairs(inv.slots[bag]) do
                if self:ShouldAddSlotToList(inv,row) then inv.visible[#inv.visible+1]=row end
            end end
        end
    end
    function manager:RefreshInventorySlot(kind) self:UpdateList(kind) end
    local repair={control={IsControlHidden=function() return false end},list={},commits=0}
    api.REPAIR_WINDOW=repair
    api.ZO_ScrollList_GetDataList=function(list) return list end
    api.ZO_ScrollList_Commit=function() repair.commits=repair.commits+1 end
    function repair:ApplySort() api.ZO_ScrollList_Commit(self.list) end
    api.GetItemCondition=function(b,s) return api.bags[b][s].condition or 10 end
    api.IsItemStolen=function(b,s) return api.bags[b][s].stolen or false end
    api.GetItemInfo=function(b,s) return "icon",1,nil,nil,nil,nil,nil,2,2 end
    api.GetItemRepairCost=function(b,s) return api.bags[b][s].repairCost or 1 end
    api.GetItemName=function() return "ring" end
    api.zo_strformat=function(_,v) return v end
    api.TEXT_SEARCH_MANAGER={IsDataInSearchTextResults=function(_,_,_,b,s) return not api.bags[b][s].searchFail end}
    function repair:UpdateList()
        for i=#self.list,1,-1 do self.list[i]=nil end
        for _,bag in ipairs({BAG_WORN,BAG_BACKPACK}) do for slot,item in pairs(api.bags[bag]) do
            if not item.searchFail and not item.stolen and (item.condition or 10)<100 and (item.repairCost or 1)>0 then
                local row={bagId=bag,slotIndex=slot,name="ring",condition=item.condition or 10,repairCost=item.repairCost or 1}
                if not self.additionalFilter or self.additionalFilter(row) then self.list[#self.list+1]={data=row} end
            end
        end end
        self:ApplySort()
    end
    local lib
    if withLib then
        lib={callbacks={},requests={}}; api.LibFilters3=lib
        for i,name in ipairs(lfNames) do api["LF_"..name]=i end
        function lib:GetFilterTypeFunctionType(kind) return kind==3 and 2 or 1 end
        function lib:RegisterFilter(tag,kind,fn) assert(not self.callbacks[kind]); self.callbacks[kind]=fn; return true end
        function lib:RequestUpdate(kind) self.requests[kind]=(self.requests[kind] or 0)+1 end
        function lib:run(kind,row)
            local own=self.callbacks[kind]
            local function call() if self:GetFilterTypeFunctionType(kind)==2 then return own(row.bagId,row.slotIndex) end; return own(row) end
            if self.reverse then return not row.libFail and call() end
            return call() and not row.libFail
        end
        for context,suffix in pairs(layouts) do
            local index; for i,c in ipairs(contexts) do if c==context then index=i end end
            api["BACKPACK_"..suffix.."_LAYOUT_FRAGMENT"].layoutData.additionalFilter=function(row) return lib:run(index,row) end
        end
        for name,index in pairs({BANK=2,GUILD_BANK=4,HOUSE_BANK=6}) do manager.inventories[name].additionalFilter=function(row) return lib:run(index,row) end end
        repair.additionalFilter=function(row) return lib:run(9,row) and row.slotIndex~=99 end
    end
    local filters=KW.InventoryFilters.New(repo,KW.Inventory.New(api),session,repo.character)
    return KW,api,repo,session,filters,manager,repair,lib
end
local function row(api,m,slot,uid,flags,kind)
    local r={bagId=BAG_BACKPACK,slotIndex=slot,stackCount=1}
    for k,v in pairs(flags or {}) do r[k]=v end
    api.bags[BAG_BACKPACK][slot]={uid=uid,link="ring"}
    m.inventories[kind or "BACKPACK"].slots[BAG_BACKPACK][slot]=r
    return r
end
local function selectContext(api,m,context)
    if layouts[context] then m.appliedLayout=api["BACKPACK_"..layouts[context].."_LAYOUT_FRAGMENT"].layoutData; return "BACKPACK" end
    m.appliedLayout=nil
    return ({bankWithdraw="BANK",guildBankWithdraw="GUILD_BANK",houseBankWithdraw="HOUSE_BANK"})[context]
end
local function capacityFixture(api,m)
    local inv=m.inventories.BACKPACK
    inv.freeSlotType="BACKPACK"
    inv.freeSlotsStringId="Capacity: %d/%d"
    inv.freeSlotsFullStringId="|cFF0000Capacity: %d/%d|r"
    inv.freeSlotsLabel={text=""}
    function inv.freeSlotsLabel:SetText(value)self.text=value end
    api.zo_strformat=function(format,...)return string.format(format,...)end
    m.used=95;m.capacity=168
    function m:GetNumSlots(kind)assert(kind=="BACKPACK");return self.used,self.capacity end
    function m:UpdateFreeSlots(kind)
        if kind=="BACKPACK" then
            inv.freeSlotsLabel:SetText(string.format(self.used<self.capacity and inv.freeSlotsStringId or inv.freeSlotsFullStringId,self.used,self.capacity))
        end
        return "native-result"
    end
    m:UpdateFreeSlots("BACKPACK")
    return inv.freeSlotsLabel
end
return {
    capacity_subtracts_own_hidden_count_and_restores_during_edit_or_when_disabled=function()
        for _,withLib in ipairs({false,true})do
            local _,api,_,session,f,m=setup(withLib)
            local label=capacityFixture(api,m);selectContext(api,m,"backpack")
            row(api,m,0,"saved");row(api,m,1,"ordinary")
            f:Attach(api);f:SetEnabled(true);m:UpdateList("BACKPACK")
            assert(label.text=="Capacity: 94/167 (hidden: 1)",label.text)
            for i=1,3 do assert(m:UpdateFreeSlots("BACKPACK")=="native-result");assert(label.text=="Capacity: 94/167 (hidden: 1)")end
            m.capacity=178;m:UpdateFreeSlots("BACKPACK");assert(label.text=="Capacity: 94/177 (hidden: 1)")
            session.view.isEditor=true;m:UpdateList("BACKPACK");assert(label.text=="Capacity: 95/178")
            session.view.isEditor=false;m:UpdateList("BACKPACK");assert(label.text=="Capacity: 94/177 (hidden: 1)")
            f:SetEnabled(false);api.flush();assert(label.text=="Capacity: 95/178")
        end
    end,
    capacity_preserves_full_color_and_tracks_search_without_changing_real_bag_counts=function()
        local _,api,_,_,f,m=setup()
        local label=capacityFixture(api,m);selectContext(api,m,"backpack")
        local candidate=row(api,m,0,"saved")
        f:Attach(api);f:SetEnabled(true);m.used=168;m:UpdateList("BACKPACK")
        assert(label.text=="|cFF0000Capacity: 167/167|r (hidden: 1)")
        local used,total=m:GetNumSlots("BACKPACK");assert(used==168 and total==168)
        candidate.searchFail=true;m:UpdateList("BACKPACK");assert(label.text=="|cFF0000Capacity: 168/168|r")
        candidate.searchFail=false;m:UpdateList("BACKPACK");assert(label.text:find("167/167",1,true))
        m.inventories.BACKPACK.slots[BAG_BACKPACK][0]=nil;m.used=167;m:UpdateList("BACKPACK")
        assert(label.text=="Capacity: 167/168")
    end,
    fallback_filter_preserves_existing_predicates_across_bank_direction_changes=function()
        local _,api,_,session,f,m=setup()
        local deposit=api.BACKPACK_BANK_LAYOUT_FRAGMENT.layoutData
        local withdraw=m.inventories.BANK
        local oldCalls=0
        local function previous(r)oldCalls=oldCalls+1;return not r.excludedBeforeWardrobe end
        deposit.additionalFilter=previous;withdraw.additionalFilter=previous
        f:Attach(api);f:SetEnabled(true)
        for _,context in ipairs({"bankDeposit","bankWithdraw","bankDeposit","bankWithdraw"})do
            local kind=selectContext(api,m,context)
            m.inventories[kind].slots[1]={}
            row(api,m,0,"saved",nil,kind)
            row(api,m,1,"ordinary",nil,kind)
            row(api,m,2,"foreign-hidden",{excludedBeforeWardrobe=true},kind)
            m:UpdateList(kind)
            assert(#m.inventories[kind].visible==1 and m.inventories[kind].visible[1].slotIndex==1)
            assert(f:HiddenCount(context)==1)
            session.view.isEditor=true;m:UpdateList(kind)
            assert(#m.inventories[kind].visible==2 and f:HiddenCount(context)==0)
            session.view.isEditor=false
        end
        assert(oldCalls>0)
    end,
    native_bank_list_and_repair_methods_are_not_manually_replaced=function()
        for _,withLib in ipairs({false,true})do
            local _,api,_,_,f,m,repair=setup(withLib)
            local predicate,update,refresh=m.ShouldAddSlotToList,m.UpdateList,m.RefreshInventorySlot
            local sort,repairUpdate=repair.ApplySort,repair.UpdateList
            f:Attach(api)
            assert(m.ShouldAddSlotToList==predicate,"do not replace native row predicate: use additionalFilter")
            assert(m.RefreshInventorySlot==refresh and repair.ApplySort==sort,"native refresh and sort must remain intact")
            local observed={}
            for _,hook in ipairs(api.securePostHooks)do
                if hook.object==m and hook.name=="UpdateList" then
                    assert(hook.original==update and m.UpdateList==hook.wrapper);observed.inventory=true
                elseif hook.object==repair and hook.name=="UpdateList" then
                    assert(hook.original==repairUpdate and repair.UpdateList==hook.wrapper);observed.repair=true
                end
            end
            assert(observed.inventory and observed.repair,"observe native list updates through SecurePostHook only")
        end
    end,
    equipment_events_do_not_rebuild_all_inventory_contexts=function()
        for _,withLib in ipairs({false,true})do
            local KW,api,_,session,f,m,_,lib=setup(withLib)
            local events=KW.Core.NewEvents();selectContext(api,m,"backpack")
            f:Attach(api,events);api.flush()
            local updates=m.updates
            local function requests()local n=0;for _,v in pairs(lib and lib.requests or {})do n=n+v end;return n end
            local before=requests()
            for _=1,40 do events:Emit("InventoryChanged");events:Emit("SessionChanged")end
            api.flush()
            assert(m.updates==updates and requests()==before,"ordinary equipment events rebuilt every context")
            session.view.isEditor=true;events:Emit("SessionChanged");api.flush()
            assert(m.updates>updates or requests()>before,"entering editor must refresh filter bypass")
        end
    end,
    house_bank_uninitialized_close_and_reopen_recounts_safely=function()
        for _,withLib in ipairs({false,true}) do
            local _,api,_,_,f,m=setup(withLib)
            local inv=m.inventories.HOUSE_BANK
            -- ESO creates storage on SCENE_SHOWING and removes it on SCENE_HIDDEN.
            -- Keep the list control visible to exercise refresh during transitions.
            inv.backingBags=nil; inv.slots=nil
            f:Attach(api); api.flush(); m:UpdateList("HOUSE_BANK")
            assert(f:HiddenCount("houseBankWithdraw")==0)
            f:SetEnabled(true); api.flush(); m:UpdateList("HOUSE_BANK")
            local function open(bag)
                inv.backingBags={bag}; inv.slots={[bag]={}}
                api.bags[bag][0]={uid="saved",link="ring"}
                api.bags[bag][1]={uid="ordinary",link="ring"}
                for slot=0,1 do inv.slots[bag][slot]={bagId=bag,slotIndex=slot,stackCount=1} end
                m:UpdateList("HOUSE_BANK")
                assert(#inv.visible==1 and inv.visible[1].slotIndex==1)
                assert(f:HiddenCount("houseBankWithdraw")==1)
            end
            open(BAG_BACKPACK)
            inv.backingBags=nil; inv.slots=nil
            f:Refresh(); api.flush(); m:UpdateList("HOUSE_BANK")
            assert(f:HiddenCount("houseBankWithdraw")==0,"closed bank must clear its old count")
            open(BAG_BANK)
            f:SetEnabled(false); api.flush(); m:UpdateList("HOUSE_BANK")
            assert(#inv.visible==2 and f:HiddenCount("houseBankWithdraw")==0)
        end
    end,
    exact_current_character_uid_and_context_matrix=function()
        local _,api,_,_,f,m=setup(); f:SetEnabled(true)
        row(api,m,0,"saved"); row(api,m,1,"same-link"); row(api,m,2,"otherchar")
        for _,context in ipairs(contexts) do
            assert(not f:ShouldShow(context,1,0),context); assert(f:ShouldShow(context,1,1)); assert(f:ShouldShow(context,1,2))
        end
        for _,context in ipairs({"buy","buyback","guildStoreBrowse","mail","crafting"}) do assert(f:ShouldShow(context,1,0)) end
        assert(f:ShouldShow("backpack",nil,nil)); assert(f:ShouldShow("backpack",1,9))
    end,
    bank_filter_bypasses_during_edit=function()
        local _,api,_,s,f,m=setup(); row(api,m,0,"saved"); f:SetEnabled(true)
        assert(not f:ShouldShow("bankWithdraw",1,0))
        for _,phase in ipairs({"confirming","preparingEdit","editing","restoring","recovery"}) do
            s.view={state=phase,isEditor=true,paused=true}; assert(f:IsBypassed()); assert(f:ShouldShow("bankWithdraw",1,0)); assert(f:IsEnabled())
        end
        s.view={state="applying",isEditor=false}; assert(not f:IsBypassed()); assert(not f:ShouldShow("bankWithdraw",1,0))
    end,
    native_predicates_counts_and_idempotent_attach=function()
        local _,api,_,_,f,m=setup(); f:Attach(api); local wrapped=m.ShouldAddSlotToList; f:Attach(api); assert(wrapped==m.ShouldAddSlotToList)
        f:SetEnabled(true)
        for _,context in ipairs(contexts) do if context~="vendorRepair" then
            local kind=selectContext(api,m,context); local inv=m.inventories[kind]; inv.slots[1]={}
            row(api,m,0,"saved",nil,kind); row(api,m,1,"saved",nil,kind); row(api,m,2,"other",nil,kind)
            for index,flag in ipairs({"searchFail","categoryFail","stolenFail","lockFail","thirdPartyFail"}) do row(api,m,2+index,"saved",{[flag]=true},kind) end
            m:UpdateList(kind); assert(#inv.visible==1,context); assert(f:HiddenCount(context)==1,context)
            assert(not m:ShouldAddSlotToList(inv,inv.slots[1][3])); assert(f:HiddenCount(context)==1)
            m.denied=true; m:UpdateList(kind); assert(f:HiddenCount(context)==0); m.denied=false
        end end
        m.appliedLayout={}; m:UpdateList("BACKPACK"); assert(#m.inventories.BACKPACK.visible==3)
    end,
    libfilters_callback_order_and_signature_keep_counts=function()
        local _,api,_,_,f,m,_,lib=setup(true); local original=m.ShouldAddSlotToList
        f:Attach(api); assert(m.ShouldAddSlotToList==original); f:SetEnabled(true)
        for _,context in ipairs(contexts) do if context~="vendorRepair" then
            local kind=selectContext(api,m,context); local inv=m.inventories[kind]; inv.slots[1]={}
            row(api,m,0,"saved",nil,kind); row(api,m,1,"saved",{libFail=true},kind); row(api,m,2,"other",nil,kind)
            row(api,m,3,"saved",{categoryFail=true},kind)
            for _,reverse in ipairs({false,true}) do lib.reverse=reverse; m:UpdateList(kind); assert(#inv.visible==1); assert(f:HiddenCount(context)==1,context) end
        end end
        api.flush(); for i=1,#contexts do assert(lib.requests[i]==1) end
    end,
    repair_native_and_libfilters_preserve_search_cost_and_sort_count=function()
        for _,withLib in ipairs({false,true}) do
            local _,api,_,s,f,m,repair=setup(withLib); f:Attach(api); f:SetEnabled(true)
            row(api,m,0,"saved"); row(api,m,1,"ordinary")
            row(api,m,2,"saved"); api.bags[1][2].searchFail=true
            row(api,m,3,"saved"); api.bags[1][3].condition=100
            row(api,m,4,"saved"); api.bags[1][4].repairCost=0
            repair:UpdateList(); assert(#repair.list==1); assert(f:HiddenCount("vendorRepair")==1)
            repair:ApplySort(); assert(f:HiddenCount("vendorRepair")==1)
            s.view={isEditor=true,state="recovery"}; repair:UpdateList(); assert(#repair.list==2); assert(f:HiddenCount("vendorRepair")==0)
        end
    end,
    repair_fallback_counts_after_existing_sort_filter_and_preserves_committed_rows=function()
        local _,api,_,_,f,m,repair=setup()
        local sortCalls=0
        api.ZO_ScrollList_Commit=function(list)
            repair.commits=repair.commits+1; repair.visible={}
            for _,entry in ipairs(list) do repair.visible[#repair.visible+1]=entry.data.slotIndex end
        end
        -- Native ApplySort sorts and commits; an addon already wraps it to exclude slot 99.
        local function nativeSort(owner)
            table.sort(owner.list,function(a,b) return a.data.slotIndex<b.data.slotIndex end)
            api.ZO_ScrollList_Commit(owner.list)
            return "sorted",nil,42
        end
        repair.ApplySort=function(owner,...)
            sortCalls=sortCalls+1
            for i=#owner.list,1,-1 do if owner.list[i].data.slotIndex==99 then table.remove(owner.list,i) end end
            return nativeSort(owner,...)
        end
        row(api,m,99,"saved"); row(api,m,8,"ordinary-eight"); row(api,m,2,"ordinary-two")
        f:Attach(api); f:SetEnabled(true); api.flush()
        assert(f:HiddenCount("vendorRepair")==0,"foreign exclusion is not our hidden item")
        assert(#repair.visible==2 and repair.visible[1]==2 and repair.visible[2]==8)
        -- The same item moves to an allowed slot; normal native UpdateList is authoritative.
        api.bags[1][0]=api.bags[1][99]; api.bags[1][99]=nil
        repair:UpdateList(); assert(f:HiddenCount("vendorRepair")==1)
        assert(#repair.visible==2 and repair.visible[1]==2 and repair.visible[2]==8)
        local before=sortCalls
        local a,b,c=repair:ApplySort()
        assert(a=="sorted" and b==nil and c==42 and sortCalls==before+1)
        assert(f:HiddenCount("vendorRepair")==1 and #repair.visible==2)
        f:SetEnabled(false); api.flush()
        assert(f:HiddenCount("vendorRepair")==0 and #repair.visible==3)
        assert(repair.visible[1]==0 and repair.visible[2]==2 and repair.visible[3]==8)
        repair:ApplySort(); assert(#repair.visible==3)
        f:SetEnabled(true); api.flush(); repair:ApplySort()
        assert(f:HiddenCount("vendorRepair")==1 and #repair.visible==2)
    end,
    bank_backing_bags_reused_slots_and_no_link_fallback=function()
        local _,api,repo,_,f,m=setup(); f:Attach(api); f:SetEnabled(true)
        local kind=selectContext(api,m,"bankWithdraw"); local inv=m.inventories[kind]
        inv.backingBags={BAG_BANK,BAG_SUBSCRIBER_BANK}; inv.slots={[BAG_BANK]={},[BAG_SUBSCRIBER_BANK]={}}
        api.bags[BAG_SUBSCRIBER_BANK][17]={uid="saved",link="ring"}
        inv.slots[BAG_SUBSCRIBER_BANK][17]={bagId=BAG_SUBSCRIBER_BANK,slotIndex=17,stackCount=1}
        m:UpdateList(kind); assert(#inv.visible==0 and f:HiddenCount("bankWithdraw")==1)
        api.bags[BAG_SUBSCRIBER_BANK][17]={uid="new-instance",link="ring"}
        m:RefreshInventorySlot(kind,17,BAG_SUBSCRIBER_BANK)
        assert(#inv.visible==1 and f:HiddenCount("bankWithdraw")==0)
        local preset=repo:List()[1]; assert(repo:Delete(preset.id,preset.revision))
        api.bags[BAG_SUBSCRIBER_BANK][17]={uid="saved",link="ring"}
        m:UpdateList(kind); assert(#inv.visible==1 and f:HiddenCount("bankWithdraw")==0)
    end,
    repair_library_foreign_filter_and_worn_uid_count=function()
        local _,api,_,_,f,m,repair=setup(true); f:Attach(api); f:SetEnabled(true)
        row(api,m,99,"saved"); repair:UpdateList()
        assert(#repair.list==0 and f:HiddenCount("vendorRepair")==0)
        api.bags[BAG_WORN][EQUIP_SLOT_RING1]=api.bags[1][99]; api.bags[1][99]=nil
        repair:UpdateList(); assert(#repair.list==0 and f:HiddenCount("vendorRepair")==1)
        f:SetEnabled(false); repair:UpdateList(); assert(#repair.list==1 and f:HiddenCount("vendorRepair")==0)
    end,
    counting_exceptions_restore_own_filter_and_preference=function()
        local _,api,_,_,f,m=setup(true); f:Attach(api); f:SetEnabled(true)
        local kind=selectContext(api,m,"backpack"); row(api,m,0,"saved")
        local inv=m.inventories[kind]
        inv.additionalFilter=function() error("foreign predicate failed") end
        assert(not pcall(function() f:RecountInventory(kind) end))
        assert(not f.countOnly and f:IsEnabled() and not f:ShouldShow("backpack",1,0))
    end,
    contexts_share_parent_and_only_active_layout_is_marked=function()
        local _,api,_,_,f,m=setup(); f:Attach(api); selectContext(api,m,"fenceLaunder")
        local shared,active
        for _,entry in ipairs(f:GetContexts()) do
            if entry.inventoryType=="BACKPACK" then
                if shared then assert(entry.parent==shared) else shared=entry.parent end
                if entry.active then assert(not active); active=entry.context end
            end
        end
        assert(active=="fenceLaunder")
        m.inventories.BACKPACK.listView.IsHidden=function() return true end
        for _,entry in ipairs(f:GetContexts()) do if entry.inventoryType=="BACKPACK" then assert(not entry.active) end end
    end,
    refresh_events_are_coalesced_and_preference_shared=function()
        local KW,api,repo,s,f,m=setup(); local events=KW.Core.NewEvents(); local changes=0
        f:Attach(api,events,function() changes=changes+1 end); selectContext(api,m,"backpack"); row(api,m,0,"saved")
        f:SetEnabled(true); f:SetEnabled(true); events:Emit("InventoryChanged"); events:Emit("PresetsChanged"); events:Emit("SessionChanged")
        api.flush(); assert(m.updates==4); assert(repo.character.hidePresetItems and f:IsEnabled()); assert(changes>0)
        assert(#f:GetContexts()==12)
        s.view={isEditor=true,state="editing"}; events:Emit("SessionChanged"); api.flush(); assert(f:HiddenCount("backpack")==0)
    end,
}
