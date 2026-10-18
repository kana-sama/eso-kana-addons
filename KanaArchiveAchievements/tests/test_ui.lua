local S=dofile('KanaArchiveAchievements/tests/support.lua')
dofile('KanaArchiveAchievements/Model.lua')
for _,path in ipairs({'View.lua','Controller.lua'}) do
    local file=io.open('KanaArchiveAchievements/'..path)
    assert(file,'Native view and lifecycle are not implemented: '..path);file:close();dofile('KanaArchiveAchievements/'..path)
end
local passed,failed=0,0
local function test(name,fn)
    local ok,error=pcall(fn)
    if ok then passed=passed+1 else failed=failed+1;print('FAIL: '..name..': '..tostring(error)) end
end
local function fixture(settings)
    local a,c,e=S.New();local v=KanaArchiveAchievements.View.New(a)
    a.ENDLESS_DUNGEON_BUFF_SELECTOR_KEYBOARD=a:Selector('Keyboard')
    a.ENDLESS_DUNGEON_BUFF_SELECTOR_GAMEPAD=a:Selector('Gamepad');a.ENDLESS_DUNGEON_BUFF_SELECTOR_GAMEPAD.control:SetHidden(true)
    local model={GetGoals=function(_,id)if id==1 then return {101,102,103} elseif id==2 then return {102} else return {} end end}
    local controller=KanaArchiveAchievements.Controller.Install(a,model,v,settings)
    return a,v,a.ENDLESS_DUNGEON_BUFF_SELECTOR_KEYBOARD,controller,e
