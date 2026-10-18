loadModule('Rules');loadModule('TimerLayout');loadModule('Native')
local setup=assert(loadfile(TEST_ROOT..'/tests/support/eso.lua'))()
local function fixture()
    local h=setup();local rules=KanaBuffPanels.Rules.New({},string.lower)
    local panels={calls=0};function panels:Render(groups) self.groups=groups;self.calls=self.calls+1 end
    local adapter=assert(KanaBuffPanels.Native.Bind(h.player,function() h.updated=(h.updated or 0)+1 end))
    return h,rules,panels,adapter
end
function Tests.moves_original_controls_and_keeps_native_timer_membership()
    local h,r,p,a=fixture();local id=r:AddPanel('Food');r:Assign('ability:2',id)
    h.update(h.player,{h.effect(1),h.effect(2),h.effect(3)})
    local buffs=a:GetIcons();local moved=buffs[2]
    a:Redistribute(r,p)
    assert(rawequal(p.groups[id][1],moved));eq(h.source.active[moved.key],moved)
    h.player:UpdateTime();eq(moved.timerUpdates,1)
    eq(buffs[3].anchor[2],buffs[1]);eq(buffs[3].anchor[4],5)
    eq(h.player.buffPool.container:GetWidth(),85)
end
function Tests.all_hidden_then_restored_has_no_old_geometry()
    local h,r,p,a=fixture();h.update(h.player,{h.effect(1),h.effect(2)})
    local icons=a:GetIcons();r:Hide('ability:1','one');r:Hide('ability:2','two')
    a:Redistribute(r,p);eq(h.player.buffPool.container:GetWidth(),0)
    assert(icons[1]:IsControlHidden());assert(icons[2]:IsControlHidden())
    r:Unhide('ability:1');r:Unhide('ability:2');a:Redistribute(r,p)
    eq(icons[1]:GetParent(),h.player.buffPool.container);assert(not icons[1]:IsControlHidden())
    eq(h.player.buffPool.container:GetWidth(),85);eq(icons[2].anchor[2],icons[1])
end
function Tests.pool_reuse_clears_player_ownership_before_target_acquires()
    local h,r,p,a=fixture();h.update(h.player,{h.effect(1)})
    local icon=a:GetIcons()[1];r:Hide('ability:1','one');a:Redistribute(r,p)
    h.update(h.player,{})
    h.update(h.target,{h.effect(9)})
    eq(h.target.buffPool.firstControl,icon);eq(icon.kbpOwner,nil)
    assert(not icon:IsControlHidden());eq(icon:GetParent(),h.target.buffPool.container)
    h.update(h.target,{});h.update(h.player,{h.effect(2)})
    a:Redistribute(r,p);eq(icon.kbpOwner,a);eq(icon.data.abilityId,2)
end
function Tests.native_updates_only_trigger_one_callback_and_no_timer_reflow()
    local h,r,p,a=fixture();local original=h.player.control:GetHandler('OnUpdate')
    h.update(h.player,{h.effect(1)});eq(h.updated,1)
    for i=1,120 do h.player:UpdateTime() end
    eq(h.updated,1);eq(h.player.control:GetHandler('OnUpdate'),original)
    eq(KanaBuffPanels.Native.Bind(h.player),a)
