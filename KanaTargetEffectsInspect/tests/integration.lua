Tests={}
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function setup() local h=assert(loadfile(TEST_ROOT..'/tests/harness.lua'))()();h.load();return h end
function Tests.inspect_survives_target_loss_before_hudui()
    local h=setup();h.set({h.effect(1),h.effect(2,{debuff=true})})
    h.enter(function() h.set(nil) end)
    local icons=h.icons();eq(#icons,2);eq(icons[1].data.abilityId,1);eq(icons[2].data.abilityId,2)
    icons[1]:GetHandler('OnMouseEnter')(icons[1]);eq(InformationTooltip.lines[1],'Effect 1')
    assert(#InformationTooltip.lines>1);icons[1]:GetHandler('OnMouseExit')(icons[1]);eq(InformationTooltip.owner,nil)
end
function Tests.native_cursor_binding_captures_before_scene_manager_changes_current_scene()
    local h=setup();h.set({h.effect(1)});h.period(function() h.set(nil) end)
    eq(#h.icons(),1);eq(h.icons()[1].data.abilityId,1)
end
function Tests.inspect_survives_target_loss_after_hudui()
    local h=setup();h.set({h.effect(1)});h.enter();h.set(nil);eq(#h.icons(),1)
    h.exit();eq(#h.icons(),0);assert(h.native.buffPool.container:IsHidden())
end
function Tests.snapshot_copies_data_and_rejects_new_target()
    local h=setup();local e=h.effect(1);h.set({e});h.enter();e.buffName='Reused';e.abilityId=99
    h.set({h.effect(3)});eq(h.icons()[1].data.buffName,'Effect 1');eq(h.icons()[1].data.abilityId,1)
    assert(h.native.buffPool.container:IsHidden())
    h.exit();eq(#h.icons(),0);assert(not h.native.buffPool.container:IsHidden())
end
function Tests.ordinary_target_loss_does_not_resurrect_previous_icons()
    local h=setup();h.set({h.effect(1)});h.set(nil);h.enter();eq(#h.icons(),0)
end
function Tests.empty_or_hidden_effects_are_not_revealed()
    local h=setup();h.set({});h.enter();eq(#h.icons(),0);h.exit()
    h.native.contextHidden=true;h.set({h.effect(1)});h.enter();eq(#h.icons(),0)
end
function Tests.menu_from_hud_and_return_do_not_show_snapshot()
    local h=setup();h.set({h.effect(1)});SCENE_MANAGER.next=h.menu;SCENE_MANAGER:SetInUIMode(true)
    h.switch(h.menu);eq(#h.icons(),0);h.switch(HUD_UI_SCENE);eq(#h.icons(),0)
end
function Tests.menu_from_inspection_closes_owned_tooltip()
    local h=setup();h.set({h.effect(1)});h.enter();local c=h.icons()[1];c:GetHandler('OnMouseEnter')(c)
    h.switch(h.menu);eq(#h.icons(),0);eq(InformationTooltip.owner,nil);h.switch(HUD_UI_SCENE);eq(#h.icons(),0)
end
function Tests.inspect_preserves_screen_geometry_at_hud_scale()
    local h=setup();h.set({h.effect(1,{x=310,y=140,scale=1.5}),h.effect(2,{x=380,y=140,scale=1.5,debuff=true})});h.enter()
    local a,b=unpack(h.icons());eq(a:GetLeft(),310);eq(a:GetTop(),140);eq(a:GetWidth(),60);eq(a:GetHeight(),60);eq(b:GetLeft(),380)
end
function Tests.timer_reaches_zero_without_removing_icon()
    local h=setup();h.set({h.effect(1),h.effect(2,{permanent=true,duration=0})});h.enter()
    local c=h.icons()[1];eq(c.duration:GetText(),10);h.time=120;h.addon.view:Update()
    eq(c.duration:GetText(),0);eq(#h.icons(),2);assert(h.icons()[2].duration:IsHidden())
end
function Tests.reentry_uses_new_target_and_releases_pool()
    local h=setup();h.set({h.effect(1),h.effect(2)});h.enter();local first=h.icons()[1];h.exit()
    h.set({h.effect(3)});h.enter();eq(#h.icons(),1);eq(h.icons()[1].data.abilityId,3);eq(first:IsControlHidden() or first.data.abilityId==3,true)
end
function Tests.deactivation_and_gamepad_clear_snapshot()
    local h=setup();h.set({h.effect(1)});h.enter();h.emit(EVENT_PLAYER_DEACTIVATED);eq(#h.icons(),0)
    h.exit();h.set({h.effect(2)});h.enter();h.gamepad=true;h.emit(EVENT_GAMEPAD_PREFERRED_MODE_CHANGED);eq(#h.icons(),0)
end
function Tests.player_container_and_original_updates_remain_live()
    local h=setup();local playerUpdate=h.player.Update;local playerVisible=h.player.RefreshContainerVisibility
    h.set({h.effect(1)});h.enter();local before=h.native.updates;h.native:Update();eq(h.native.updates,before+1)
    eq(h.player.Update,playerUpdate);eq(h.player.RefreshContainerVisibility,playerVisible)
end
function Tests.direct_camera_event_uses_prepared_native_snapshot()
    local h=setup();h.set({h.effect(1)});h.cursor=true;h.set(nil);h.emit(EVENT_GAME_CAMERA_UI_MODE_CHANGED);h.switch(HUD_UI_SCENE)
    eq(#h.icons(),1)
end
function Tests.delayed_direct_camera_event_preserves_snapshot()
    local h=setup();h.set({h.effect(1)});h.cursor=true;h.set(nil)
    h.switch(HUD_UI_SCENE);h.emit(EVENT_GAME_CAMERA_UI_MODE_CHANGED)
    eq(#h.icons(),1)
end
function Tests.render_failure_restores_native_visibility_once()
    local h=setup();h.set({h.effect(1)});h.native.styleObject.SetupIcon=function() error('broken style') end
    h.enter();eq(#h.icons(),0);assert(not h.native.buffPool.container:IsHidden());eq(#h.messages,1)
    h.exit();h.enter();eq(#h.messages,1)
end
function Tests.hide_does_not_clear_another_tooltip()
    local h=setup();h.set({h.effect(1)});h.enter();InitializeTooltip(InformationTooltip,GuiRoot);h.exit();eq(InformationTooltip.owner,GuiRoot)
end
function Tests.missing_native_style_leaves_original_container_intact()
    local h=assert(loadfile(TEST_ROOT..'/tests/harness.lua'))()()
    h.native.styleObject=nil;local update,refresh=h.native.Update,h.native.RefreshContainerVisibility
    h.load();eq(#h.messages,1);eq(h.native.Update,update);eq(h.native.RefreshContainerVisibility,refresh)
    h.set({h.effect(1)});assert(not h.native.buffPool.container:IsHidden())
end
function Tests.screen_resize_removes_old_geometry()
    local h=setup();h.set({h.effect(1)});h.period();h.emit(EVENT_SCREEN_RESIZED);eq(#h.icons(),0)
    assert(not h.native.buffPool.container:IsHidden())
end
function Tests.repeated_initialization_does_not_duplicate_hooks_or_icons()
    local h=setup();local update=h.native.Update
    KanaTargetEffectsInspect.Initialize('KanaTargetEffectsInspect');eq(h.native.Update,update)
    h.set({h.effect(1)});h.period();eq(#h.icons(),1)
end