end
test('achievement markers and tooltips can be disabled independently',function()
    local a,v,s=fixture({indicators=false,tooltips=true})
    s:OnShowing();s:SelectBuff(s.buffControls[1])
    assert(s.buffControls[1].kanaArchiveIndicator==nil and #a.nativeInstances==3)

    a,v,s=fixture({indicators=true,tooltips=false})
    s:OnShowing();s:SelectBuff(s.buffControls[1])
    assert(s.buffControls[1].kanaArchiveIndicator and #a.nativeInstances==0 and v.root:IsHidden())
end)
test('complete native goal instances own independent pools',function()
    local a,v,s=fixture();s:OnShowing();s:SelectBuff(s.buffControls[1])
    assert(#a.nativeInstances==3 and a.nativeInstances[1].id==101 and a.nativeInstances[3].id==103)
    assert(a.nativeInstances[1].pools[1]~=a.nativeInstances[2].pools[1])
    assert(a.nativeInstances[1].progress=='progress:101' and a.nativeInstances[1].timestamp==10100)
end)
test('embedded cards use native achievement rendering and raise only the top-level area',function()
    local a,v,s=fixture();s:OnShowing();s:SelectBuff(s.buffControls[1])
    assert(a.nativeRenders[101]==1 and a.nativeRenders[102]==1 and a.nativeRenders[103]==1)
    assert(not a.nativeInstances[1].collapsed and v.cards[1].control.height==700)
    assert(v.root.broughtTop and not v.cards[1].control.broughtTop)
end)
test('native indicators cover every applicable choice without altering colours or name',function()
    local a,v,s=fixture();s:OnShowing()
    local one,two,three=s.buffControls[1].kanaArchiveIndicator,s.buffControls[2].kanaArchiveIndicator,s.buffControls[3].kanaArchiveIndicator
    assert(not one:IsHidden() and not two:IsHidden() and three:IsHidden())
    assert(one.texture=='esoui/art/treeicons/achievements_indexicon_summary_up.dds' and one.exclude and not one.mouse)
    assert(s.buffControls[1].nameLabel.width==220 and s.control.width==820)
end)
test('indicator remains visible when the selector finishes opening',function()
    local a,v,s,controller=fixture();s.control:SetHidden(true)
    v:UpdateIndicators(s,controller.model)
    s.control:SetHidden(false)
    assert(not s.buffControls[1].kanaArchiveIndicator:IsHidden(),'Do not copy temporary ancestor invisibility into the indicator')
    assert(s.buffControls[1].kanaArchiveIndicator.layer==a.DL_OVERLAY,'The badge must draw above the selector backdrop')
    assert(s.buffControls[1].kanaArchiveIndicator.tier==a.DT_HIGH)
end)
test('indicator stays next to centered text rather than the fixed label edge at every scale',function()
    for _,mode in ipairs({'KEYBOARD','GAMEPAD'}) do
        for _,scale in ipairs({0.8,1,1.5}) do
            for _,text in ipairs({{80,26},{126,52},{214,52}}) do
                local a,v,s=fixture();a.GuiRoot.scale=scale
                s=a['ENDLESS_DUNGEON_BUFF_SELECTOR_'..mode]
                local label=s.buffControls[1].nameLabel
                label.textWidth=text[1];label:SetHeight(text[2])
                label.fontHeight=mode=='GAMEPAD' and 36 or 26
                s:OnShowing()
                local icon=s.buffControls[1].kanaArchiveIndicator
                local textRight=label:GetLeft()+label:GetWidth()/2+text[1]*scale/2
                assert(math.abs((icon:GetLeft()-textRight)/scale-4)<0.001,'The gap from the text must be four UI units')
                assert(math.abs((icon:GetTop()-label:GetTop())/scale-(label.fontHeight-20)/2)<0.001,'Align with the first line without dividing font units by scale')
                assert(label.width==220 and label.height==text[2],'Preserve native wrapping and choice geometry')
            end
        end
    end
end)
test('reroll repositions the existing indicator for the new name width',function()
    local a,v,s=fixture();s:OnShowing()
    local label=s.buffControls[1].nameLabel
    local icon=s.buffControls[1].kanaArchiveIndicator
    local oldLeft=icon:GetLeft()
    label.textWidth=200;s:RefreshBuffs()
    assert(icon==s.buffControls[1].kanaArchiveIndicator and icon:GetLeft()==oldLeft+40)
end)
test('tooltip grid is centered below the selector and above keybinds',function()
    local a,v,s=fixture();s:OnShowing();s:SelectBuff(s.buffControls[1])
    assert(v.root:GetTop()==614 and v.root:GetBottom()<=984)
    assert(v.scroll.template=='ZO_ScrollContainer' and v.cards[1].control.parent==v.child)
    assert(v.cards[1].control.anchor.x==68.5 and v.cards[3].control.anchor.x==1222.5)
end)
test('short screen keeps long last criteria accessible through shared scroll',function()
    local a,v,s=fixture();a.GuiRoot.height=820;a.ZO_KeybindStripControl.top=760
    s:OnShowing();s:SelectBuff(s.buffControls[1]);assert(v.root.height==130)
    v:Scroll(10000);assert(v.viewport.offset==574 and v.child.height==704)
end)
test('scaled narrow screen wraps and centers last row',function()
    local a,v,s=fixture();a.GuiRoot.scale=1.5;a.GuiRoot.width=900;v.root.scale=1.5
    for _,c in ipairs(v.cards)do c.control.scale=1.5 end
    s:OnShowing();s:SelectBuff(s.buffControls[1])
    assert(v.child.height==1096 and #v.cards==3)
    assert(v.cards[3].control.anchor.y==932)
end)
test('leaving an icon retains readable tooltips and native deselection',function()
    local a,v,s=fixture();s:OnShowing();s:SelectBuff(s.buffControls[1]);s:DeselectBuff(s.buffControls[1])
    assert(not v.root:IsHidden() and s.selectedBuffControl==nil and s.calls.DeselectBuff==1)
end)
test('new highlight resets scroll and hides unused native instances',function()
    local a,v,s=fixture();s:OnShowing();s:SelectBuff(s.buffControls[1]);v:Scroll(100)
    s:SelectBuff(s.buffControls[2]);assert(v.viewport.offset==0 and a.nativeInstances[2].id==nil)
end)
test('achievement refresh preserves scroll until content is shorter',function()
    local a,v,s,controller,e=fixture();s:OnShowing();s:SelectBuff(s.buffControls[1]);v:Scroll(80)
    e[a.EVENT_ACHIEVEMENT_UPDATED]();assert(v.viewport.offset==80)
    controller.model.GetGoals=function()return {102}end
    e[a.EVENT_ACHIEVEMENT_UPDATED]();assert(v.viewport.offset==0)
end)
test('reroll clears old goal cards and indicators immediately',function()
    local a,v,s=fixture();s:OnShowing();s:SelectBuff(s.buffControls[1]);s:SetIsRerolling(true)
    assert(v.root:IsHidden() and s.buffControls[1].kanaArchiveIndicator:IsHidden())
    s.buffControls[1].abilityId=3;s.selectedBuffControl=nil;s:RefreshBuffs()
    assert(v.root:IsHidden() and s.buffControls[1].kanaArchiveIndicator:IsHidden())
end)
test('refresh and close run original behavior and clear stale presentation',function()
    local a,v,s=fixture();s:OnShowing();s:SelectBuff(s.buffControls[1]);s:RefreshBuffs();s:OnHiding()
    assert(s.calls.RefreshBuffs==1 and s.calls.OnHiding==1 and v.root:IsHidden())
end)
test('gamepad uses its focus and scroll binds without replacing native actions',function()
    local a,v,s=fixture();a.gamepad=true;local g=a.ENDLESS_DUNGEON_BUFF_SELECTOR_GAMEPAD
    g:OnShowing();g:SelectBuff(g.buffControls[1]);assert(not v.root:IsHidden())
    assert(a.KEYBIND_STRIP.groups[v.keybinds])
    assert(v.keybinds[1].keybind=='UI_SHORTCUT_LEFT_TRIGGER' and v.keybinds[2].keybind=='UI_SHORTCUT_RIGHT_TRIGGER')
    v.keybinds[2].callback();assert(v.viewport.offset>0)
    g:CommitChoice();assert(g.calls.CommitChoice==1 and v.root:IsHidden())
    g:OnHiding();assert(not a.KEYBIND_STRIP.groups[v.keybinds])
end)
test('mode switch hides previous presentation',function()
    local a,v,s,controller,e=fixture();s:OnShowing();s:SelectBuff(s.buffControls[1]);a.gamepad=true
    e[a.EVENT_GAMEPAD_PREFERRED_MODE_CHANGED]();assert(v.root:IsHidden())
end)
test('repeated showing does not duplicate goal instances or hooks',function()
    local a,v,s=fixture();for i=1,3 do s:OnShowing();s:SelectBuff(s.buffControls[1]);s:OnHiding()end
    assert(#a.nativeInstances==3 and s.calls.SelectBuff==3)
end)
test('resize restores an area that had no remaining screen height',function()
    local a,v,s,controller,e=fixture();a.GuiRoot.height=600;a.ZO_KeybindStripControl.top=580
    s:OnShowing();s:SelectBuff(s.buffControls[1]);assert(v.root:IsHidden())
    a.GuiRoot.height=1080;a.ZO_KeybindStripControl.top=1000
    e[a.EVENT_SCREEN_RESIZED]();assert(not v.root:IsHidden() and v.root.height==370)
end)
test('helper controls and handlers remain entirely under helper settings',function()
    local a,c,e=S.New()
    local red=a.WINDOW_MANAGER:CreateControl(nil,a.GuiRoot,a.CT_TEXTURE);red:SetTexture('/esoui/art/login/login_icon_yield.dds')
    local favourite=a.WINDOW_MANAGER:CreateControl(nil,a.GuiRoot,a.CT_TEXTURE);favourite:SetTexture('/esoui/art/campaign/overview_indexicon_bonus_down.dds')
    a.ArchiveHelper={ICONS={ACH={name='login/login_icon_yield'}},IconObjectPool={GetActiveObjects=function()return {
        {texture=red,SetHidden=function(_,v)red:SetHidden(v)end},
        {texture=favourite,SetHidden=function(_,v)favourite:SetHidden(v)end},
    }end},OnBuffSelectorShowing=function()red:SetHidden(false);favourite:SetHidden(false)end}
    a.ENDLESS_DUNGEON_BUFF_SELECTOR_KEYBOARD=a:Selector('Keyboard');a.ENDLESS_DUNGEON_BUFF_SELECTOR_GAMEPAD=a:Selector('Gamepad')
    local model={GetGoals=function()return {}end}
    local original=a.ArchiveHelper.OnBuffSelectorShowing
    KanaArchiveAchievements.Controller.Install(a,model,KanaArchiveAchievements.View.New(a))
    a.ArchiveHelper.OnBuffSelectorShowing();assert(not red:IsHidden() and not favourite:IsHidden())
    assert(a.ArchiveHelper.OnBuffSelectorShowing==original,'Do not hook or replace helper rendering')
end)
test('UI settings reflow a hidden tooltip area',function()
    local a,v,s,controller,e=fixture();a.GuiRoot.height=600;a.ZO_KeybindStripControl.top=580
    s:OnShowing();s:SelectBuff(s.buffControls[1]);assert(v.root:IsHidden())
    a.GuiRoot.height=1080;a.ZO_KeybindStripControl.top=1000
    e[a.EVENT_INTERFACE_SETTING_CHANGED]();assert(not v.root:IsHidden())
end)
test('bootstrap ignores other addons and installs exactly once',function()
    local a,c,e=S.New();KanaArchiveAchievements.controller=nil
    local saved
    a.ZO_SavedVars={NewAccountWide=function(_,name,version,scope,defaults)
        assert(name=='KanaArchiveAchievementsSavedVariables' and version==1 and scope==nil)
        saved=saved or defaults
        return saved
    end}
    a.LibAddonMenu2={RegisterAddonPanel=function()end,RegisterOptionControls=function(_,_,options)a.options=options end}
    a.ArchiveHelper={ABILITIES={},GENERAL={},AVATAR={},CLASSES={}}
    a.ENDLESS_DUNGEON_BUFF_SELECTOR_KEYBOARD=a:Selector('Keyboard');a.ENDLESS_DUNGEON_BUFF_SELECTOR_GAMEPAD=a:Selector('Gamepad')
    S.Load('KanaArchiveAchievements/KanaArchiveAchievements.lua',a)
    local callback=e[a.EVENT_ADD_ON_LOADED]
    callback(a.EVENT_ADD_ON_LOADED,'OtherAddon');assert(KanaArchiveAchievements.controller==nil)
    callback(a.EVENT_ADD_ON_LOADED,'KanaArchiveAchievements');local first=KanaArchiveAchievements.controller
    assert(first and e[a.EVENT_ADD_ON_LOADED]==nil)
    assert(#a.options==2 and a.options[1].getFunc() and a.options[2].getFunc())
    a.options[1].setFunc(false);assert(not saved.indicators and saved.tooltips)
    callback(a.EVENT_ADD_ON_LOADED,'KanaArchiveAchievements');assert(KanaArchiveAchievements.controller==first)
    a.ENDLESS_DUNGEON_BUFF_SELECTOR_KEYBOARD:OnShowing();assert(a.ENDLESS_DUNGEON_BUFF_SELECTOR_KEYBOARD.calls.OnShowing==1)
    KanaArchiveAchievements.controller=nil
end)
print(string.format('UI: %d passed, %d failed',passed,failed))
os.exit(failed==0 and 0 or 1)
