local Fake=dofile(ROOT.."/tests/support/fake_eso.lua")
local function setup(f)
    local files={}
    for line in io.lines(ROOT.."/KanaWardrobe.txt")do if line:match("%.lua$")then files[#files+1]=line end end
    local k=Fake.Load(files)
    -- Retain coverage of persisted legacy consumers; new runtime has separate end-to-end cases below.
    if not f.stepwise then k.OperationSession=nil;k.OperationWindow=nil end
    -- This harness exercises the supported eight-argument legacy gear runtime.
    if not f.modern then k.BuildDraft=nil end
    local a=Fake.New(); a.sheathed=true; local saved={}; f.k=k;f.a=a;f.applied=0;f.globals={}
    -- Native character IDs are already strings; native item UIDs are opaque id64 values.
    local id64Tag={}
    function a.GetItemUniqueId(bag,slot)
        local item=(a.bags[bag] or {})[slot]
        if item and item.uid then return setmetatable({value=item.uid},id64Tag) end
    end
    function a.Id64ToString(value)
        assert(type(value)=="table" and getmetatable(value)==id64Tag,"Id64ToString requires native id64, not a character-ID string")
        return value.value
    end
    function f:Global(name,value) self.globals[name]={_G[name]}; _G[name]=value end
    function f:Cleanup() for name,value in pairs(self.globals) do _G[name]=value[1] end end
    local clock={now=0,next=0,timers={}}
    function clock:Schedule(delay,cb) self.next=self.next+1; self.timers[self.next]={at=self.now+math.max(1,delay),cb=cb}; return self.next end
    function clock:Advance(delta)
        local limit=self.now+delta;local steps=0
        while true do
            local id,at
            for n,t in pairs(self.timers) do if t.at<=limit and (not at or t.at<at or t.at==at and n<id)then id,at=n,t.at end end
            if not id then break end
            steps=steps+1;assert(steps<1000,"timer loop");local t=self.timers[id];self.timers[id]=nil;self.now=at;t.cb()
        end
        self.now=limit
    end
    f.clock=clock
    function a.GetFrameTimeMilliseconds() return clock.now end
    a.zo_callLater=function(cb,delay) return clock:Schedule(delay,cb) end; f:Global("zo_callLater",a.zo_callLater)
    a.EVENT_MANAGER={events={},updates={}}
    function a.EVENT_MANAGER:RegisterForEvent(name,event,cb) self.events[name]={event,cb} end
    function a.EVENT_MANAGER:UnregisterForEvent(name) self.events[name]=nil end
    function a.EVENT_MANAGER:RegisterForUpdate(name,delay,cb) self:UnregisterForUpdate(name);self.updates[name]=clock:Schedule(delay,cb) end
    function a.EVENT_MANAGER:UnregisterForUpdate(name) if self.updates[name]then clock.timers[self.updates[name]]=nil end; self.updates[name]=nil end
    function f:Event(name,...) for _,entry in pairs(a.EVENT_MANAGER.events)do if entry[1]==a[name]then entry[2](a[name],...)end end end
    for _,name in ipairs({"INVENTORY_SINGLE_SLOT_UPDATE","INVENTORY_FULL_UPDATE","OPEN_BANK","CLOSE_BANK","PLAYER_ACTIVATED","CLOSE_GUILD_BANK","GUILD_BANK_SELECTED","GUILD_BANK_ITEMS_READY","PLAYER_COMBAT_STATE","PLAYER_DEAD","PLAYER_ALIVE","PLAYER_REINCARNATED","PLAYER_DEACTIVATED"}) do a["EVENT_"..name]=name end
    function a.GetWorldName()return "EU"end;function a.GetDisplayName()return "acct"end
    function a.GetCurrentCharacterId()return "1234567890123456789"end;function a.GetUnitName()return "Kana"end;function a.GetAPIVersion()return 999999 end
    a.ZO_SavedVars={NewAccountWide=function()return saved end};a.SLASH_COMMANDS={};a.messages={};a.d=function(s)a.messages[#a.messages+1]=s end
    function a.IsUnitDeadOrReincarnating()return a.dead or false end
    function a.ArePlayerWeaponsSheathed()return a.sheathed end
    function a.TogglePlayerWield()a.sheathed=true end
    function a.CanItemBePlayerLocked()return true end
    function a.IsItemPlayerLocked(b,s)return a.bags[b][s].locked==true end
    function a.SetItemIsPlayerLocked(b,s,v)a.bags[b][s].locked=v end
    -- These functions belong to ESO's secure action path. Preserving callback
    -- identity alone is insufficient: even wrapping discovery can taint it.
    a.SI_ITEM_ACTION_UNMARK_AS_LOCKED=17
    function a.ZO_Inventory_GetBagAndIndex(c)return c.bagId,c.slotIndex end
    f.nativeUse=function()f.used=(f.used or 0)+1 end
    f.nativeDeposit=function(c)
        a.bags[BAG_BANK][c.slotIndex]=a.bags[BAG_BACKPACK][c.slotIndex];a.bags[BAG_BACKPACK][c.slotIndex]=nil
    end
    f.nativeWithdraw=function(c)
        a.bags[BAG_BACKPACK][c.slotIndex]=a.bags[BAG_BANK][c.slotIndex];a.bags[BAG_BANK][c.slotIndex]=nil
    end
    f.nativeDiscover=function(c,actions)
        actions:AddSlotAction(1,c.bagId==BAG_BANK and f.nativeWithdraw or a.bankOpen and f.nativeDeposit or f.nativeUse)
    end
    a.ZO_InventorySlot_DiscoverSlotActionsFromActionList=f.nativeDiscover
    f.nativePrimary=function(actions,control)actions.callback(control)end
    a.ZO_InventorySlotActions={DoPrimaryAction=f.nativePrimary}
    local function control()
        local c={children={}};function c:GetScale()return 1 end
        function c:GetNamedChild(n)self.children[n]=self.children[n]or control();return self.children[n]end
        for _,name in ipairs({"SetClampedToScreen","SetCenterColor","SetEdgeColor","SetDimensions","SetDrawTier","SetMouseEnabled","SetHidden","SetAnchor","SetFont","SetTexture","SetText","SetResizeToFitDescendents","SetHandler"})do c[name]=function()end end
        for _,name in ipairs({'SetAnchorFill','SetEdgeTexture','SetMaxLineCount','SetWrapMode','SetColor','SetDrawLayer','SetDrawLevel','SetHorizontalAlignment','SetVerticalAlignment','ClearAnchors','SetEnabled','SetHeight','SetWidth'})do c[name]=function()end end
        function c:SetText(v)self.text=v or ''end;function c:GetText()return self.text or ''end
        function c:SetDimensions(w,h)self.w=w;self.h=h end
        function c:GetWidth()return self.w or 1600 end;function c:GetHeight()return self.h or 1000 end
        function c:GetTextHeight()return 20 end
        function c:GetTextWidth()return #(self.text or '')*8 end
        return c
    end
    f:Global('GuiRoot',control())
    f:Global('ZO_MEDIUM_TIER_KEYBOARD_STANDARD_DIALOG',100)
    f:Global('ZO_Scroll_SetOnInteractWithScrollbarCallback',function(c,fn)c.onInteractWithScrollbarCallback=fn end)
    f:Global('ZO_Scroll_SetScrollToRealOffsetAccountingForGradients',function()end)
    local function virtualControl(_,name,parent,template)
        local c=control()
        if template=='ZO_DefaultButton' or template=='ZO_CloseButton'then
            local label=control()
            c.GetText=nil;c.GetTextWidth=nil;c.GetTextHeight=nil
            function c:GetLabelControl()return label end
            function c:SetText(v)label:SetText(v)end
        end
        return c
    end
    f:Global("WINDOW_MANAGER",{CreateTopLevelWindow=function()return control()end,CreateControl=function()return control()end,CreateControlFromVirtual=virtualControl})
    f:Global("KanaWardrobePanel",nil)
    f:Global("ZO_TOOLTIP_STYLES",{tooltip={},bodySection={},bodyHeader={}})
    for _,name in ipairs({"SetLabelText","SetToggleFunction","SetCheckState","SetEnableState"})do f:Global("ZO_CheckButton_"..name,function(c,v)c[name]=v end)end
    -- Native list boundary: actual filters run over current physical bag rows.
    a.PLAYER_INVENTORY={inventories={}};local manager=a.PLAYER_INVENTORY
    for _,name in ipairs({"BACKPACK","BANK","GUILD_BANK","HOUSE_BANK"})do
        a["INVENTORY_"..name]=name
        manager.inventories[name]={backingBags={BAG_BACKPACK},slots={[BAG_BACKPACK]={}},listView={IsHidden=function()return false end}}
    end
    for _,name in ipairs({"MENU_BAR","DEFAULT","BANK","GUILD_BANK","HOUSE_BANK","STORE","FENCE","LAUNDER","TRADING_HOUSE"})do a["BACKPACK_"..name.."_LAYOUT_FRAGMENT"]={layoutData={}}end
    manager.appliedLayout=a.BACKPACK_MENU_BAR_LAYOUT_FRAGMENT.layoutData
    function manager:ShouldAddEntries()return true end
    function manager:ShouldAddSlotToList(inv,row)
        if row.stackCount<=0 then return false end
        if inv.additionalFilter and not inv.additionalFilter(row)then return false end
        if self.appliedLayout and self.appliedLayout.additionalFilter and not self.appliedLayout.additionalFilter(row)then return false end
        return true
    end
    function manager:UpdateList(kind)
        local inv=self.inventories[kind];inv.slots[BAG_BACKPACK]={};inv.visible={}
        for slot in pairs(a.bags[BAG_BACKPACK])do local row={bagId=BAG_BACKPACK,slotIndex=slot,stackCount=1};inv.slots[BAG_BACKPACK][slot]=row
            if self:ShouldAddSlotToList(inv,row)then inv.visible[#inv.visible+1]=row end
        end
    end
    function manager:RefreshInventorySlot(kind)self:UpdateList(kind)end
    a.REPAIR_WINDOW={list={},control={IsControlHidden=function()return true end},ApplySort=function()end,UpdateList=function()end}
    a.ZO_ScrollList_GetDataList=function(list)return list end
    a.ZO_ScrollList_Commit=function()end
    a.ItemTooltip=Fake.Control({lines={},IsHidden=function()return false end})
    function a.ItemTooltip:ClearLines()self.lines={};if self.OnCleared then self.OnCleared(self)end end
    function a.ItemTooltip:AddLine(s)self.lines[#self.lines+1]=s end
    function a.ItemTooltip:SetBagItem()self:ClearLines();self:AddLine("native")end
    a.ZO_PostHook=function(obj,name,fn)local old=obj[name];obj[name]=function(...)old(...);fn(...)end end
    a.ZO_PostHookHandler=function(obj,name,fn)obj[name]=fn end
    function f:Add(uid,bag,slot,equip)local v={uid=uid,link="link:"..uid};a.bags[bag][slot]=v;a.descriptions[v.link]={equipType=equip or EQUIP_TYPE_RING};return {kind="item",uid=uid,link=v.link}end
    function f:Preset(slots,name)local p=self.r.repo:NewDraft();p.slots=slots;p.name=name or "Partial";return assert(self.r.repo:Save(p,0))end
    function f:ApplyRequest(index)
        local q=assert(a.requests[index]);if q[1]=="equip"then local v=a.bags[q[2]][q[3]];a.bags[q[2]][q[3]]=a.bags[BAG_WORN][q[5]];a.bags[BAG_WORN][q[5]]=v
        else a.bags[BAG_BACKPACK][900+index]=a.bags[BAG_WORN][q[3]];a.bags[BAG_WORN][q[3]]=nil;a.free=a.free-1 end
        self:Event("EVENT_INVENTORY_SINGLE_SLOT_UPDATE")
    end
    function f:Drain()local count=0;repeat count=count+1;assert(count<100);if self.applied<#a.requests then self.applied=self.applied+1;self:ApplyRequest(self.applied)end;clock:Advance(2)until self.applied==#a.requests end
    function f:DrainOperationGear()
        for i=1,100 do
            if self.applied<#a.requests then self.applied=self.applied+1;self:ApplyRequest(self.applied)end
            clock:Advance(5)
            local op=self.r.session.operations.operation
            if not op or not self.r.session.operations:IsBusy()then return end
            local step=op.steps[op.index]
            if step.status=='running' and (step.kind=='attributes' or step.kind=='skills' or step.kind=='bar')then return end
        end
        error('operation did not settle')
    end
    local nativeManager={ShouldAddSlotToList=manager.ShouldAddSlotToList,UpdateList=manager.UpdateList,RefreshInventorySlot=manager.RefreshInventorySlot}
    local nativeRepair={ApplySort=a.REPAIR_WINDOW.ApplySort,UpdateList=a.REPAIR_WINDOW.UpdateList}
    local nativeTooltip=a.ItemTooltip.SetBagItem
    function f:Reload()
        if self.r then self:Event("EVENT_PLAYER_DEACTIVATED");self.r.runner:Stop("stopped")end
        -- Reload discards old Lua callbacks, while SavedVariables/native inventory survive.
        a.EVENT_MANAGER.events={};a.EVENT_MANAGER.updates={};clock.timers={};manager.KanaWardrobeFilters=nil
        a.securePostHooks={}
        for _,inv in pairs(manager.inventories)do inv.additionalFilter=nil end
        for _,name in ipairs({"MENU_BAR","DEFAULT","BANK","GUILD_BANK","HOUSE_BANK","STORE","FENCE","LAUNDER","TRADING_HOUSE"})do
            a["BACKPACK_"..name.."_LAYOUT_FRAGMENT"].layoutData.additionalFilter=nil
        end
        for name,fn in pairs(nativeManager)do manager[name]=fn end
        for name,fn in pairs(nativeRepair)do a.REPAIR_WINDOW[name]=fn end
        a.ItemTooltip.SetBagItem=nativeTooltip;a.ItemTooltip.OnCleared=nil;a.ItemTooltip.OnHide=nil
        a.ZO_InventorySlot_DiscoverSlotActionsFromActionList=self.nativeDiscover
        k.runtime=nil;self.r=k.Core.Initialize(a)
    end
    for _,name in ipairs({"GetWorldName","GetDisplayName","GetCurrentCharacterId","GetUnitName","GetAPIVersion","ZO_SavedVars","EVENT_MANAGER","GetFrameTimeMilliseconds"})do f:Global(name,a[name])end
    if f.nativeModern then
        local BF=dofile(ROOT.."/tests/support/build_fixture.lua");local AF=dofile(ROOT.."/tests/support/attribute_fixture.lua")
        local native=BF.New();native.api=a;BF.InstallSkills(native,{{lineId=10,kind="active",id=51,purchased=true,morph=1}});AF.Attach(native);BF.InstallSkillDrafts(native)
        f.native=native
        for _,name in ipairs({"START_SKILL_RESPEC","SKILL_RESPEC_RESULT","ATTRIBUTE_RESPEC_RESULT","SKILLS_FULL_UPDATE",
            "SKILL_POINTS_CHANGED","SKILL_LINE_ADDED","ABILITY_PROGRESSION_RANK_UPDATE","HOTBAR_SLOT_UPDATED",
            "ACTION_SLOTS_ALL_HOTBARS_UPDATED","ATTRIBUTE_UPGRADE_UPDATED","SKILL_RANK_UPDATE"})do a["EVENT_"..name]=name end
        a.SCENE_SHOWING='showing';a.SCENE_HIDING='hiding'
        local scenes={};local sceneManager={}
        for _,page in ipairs({'inventory','skills','stats'})do
            local scene={callbacks={},name=page}
            function scene:RegisterCallback(name,fn)self.callbacks[name]=self.callbacks[name]or {};table.insert(self.callbacks[name],fn)end
            function scene:FireCallbacks(name,...)for _,fn in ipairs(self.callbacks[name]or {})do fn(...)end end
            function scene:UnregisterAllCallbacks(name)self.callbacks[name]=nil end
            -- ZO_Scene public confirmation protocol, zo_scene.lua:295-331.
            function scene:SetHideSceneConfirmationCallback(cb)self.hideSceneConfirmationCallback=cb end
            function scene:HasHideSceneConfirmation()return self.hideSceneConfirmationCallback~=nil end
            function scene:ConfirmHideScene(nextName,push,clear,pops,reason)
                self.hideSceneConfirmationNextSceneName=nextName;self.hideSceneConfirmationPush=push
                self.hideSceneConfirmationNextSceneClearsSceneStack=clear;self.hideSceneConfirmationNumScenesNextScenePops=pops
                self.hideSceneConfirmationCallback(self,nextName,reason)
            end
            function scene:ClearConfirmation()
                self.hideSceneConfirmationNextSceneName=nil;self.hideSceneConfirmationPush=nil
                self.hideSceneConfirmationNextSceneClearsSceneStack=nil;self.hideSceneConfirmationNumScenesNextScenePops=nil
                self:UnregisterAllCallbacks('HideSceneConfirmationResult')
            end
            function scene:AcceptHideScene()
                local nextName,push,clear,pops=self.hideSceneConfirmationNextSceneName,self.hideSceneConfirmationPush,self.hideSceneConfirmationNextSceneClearsSceneStack,self.hideSceneConfirmationNumScenesNextScenePops
                self:FireCallbacks('HideSceneConfirmationResult',true);self:ClearConfirmation()
                sceneManager:Show(nextName,push,clear,pops,'ALREADY_SEEN')
            end
            function scene:RejectHideScene()self:FireCallbacks('HideSceneConfirmationResult',false);self:ClearConfirmation()end
            scenes[page]=scene
        end
        function sceneManager:GetScene(page)return scenes[page]end
        function sceneManager:Show(page,push,clear,pops,reason)
            if page==self.page then return end
            local current=scenes[self.page]
            if current and current:HasHideSceneConfirmation() and reason~='ALREADY_SEEN'then return current:ConfirmHideScene(page,push,clear,pops,reason)end
            if current then current:FireCallbacks('StateChange',a.SCENE_SHOWING,a.SCENE_HIDING)end
            self.page=page;if scenes[page]then scenes[page]:FireCallbacks('StateChange',a.SCENE_HIDING,a.SCENE_SHOWING)end
        end
        a.SCENE_MANAGER=sceneManager
        a.StartSkillRespecFromUI=function()native.entryRequests=(native.entryRequests or 0)+1;sceneManager:Show('skills')end
    end
    f.r=k.Core.Initialize(a)
    if f.native then f.native.events=f.r.events end
    assert(f.r.session and f.r.filters and f.r.ui,"Core must assemble all runtime consumers")
    return f
end
local function modernTest(body)
    return function()
        local f={modern=true,nativeModern=true}
        local ok,err=xpcall(function()setup(f);body(f)end,function(issue)
            return debug.traceback(type(issue)=='table' and tostring(issue.code)..': '..tostring(issue.details and issue.details.reason) or tostring(issue),2)
        end)
        if f.Cleanup then f:Cleanup()end;assert(ok,err)
    end
end
local tests={}
local function test(name,body)tests[name]=function()local f={};local ok,err=pcall(function()setup(f);body(f)end);if f.Cleanup then f:Cleanup()end;assert(ok,err)end end
test("late_completed_apply_unlocks_rows_without_reload_or_rollback",function(f)
    local old=f:Add("old",BAG_WORN,EQUIP_SLOT_RING1)
    local new=f:Add("new",BAG_BACKPACK,1)
    local first=f:Preset({[EQUIP_SLOT_RING1]=new},"First")
    local second=f:Preset({[EQUIP_SLOT_RING1]=old},"Second")
    assert(f.r.session:Apply(first.id)); f.clock:Advance(5001)
    assert(f.r.session:GetView().state=="recovery")
    f:ApplyRequest(1); f.applied=1; f.clock:Advance(2)
    assert(f.r.session:GetView().state=="idle" and f.r.repo.character.journal==nil,
        "late success must release the session instead of leaving an eternal busy journal")
    assert(#f.a.requests==1 and f.r.ui:FindRow(second.id).canApply)
    f.r.ui:RowClick(second.id,1); f:Drain()
    assert(f.r.session:GetView().state=="idle" and f.a.bags[BAG_WORN][EQUIP_SLOT_RING1].uid=="old")
end)
test("late_destination_does_not_unlock_until_source_and_displaced_item_settle",function(f)
    local old=f:Add("old",BAG_WORN,EQUIP_SLOT_RING1)
    local new=f:Add("new",BAG_BACKPACK,1)
    local p=f:Preset({[EQUIP_SLOT_RING1]=new})
    assert(f.r.session:Apply(p.id)); f.clock:Advance(5001)
    f.a.bags[BAG_WORN][EQUIP_SLOT_RING1]=f.a.bags[BAG_BACKPACK][1]
    f:Event("EVENT_INVENTORY_SINGLE_SLOT_UPDATE")
    assert(f.r.session:GetView().state=="recovery")
    f.a.bags[BAG_BACKPACK][1]=nil
    f:Event("EVENT_INVENTORY_SINGLE_SLOT_UPDATE")
    assert(f.r.session:GetView().state=="recovery","displaced item is still outstanding")
    f.a.bags[BAG_BACKPACK][9]={uid=old.uid,link=old.link}
    f:Event("EVENT_INVENTORY_SINGLE_SLOT_UPDATE")
    assert(f.r.session:GetView().state=="idle" and #f.a.requests==1)
end)
test("late_completion_never_resumes_editing_paused_or_external_changes",function(f)
    local item=f:Add("new",BAG_BACKPACK,1)
    local p=f:Preset({[EQUIP_SLOT_RING1]=item})
    assert(f.r.session:BeginEdit(p.id)); f.clock:Advance(5001)
    f:ApplyRequest(1)
    assert(f.r.session:GetView().state=="recovery","editor recovery remains explicit")
    assert(f.r.session:Recover("keepCurrent"))
    local nextItem=f:Add("next",BAG_BACKPACK,2)
    local nextPreset=f:Preset({[EQUIP_SLOT_RING1]=nextItem},"Next")
    assert(f.r.session:Apply(nextPreset.id)); f.clock:Advance(5001)
    f:Add("external",BAG_WORN,EQUIP_SLOT_HEAD,EQUIP_TYPE_HEAD)
    f:ApplyRequest(2)
    assert(f.r.session:GetView().state=="recovery","unrelated worn changes must not be accepted as success")
    f.a.bags[BAG_WORN][EQUIP_SLOT_HEAD]=nil
    assert(f.r.session:Pause("sceneHidden"))
    f:Event("EVENT_INVENTORY_SINGLE_SLOT_UPDATE")
    assert(f.r.session:GetView().paused and f.r.session:GetView().state=="recovery")
end)
test("userdata_tooltip_initialization_keeps_filters_events_and_repeated_preset_clicks_working",function(f)
    assert(type(f.a.ItemTooltip)=="userdata")
    assert(next(f.r.ui.toggles)~=nil,"initialization must reach hide toggle registration")
    assert(f.a.SLASH_COMMANDS["/kw"],"initialization must reach status command registration")
    assert(f.a.EVENT_MANAGER.events.KanaWardrobeEVENT_INVENTORY_SINGLE_SLOT_UPDATE)
    local old=f:Add("old",BAG_WORN,EQUIP_SLOT_RING1)
    local new=f:Add("new",BAG_BACKPACK,1)
    local first=f:Preset({[EQUIP_SLOT_RING1]=new},"First")
    local second=f:Preset({[EQUIP_SLOT_RING1]=old},"Second")
    f.clock:Advance(2)
    for _,id in ipairs({first.id,second.id,first.id})do
        f.r.ui:RowClick(id,1);f:Drain();f.clock:Advance(2)
        assert(f.r.session:GetView().state=="idle" and not f.r.runner:IsBusy())
        assert(f.r.ui:FindRow(first.id).canApply and f.r.ui:FindRow(second.id).canApply,
            "finished operation must refresh cached row availability")
    end
    assert(#f.a.requests==3 and f.r.inventory:Capture(false).worn[EQUIP_SLOT_RING1].uid=="new")
end)
test("native_item_action_discovery_is_never_replaced",function(f)
    local function check()
        assert(f.a.ZO_InventorySlot_DiscoverSlotActionsFromActionList==f.nativeDiscover,"addon replaced native item action discovery")
        local actions={}
        local add=function(self,_,callback)self.callback=callback end
        actions.AddSlotAction=add
        f.a.ZO_InventorySlot_DiscoverSlotActionsFromActionList({bagId=BAG_BACKPACK,slotIndex=1},actions)
        assert(actions.AddSlotAction==add and actions.callback==f.nativeUse)
        actions.callback()
    end
    check()
    local ring=f:Add("protected",BAG_BACKPACK,1)
    f:Preset({[EQUIP_SLOT_RING1]=ring})
    assert(f.a.bags[BAG_BACKPACK][1].locked)
    check()
    f.a.bags[BAG_BACKPACK][1].locked=false
    f:Event("EVENT_INVENTORY_SINGLE_SLOT_UPDATE")
    assert(f.a.bags[BAG_BACKPACK][1].locked,"event-based protection must remain active")
    check()
    f:Reload();check()
    assert(f.used==4)
end)
test("integration_preserves_character_string_and_converts_native_item_id64",function(f)
    assert(f.r.repo.characterId=="1234567890123456789")
    assert(f.r.repo.characters["1234567890123456789"]==f.r.repo.character)
    local uid="9876543210987654321"
    f:Add(uid,BAG_BACKPACK,1)
    local item=f.r.inventory:ReadSlot(BAG_BACKPACK,1)
    assert(item.uid==uid and f.r.inventory:Capture().byUid[uid].uid==uid)
    local preset=f:Preset({[EQUIP_SLOT_RING1]={kind="item",uid=uid,link=item.link}})
    assert(f.r.repo:Get(preset.id).slots[EQUIP_SLOT_RING1].uid==uid)
end)
test("edit_cancel_restores_confirmed_extras",function(f)
    f:Add("sword",BAG_WORN,EQUIP_SLOT_MAIN_HAND,EQUIP_TYPE_ONE_HAND);f:Add("shield",BAG_WORN,EQUIP_SLOT_OFF_HAND,EQUIP_TYPE_OFF_HAND)
    local weapon=f:Add("greatsword",BAG_BACKPACK,1,EQUIP_TYPE_TWO_HAND);local original=f.r.inventory:Capture().worn
    local p=f:Preset({[EQUIP_SLOT_MAIN_HAND]=weapon});local revision=p.revision
    assert(f.r.session:BeginEdit(p.id));assert(f.r.session:GetView().confirmation.plan.extras[1].uid=="shield")
    assert(f.r.session:RejectConfirmation());assert(#f.a.requests==0)
    assert(f.r.session:BeginEdit(p.id));assert(f.r.session:Confirm(f.r.session:GetView().confirmation.plan.extraKey));f:Drain()
    assert(f.r.session:GetView().state=="editing" and f.r.filters:IsBypassed())
    f:Add("manualhat",BAG_WORN,EQUIP_SLOT_HEAD,EQUIP_TYPE_HEAD);f:Event("EVENT_INVENTORY_SINGLE_SLOT_UPDATE")
    assert(f.r.session:Cancel());f:Drain()
    assert(f.k.Slots.Equal(f.r.inventory:Capture().worn,original));assert(f.r.repo:Get(p.id).revision==revision)
    assert(f.r.session:GetView().state=="idle" and f.r.repo.character.journal==nil and f.r.ui.lastOutcome=="cancelled")
end)
test("integration_create_save_apply_edit_rename_tooltip_filter_delete",function(f)
    local old=f:Add("old",BAG_WORN,EQUIP_SLOT_RING1);local ring=f:Add("new",BAG_BACKPACK,1)
    assert(f.r.session:BeginNew());f.a.bags[BAG_BACKPACK][2]=f.a.bags[BAG_WORN][EQUIP_SLOT_RING1];f.a.bags[BAG_WORN][EQUIP_SLOT_RING1]=f.a.bags[BAG_BACKPACK][1];f.a.bags[BAG_BACKPACK][1]=nil
    assert(f.r.session:SetName("Created"));assert(f.r.session:Save());f:Drain();local p=f.r.repo:List()[1]
    assert(p.slots[EQUIP_SLOT_RING1].uid=="new" and f.r.inventory:Capture().worn[EQUIP_SLOT_RING1].uid==old.uid)
    assert(f.r.inventory:Resolve("new").uid=="new");f.r.filters:SetEnabled(true);f.clock:Advance(2)
    local loc=f.r.inventory:Resolve("new");assert(f.a.bags[loc.bagId][loc.slotIndex].locked)
    f.a.ItemTooltip:SetBagItem(loc.bagId,loc.slotIndex);assert(f.a.ItemTooltip.lines[2]:find("Created",1,true))
    assert(not f.r.filters:ShouldShow("backpack",loc.bagId,loc.slotIndex))
    assert(f.r.session:Apply(p.id));f:Drain();assert(f.r.inventory:Capture().worn[EQUIP_SLOT_RING1].uid=="new" and f.r.ui.lastOutcome=="applied")
    assert(f.r.session:BeginEdit(p.id));assert(f.r.session:SetName("Edited"));assert(f.r.session:Save());f:Drain()
    p=f.r.repo:Get(p.id);p.name="Renamed";p=assert(f.r.repo:Save(p,p.revision));f.clock:Advance(2)
    assert(f.r.repo:Memberships("new","current")[1].name=="Renamed")
    loc=f.r.inventory:Resolve("new");f.a.ItemTooltip:SetBagItem(loc.bagId,loc.slotIndex)
    p.name="Again";p=assert(f.r.repo:Save(p,p.revision));assert(f.a.ItemTooltip.lines[2]:find("Again",1,true))
    assert(f.r.repo:Delete(p.id,p.revision));assert(#f.a.ItemTooltip.lines==1)
    assert(f.r.filters:ShouldShow("backpack",loc.bagId,loc.slotIndex));assert(f.a.bags[loc.bagId][loc.slotIndex].locked)
end)
test("integration_missing_external_swap_and_late_recovery",function(f)
    local p=f:Preset({[EQUIP_SLOT_RING1]={kind="item",uid="missing",link="link:missing"}})
    local ok,e=f.r.session:Apply(p.id);assert(not ok and e.code=="itemMissing" and #f.a.requests==0)
    local ring=f:Add("ring",BAG_BACKPACK,1);p=f:Preset({[EQUIP_SLOT_RING1]=ring},"Available");assert(f.r.session:Apply(p.id))
    f:Add("wwhat",BAG_WORN,EQUIP_SLOT_HEAD,EQUIP_TYPE_HEAD);f:Event("EVENT_INVENTORY_SINGLE_SLOT_UPDATE");f.clock:Advance(2)
    assert(f.r.session:GetView().state=="recovery" and #f.a.requests==1 and f.r.repo.character.journal.pending.uid=="ring")
    f:ApplyRequest(1);f.applied=1;f.clock:Advance(6000);assert(#f.a.requests==1)
    assert(f.r.session:Recover("restore"));f:Drain()
    assert(f.r.inventory:Capture().worn[EQUIP_SLOT_RING1].kind=="empty" and f.r.inventory:Capture().worn[EQUIP_SLOT_HEAD].kind=="empty")
    -- The foreign snapshot prevents proof of the old request's full outcome.
    assert(f.r.session:GetView().state=="recovery" and f.r.repo.character.journal~=nil)
    assert(f.r.session:Recover("keepCurrent"));assert(f.r.repo.character.journal==nil)
end)
test("integration_timeout_late_event_does_not_resume_old_chain",function(f)
    local ring=f:Add("ring",BAG_WORN,EQUIP_SLOT_RING1);local p=f:Preset({[EQUIP_SLOT_RING2]=ring})
    assert(f.r.session:Apply(p.id));assert(f.r.session:Confirm(f.r.session:GetView().confirmation.plan.extraKey));f.clock:Advance(6000)
    assert(f.r.session:GetView().state=="recovery" and #f.a.requests==1 and f.r.repo.character.journal.pending.uid=="ring")
    f:ApplyRequest(1);f.applied=1;f.clock:Advance(10);assert(#f.a.requests==1)
    assert(f.r.session:Recover("restore"));f:Drain()
    assert(f.r.inventory:Capture().worn[EQUIP_SLOT_RING1].uid=="ring" and f.r.repo.character.journal==nil)
end)
test("integration_reload_after_commit_never_repeats_save",function(f)
    f:Add("old",BAG_WORN,EQUIP_SLOT_RING1);local original=f.r.inventory:Capture().worn;assert(f.r.session:BeginNew())
    f.a.bags[BAG_BACKPACK][1]=f.a.bags[BAG_WORN][EQUIP_SLOT_RING1];f:Add("new",BAG_WORN,EQUIP_SLOT_RING1)
    assert(f.r.session:Save());local p=f.r.repo:List()[1];assert(f.r.repo.character.journal.saveCommitted)
    f:ApplyRequest(1);f.applied=1;f:Reload();assert(f.r.session:GetView().state=="recovery" and #f.a.requests==1)
    assert(f.r.session:Recover("restore"));f:Drain();assert(f.r.repo:Get(p.id).revision==1 and f.k.Slots.Equal(f.r.inventory:Capture().worn,original))
end)
test("integration_combat_and_world_exit_pause_without_auto_resume_status_readonly",function(f)
    f:Add("old",BAG_WORN,EQUIP_SLOT_RING1);assert(f.r.session:BeginNew());f.a.combat=true;f:Event("EVENT_PLAYER_COMBAT_STATE")
    assert(f.r.session:GetView().paused);f.a.combat=false;f:Event("EVENT_PLAYER_COMBAT_STATE");f.clock:Advance(10)
    assert(f.r.session:GetView().paused and #f.a.requests==0);assert(f.r.session:Resume())
    f:Event("EVENT_PLAYER_DEACTIVATED");assert(f.r.session:GetView().paused and not f.r.runner:IsBusy())
    local journal=f.k.Copy(f.r.repo.character.journal);local messagesBefore=#f.a.messages;f.a.SLASH_COMMANDS["/kw"]("status")
    assert(#f.a.requests==0 and #f.a.messages==messagesBefore+1 and f.a.messages[#f.a.messages]:find("999999",1,true));assert(f.r.repo.character.journal.phase==journal.phase)
end)
test("integration_death_stops_inflight_and_world_exit_releases_runner_subscriptions",function(f)
    local ring=f:Add("ring",BAG_BACKPACK,1);local p=f:Preset({[EQUIP_SLOT_RING1]=ring});assert(f.r.session:Apply(p.id))
    f.a.dead=true;f:Event("EVENT_PLAYER_DEAD")
    assert(not f.r.runner:IsBusy() and f.r.session:GetView().paused and f.r.repo.character.journal.pending.uid=="ring")
    local count=0;for _ in pairs(f.r.events.listeners)do count=count+1 end
    f.a.dead=false;f:Event("EVENT_PLAYER_ALIVE");f.clock:Advance(5000);assert(#f.a.requests==1)
    f:Event("EVENT_PLAYER_DEACTIVATED");f:Event("EVENT_PLAYER_ACTIVATED");f.clock:Advance(5)
    local after=0;for _ in pairs(f.r.events.listeners)do after=after+1 end
    assert(count==after and #f.a.requests==1 and not f.r.runner:IsBusy())
end)
function tests.membership_index_shared_mutations_and_no_per_row_preset_scan()
    local k=Fake.Load();local saved={};local one=k.Presets.New(saved,"EU","a","one","One");local two=k.Presets.New(saved,"EU","a","two","Two")
    local p=two:NewDraft();p.name="Two preset";p.slots={[EQUIP_SLOT_RING1]={kind="item",uid="shared",link="ring"}};p=assert(two:Save(p,0))
    assert(one:Memberships("shared","all")[1].name=="Two preset");assert(#one:Memberships("shared","current")==0)
    -- Once indexed, listing membership cannot enumerate persisted preset slots per row.
    local slots=two.character.presets[p.id].slots;two.character.presets[p.id].slots=setmetatable({},{__pairs=function()error("per-row preset scan")end})
    assert(one:Memberships("shared","all")[1].name=="Two preset");two.character.presets[p.id].slots=slots
    p.name="Renamed";p=assert(two:Save(p,p.revision));local result=one:Memberships("shared","all");assert(result[1].name=="Renamed")
    result[1].name="mutated copy";assert(one:Memberships("shared","all")[1].name=="Renamed")
    k.Presets.New(saved,"EU","a","two","New character name");assert(one:Memberships("shared","all")[1].characterName=="New character name")
    assert(two:Delete(p.id,p.revision));assert(#one:Memberships("shared","all")==0)
end
function tests.modern_core_injects_services_and_refuses_incomplete_quick_or_included_attributes()
    local f={modern=true};local ok,err=pcall(function()
        setup(f);assert(f.r.session.services and f.r.buildRunner and f.r.buildPlanner)
        local saved,problem=f.r.session:QuickSave();assert(not saved and problem.code=="buildCapabilityUnavailable")
        local item=f:Add("target",BAG_BACKPACK,1)
        local draft=f.r.repo:NewDraft();draft.slots=nil;draft.equipment={[EQUIP_SLOT_RING1]=item};draft.attributes={health=1,magicka=0,stamina=0}
        local preset=assert(f.r.repo:Save(draft,0));local applied,why=f.r.session:Apply(preset.id)
        assert(not applied and why.code=="attributesUnavailable" and #f.a.requests==0)
        assert(f.r.session:BeginNew("inventory"));assert(f.r.session:GetView().component=="equipment");assert(f.r.session:Cancel())
    end);if f.Cleanup then f:Cleanup()end;assert(ok,err)
end
function tests.modern_core_native_actual_quick_and_foreign_pending_guard()
    local f={modern=true,nativeModern=true};local ok,err=pcall(function()
        setup(f);assert(f.r.session:QuickSave());local quick=f.r.repo:Get(f.k.Presets.QUICK_ID)
        assert(quick.abilities.skills["10:active:51"].morph==1 and quick.attributes.health==10 and quick.equipment)
        f.a.STATS.attributeControls[1].pointLimitedSpinner.addedPoints=1
        f.a.STATS.attributeControls[2].pointLimitedSpinner.addedPoints=-1
        local saved,problem=f.r.session:QuickSave();assert(not saved and problem.code=="foreignAttributeDraft")
        assert(f.r.repo:Get(f.k.Presets.QUICK_ID).revision==quick.revision)
        f.a.STATS.attributeControls[1].pointLimitedSpinner.addedPoints=0;f.a.STATS.attributeControls[2].pointLimitedSpinner.addedPoints=0
        assert(f.r.session:BeginNew("stats"));assert(f.r.session:Save());assert(f.native.attributeSends==0 and #f.native.requests.skills==0)
        local seen;f.r.events:Subscribe("NativeAttributeRespecResult",function(payload)seen=payload.result end)
        for _,entry in pairs(f.a.EVENT_MANAGER.events)do if entry[1]==f.a.EVENT_ATTRIBUTE_RESPEC_RESULT then entry[2](entry[1],14)end end
        assert(seen==14)
    end);if f.Cleanup then f:Cleanup()end;assert(ok,err)
end
tests.hidden_preset_list_does_not_refresh_skills_during_equipment_edit=modernTest(function(f)
    local item=f:Add('worn-ring',BAG_WORN,EQUIP_SLOT_RING1);local preset=f:Preset({[EQUIP_SLOT_RING1]=item})
    local other=f.r.repo:NewDraft();other.slots=nil;other.abilities={skills={['10:active:51']={kind='active',purchased=true,morph=1}}}
    assert(f.r.repo:Save(other,0));f.r.ui:Refresh()
    local read=f.k.SkillState.ReadDisplay;local calls=0
    f.k.SkillState.ReadDisplay=function(...)calls=calls+1;return read(...)end
    assert(f.r.session:BeginEdit(preset.id,false,'inventory'))
    f:Event('EVENT_SKILLS_FULL_UPDATE');f.clock:Advance(2)
    assert(f.r.session:GetView().state=='editing' and calls==0,'hidden list must not inspect skills while editing equipment')
    f.k.SkillState.ReadDisplay=read
    assert(f.r.session:Cancel())
end)
tests.native_skill_block_automatically_reports_reason_and_preserves_actual_preset_match=modernTest(function(f)
    assert(f.r.session:QuickSave());local quick=f.r.repo:Get(f.k.Presets.QUICK_ID)
    local draft=f.r.repo:NewDraft();draft.abilities=quick.abilities;draft.attributes=quick.attributes
    local preset=assert(f.r.repo:Save(draft,0))
    local reports={};f.r.buildProbe.report=function(text)reports[#reports+1]=text end
    f.native.foreignPending=true
    f.a.SKILL_LINE_ASSIGNMENT_MANAGER={IsAnyChangePending=function()return true end}
    local ok,problem=f.r.ui:Command('Apply',preset.id)
    assert(not ok and problem.code=='foreignSkillDraft')
    assert(#reports==1 and reports[1]:find('lines.pending=true',1,true))
    assert(problem.details.nativeReasons[1]=='lines')
    assert(f.k.Dialogs.Problem(problem):find('skill lines',1,true))
    assert(not f.k.Dialogs.Problem(problem):find('Finish or discard',1,true))
    assert(f.native.foreignPending and #f.native.requests.skills==0 and #f.a.requests==0)
    assert(f.r.repo.character.buildProbeJournal.skillBlockReport==reports[1])
    assert(f.k.BuildModel.Matches(f.r.captureDisplay(),preset),'checkmark represents the actual build, independent of native pending flags')
    f.r.ui:Command('Apply',preset.id);assert(#reports==1)
end)
tests.bar_override_automatically_opens_copyable_snapshot_and_reopens_without_native_reads=modernTest(function(f)
    f.native.actualBars[1][4]={type=1,id=511}
    f.native.immutableSlots={['1:4']=true}
    f.a.ACTION_BAR_ASSIGNMENT_MANAGER:ResetPlayerHotbars()
    local draft=f.r.repo:NewDraft();draft.slots=nil;draft.name='Blocked slot'
    draft.abilities={bars={back={[2]={kind='empty'}}}}
    local preset=assert(f.r.repo:Save(draft,0))
    local reports={};f.r.buildProbe.report=function(text)reports[#reports+1]=text end
    local ok,problem=f.r.ui:Command('Apply',preset.id)
    assert(not ok and problem.code=='skillBarOverride')
    assert(#reports==1,'bar refusal did not open the report')
    for _,line in ipairs({'KanaWardrobe action slot block report','action=Apply','presetName=Blocked slot',
        'slotContext.bar=back','slotContext.slot=2','slotContext.nativeSlot=4','slotContext.mutable=false',
        'slotContext.beforeAbility.id=511','slotContext.target.kind=empty','live.slot.actualId=511'})do
        assert(reports[1]:find(line,1,true),line)
    end
    assert(problem.details.nativeReportSaved and not f.native.entryRequests and #f.native.requests.skills==0 and #f.a.requests==0)
    for _=1,4 do f.r.ui:Refresh()end
    assert(#reports==1,'render repeatedly opened reports')
    f.r.ui:Command('Apply',preset.id);assert(#reports==1)
    local saved=f.r.repo.character.buildProbeJournal.skillBlockReport
    assert(saved==reports[1])
    f.a.GetSlotBoundId=function()error('saved report must not read current slots')end
    assert(f.r.buildProbe:Run('blocked'));assert(#reports==2 and reports[2]==saved)
end)
tests.equipment_preset_can_open_empty_skills_component_with_native_effective_id_difference=modernTest(function(f)
    local BF=dofile(ROOT..'/tests/support/build_fixture.lua')
    f.native.actualBars[1][4]={type=1,id=511};BF.InstallEffectiveSlotIds(f.native,{[511]=519})
    local item=f:Add('gear-only',BAG_WORN,EQUIP_SLOT_RING1);local preset=f:Preset({[EQUIP_SLOT_RING1]=item})
    assert(not preset.abilities)
    f.a.SCENE_MANAGER:Show('skills')
    local ok,problem=f.r.ui:Command('BeginEdit',preset.id,false,'skills');assert(ok,problem and problem.code)
    assert(f.r.session:GetView().component=='abilities' and f.r.session:GetView().state=='editing')
    assert(f.r.ui:Command('Cancel'));assert(f.r.session:GetView().state=='idle' and not f.r.skills:GetNativeOwnership())
    assert(not f.r.repo:Get(preset.id).abilities and #f.native.requests.skills==0 and #f.a.requests==0)
    assert(f.r.ui:Command('BeginEdit',preset.id,false,'skills'));assert(f.r.ui:Command('Save'))
    assert(f.r.session:GetView().state=='idle' and not f.r.repo:Get(preset.id).abilities)
end)
tests.build_equipment_source_is_durable_before_native_dispatch=modernTest(function(f)
    local item=f:Add('durable-ring',BAG_BACKPACK,7);local preset=f:Preset({[EQUIP_SLOT_RING1]=item})
    local send=f.a.RequestEquipItem;local observed=false
    f.a.RequestEquipItem=function(bag,slot,...)
        local pending=assert(f.r.repo.character.journal.pending)
        local source=assert(pending.batch[1].source,'source must be persisted before sending')
        assert(source.bagId==bag and source.slotIndex==slot and source.uid==item.uid)
        observed=true;return send(bag,slot,...)
    end
    assert(f.r.session:Apply(preset.id));assert(observed)
    f:Drain();assert(f.r.session:GetView().state=='idle')
end)
tests.confirmed_partial_equipment_failure_does_not_block_the_next_apply=modernTest(function(f)
    local a=f:Add('first-hat',BAG_BACKPACK,7,EQUIP_TYPE_HEAD);local b=f:Add('next-ring',BAG_BACKPACK,8)
    local preset=f:Preset({[EQUIP_SLOT_HEAD]=a,[EQUIP_SLOT_RING1]=b})
    local request=f.a.RequestEquipItem
    f.a.RequestEquipItem=function(...)
        request(...)
        if #f.a.requests==1 then f.a.bags[BAG_BACKPACK][8].unusable=true end
    end
    assert(f.r.session:Apply(preset.id))
    assert(f.r.session:GetView().state=='recovery' and #f.a.requests==1)
    assert(#f.r.repo.character.journal.pending.batch==1,'only the actually sent request may stay unresolved')
    f:ApplyRequest(1);f.applied=1;f.clock:Advance(2)
    assert(f.r.session:GetView().state=='idle' and not f.r.buildRunner:IsBusy(),'settled partial failure must release Apply')
    assert(#f.a.requests==1 and f.a.bags[BAG_WORN][EQUIP_SLOT_HEAD].uid==a.uid)
    f.a.bags[BAG_BACKPACK][8].unusable=false
    assert(f.r.session:Apply(preset.id));f:Drain()
    assert(f.r.session:GetView().state=='idle' and #f.a.requests==2)
end)
tests.reapply_after_manually_removing_one_weapon_restores_it_without_waiting_for_sheath=modernTest(function(f)
    local front=f:Add('front-sword',BAG_BACKPACK,7,EQUIP_TYPE_ONE_HAND)
    local back=f:Add('back-sword',BAG_BACKPACK,8,EQUIP_TYPE_ONE_HAND)
    local preset=f:Preset({[EQUIP_SLOT_MAIN_HAND]=front,[EQUIP_SLOT_BACKUP_MAIN]=back})
    assert(f.r.session:Apply(preset.id));f:Drain()
    assert(f.r.session:GetView().state=='idle' and f.r.ui.model.rows[1].matches)
    -- Native inventory events after manual removal invalidate the row badge.
    f.a.bags[BAG_BACKPACK][9]=f.a.bags[BAG_WORN][EQUIP_SLOT_MAIN_HAND]
    f.a.bags[BAG_WORN][EQUIP_SLOT_MAIN_HAND]=nil
    f:Event('EVENT_INVENTORY_SINGLE_SLOT_UPDATE');f.clock:Advance(2)
    assert(not f.r.ui.model.rows[1].matches)
    f.a.sheathed=false;local toggles=0
    f.a.TogglePlayerWield=function()toggles=toggles+1 end
    local requests=#f.a.requests
    assert(f.r.session:Apply(preset.id))
    assert(#f.a.requests==requests+1,'clicking the preset must issue equip immediately')
    assert(f.a.requests[requests+1][5]==EQUIP_SLOT_MAIN_HAND)
    f:Drain()
    assert(f.r.session:GetView().state=='idle' and not f.r.repo.character.journal)
    assert(f.r.ui.model.rows[1].matches and toggles==0)
    assert(f.a.bags[BAG_WORN][EQUIP_SLOT_MAIN_HAND].uid=='front-sword')
    assert(f.a.bags[BAG_WORN][EQUIP_SLOT_BACKUP_MAIN].uid=='back-sword')
    assert(f.r.session:Apply(preset.id));f:Drain()
    assert(#f.a.requests==requests+1 and f.r.session:GetView().state=='idle')
end)
tests.unsent_native_rejection_releases_session_for_another_attempt=modernTest(function(f)
    local item=f:Add('sword',BAG_BACKPACK,7,EQUIP_TYPE_ONE_HAND)
    local preset=f:Preset({[EQUIP_SLOT_MAIN_HAND]=item})
    f.a.sheathed=false;f.a.TogglePlayerWield=function()error('must not toggle wield')end
    local equipable=f.a.IsEquipable
    f.a.IsEquipable=function()return false,123 end
    assert(f.r.session:Apply(preset.id))
    assert(f.r.session:GetView().state=='idle' and not f.r.repo.character.journal,'unsent failure must release the operation')
    assert(#f.a.requests==0)
    f.a.IsEquipable=equipable
    assert(f.r.session:Apply(preset.id));f:Drain()
    assert(f.r.session:GetView().state=='idle' and f.a.bags[BAG_WORN][EQUIP_SLOT_MAIN_HAND].uid==item.uid)
end)

tests.late_batch_confirmation_releases_apply_only_after_all_items_arrive=modernTest(function(f)
    local a=f:Add('late-hat',BAG_BACKPACK,7,EQUIP_TYPE_HEAD);local b=f:Add('late-ring',BAG_BACKPACK,8)
    local preset=f:Preset({[EQUIP_SLOT_HEAD]=a,[EQUIP_SLOT_RING1]=b})
    assert(f.r.session:Apply(preset.id));assert(#f.a.requests==2)
    f.clock:Advance(5001);assert(f.r.session:GetView().state=='recovery' and #f.a.requests==2)
    f:ApplyRequest(1);f.applied=1;f.clock:Advance(2)
    assert(f.r.session:GetView().state=='recovery' and #f.a.requests==2)
    f:ApplyRequest(2);f.applied=2;f.clock:Advance(2);f:Drain()
    assert(f.r.session:GetView().state=='idle' and #f.a.requests==2)
    assert(f.a.bags[BAG_WORN][EQUIP_SLOT_RING1].uid==b.uid)
end)
tests.late_first_stage_confirmation_resumes_remaining_gear_without_reload=modernTest(function(f)
    f:Add('greatsword',BAG_WORN,EQUIP_SLOT_MAIN_HAND,EQUIP_TYPE_TWO_HAND)
    local a=f:Add('sword',BAG_BACKPACK,7,EQUIP_TYPE_ONE_HAND)
    local b=f:Add('dagger',BAG_BACKPACK,8,EQUIP_TYPE_ONE_HAND)
    local preset=f:Preset({[EQUIP_SLOT_MAIN_HAND]=a,[EQUIP_SLOT_OFF_HAND]=b})
    assert(f.r.session:Apply(preset.id));assert(#f.a.requests==1)
    f.clock:Advance(5001);assert(f.r.session:GetView().state=='recovery')
    f:ApplyRequest(1);f.applied=1;f.clock:Advance(2)
    assert(#f.a.requests==2 and f.a.requests[2][5]==EQUIP_SLOT_OFF_HAND)
    f:Drain();assert(f.r.session:GetView().state=='idle' and not f.r.repo.character.journal)
    assert(f.a.bags[BAG_WORN][EQUIP_SLOT_MAIN_HAND].uid==a.uid and f.a.bags[BAG_WORN][EQUIP_SLOT_OFF_HAND].uid==b.uid)
end)
tests.equipment_editor_and_apply_never_read_unrelated_build_domains=modernTest(function(f)
    local target=f:Add('equipment-only',BAG_BACKPACK,7)
    local preset=f:Preset({[EQUIP_SLOT_RING1]=target})
    f.r.skills.Catalogue=function()error('equipment must not scan skills')end
    f.r.attributes.Capture=function()error('equipment must not read attributes')end
    f.a.SKILLS_AND_ACTION_BAR_MANAGER.HasAnyPendingChanges=function()error('equipment must not check native skills draft')end
    assert(f.r.session:BeginEdit(preset.id,false,'inventory'))
    f:Drain();assert(f.r.session:GetView().state=='editing')
    assert(f.r.session:Save());f:Drain();assert(f.r.session:GetView().state=='idle')
    assert(f.r.session:Apply(preset.id));f:Drain();assert(f.r.session:GetView().state=='idle')
end)
tests.complete_preset_runs_from_each_page=modernTest(function(f)
    for _,page in ipairs({'inventory','skills','stats'})do
        local target=f:Add('target-'..page,BAG_BACKPACK,7)
        f.native.skillObjects[1].spec.morph=1;f.native.actualBars[0][3]=nil;f.native.actualBars[1][3]=nil
        f.native.api.SKILLS_AND_ACTION_BAR_MANAGER:ResetRespecState()
        -- Fixture initialization represents settled actuals, with no player's native draft.
        f.native.api.SKILLS_AND_ACTION_BAR_MANAGER.isDirty=false
        f.native.actualAttributes={10,20,34};f.native.attributeUnspent=2;f.native:ResetAttributesNative()
        f.a.SCENE_MANAGER:Show(page)
        assert(f.r.session:GetView().page==page)
        local draft=f.r.repo:NewDraft();draft.slots=nil;draft.name='Complete '..page
        draft.equipment={[EQUIP_SLOT_RING1]=target}
        draft.abilities={skills={['10:active:51']={kind='active',purchased=true,morph=2}},bars={
            front={[1]={kind='skill',skillKey='10:active:51',expectedMorph=2}},
            back={[1]={kind='skill',skillKey='10:active:51',expectedMorph=2}}}}
        draft.attributes={health=0,magicka=0,stamina=64}
        local preset=assert(f.r.repo:Save(draft,0));local before=#f.a.requests
        local skillBefore=#f.native.requests.skills;local attrBefore=f.native.attributeSends
        assert(f.r.session:Apply(preset.id));assert(f.native.entryRequests and f.a.SCENE_MANAGER.page=='skills')
        assert(#f.native.requests.skills==skillBefore and f.native.attributeSends==attrBefore and #f.a.requests==before)
        local manager=f.a.SKILLS_AND_ACTION_BAR_MANAGER
        manager:SetSkillPointAllocationMode(f.a.SKILL_POINT_ALLOCATION_MODE_FULL);manager:SetSkillRespecPaymentType(f.a.RESPEC_PAYMENT_TYPE_GOLD)
        f:Event('EVENT_START_SKILL_RESPEC',manager.mode,manager.payment);f.clock:Advance(2)
        assert(#f.native.requests.skills==skillBefore+1,'real native entry event must reach the Core bridge')
        assert(f.native.attributeSends==attrBefore and #f.a.requests==before)
        local packet=f.native.requests.skills[skillBefore+1]
        assert(#packet.skills==1 and packet.skills[1].morph==2 and #packet.bars==18)
        local assigned=0
        for _,slot in ipairs(packet.bars)do
            if slot.kind~=f.a.ACTION_TYPE_NOTHING then
                assert(slot.slot==3 and (slot.bar==0 or slot.bar==1) and slot.id==512);assigned=assigned+1
            end
        end
        assert(assigned==2)
        f.native.skillObjects[1].spec.morph=2;f.native.actualBars[0][3]={type=1,id=512};f.native.actualBars[1][3]={type=1,id=512}
        manager:ResetInterface();f:Event('EVENT_SKILL_RESPEC_RESULT',0);f.clock:Advance(101)
        assert(f.native.attributeSends==attrBefore+1 and #f.a.requests==before)
        local attr=f.native.requests.attributes[attrBefore+1].payload
        assert(attr.health==-10 and attr.magicka==-20 and attr.stamina==30)
        f.native.actualAttributes={0,0,64};f.native.attributeUnspent=2;f.native:ResetAttributesNative()
        f:Event('EVENT_ATTRIBUTE_RESPEC_RESULT',0);f.clock:Advance(101);f:Drain()
        assert(#f.a.requests==before+1 and f.a.bags[BAG_WORN][EQUIP_SLOT_RING1].uid=='target-'..page)
        local actual=f.r.session.services.capture()
        assert(f.k.BuildModel.Matches(actual,preset) and actual.attributes.health==0 and actual.attributes.stamina==64)
        assert(f.r.session:GetView().state=='idle' and not f.r.buildRunner:IsBusy() and not f.r.runner:IsBusy())
        assert(f.r.repo.character.journal==nil and f.r.repo:Get(preset.id).revision==preset.revision)
    end
end)
tests.complete_noop_has_no_wait_and_no_requests=modernTest(function(f)
    local draft=f.r.repo:NewDraft();local actual=f.r.session.services.capture()
    draft.slots=nil;draft.equipment=actual.equipment;draft.abilities=actual.abilities;draft.attributes=actual.attributes
    local preset=assert(f.r.repo:Save(draft,0))
    assert(f.r.session:Apply(preset.id))
    assert(f.r.session:GetView().state=='idle' and f.r.repo.character.journal==nil and not f.r.buildRunner:IsBusy())
    assert(not f.r.runner:IsBusy() and f.r.skills:GetSubmissionState().phase=='idle' and f.r.attributes:GetSubmissionState().phase=='idle',
        'no-op must complete synchronously without native waiting')
    assert(#f.a.requests==0 and #f.native.requests.skills==0 and f.native.attributeSends==0 and not f.native.entryRequests)
end)
function tests.unsupported_new_api_keeps_legacy_inventory_working()
    local f={modern=true};local ok,err=pcall(function()
        setup(f);assert(not f.r.buildCapabilities.skills and not f.r.buildCapabilities.attributes)
        local target=f:Add('legacy',BAG_BACKPACK,1);local preset=f:Preset({[EQUIP_SLOT_RING1]=target})
        assert(f.r.session:Apply(preset.id));f:Drain()
        assert(f.a.bags[BAG_WORN][EQUIP_SLOT_RING1].uid=='legacy' and f.r.session:GetView().state=='idle')
        assert(f.r.repo:Memberships('legacy','current')[1].presetId==preset.id)
        f.a.ItemTooltip:SetBagItem(BAG_WORN,EQUIP_SLOT_RING1);assert(f.a.ItemTooltip.lines[2]:find(preset.name,1,true))
        local mixed=f.r.repo:NewDraft();mixed.slots=nil;mixed.equipment=preset.equipment
        mixed.abilities={skills={['10:active:51']={kind='active',purchased=true,morph=2}}}
        mixed=assert(f.r.repo:Save(mixed,0));local before=#f.a.requests
        local accepted,problem=f.r.session:Apply(mixed.id)
        assert(not accepted and problem.code=='skillsUnavailable' and #f.a.requests==before)
        assert(f.r.session:BeginNew('inventory'));assert(f.r.session:Cancel())
    end);if f.Cleanup then f:Cleanup()end;assert(ok,err)
end
tests.native_use_and_bank_actions_keep_original_identity=modernTest(function(f)
    local target=f:Add('native',BAG_BACKPACK,1);f:Preset({[EQUIP_SLOT_RING1]=target})
    local function primary(bag)
        assert(f.a.ZO_InventorySlot_DiscoverSlotActionsFromActionList==f.nativeDiscover)
        assert(f.a.ZO_InventorySlotActions.DoPrimaryAction==f.nativePrimary)
        local control={bagId=bag,slotIndex=1};local actions={AddSlotAction=function(self,_,callback)self.callback=callback end}
        f.a.ZO_InventorySlot_DiscoverSlotActionsFromActionList(control,actions)
        f.a.ZO_InventorySlotActions.DoPrimaryAction(actions,control)
    end
    primary(BAG_BACKPACK);assert(f.used==1 and f.a.bags[BAG_BACKPACK][1].uid=='native')
    f.a.bankOpen=true;f:Event('EVENT_OPEN_BANK');primary(BAG_BACKPACK)
    assert(f.a.bags[BAG_BANK][1].uid=='native' and not f.a.bags[BAG_BACKPACK][1])
    f:Event('EVENT_INVENTORY_SINGLE_SLOT_UPDATE');primary(BAG_BANK)
    assert(f.a.bags[BAG_BACKPACK][1].uid=='native' and not f.a.bags[BAG_BANK][1])
    f.a.bankOpen=false;f:Event('EVENT_CLOSE_BANK');f:Reload();primary(BAG_BACKPACK)
    assert(f.used==2 and #f.a.requests==0 and #f.native.requests.skills==0 and f.native.attributeSends==0)
end)
tests.native_actual_changes_refresh_shared_rows_with_domain_revisions_and_one_capture=modernTest(function(f)
    local skill=f.r.repo:NewDraft();skill.slots=nil;skill.abilities={skills={['10:active:51']={kind='active',purchased=true,morph=1}}}
    skill=assert(f.r.repo:Save(skill,0))
    local attr=f.r.repo:NewDraft();attr.slots=nil;attr.attributes={health=10,magicka=20,stamina=34}
    attr=assert(f.r.repo:Save(attr,0));f.clock:Advance(2)
    assert(f.r.ui:FindRow(skill.id).matches and f.r.ui:FindRow(attr.id).matches)
    local changed={};f.r.events:Subscribe('BuildActualChanged',function(payload)changed[#changed+1]=payload end)
    local capture=f.r.ui.services.captureActual;local captures=0
    f.r.ui.services.captureActual=function(...)captures=captures+1;return capture(...)end
    local catalogue=f.r.skills.Catalogue;local attributes=f.r.attributes.Capture;local inventory=f.r.inventory.Capture
    f.r.skills.Catalogue=function()error('catalogue in native invalidation callback')end
    f.r.attributes.Capture=function()error('attributes in native invalidation callback')end
    f.r.inventory.Capture=function()error('inventory in native invalidation callback')end
    f.native.skillObjects[1].spec.morph=2;f.native.actualAttributes={11,20,34};f.native.attributeUnspent=1
    f:Event('EVENT_SKILLS_FULL_UPDATE');f:Event('EVENT_SKILL_POINTS_CHANGED',10,9,0,0,0)
    f:Event('EVENT_HOTBAR_SLOT_UPDATED',3,0,false);f:Event('EVENT_ATTRIBUTE_UPGRADE_UPDATED')
    assert(captures==0 and #changed==4,'native updates must invalidate without full capture')
    assert(changed[1].domain=='abilities' and changed[1].revision==1 and changed[2].revision==2 and changed[3].revision==3)
    assert(changed[4].domain=='attributes' and changed[4].revision==1)
    f.r.skills.Catalogue=catalogue;f.r.attributes.Capture=attributes;f.r.inventory.Capture=inventory
    f.clock:Advance(2)
    assert(captures==1,'burst of actual changes must coalesce to one full UI capture')
    assert(not f.r.ui:FindRow(skill.id).matches and not f.r.ui:FindRow(attr.id).matches)
    local equipmentBefore=#changed;f:Event('EVENT_INVENTORY_SINGLE_SLOT_UPDATE')
    assert(#changed==equipmentBefore+1 and changed[#changed].domain=='equipment' and changed[#changed].revision==1)
    assert(#f.a.requests==0 and #f.native.requests.skills==0 and f.native.attributeSends==0)
end)
tests.preset_list_never_reads_equipment_constraints_or_allocation_catalogue=modernTest(function(f)
    local item=f:Add('display-gear',BAG_WORN,EQUIP_SLOT_RING1)
    local p=assert(f:Preset({[EQUIP_SLOT_RING1]=item}))
    local full=f.r.skills.Catalogue
    f.r.skills.Catalogue=function()error('list traversed allocation catalogue')end
    f.r.inventory.Metadata=function()error('list read equipment constraints')end
    for _=1,4 do f.r.ui:Refresh()end
    assert(f.r.ui:FindRow(p.id).matches)
    -- Selecting a skills preset still shows actual morphs; no allocation data is needed.
    local s=f.r.repo:NewDraft();s.slots=nil
    s.abilities={skills={['10:active:51']={kind='active',purchased=true,morph=1}}}
    s=assert(f.r.repo:Save(s,0));f.r.ui:Refresh()
    assert(f.r.ui:FindRow(s.id).matches)
    f.r.skills.Catalogue=full
end)
tests.display_cache_reuses_unchanged_domains_and_updates_only_changed_state=modernTest(function(f)
    local p=f.r.repo:NewDraft();p.slots=nil
    p.abilities={skills={['10:active:51']={kind='active',purchased=true,morph=1}}}
    p.attributes={health=10,magicka=20,stamina=34};p=assert(f.r.repo:Save(p,0))
    f.clock:Advance(2);assert(f.r.ui:FindRow(p.id).matches)
    local skillReads,attributeReads,inventoryReads=0,0,0
    local iterator=f.a.SKILLS_DATA_MANAGER.SkillTypeIterator
    f.a.SKILLS_DATA_MANAGER.SkillTypeIterator=function(self,...)skillReads=skillReads+1;return iterator(self,...)end
    local attrs=f.r.attributes.Capture
    f.r.attributes.Capture=function(self,...)attributeReads=attributeReads+1;return attrs(self,...)end
    local inv=f.r.inventory.Capture
    f.r.inventory.Capture=function(self,...)inventoryReads=inventoryReads+1;return inv(self,...)end
    for _=1,4 do f.r.ui:Refresh()end
    assert(skillReads==0 and attributeReads==0 and inventoryReads==0,'opening an unchanged list rescanned actual state')
    f:Event('EVENT_INVENTORY_SINGLE_SLOT_UPDATE');f.clock:Advance(2)
    assert(skillReads==0 and attributeReads==0,'moving gear reread unrelated skill/attribute domains')
    f.native.skillObjects[1].spec.morph=2
    f:Event('EVENT_SKILLS_FULL_UPDATE');f.clock:Advance(2)
    assert(skillReads==1 and not f.r.ui:FindRow(p.id).matches)
    f.native.actualAttributes={11,20,34};f.native.attributeUnspent=1
    f:Event('EVENT_ATTRIBUTE_UPGRADE_UPDATED');f.clock:Advance(2)
    assert(skillReads==1 and attributeReads==1)
    assert(#f.a.requests==0 and #f.native.requests.skills==0 and f.native.attributeSends==0)
end)
tests.recovery_page_open_does_not_rebuild_allocation_catalogues=modernTest(function(f)
    local actual=f.r.session.services.capture()
    f.r.repo.character.journal={version=2,kind='apply',operation='apply',state='recovery',phase='skills',
        original=actual,target={abilities=actual.abilities},confirmed={},maySent=true,
        pending={phase='dispatching',token=1,sent=false,original=actual.abilities,target=actual.abilities}}
    f:Reload()
    local reads=0;local catalogue=f.r.skills.Catalogue
    f.r.skills.Catalogue=function(self,...)reads=reads+1;return catalogue(self,...)end
    for _,page in ipairs({'skills','inventory','stats'})do
        f.a.SCENE_MANAGER:Show(page);f.clock:Advance(2)
        f.r.pages:RefreshOwnership();f.r.ui:Refresh()
        assert(f.r.ui.model.view.state=='recovery' and f.r.ui.model.view.recovery,'recovery entry vanished')
    end
    assert(reads==0,'opening recovery pages rebuilt the catalogue '..reads..' times')
    assert(#f.native.requests.skills==0 and f.native.attributeSends==0)
end)
tests.apply_checks_fresh_actual_even_when_display_cache_is_unchanged=modernTest(function(f)
    local p=f.r.repo:NewDraft();p.slots=nil
    p.abilities={skills={['10:active:51']={kind='active',purchased=true,morph=1}}}
    p=assert(f.r.repo:Save(p,0));f.clock:Advance(2)
    assert(f.r.ui:FindRow(p.id).matches)
    -- No invalidation delivered yet: mutation must never trust the presentation snapshot.
    f.native.skillObjects[1].spec.morph=2
    assert(f.r.session:Apply(p.id))
    assert(f.r.session:GetView().state~='idle' and f.native.entryRequests==1)
end)
tests.activation_and_line_changes_refresh_display_without_losing_inventory_activation=modernTest(function(f)
    local p=f.r.repo:NewDraft();p.slots=nil
    p.abilities={skills={['10:active:51']={kind='active',purchased=true,morph=1}}}
    p.attributes={health=10,magicka=20,stamina=34};p=assert(f.r.repo:Save(p,0))
    f.clock:Advance(2);assert(f.r.ui:FindRow(p.id).matches)
    f.native.skillObjects[1].spec.morph=2;f.native.actualAttributes={11,20,34}
    local eqRevision=f.r.actualRevisions.equipment
    f:Event('EVENT_PLAYER_ACTIVATED');f.clock:Advance(2)
    local actual=f.r.ui.services.captureActual()
    assert(actual.attributes.health==11 and actual.abilities.skills['10:active:51'].morph==2)
    assert(f.r.actualRevisions.equipment==eqRevision+1,'lost the inventory player-activated handler')
    f.native.skillObjects[1].spec.morph=1
    f:Event('EVENT_SKILL_RANK_UPDATE',1,10);f.clock:Advance(2)
    actual=f.r.ui.services.captureActual()
    assert(actual.abilities.skills['10:active:51'].morph==1)
end)
tests.gear_native_transition_waits_for_restore_and_continue_keeps_original_scene=modernTest(function(f)
    local manager=f.a.SCENE_MANAGER;manager:Show('inventory')
    local old=f:Add('original',BAG_WORN,EQUIP_SLOT_RING1);local new=f:Add('preview',BAG_BACKPACK,1)
    local dialog,prompts;prompts=0
    f.k.Dialogs.CloseEditor=function(save,cancel,continue)prompts=prompts+1;dialog={save=save,cancel=cancel,continue=continue};return {active=true}end
    local native=manager:GetScene('inventory');local originalSet=native.SetHideSceneConfirmationCallback
    assert(f.r.session:BeginNew('inventory'));assert(f.r.session:SetName('Before leaving'))
    manager:Show('skills');assert(prompts==1 and manager.page=='inventory');dialog.continue();assert(manager.page=='inventory' and not native.hideSceneConfirmationNextSceneName and f.r.session:GetView().state=='editing')
    -- Manual native gear experiment; only the restoration is requested by Save.
    f.a.bags[BAG_WORN][EQUIP_SLOT_RING1],f.a.bags[BAG_BACKPACK][1]=f.a.bags[BAG_BACKPACK][1],f.a.bags[BAG_WORN][EQUIP_SLOT_RING1]
    f.r.inventory:Refresh();assert(f.r.session:SwitchPage('stats'));assert(prompts==2 and manager.page=='inventory')
    local stale=dialog;dialog.save();assert(manager.page=='inventory' and f.r.session:GetView().state=='restoring' and #f.a.requests==1)
    manager:Show('skills');f.r.ui:CloseEditor();assert(prompts==2);stale.save();stale.cancel();assert(#f.a.requests==1)
    f:Drain();assert(manager.page=='skills' and f.r.session:GetView().state=='idle' and not native:HasHideSceneConfirmation() and not native.hideSceneConfirmationNextSceneName)
    assert(f.r.repo:List()[1].equipment[EQUIP_SLOT_RING1].uid==new.uid and f.a.bags[BAG_WORN][EQUIP_SLOT_RING1].uid==old.uid)
    stale.save();stale.cancel();assert(#f.a.requests==1 and native.SetHideSceneConfirmationCallback==originalSet)
    assert(#f.native.requests.skills==0 and f.native.attributeSends==0)
end)
tests.gear_native_restore_failure_rejects_pending_exit_and_preserves_recovery=modernTest(function(f)
    local manager=f.a.SCENE_MANAGER;manager:Show('inventory');local native=manager:GetScene('inventory')
    f:Add('original',BAG_WORN,EQUIP_SLOT_RING1);f:Add('preview',BAG_BACKPACK,1)
    local dialog;f.k.Dialogs.CloseEditor=function(save,cancel,continue)dialog={save=save,cancel=cancel,continue=continue};return {active=true}end
    assert(f.r.session:BeginNew('inventory'))
    f.a.bags[BAG_WORN][EQUIP_SLOT_RING1],f.a.bags[BAG_BACKPACK][1]=f.a.bags[BAG_BACKPACK][1],f.a.bags[BAG_WORN][EQUIP_SLOT_RING1];f.r.inventory:Refresh()
    manager:Show('skills');dialog.cancel();assert(f.r.session:GetView().state=='restoring' and manager.page=='inventory')
    f.r.runner:Stop('stopped');f.clock:Advance(2)
    assert(f.r.session:GetView().state=='recovery' and f.r.repo.character.journal and manager.page=='inventory')
    assert(not native.hideSceneConfirmationNextSceneName and not f.r.ui.closeDecision and #f.r.repo:List()==0)
    dialog.save();assert(#f.a.requests==1 and #f.native.requests.skills==0 and f.native.attributeSends==0)
end)
local function operationTest(body)
 return function()
  local f={modern=true,nativeModern=true,stepwise=true}
  local ok,err=xpcall(function()setup(f);body(f)end,function(err)return debug.traceback(tostring(type(err)=='table' and err.code or err),2)end)
  if f.Cleanup then f:Cleanup()end;assert(ok,err)
 end
end
tests.operation_skill_refusal_persists_fresh_diagnostics_without_opening_another_window=operationTest(function(f)
 local p=f.r.repo:NewDraft();p.slots=nil;p.name='Diagnostic build'
 p.abilities={skills={['10:active:51']={kind='active',purchased=true,morph=2}}}
 p=assert(f.r.repo:Save(p,0))
 f.r.repo.character.buildProbeJournal.skillBlockReport='old recovery report'
 local popups=0;f.r.buildProbe.report=function()popups=popups+1 end
 local global=f.a.SKILLS_AND_ACTION_BAR_MANAGER;global.isDirty=true
 assert(f.r.ui:Command('BeginEdit',p.id,false,'skills'));f.clock:Advance(5)
 local op=f.r.repo.character.operation;local problem=op.steps[1].problem
 assert(op.status=='failed' and problem.code=='foreignSkillDraft')
 local report=problem.details.nativeReport
 assert(type(report)=='string' and report:find('dirty=true',1,true),'async failure lost fresh native evidence')
 assert(report:find('operation.id='..op.id,1,true) and report:find('action=edit',1,true))
 assert(f.r.repo.character.buildProbeJournal.skillBlockReport==report and popups==0)
 assert(f.k.Dialogs.Problem(problem):find('unsent-change',1,true))
 global.isDirty=false;global.mode=f.a.SKILL_POINT_ALLOCATION_MODE_FULL
 assert(f.r.session.operations:Continue());f.clock:Advance(5)
 op=f.r.repo.character.operation
 assert(op.steps[1].problem.details.nativeReport:find('reasons=mode',1,true),'retry reused old diagnostics')
 assert(op.steps[1].attempts[1].problem.details.nativeReport==report,'retry overwrote the first attempt')
 local latest=op.steps[1].problem.details.nativeReport
 f:Reload();assert(f.r.repo.character.operation.steps[1].problem.details.nativeReport==latest)
 assert(#f.native.requests.skills==0 and #f.a.requests==0 and popups==0)
end)
tests.operation_runtime_orders_gear_attributes_talents_then_each_bar=operationTest(function(f)
 for _,page in ipairs({'inventory','skills','stats'})do
  local ring=f:Add('ring-'..page,BAG_BACKPACK,7)
  f.native.skillObjects[1].spec.morph=1;f.native.actualBars[0][3]=nil;f.native.actualBars[1][3]=nil
  f.a.SKILLS_AND_ACTION_BAR_MANAGER:ResetRespecState();f.a.SKILLS_AND_ACTION_BAR_MANAGER.isDirty=false
  f.native.actualAttributes={10,20,34};f.native:ResetAttributesNative();f.a.SCENE_MANAGER:Show(page)
  local p=f.r.repo:NewDraft();p.slots=nil;p.name='Build '..page;p.equipment={[EQUIP_SLOT_RING1]=ring}
  p.attributes={health=0,magicka=0,stamina=64}
  p.abilities={skills={['10:active:51']={kind='active',purchased=true,morph=2}},bars={front={[1]={kind='skill',skillKey='10:active:51',expectedMorph=2}},back={[1]={kind='skill',skillKey='10:active:51',expectedMorph=2}}}}
  p=assert(f.r.repo:Save(p,0));local gear=#f.a.requests;local attrs=f.native.attributeSends;local skills=#f.native.requests.skills
  assert(f.r.session.operations and not f.r.buildRunner)
  assert(f.r.session:Apply(p.id));assert(#f.a.requests==gear and f.r.repo.character.operation.index==1)
  f:DrainOperationGear();assert(#f.a.requests==gear+1 and f.native.attributeSends==attrs+1 and #f.native.requests.skills==skills)
  f.native.actualAttributes={0,0,64};f.native:ResetAttributesNative();f:Event('EVENT_ATTRIBUTE_RESPEC_RESULT',0);f.clock:Advance(10)
  local manager=f.a.SKILLS_AND_ACTION_BAR_MANAGER
  manager:SetSkillPointAllocationMode(f.a.SKILL_POINT_ALLOCATION_MODE_FULL);manager:SetSkillRespecPaymentType(f.a.RESPEC_PAYMENT_TYPE_GOLD)
  f:Event('EVENT_START_SKILL_RESPEC',manager.mode,manager.payment);f.clock:Advance(10)
  assert(#f.native.requests.skills==skills+1)
  local talentPacket=f.native.requests.skills[skills+1];assert(talentPacket.skills[1].morph==2)
  for _,slot in ipairs(talentPacket.bars)do assert(slot.kind==f.a.ACTION_TYPE_NOTHING)end
  f.native.skillObjects[1].spec.morph=2;manager:ResetInterface();f:Event('EVENT_SKILL_RESPEC_RESULT',0);f.clock:Advance(10)
  assert(#f.native.requests.skills==skills+2)
  for index,bar in ipairs({0,1})do
   local packet=f.native.requests.skills[skills+1+index];assert(#packet.skills==0 and #packet.bars==1 and packet.bars[1].bar==bar and packet.bars[1].id==512)
   f.native.actualBars[bar][3]={type=1,id=512};manager:ResetInterface();f.a.ACTION_BAR_ASSIGNMENT_MANAGER:ResetPlayerHotbars();f:Event('EVENT_SKILL_RESPEC_RESULT',0);f.clock:Advance(10)
  end
  assert(not f.r.session.operations.operation and f.r.session:GetView().state=='idle')
  assert(f.k.BuildModel.Matches(f.r.session.services.capture(),p))
 end
end)
tests.operation_timeout_survives_reload_without_locked_list_or_auto_send=operationTest(function(f)
 local ring=f:Add('ring',BAG_BACKPACK,1);local p=f:Preset({[EQUIP_SLOT_RING1]=ring})
 f.r.session:Apply(p.id);f.clock:Advance(6000);assert(f.r.repo.character.operation.status=='failed')
 assert(f.r.ui:Refresh().rows[1].canApply)
 f:Reload();f.clock:Advance(10);assert(f.r.repo.character.operation.status=='paused' and #f.a.requests==1)
 f:ApplyRequest(1);f.applied=1;f.clock:Advance(10);assert(f.r.repo.character.operation.status=='paused')
 assert(f.r.session.operations:Continue());f:DrainOperationGear();assert(not f.r.repo.character.operation and #f.a.requests==1)
 assert(#f.r.repo.character.operationHistory==1)
end)
tests.operation_native_exit_awaits_gear_restoration=operationTest(function(f)
 local old=f:Add('old',BAG_WORN,EQUIP_SLOT_RING1);local ring=f:Add('ring',BAG_BACKPACK,1);local p=f:Preset({[EQUIP_SLOT_RING1]=ring})
 f.a.SCENE_MANAGER:Show('inventory');f.r.session:BeginEdit(p.id,false,'inventory');f:DrainOperationGear()
 assert(f.r.session:GetView().state=='editing')
 f.r.pages:RefreshOwnership()
 local dialog=f.k.Dialogs.CloseEditor
 f.k.Dialogs.CloseEditor=function(save,cancel)f.exitCancel=cancel;return {}end
 f.a.SCENE_MANAGER:Show('skills');assert(f.exitCancel and f.a.SCENE_MANAGER.page=='inventory')
 f.exitCancel();f:DrainOperationGear();f.clock:Advance(5)
 assert(f.a.SCENE_MANAGER.page=='skills' and f.a.bags[BAG_WORN][EQUIP_SLOT_RING1].uid=='old')
 f.k.Dialogs.CloseEditor=dialog
end)
return tests
