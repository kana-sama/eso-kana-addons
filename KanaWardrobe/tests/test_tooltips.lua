local Fake = dofile(ROOT .. "/tests/support/fake_eso.lua")
local unpackArgs = unpack or table.unpack

local function fixture()
    local KW = Fake.Load()
    dofile(ROOT .. "/ItemTooltips.lua")
    KW.Strings.TOOLTIP_PRESETS = "Presets: %s"
    KW.Strings.TOOLTIP_OTHER_CHARACTER = "%s (%s)"
    local api = Fake.New()
    api.LEFT, api.MODIFY_TEXT_TYPE_NONE, api.TEXT_ALIGN_LEFT = 1, 0, 0
    function api.ZO_PostHook(object, name, hook)
        local original = object[name]
        object[name] = function(...)
            local results = {original(...)}
            hook(...)
            return unpackArgs(results)
        end
    end
    function api.ZO_PostHookHandler(control, name, hook)
        local previous = control.handlers[name]
        control.handlers[name] = function(...)
            if previous then previous(...) end
            hook(...)
        end
    end
    local function tooltip()
        local tip = Fake.Control({lines={}, handlers={}, hidden=false, layouts=0})
        function tip:ClearLines()
            self.lines = {}
            if self.handlers.OnCleared then self.handlers.OnCleared(self) end
        end
        function tip:AddLine(text, font, r,g,b, anchor, modify, align, fullSize)
            self.lines[#self.lines+1] = {text=text, fullSize=fullSize}
        end
        function tip:IsHidden() return self.hidden end
        function tip:SetHidden(hidden)
            self.hidden=hidden
            if hidden and self.handlers.OnHide then self.handlers.OnHide(self) end
        end
        for _, name in ipairs({"SetBagItem", "SetWornItem", "SetItemUsingEnchantment",
            "SetLink", "SetStoreItem", "SetBuybackItem", "SetTradingHouseItem", "SetQuestItem"}) do
            tip[name] = function(self, ...)
                self:ClearLines()
                self.layouts=self.layouts+1
                self.lastMethod, self.args = name, {n=select('#', ...), ...}
                self:AddLine("Native " .. name)
            end
        end
        -- Simulates an installed extension, preserving its full native hook chain.
        api.ZO_PostHook(tip, "SetBagItem", function(self) self:AddLine("Other addon") end)
        return tip
    end
    api.ItemTooltip=tooltip()
    api.PopupTooltip=tooltip()
    api.ComparativeTooltip1=tooltip()
    api.ComparativeTooltip2=tooltip()
    api.bags[BAG_BACKPACK][4]={uid="first",link="same"}
    api.bags[BAG_BACKPACK][5]={uid="second",link="same"}
    api.bags[BAG_WORN][EQUIP_SLOT_HEAD]={uid="first",link="same"}
    api.bags[BAG_BANK][9]={uid="first",link="same"}
    api.bags[BAG_SUBSCRIBER_BANK][9]={uid="first",link="same"}
    api.bags[BAG_GUILDBANK][9]={uid="first",link="same"}
    local saved={}
    local repo=KW.Presets.New(saved,"server","account","1","Current")
    local other=KW.Presets.New(saved,"server","account","2","Other")
    local function save(name, owner)
        owner=owner or repo
        local draft=owner:NewDraft()
        draft.name=name
        draft.slots[EQUIP_SLOT_HEAD]={kind="item",uid="first",link="same"}
        return assert(owner:Save(draft,0))
    end
    local first=save("Solo")
    save("Dungeon")
    save("Solo",other)
    local service=KW.ItemTooltips.New(repo,KW.Inventory.New(api))
    assert(service:Attach()~=false)
    return {KW=KW,api=api,repo=repo,save=save,service=service,tip=api.ItemTooltip,first=first}
end

local function blocks(tip)
    local result={}
    for _,line in ipairs(tip.lines) do
        if line.text:find("Presets: ",1,true)==1 then result[#result+1]=line end
    end
    return result
end
local function block(tip, text)
    local own=blocks(tip)
    assert(#own==1, "expected one membership block, got "..#own)
    assert(own[1].text==text, "unexpected membership: "..own[1].text)
end

return {
    native_userdata_tooltips_use_control_compatible_display_hooks=function()
        local f=fixture()
        assert(type(f.tip)=="userdata")
        assert(#f.api.securePostHooks==0,"table-only SecurePostHook cannot observe native tooltip userdata")
        f.tip:SetBagItem(BAG_BACKPACK,4)
        block(f.tip,"Presets: Solo, Dungeon, Solo (Other)")
    end,
    pooled_tooltip_forgets_previous_uid=function()
        local f=fixture()
        f.tip:SetBagItem(BAG_BACKPACK,4)
        block(f.tip,"Presets: Solo, Dungeon, Solo (Other)")
        f.tip:SetLink("same")
        assert(#blocks(f.tip)==0)
        f.service:Invalidate()
        assert(f.tip.lastMethod=="SetLink" and #blocks(f.tip)==0)
        f.tip:SetBagItem(BAG_BACKPACK,5)
        assert(#blocks(f.tip)==0, "equal links do not establish instance membership")
        f.tip:SetBagItem(BAG_BACKPACK,4)
        block(f.tip,"Presets: Solo, Dungeon, Solo (Other)")
    end,
    rename_and_delete_refresh_open_tooltip_without_duplicate_lines=function()
        local f=fixture()
        f.tip:SetBagItem(BAG_BACKPACK,4,77)
        f.first.name="Renamed"
        f.first=assert(f.repo:Save(f.first,1))
        f.service:Invalidate()
        block(f.tip,"Presets: Renamed, Dungeon, Solo (Other)")
        assert(f.tip.lines[1].text=="Native SetBagItem" and f.tip.lines[2].text=="Other addon")
        assert(f.tip.args[3]==77, "native display flags must survive refresh")
        assert(f.repo:Delete(f.first.id,2))
        f.service:Invalidate()
        f.service:Invalidate()
        block(f.tip,"Presets: Dungeon, Solo (Other)")
        assert(#f.tip.lines==3)
    end,
    all_exact_native_bag_and_worn_contexts=function()
        local f=fixture()
        for _,bag in ipairs({BAG_BACKPACK,BAG_BANK,BAG_SUBSCRIBER_BANK,BAG_GUILDBANK}) do
            f.tip:SetBagItem(bag,bag==BAG_BACKPACK and 4 or 9)
            block(f.tip,"Presets: Solo, Dungeon, Solo (Other)")
        end
        f.tip:SetWornItem(EQUIP_SLOT_HEAD,BAG_WORN)
        block(f.tip,"Presets: Solo, Dungeon, Solo (Other)")
        -- The bag argument is not always BAG_WORN (e.g. companion equipment).
        f.tip:SetWornItem(EQUIP_SLOT_HEAD,999)
        assert(#blocks(f.tip)==0)
        f.tip:SetWornItem(EQUIP_SLOT_HEAD)
        block(f.tip,"Presets: Solo, Dungeon, Solo (Other)")
        f.tip:SetItemUsingEnchantment(BAG_BACKPACK,4,BAG_BACKPACK,5)
        block(f.tip,"Presets: Solo, Dungeon, Solo (Other)")
    end,
    recycled_slots_and_empty_uids_never_reuse_previous_memberships=function()
        local f=fixture()
        f.tip:SetBagItem(BAG_BACKPACK,4)
        f.api.bags[BAG_BACKPACK][4]={uid="second",link="same"}
        f.service:Invalidate()
        assert(#blocks(f.tip)==0)
        for _,uid in ipairs({"", "0"}) do
            f.api.bags[BAG_BACKPACK][4]={uid=uid,link="same"}
            f.tip:SetBagItem(BAG_BACKPACK,4)
            assert(#blocks(f.tip)==0)
        end
        f.api.bags[BAG_BACKPACK][4]={link="same"}
        f.tip:SetBagItem(BAG_BACKPACK,4)
        assert(#blocks(f.tip)==0)
    end,
    unknown_layouts_and_hidden_controls_are_not_resurrected=function()
        local f=fixture()
        for _,method in ipairs({"SetStoreItem","SetBuybackItem","SetTradingHouseItem","SetQuestItem"}) do
            f.tip:SetBagItem(BAG_BACKPACK,4)
            f.tip[method](f.tip,1)
            f.service:Invalidate()
            assert(f.tip.lastMethod==method and #blocks(f.tip)==0)
        end
        f.tip:SetBagItem(BAG_BACKPACK,4)
        f.tip:ClearLines()
        local layouts=f.tip.layouts
        f.service:Invalidate()
        assert(f.tip.layouts==layouts and #f.tip.lines==0)
        f.tip:SetBagItem(BAG_BACKPACK,4)
        f.tip:SetHidden(true)
        layouts=f.tip.layouts
        f.service:Invalidate()
        assert(f.tip.layouts==layouts)
    end,
    per_tooltip_context_is_independent_and_attach_is_idempotent=function()
        local f=fixture()
        f.service:Attach()
        f.tip:SetBagItem(BAG_BACKPACK,4)
        f.api.PopupTooltip:SetLink("same")
        f.api.ComparativeTooltip1:SetWornItem(EQUIP_SLOT_HEAD,BAG_WORN)
        f.api.ComparativeTooltip2:SetBagItem(BAG_BACKPACK,5)
        f.service:Invalidate()
        block(f.tip,"Presets: Solo, Dungeon, Solo (Other)")
        block(f.api.ComparativeTooltip1,"Presets: Solo, Dungeon, Solo (Other)")
        assert(#blocks(f.api.PopupTooltip)==0 and #blocks(f.api.ComparativeTooltip2)==0)
    end,
    long_membership_list_is_complete_and_uses_wrapping=function()
        local f=fixture()
        for i=1,40 do f.save("A lengthy preset name "..i) end
        f.tip:SetBagItem(BAG_BACKPACK,4)
        local own=blocks(f.tip)
        assert(#own==1 and own[1].fullSize==true, "use the tooltip width for wrapping")
        assert(own[1].text:find("Solo, Dungeon, A lengthy preset name 1,",1,true))
        assert(own[1].text:find("A lengthy preset name 40, Solo (Other)",1,true))
    end,
    refresh_reentrancy_does_not_replay_forever=function()
        local f=fixture()
        f.api.ZO_PostHook(f.tip,"SetBagItem",function() f.service:Invalidate() end)
        f.tip:SetBagItem(BAG_BACKPACK,4)
        block(f.tip,"Presets: Solo, Dungeon, Solo (Other)")
        assert(f.tip.layouts<=2)
    end,
    save_adds_membership_to_open_unmarked_item_and_last_delete_removes_it=function()
        local f=fixture()
        f.tip:SetBagItem(BAG_BACKPACK,5)
        assert(#blocks(f.tip)==0)
        local draft=f.repo:NewDraft()
        draft.name="Second instance"
        draft.slots[EQUIP_SLOT_HEAD]={kind="item",uid="second",link="same"}
        local preset=assert(f.repo:Save(draft,0))
        f.service:Invalidate()
        block(f.tip,"Presets: Second instance")
        assert(f.repo:Delete(preset.id,1))
        f.service:Invalidate()
        assert(#blocks(f.tip)==0 and #f.tip.lines==2)
    end,
}
