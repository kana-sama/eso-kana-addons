loadModule('Layout');loadModule('TimerLayout');loadModule('Panels')
local setup=assert(loadfile(TEST_ROOT..'/tests/support/eso.lua'))()
local hud=assert(loadfile(TEST_ROOT..'/tests/support/hud.lua'))()
local function fixture(saved)
    local h=setup();local manager=hud(h,saved)
    KanaBuffPanels.Strings={orientation='Orientation',growth='Growth'}
    local names={[1]={name='Food'}}
    local p=KanaBuffPanels.Panels.New(names,h.player.control);p:Sync()
    local root=h.controls.KanaBuffPanelsPanel1
    return h,p,names,manager,root,manager.keyboard[root:GetName()]
end
function Tests.empty_panels_register_in_both_modes_with_useful_bounds()
    local h,p,n,m,root,e=fixture();p:Render({})
    assert(e:IsValid());assert(m.gamepad[root:GetName()]:IsValid())
    assert(root.hudElementRef:GetWidth()>=40);assert(root.hudElementRef:GetHeight()>=40)
    assert(root.excluded);eq(e.displayName(),'Food');eq(root:GetParent(),h.player.control)
end
function Tests.empty_editor_preview_tracks_orientation_without_moving_or_creating_icons()
    local h,p,n,m,root,e=fixture();local x,y=root:GetCenter();local created=h.created
    for _,gamepad in ipairs({false,true}) do
        h.gamepad=gamepad;m:FireCallbacks('PropagateSettings')
        local active=gamepad and m.gamepad[root:GetName()] or e
        for axis=1,2 do for growth=1,3 do
            active:SetCustomOptionValue('orientation',nil,axis)
            active:SetCustomOptionValue('growth',nil,growth)
            local width,height=root.hudElementRef:GetDimensions()
            if axis==1 then assert(width>height) else assert(height>width) end
            near(root:GetCenter(),x);near(select(2,root:GetCenter()),y)
            assert(root:IsHidden());assert(active:IsValid());eq(h.created,created)
        end end
    end
end
function Tests.reuses_native_icons_and_preserves_anchor_on_count_changes()
    local h,p,n,m,root,e=fixture();h.update(h.player,{h.effect(1),h.effect(2)})
    local a=h.player.buffPool.firstControl;local b=h.player.buffPool.lastControl
    local x,y=root:GetCenter();p:Render({[1]={a,b}})
    eq(a:GetParent(),root);eq(b:GetParent(),root);near(b:GetLeft()-a:GetRight(),5)
    p:Render({[1]={a}});near(root:GetCenter(),x);local _,cy=root:GetCenter();near(cy,y)
end
function Tests.orientation_and_growth_use_native_options_and_reserve_labels()
    local h,p,n,m,root,e=fixture();h.update(h.player,{h.effect(1),h.effect(2)})
    local a,b=h.player.buffPool.firstControl,h.player.buffPool.lastControl
    p:Render({[1]={a,b}});e:SetCustomOptionValue('orientation',nil,2)
    near(a:GetLeft(),b:GetLeft());assert(b:GetTop()-a:GetBottom()>=25)
    e:SetCustomOptionValue('growth',nil,2);assert(b:GetTop()<a:GetTop())
    e:SetCustomOptionValue('growth',nil,3)
    near((root.hudElementRef:GetTop()+root.hudElementRef:GetBottom())/2,select(2,root:GetCenter()))
    eq(e.options[2].valueStringPrefix,'SI_KBP_VERTICAL')
end
function Tests.saved_options_load_before_or_after_panel_creation()
    for _,late in ipairs({false,true}) do
        local saved={keyboard={},gamepad={}}
        if not late then saved.keyboard.KanaBuffPanelsPanel1={orientation=2,growth=2,x=123,y=45} end
        local h,p,n,m,root,e=fixture(saved)
        if late then saved.keyboard.KanaBuffPanelsPanel1={orientation=2,growth=2,x=123,y=45} end
        m:FireCallbacks('SavedVarsReady')
        near(root:GetCenter(),1083);near(select(2,root:GetCenter()),585)
        eq(e.options[2].valueStringPrefix,'SI_KBP_VERTICAL')
    end
end
function Tests.rename_and_delete_keep_ids_but_disable_deleted_editor_entry()
    local h,p,n,m,root,e=fixture();n[1].name='New';p:Sync();eq(e.displayName(),'New')
    n[1]=nil;p:Sync();assert(not e:IsValid());assert(root:IsHidden())
    n[2]={name='Next'};p:Sync();assert(h.controls.KanaBuffPanelsPanel2)
    assert(not e:IsValid())
end
function Tests.platform_settings_are_separate_and_geometry_refreshed()
    local saved={keyboard={KanaBuffPanelsPanel1={orientation=1,growth=1}},gamepad={KanaBuffPanelsPanel1={orientation=2,growth=2}}}
    local h,p,n,m,root,e=fixture(saved)
    h.gamepad=true;m:FireCallbacks('PropagateSettings')
    eq(m.gamepad[root:GetName()].options[2].valueStringPrefix,'SI_KBP_VERTICAL')
    eq(e.options[2].valueStringPrefix,'SI_KBP_HORIZONTAL')
    eq(root.hudElementRef:GetWidth(),46)
end
function Tests.font_resize_remeasures_without_trusting_old_label_height()
    local h,p,n,m,root,e=fixture();h.update(h.player,{h.effect(1),h.effect(2)})
    local a,b=h.player.buffPool.firstControl,h.player.buffPool.lastControl
    a.duration:SetHeight(9999);p:Render({[1]={a,b}});e:SetCustomOptionValue('orientation',nil,2)
    assert(b:GetTop()-a:GetBottom()<100)
    h.fontHeight=20;m:FireCallbacks('PropagateSettings')
    assert(b:GetTop()-a:GetBottom()>=45);assert(b:GetTop()-a:GetBottom()<100)
