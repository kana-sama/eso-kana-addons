loadModule('Rules');loadModule('Menu');loadModule('Settings')
local setup=assert(loadfile(TEST_ROOT..'/tests/support/eso.lua'))()
local ui=assert(loadfile(TEST_ROOT..'/tests/support/ui.lua'))()
local function fixture()
    local h=setup();ui(h);loadModule('Strings')
    local r=KanaBuffPanels.Rules.New({},string.lower)
    local changes=0;local function changed() changes=changes+1;if h.settings then h.settings:Refresh() end end
    return h,r,changed,function() return changes end
end
local function icon(h,r,changed)
    h.update(h.player,{h.effect(1,'First')});local c=h.player.buffPool.firstControl;c.kbpOwner={active=true}
    KanaBuffPanels.Menu.Bind(c,r,changed);return c
end
function Tests.right_click_menu_and_existing_handlers_are_preserved()
    local h,r,changed,count=fixture();h.update(h.player,{h.effect(1)})
    local c=h.player.buffPool.firstControl;c.kbpOwner={active=true};local old=0
    c:SetHandler('OnMouseUp',function() old=old+1 end)
    local enter,leave=c:GetHandler('OnMouseEnter'),c:GetHandler('OnMouseExit')
    KanaBuffPanels.Menu.Bind(c,r,changed);local mouse=c:GetHandler('OnMouseUp');KanaBuffPanels.Menu.Bind(c,r,changed)
    eq(c:GetHandler('OnMouseUp'),mouse);eq(c:GetHandler('OnMouseEnter'),enter);eq(c:GetHandler('OnMouseExit'),leave)
    mouse(c,1,true);eq(#h.menu,0);mouse(c,2,false);eq(#h.menu,0)
    mouse(c,2,true);eq(old,3);eq(h.menu[1].label,'Скрыть');eq(h.menu[2].label,'Переместить на панель')
    eq(h.menu[2].entries[1].label,'Стандартная')
end
function Tests.menu_captures_identity_even_after_control_reuse()
    local h,r,changed,count=fixture();local c=icon(h,r,changed)
    c:GetHandler('OnMouseUp')(c,2,true);local hide=h.menu[1].callback
    c.data=h.effect(2,'Second');c.kbpOwner=nil;hide()
    eq(r:Destination('ability:1'),'hidden');eq(r:Destination('ability:2'),'default');eq(count(),1)
end
function Tests.target_or_unknown_id_never_get_custom_actions()
    local h,r,changed=fixture();local c=icon(h,r,changed);c.kbpOwner=nil
    c:GetHandler('OnMouseUp')(c,2,true);eq(#h.menu,0)
    c.kbpOwner={active=true};c.data={buffName='Unknown'}
    c:GetHandler('OnMouseUp')(c,2,true);eq(#h.menu,0)
end
function Tests.menu_moves_returns_default_and_handles_deleted_destination()
    local h,r,changed=fixture();local id=r:AddPanel('Food');local c=icon(h,r,changed)
    c:GetHandler('OnMouseUp')(c,2,true);h.menu[2].entries[2].callback();eq(r:Destination('ability:1'),id)
    h.menu[2].entries[1].callback();eq(r:Destination('ability:1'),'default')
    r:RemovePanel(id);h.menu[2].entries[2].callback();eq(r:Destination('ability:1'),'default')
end
local function settings(h,r,changed)
    h.settings=KanaBuffPanels.Settings.Register(r,changed);h.materialize();return h.settings
end
function Tests.settings_create_rename_delete_and_name_validation()
    local h,r,changed=fixture();settings(h,r,changed)
    h.option('Name').setFunc('Food');h.option('Create').func();local id=h.option('Panel').getFunc()
    assert(id);eq(r.saved.panels[id].name,'Food')
    h.option('Name').setFunc('food');h.option('Create').func();eq(r.saved.nextPanelId,2);eq(#h.messages,1)
    h.option('Name').setFunc('Meals');h.option('Rename').func();eq(r.saved.panels[id].name,'Meals')
    r:Assign('ability:1',id);h.option('Delete').func();eq(r:Destination('ability:1'),'default');eq(h.option('Panel').getFunc(),nil)
    eq(h.panelData.displayName,'|cFF0000Kana|r |cFFFFFFBuff Panels|r');eq(h.panelData.name,'Kana Buff Panels')
end
function Tests.hidden_search_by_id_and_unhide_without_active_effects()
    local h,r,changed=fixture();local id=r:AddPanel('Food');r:Assign('ability:42',id)
    r:Hide('ability:42','Same');r:Hide('ability:43','Same');settings(h,r,changed)
    h.option('Search').setFunc('ability:42');eq(#h.option('Hidden').choices,1)
    assert(h.option('Hidden').choices[1]:find('42',1,true));h.option('Show').func();eq(r:Destination('ability:42'),id)
    h.option('Search').setFunc('');eq(#h.option('Hidden').choices,1)
    eq(h.option('Hidden').choicesValues[1],'ability:43')
end
function Tests.large_lists_remain_scrollable_and_last_entry_is_selectable()
    local h,r,changed=fixture()
    for i=1,60 do r:AddPanel(string.format('%02d',i)..string.rep('Long',20));r:Hide('ability:'..i,'Effect '..i) end
    settings(h,r,changed)
    local panels,hidden=h.option('Panel'),h.option('Hidden')
    assert(panels.scrollable);assert(hidden.scrollable);eq(#panels.choices,60);eq(#hidden.choices,60)
    panels.setFunc(panels.choicesValues[60]);eq(panels.getFunc(),60)
    hidden.setFunc(hidden.choicesValues[60]);eq(hidden.getFunc(),hidden.choicesValues[60])
    assert(h.panelData.registerForRefresh)
end
function Tests.settings_support_late_control_creation_and_empty_lists()
    local h,r,changed=fixture();h.settings=KanaBuffPanels.Settings.Register(r,changed)
    r:AddPanel('Late');h.settings:Refresh();h.materialize()
    eq(#KanaBuffPanelsPanel.names,1);eq(KanaBuffPanelsPanel.names[1],'Late')
    assert(h.option('Show').disabled());eq(#h.option('Hidden').choices,0)
end
