local setup=assert(loadfile(TEST_ROOT..'/tests/support/eso.lua'))()
local hud=assert(loadfile(TEST_ROOT..'/tests/support/hud.lua'))()
local ui=assert(loadfile(TEST_ROOT..'/tests/support/ui.lua'))()
local function fixture(saved,hudSaved,missing)
    local h=setup();hud(h,hudSaved);ui(h)
    h.saved=saved or {};ZO_SavedVars={NewAccountWide=function(_,name,version,namespace,defaults)
        eq(name,'KanaBuffPanelsSV');eq(version,1);return h.saved
    end}
    KanaBuffPanels={}
    for _,module in ipairs({'Rules','Layout','TimerLayout','Strings','Panels','Native','Menu','Settings','Core'}) do loadModule(module) end
    if missing then missing(h) end
    local original=h.player.Update;h.emit(EVENT_ADD_ON_LOADED,'Other');eq(h.player.Update,original)
    h.emit(EVENT_ADD_ON_LOADED,'KanaBuffPanels')
    return h,KanaBuffPanels
end
local function click(h,c) c:GetHandler('OnMouseUp')(c,2,true) end
function Tests.complete_lifecycle_and_reload_keep_native_controls_and_saved_state()
    local h,a=fixture();h.materialize()
    h.option('Name').setFunc('Food');h.option('Create').func();local food=h.option('Panel').getFunc()
    h.option('Name').setFunc('Protection');h.option('Create').func();local protection=h.option('Panel').getFunc()
    h.update(h.player,{h.effect(42),h.effect(43)})
    local c=a.native:GetIcons()[1];click(h,c);h.menu[2].entries[2].callback()
    eq(c:GetParent(),h.controls['KanaBuffPanelsPanel'..food])
    click(h,c);h.menu[1].callback();assert(c:IsControlHidden())
    h.update(h.player,{});h.update(h.target,{h.effect(99)})
    eq(h.target.buffPool.firstControl.kbpOwner,nil)
    h.option('Show').func();eq(a.rules:Destination('ability:42'),food)
    h.update(h.player,{h.effect(42)});c=a.native:GetIcons()[1];eq(c:GetParent(),h.controls['KanaBuffPanelsPanel'..food])
    h.option('Panel').setFunc(food);h.option('Name').setFunc('Meals');h.option('Rename').func()
    eq(HUD_MANAGER.keyboard['KanaBuffPanelsPanel'..food].displayName(),'Meals')
    h.option('Delete').func();eq(c:GetParent(),h.player.buffPool.container)
    a.rules:Assign('ability:42',protection);a.Refresh()
    HUD_MANAGER.keyboard['KanaBuffPanelsPanel'..protection]:SetCustomOptionValue('orientation',nil,2)
    local h2,a2=fixture(h.saved,h.hudSaved);h2.update(h2.player,{h2.effect(42)})
    eq(a2.rules:Destination('ability:42'),protection);assert(not h2.controls['KanaBuffPanelsPanel'..food])
    eq(HUD_MANAGER.keyboard['KanaBuffPanelsPanel'..protection]:GetCustomOptionValue('orientation'),2)
end
function Tests.no_extra_hooks_on_repeat_and_effect_update_does_not_refresh_settings()
    local h,a=fixture();local update=h.player.Update;local before=h.settingsRefreshes
    a.Initialize('KanaBuffPanels');h.emit(EVENT_ADD_ON_LOADED,'KanaBuffPanels');eq(h.player.Update,update)
    for i=1,20 do h.update(h.player,{h.effect(i)}) end
    eq(h.settingsRefreshes,before);eq(h.player.updates,20)
    local created=h.created;local original=a.panels.Render;local render=0
    function a.panels:Render(groups) render=render+1;return original(self,groups) end
    for i=1,120 do h.player.control:GetHandler('OnUpdate')() end
    eq(h.created,created);eq(render,0)