end
function Tests.group_order_and_duplicate_instances_are_preserved()
    local h,r,p,a=fixture();local id=r:AddPanel('All')
    r:Assign('ability:1',id);r:Assign('ability:2',id)
    h.update(h.player,{h.effect(1),h.effect(1)},{h.effect(2)})
    a:Redistribute(r,p);eq(#p.groups[id],3)
    assert(p.groups[id][1]~=p.groups[id][2]);eq(p.groups[id][3].data.abilityId,2)
end
function Tests.target_update_does_not_change_cached_player_order()
    local h,r,p,a=fixture();h.update(h.player,{h.effect(2),h.effect(1)})
    local before=a:GetIcons()[1];h.update(h.target,{h.effect(99)})
    a:Redistribute(r,p);eq(a:GetIcons()[1],before);eq(before.data.abilityId,2)
end
function Tests.restore_deactivates_hooks_without_changing_native_updates()
    local h,r,p,a=fixture();h.update(h.player,{h.effect(1)})
    local icon=a:GetIcons()[1];r:Hide('ability:1','one');a:Redistribute(r,p)
    a:Restore();assert(not icon:IsControlHidden());eq(icon.kbpOwner,nil)
    h.update(h.player,{h.effect(2)});eq(h.updated,1);eq(h.player.updates,2)
end
function Tests.incompatible_contract_has_no_partial_mutations()
    local h=setup();local update=h.player.Update
    h.player.debuffPool.SetCustomResetBehavior=nil
    local a,reason=KanaBuffPanels.Native.Bind(h.player)
    eq(a,nil);assert(reason);eq(h.player.Update,update);eq(h.player.kbpAdapter,nil)
end
function Tests.each_icon_is_classified_once_independent_of_panel_count()
    local h,r,p,a=fixture();for i=1,50 do r:AddPanel('Panel '..i) end
    local data={};for i=1,30 do data[i]=h.effect(i) end
    h.update(h.player,data)
    local original=r.Destination;local calls=0
    function r:Destination(key) calls=calls+1;return original(self,key) end
    a:Redistribute(r,p);eq(calls,30)
end
function Tests.custom_parent_mirrors_native_context_visibility_without_reflow()
    local h,r,p,a=fixture();h.update(h.player,{h.effect(1)})
    local root=a:GetPanelParent();eq(root:GetParent(),h.player.control)
    h.player:RefreshContainerVisibility();assert(not root:IsControlHidden())
    h.player.contextHidden=true;h.player:RefreshContainerVisibility();assert(root:IsControlHidden())
    h.player.contextHidden=false;h.player:RefreshContainerVisibility();assert(not root:IsControlHidden())
    eq(h.updated,1)
end
local function assertStockDuration(icon)
    local valid,point,relative,relativePoint=icon.duration:GetAnchor(0)
    assert(valid);eq(point,TOPLEFT);eq(relative,icon:GetNamedChild('Frame'));eq(relativePoint,BOTTOMLEFT)
    valid,point,relative,relativePoint=icon.duration:GetAnchor(1)
    assert(valid);eq(point,TOPRIGHT);eq(relative,icon:GetNamedChild('Frame'));eq(relativePoint,BOTTOMRIGHT)
    eq(icon.duration:GetWidth(),40)
    eq(icon.duration:GetHorizontalAlignment(),TEXT_ALIGN_CENTER)
end
function Tests.timer_layout_restores_before_target_pool_reuse()
    local h,r,p,a=fixture();h.update(h.player,{h.effect(1)})
    local icon=a:GetIcons()[1]
    KanaBuffPanels.TimerLayout.Apply(icon,2,{labelWidth=60,gap=5})
    eq(icon.duration:GetWidth(),60)
    h.update(h.player,{});h.update(h.target,{h.effect(9)})
    eq(h.target.buffPool.firstControl,icon);assertStockDuration(icon)
end
function Tests.timer_layout_restores_on_default_hide_and_fallback()
    for _,route in ipairs({'default','hidden','fallback'}) do
        local h,r,p,a=fixture();h.update(h.player,{h.effect(1)})
        local icon=a:GetIcons()[1]
        KanaBuffPanels.TimerLayout.Apply(icon,4,{labelWidth=60,gap=5})
        KanaBuffPanels.TimerLayout.Apply(icon,3,{labelWidth=50,gap=5})
        if route=='fallback' then a:Restore()
        else
            if route=='hidden' then r:Hide('ability:1','Effect') end
            a:Redistribute(r,p)
        end
        assertStockDuration(icon)
    end
end
function Tests.timer_layout_restores_the_original_alignment_on_bottom_or_permanent_effect()
    for _,permanent in ipairs({false,true}) do
        local h,r,p,a=fixture();h.update(h.player,{h.effect(1)})
        local icon=a:GetIcons()[1];icon.duration:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        KanaBuffPanels.TimerLayout.Apply(icon,2,{labelWidth=40,gap=5})
        eq(icon.duration:GetHorizontalAlignment(),TEXT_ALIGN_RIGHT)
        KanaBuffPanels.TimerLayout.Apply(icon,4,{labelWidth=40,gap=5})
        eq(icon.duration:GetHorizontalAlignment(),TEXT_ALIGN_CENTER)
        icon.data.permanent=permanent
        KanaBuffPanels.TimerLayout.Apply(icon,permanent and 2 or 1,{labelWidth=40,gap=5})
        eq(icon.duration:GetHorizontalAlignment(),TEXT_ALIGN_LEFT)
    end
end