end
function Tests.open_editor_observes_root_rect_changes_when_effects_expire()
    local h,p,n,m,root,e=fixture();h.update(h.player,{h.effect(1),h.effect(2)})
    local a,b=h.player.buffPool.firstControl,h.player.buffPool.lastControl
    p:Render({[1]={a,b}})
    local x,y=root:GetCenter();local frames=0;local width,center
    -- The native editor subscribes to the registered root, not hudElementRef.
    root:SetHandler('OnRectChanged',function()
        frames=frames+1;width=root.hudElementRef:GetWidth();center=root.hudElementRef:GetCenter()
    end)
    p:Render({[1]={a}})
    eq(frames,1);eq(width,40);near(center,x);near(root:GetCenter(),x);near(select(2,root:GetCenter()),y)
    p:Render({[1]={a}});eq(frames,1)
end
function Tests.permanent_column_does_not_reserve_invisible_duration_labels()
    local h,p,n,m,root,e=fixture()
    local one,two,three=h.effect(1),h.effect(2),h.effect(3)
    one.duration=0;two.permanent=true;three.duration=0
    h.update(h.player,{one,two,three})
    local controls={};for _,c in pairs(h.player.buffPool.activeObjects) do controls[c.data.abilityId]=c end
    p:Render({[1]=controls});e:SetCustomOptionValue('orientation',nil,2)
    near(controls[2]:GetTop()-controls[1]:GetBottom(),5)
    near(controls[3]:GetTop()-controls[2]:GetBottom(),5)
end
function Tests.timer_option_moves_the_existing_label_and_preserves_native_content()
    local h,p,n,m,root,e=fixture();h.update(h.player,{h.effect(1),h.effect(2)})
    local a,b=h.player.buffPool.firstControl,h.player.buffPool.lastControl
    local label=a.duration;label:SetText('17 m');local font=label:GetFont()
    p:Render({[1]={a,b}});e:SetCustomOptionValue('orientation',nil,2)
    eq(e.options[3].key,'timerPosition');eq(#e.options[3].values,4)
    for position=1,4 do
        e:SetCustomOptionValue('timerPosition',nil,position)
        eq(a.duration,label);eq(label:GetText(),'17 m');eq(label:GetFont(),font)
        local valid,point,relative,relativePoint=label:GetAnchor(0);assert(valid)
        if position==1 then eq(point,TOPLEFT);eq(relative,a:GetNamedChild('Frame'));eq(relativePoint,BOTTOMLEFT)
        elseif position==2 then eq(point,RIGHT);eq(relative,a);eq(relativePoint,LEFT)
        elseif position==3 then eq(point,LEFT);eq(relative,a);eq(relativePoint,RIGHT)
        else eq(point,CENTER);eq(relative,a);eq(relativePoint,CENTER);eq(label:GetHorizontalAlignment(),TEXT_ALIGN_CENTER) end
        if position>1 then near(b:GetTop()-a:GetBottom(),5) end
    end
    e:SetCustomOptionValue('timerPosition',nil,1)
    local valid,point,relative,relativePoint=label:GetAnchor(1)
    assert(valid);eq(point,TOPRIGHT);eq(relative,a:GetNamedChild('Frame'));eq(relativePoint,BOTTOMRIGHT)
    eq(label:GetHorizontalAlignment(),TEXT_ALIGN_CENTER)
end
function Tests.side_timer_text_uses_the_edge_nearest_the_icon()
    local h,p,n,m,root,e=fixture();h.update(h.player,{h.effect(1)})
    local icon=h.player.buffPool.firstControl;local label=icon.duration;label:SetText('2 ч.')
    p:Render({[1]={icon}})
    for orientation=1,2 do
        e:SetCustomOptionValue('orientation',nil,orientation)
        e:SetCustomOptionValue('timerPosition',nil,2)
        eq(label:GetHorizontalAlignment(),TEXT_ALIGN_RIGHT)
        near(icon:GetLeft()-label:GetRight(),5)
        e:SetCustomOptionValue('timerPosition',nil,3)
        eq(label:GetHorizontalAlignment(),TEXT_ALIGN_LEFT)
        near(label:GetLeft()-icon:GetRight(),5)
    end
end
function Tests.moving_a_timed_effect_keeps_the_icon_line_at_the_same_screen_edge_distance()
    for axis=1,2 do
        local h,p,n,m,root,e=fixture()
        local permanent,timed=h.effect(1),h.effect(2);permanent.permanent=true
        h.update(h.player,{permanent,timed})
        local a,b=h.player.buffPool.firstControl,h.player.buffPool.lastControl
        root:ClearAnchors();root:SetAnchor(CENTER,GuiRoot,TOPLEFT,1880,1040)
        e:SetCustomOptionValue('orientation',nil,axis)
        e:SetCustomOptionValue('growth',nil,3)
        p:Render({[1]={a}})
        local edgeGap=axis==2 and GuiRoot:GetRight()-a:GetRight() or GuiRoot:GetBottom()-a:GetBottom()
        for timerPosition=1,4 do
            e:SetCustomOptionValue('timerPosition',nil,timerPosition)
            for _,icons in ipairs({{a,b},{b,a},{a},{b},{a}}) do
                p:Render({[1]=icons})
                for _,icon in ipairs(icons) do
                    local gap=axis==2 and GuiRoot:GetRight()-icon:GetRight() or GuiRoot:GetBottom()-icon:GetBottom()
                    near(gap,edgeGap)
                end
                near(root:GetCenter(),1880);near(select(2,root:GetCenter()),1040)
            end
        end
    end
end