end
function Tests.missing_hud_or_pool_contract_leaves_native_update_unmodified()
    for _,breakContract in ipairs({
        function(h) HUD_MANAGER.RegisterGamepadElement=nil end,
        function(h) h.player.debuffPool.SetCustomResetBehavior=nil end,
    }) do
        local original
        local h,a=fixture(nil,nil,function(h) original=h.player.Update;breakContract(h) end)
        eq(h.player.Update,original);eq(h.player.kbpAdapter,nil);eq(#h.messages,1)
        a.Initialize('KanaBuffPanels');eq(#h.messages,1)
        h.update(h.player,{h.effect(1)});eq(h.player.updates,1)
    end
end
function Tests.layout_failure_restores_stock_and_reports_once()
    local h,a=fixture();local id=a.rules:AddPanel('Food');a.rules:Assign('ability:1',id);a.Refresh()
    a.panels.Render=function() error('simulated incompatibility') end
    h.update(h.player,{h.effect(1)});local c=h.player.buffPool.firstControl
    eq(c:GetParent(),h.player.buffPool.container);eq(c.kbpOwner,nil);eq(#h.messages,1)
    h.update(h.player,{h.effect(2)});eq(#h.messages,1);eq(h.player.updates,2)
end
function Tests.invalid_saved_fields_normalize_and_late_hud_options_apply()
    local h,a=fixture({panels={[3]={name='Valid'},bad={}},assignments={['ability:1']=99},hidden=false,nextPanelId=1})
    eq(a.rules:Destination('ability:1'),'default');eq(a.rules.saved.nextPanelId,4)
    h.hudSaved.keyboard.KanaBuffPanelsPanel3={orientation=2,growth=2,x=30,y=20}
    HUD_MANAGER:FireCallbacks('SavedVarsReady');local root=h.controls.KanaBuffPanelsPanel3
    near(root:GetCenter(),990);eq(HUD_MANAGER.keyboard[root:GetName()].options[2].valueStringPrefix,'SI_KBP_VERTICAL')
end
function Tests.context_visibility_and_native_tooltips_survive_transfer()
    local h,a=fixture();local id=a.rules:AddPanel('Food');a.rules:Assign('ability:1',id);a.Refresh()
    h.update(h.player,{h.effect(1)});local c=a.native:GetIcons()[1]
    c:GetHandler('OnMouseEnter')(c);eq(h.tooltips,1)
    h.player.control:GetHandler('OnUpdate')();assert(not c:IsControlHidden())
    h.player.contextHidden=true;h.player:RefreshContainerVisibility();assert(c:IsControlHidden())
    h.player.contextHidden=false;h.player:RefreshContainerVisibility();assert(not c:IsControlHidden())
    h.player:UpdateTime();assert(c.timerUpdates>=1)
end
function Tests.eso_plus_zero_id_supports_menu_routing_hiding_and_reload()
    local h,a=fixture();h.materialize()
    local id=assert(a.rules:AddPanel('Account'));a.Refresh()
    local effect={isArtificial=true,effectId=0,buffName='ESO Plus Subscriber',duration=0,permanent=true}
    h.update(h.player,{effect});local icon=a.native:GetIcons()[1]
    click(h,icon);eq(#h.menu,2)
    h.menu[2].entries[2].callback();eq(icon:GetParent(),h.controls['KanaBuffPanelsPanel'..id])
    click(h,icon);h.menu[1].callback();assert(icon:IsControlHidden())
    local h2,a2=fixture(h.saved,h.hudSaved);h2.materialize();h2.update(h2.player,{effect})
    icon=a2.native:GetIcons()[1];assert(icon:IsControlHidden())
    eq(h2.option('Hidden').choicesValues[1],'artificial:0')
    h2.option('Show').func();assert(not icon:IsControlHidden())
    eq(icon:GetParent(),h2.controls['KanaBuffPanelsPanel'..id])
    click(h2,icon);h2.menu[2].entries[1].callback();eq(icon:GetParent(),h2.player.buffPool.container)
end
function Tests.timer_option_persists_separately_without_replacing_existing_hud_settings()
    local saved={nextPanelId=2,panels={[1]={name='Effects'}},assignments={['ability:1']=1},hidden={}}
    local hudSaved={keyboard={KanaBuffPanelsPanel1={orientation=2,growth=3,x=30,y=20}},gamepad={}}
    local h,a=fixture(saved,hudSaved)
    local e=HUD_MANAGER.keyboard.KanaBuffPanelsPanel1
    eq(e:GetCustomOptionValue('timerPosition'),1)
    h.update(h.player,{h.effect(1)})
    e:SetCustomOptionValue('timerPosition',nil,2)
    local gamepad=HUD_MANAGER.gamepad.KanaBuffPanelsPanel1
    eq(gamepad:GetCustomOptionValue('timerPosition'),1)
    local h2,a2=fixture(h.saved,h.hudSaved);h2.update(h2.player,{h2.effect(1)})
    e=HUD_MANAGER.keyboard.KanaBuffPanelsPanel1
    eq(e:GetCustomOptionValue('timerPosition'),2);eq(e:GetCustomOptionValue('orientation'),2);eq(e:GetCustomOptionValue('growth'),3)
    near(h2.controls.KanaBuffPanelsPanel1:GetCenter(),990)
    local valid,point,relative,relativePoint=a2.native:GetIcons()[1].duration:GetAnchor(0)
    assert(valid);eq(point,RIGHT);eq(relativePoint,LEFT)
    eq(h2.strings.SI_KBP_TIMER_POSITION1,'Снизу');eq(h2.strings.SI_KBP_TIMER_POSITION2,'Слева')
    eq(h2.strings.SI_KBP_TIMER_POSITION3,'Справа');eq(h2.strings.SI_KBP_TIMER_POSITION4,'Внутри')
end
function Tests.timer_pool_rebuilds_and_panel_deletion_restore_native_anchors()
    local h,a=fixture();local id=a.rules:AddPanel('Effects');a.rules:Assign('ability:1',id);a.Refresh()
    local e=HUD_MANAGER.keyboard['KanaBuffPanelsPanel'..id];e:SetCustomOptionValue('timerPosition',nil,4)
    h.update(h.player,{h.effect(1)});local first=a.native:GetIcons()[1];local duration=first.duration
    local created=h.created
    for i=1,20 do h.update(h.player,{h.effect(1)}) end
    eq(a.native:GetIcons()[1],first);eq(first.duration,duration);eq(h.created,created)
    local valid,point=duration:GetAnchor(0);assert(valid);eq(point,CENTER)
    a.rules:RemovePanel(id);a.Refresh();eq(first:GetParent(),h.player.buffPool.container)
    valid,point=duration:GetAnchor(0);assert(valid);eq(point,TOPLEFT)
    valid,point=duration:GetAnchor(1);assert(valid);eq(point,TOPRIGHT)
end
