local Fake=dofile(ROOT.."/tests/support/fake_eso.lua")
local G=dofile(ROOT.."/tests/support/geometry_controls.lua")
local function setup(f)
 local kw=Fake.Load({"Core.lua","SoftPanel.lua","Slots.lua","lang/en.lua","Presets.lua","Inventory.lua","SetModel.lua","Dialogs.lua","PageAdapters.lua","SelectionOverlay.lua","UI.lua"})
 local inventory=kw.Inventory.New(Fake.New());local repo=kw.Presets.New({},"EU","@a","1","One")
 local session={view={state="editing",isEditor=true,name="A preset",selected={[EQUIP_SLOT_HEAD]=true},missing={}}}
 function session:GetView()return self.view end
 function session:IsEditorActive()return self.view.isEditor end
 function session:GetSelected(domain,key)if type(domain)=="number"then key=domain end;return self.view.selected[key]==true end
 function session:Pause()self.view.paused=true;return true end
 local ui=kw.UI.New(repo,session,{Hide=function()end},inventory)
 f.scene.callback(nil,SCENE_SHOWN)
 return ui,session,kw
end
local function snapshot(control)
 local result={rect=control:Rect(),w=control.w,h=control.h,anchors={}}
 for i,a in ipairs(control.anchors)do result.anchors[i]={table.unpack(a)}end
 return result
end
local function unchanged(control,before)
 local now=control:Rect()
 for k,v in pairs(before.rect)do assert(math.abs(now[k]-v)<.01,control.name.." position/size drift at "..k)end
 assert(#control.anchors==#before.anchors,"native anchor count changed")
 for i,a in ipairs(before.anchors)do for j,v in pairs(a)do assert(control.anchors[i][j]==v,"native anchor not restored")end end
end
local function notBelowScroll(control,scroll)
 local parent=control.parent
 while parent do assert(parent~=scroll,"sticky action is inside scrolling content");parent=parent.parent end
end
local tests={}
for _,case in ipairs({{1280,720,.75},{1920,1080,1},{2560,1440,1.25},{5120,2880,2}})do
 local suffix=case[1].."_scale_"..tostring(case[3]):gsub("%.","_")
 tests["geometry_checks_inside_native_icons_"..suffix]=function()
  G.With(case[1],case[2],case[3],function(f)
   local ui=setup(f);local count=0
   for _,check in pairs(ui.checks)do
    count=count+1;assert(not check.hidden);G.Contained(check,GuiRoot)
    G.Contained(check.background,check)
    assert(check.layer==DL_OVERLAY and check.background.layer==DL_CONTROLS,"checkbox backing must draw above paperdoll texture and below tick")
    assert(check.background.color[4]==1,"checkbox needs an opaque backing over the paperdoll")
    assert(check.background.mouse==false,"backing must not intercept clicks")
    assert(check.background.edgeColor[4]==0,"backing must not add a second border to native checkbox")
    G.Contained(check,check.parent:GetNamedChild("Icon"))
    assert(check.w==18 and check.h==18,"selection tick is 18 raw UI units")
    for _,other in pairs(ui.checks)do if other~=check then G.Disjoint(check,other)end end
   end
   assert(count==14,"all editable slots need a checkbox")
  end)
 end
 tests["geometry_panel_inside_screen_avoids_native_columns_"..suffix]=function()
  G.With(case[1],case[2],case[3],function(f)
   local ui=setup(f)
   G.Contained(ui.root,GuiRoot)
   G.Disjoint(ui.root,ZO_CharacterWindowStatsScroll,"panel covers native stats or scrollbar")
   G.Disjoint(ui.root,ZO_PlayerInventory,"panel covers native inventory")
   assert(ui.root:GetLeft()>=ZO_CharacterWindowStatsScroll:GetRight(),"panel belongs after native stats")
  end)
 end
 tests["geometry_editor_width_fits_scroll_"..suffix]=function()
  G.With(case[1],case[2],case[3],function(f)
   local ui=setup(f);local viewport=ui.editorScroll:GetNamedChild("Scroll")
   assert(ui.editor:GetWidth()<=viewport:GetWidth()+.01,"editor child overflows native 16-unit scrollbar gutter")
   for _,control in ipairs({ui.nameButton,ui.allButton,ui.noneButton,ui.ghostButton})do
    assert(control:GetRight()<=viewport:GetRight()+.01,control.name.." clipped at right edge")
   end
  end)
 end
 tests["geometry_native_section_and_compact_editor_"..suffix]=function()
  G.With(case[1],case[2],case[3],function(f)
   local original=snapshot(ZO_SharedWideLeftPanelBackground)
   local ui,session,kw=setup(f)
   assert(math.abs(ui.title:GetTop()-ZO_CharacterHeaderSectionTitle:GetTop())<.01,"headings must align")
   assert(ui.title.font=="ZoFontHeader4","use native equipment heading font")
   assert(not ui.listSurface,"presets belong to the native equipment panel")
   assert(ZO_SharedWideLeftPanelBackground:GetRight()>=ui.root:GetRight())
   assert(not f.controls.KanaWardrobePanelContentBackground,"no standalone framed background")
   local presetsWidth=ZO_SharedWideLeftPanelBackground:GetNamedChild("Left"):GetWidth()
   ui.preview.control=f:Control("TestDescriptionPanel",nil,nil,400,600)
   ui.preview.control:SetAnchor(TOPLEFT,ui.root,TOPRIGHT,12,0)
   ui.preview.visible=true;ui:SetBackgroundExpanded(true)
   assert(ZO_SharedWideLeftPanelBackground:GetNamedChild("Right"):GetRight()<ui.preview.control:GetRight(),"description has its own surface")
   ui.preview.visible=false;ui:SetBackgroundExpanded(true)
   assert(math.abs(ZO_SharedWideLeftPanelBackground:GetNamedChild("Left"):GetWidth()-presetsWidth)<.01,"closing description must restore preset-only width")
   for _,name in ipairs({"KanaWardrobeHelp","KanaWardrobeStatus","KanaWardrobeReturn","KanaWardrobeEmpty"})do
    assert(not f.controls[name],"persistent explanatory copy should not occupy panel: "..name)
   end
   for _,button in ipairs({ui.saveButton,ui.cancelButton})do
    assert(not button:IsControlHidden(),"editor action hidden")
    G.Contained(button,ui.content);G.Contained(button,GuiRoot)
    notBelowScroll(button,ui.editorScroll);G.Disjoint(button,ui.editorScroll)
   end
   G.Disjoint(ui.saveButton,ui.cancelButton)
   local top=ui.root:GetTop()
   session.view.state="idle";session.view.isEditor=false;ui:Refresh()
   assert(ui.root:GetTop()==top,"switching editor must not shift section heading")
   for _=1,5 do
    f.scene.callback(nil,SCENE_HIDDEN);unchanged(ZO_SharedWideLeftPanelBackground,original)
    f.scene.callback(nil,SCENE_SHOWN)
    assert(ZO_SharedWideLeftPanelBackground:GetRight()>=ui.root:GetRight())
   end
   f:Put("IsInGamepadPreferredMode",function()return true end);ui:Refresh()
   unchanged(ZO_SharedWideLeftPanelBackground,original)
  end)
 end
 tests["geometry_scene_cycles_restore_native_without_scale_drift_"..suffix]=function()
  G.With(case[1],case[2],case[3],function(f)
   local native={ZO_CharacterWeaponsSection,ZO_CharacterEquipmentSlotsMainHand,ZO_CharacterEquipmentSlotsBackupMain}
   local original={};for i,c in ipairs(native)do original[i]=snapshot(c)end
   local ui,session=setup(f)
   local editor={};for i,c in ipairs(native)do unchanged(c,original[i]);editor[i]=snapshot(c)end
   for _=1,8 do
    f.scene.callback(nil,SCENE_HIDDEN)
    assert(ui.content.hidden)
    for _,check in pairs(ui.checks)do assert(check.hidden)end
    for i,c in ipairs(native)do unchanged(c,original[i])end
    session.view.paused=false;f.scene.callback(nil,SCENE_SHOWN)
    for i,c in ipairs(native)do unchanged(c,editor[i])end
   end
  end)
 end
 tests["geometry_hide_toggle_below_info_bar_preserves_list_"..suffix]=function()
  G.With(case[1],case[2],case[3],function(f)
   local ui=setup(f)
   local parent=f:Control("TestNativeInventory",nil,nil,565,500)
   parent:SetAnchor(TOPRIGHT,GuiRoot,TOPRIGHT,-20,100)
   local sort=f:Control("TestNativeSortBy",parent,nil,565,32)
   sort:SetAnchor(TOPLEFT,parent,TOPLEFT,0,110)
   local list=f:Control("TestNativeInventoryList",parent)
   -- Native inventory.xml: list starts five units below sort headers and ends at parent bottom.
   list:SetAnchor(TOPLEFT,sort,BOTTOMLEFT,0,5);list:SetAnchor(BOTTOMRIGHT,parent,BOTTOMRIGHT,0,0)
   local original=snapshot(list)
   local filters={active=true}
   function filters:GetContexts()return {{context="backpack",active=self.active,list=list,parent=parent}}end
   function filters:IsEnabled()return true end
   function filters:IsBypassed()return false end
   function filters:HiddenCount()return 999 end
   local toggle=ui:RegisterHideToggle(parent,"backpack",filters)
   for _=1,8 do
    assert(not toggle.hidden);G.Contained(toggle,GuiRoot);G.Contained(toggle.label,GuiRoot)
    assert(toggle:GetTop()>=list:GetBottom()+64*toggle:GetScale(),"toggle must follow native info bar")
    G.Disjoint(toggle,list)
    G.Disjoint(toggle.label,list)
    G.Disjoint(toggle,sort);G.Disjoint(toggle.label,sort)
    unchanged(list,original)
    local active=snapshot(list);ui:RefreshToggles();unchanged(list,active)
    -- Native ancestor hide/show emits these events even when the toggle's own
    -- hidden flag is unchanged; no filter refresh is needed for restoration.
    parent:SetHidden(true);assert(toggle.handlers.OnEffectivelyHidden)(toggle);unchanged(list,original)
    parent:SetHidden(false);assert(toggle.handlers.OnEffectivelyShown)(toggle);unchanged(list,active)
    toggle.handlers.OnEffectivelyShown(toggle);unchanged(list,active)
    filters.active=false;ui:RefreshToggles();assert(toggle.hidden);unchanged(list,original)
    filters.active=true;ui:RefreshToggles()
   end
  end)
 end
end
tests.geometry_native_repair_context_keeps_viewport_and_uses_footer=function()
 G.With(1920,1080,1,function(f)
  local ui,session,kw=setup(f);dofile(ROOT.."/InventoryFilters.lua")
  local root=f:Control("TestRepairWindow",GuiRoot,nil,565,675)
  root:SetAnchor(TOPLEFT,GuiRoot,RIGHT,-575,-310)
  local sort=f:Control("TestRepairSortBy",root,nil,565,32)
  sort:SetAnchor(TOPLEFT,root,TOPLEFT,0,110)
  local list=f:Control("TestRepairList",root)
  -- repairwindow.xml uses these two list anchors, independently of the root.
  list:SetAnchor(TOPLEFT,sort,BOTTOMLEFT,0,5);list:SetAnchor(BOTTOMRIGHT,root,BOTTOMRIGHT,0,0)
  local api={PLAYER_INVENTORY={inventories={}},REPAIR_WINDOW={control=root,list=list}}
  for _,name in ipairs({"BACKPACK","BANK","GUILD_BANK","HOUSE_BANK"})do
   api["INVENTORY_"..name]=name
   local hidden=f:Control("Hidden"..name,GuiRoot);hidden:SetHidden(true)
   api.PLAYER_INVENTORY.inventories[name]={listView=hidden}
  end
  local filters=kw.InventoryFilters.New(ui.repo,ui.inventory,session,{hidePresetItems=true});filters.api=api
  local function repairContext()
   for _,context in ipairs(filters:GetContexts())do if context.context=="vendorRepair"then return context end end
   error("repair context missing")
  end
  local originalRoot,originalSort,originalList=snapshot(root),snapshot(sort),snapshot(list)
  local context=repairContext()
  assert(context.active and context.list==list and context.parent==root,"vendorRepair must expose native list child and repair window parent")
  local toggle=ui:RegisterHideToggle(context.parent,context.context,filters)
  assert(toggle:GetParent()==root,"repair toggle must share native window visibility")
  unchanged(root,originalRoot);unchanged(sort,originalSort)
  unchanged(list,originalList)
  assert(list:GetBottom()==originalList.rect.b,"repair list bottom must remain fixed")
  G.Disjoint(toggle,sort);G.Disjoint(toggle,list)
  local active=snapshot(list)
  for _=1,4 do
   root:SetHidden(true);assert(not repairContext().active)
   toggle.handlers.OnEffectivelyHidden(toggle);unchanged(list,originalList);unchanged(root,originalRoot)
   root:SetHidden(false);assert(repairContext().active)
   toggle.handlers.OnEffectivelyShown(toggle);unchanged(list,active)
   toggle.handlers.OnEffectivelyShown(toggle);unchanged(list,active)
   unchanged(root,originalRoot);unchanged(sort,originalSort)
  end
 end)
end
tests.geometry_footer_toggle_never_resizes_or_recommits_list=function()
 G.With(1920,1080,1,function(f)
  local ui=setup(f)
  local parent=f:Control("TestCommittedInventory",GuiRoot,nil,565,540)
  parent:SetAnchor(TOPRIGHT,GuiRoot,TOPRIGHT,-20,100)
  local list=f:Control("TestCommittedList",parent)
  list:SetAnchor(TOPLEFT,parent,TOPLEFT,0,40);list:SetAnchor(BOTTOMRIGHT,parent,BOTTOMRIGHT,0,0)
  -- Native list already committed 20 rows of height 25: precisely one viewport.
  list.contentHeight=20*25;ZO_ScrollList_Commit(list)
  assert(list.scrollableDistance==0 and list:GetHeight()==list.contentHeight)
  local filters={active=true}
  function filters:GetContexts()return {{context="backpack",active=self.active,list=list,parent=parent}}end
  function filters:IsEnabled()return true end
  function filters:IsBypassed()return false end
  function filters:HiddenCount()return 0 end
  local toggle=ui:RegisterHideToggle(parent,"backpack",filters)
  assert(list.scrollableDistance==0,"footer toggle must not reduce viewport")
  assert(list:GetHeight()+list.scrollableDistance>=list.contentHeight,"last row must be reachable")
  local committed=list.commitCount
  ui:RefreshToggles();ui:RefreshToggles()
  assert(list.commitCount==committed,"unchanged layout must not repeatedly commit native list")
  parent:SetHidden(true);toggle.handlers.OnEffectivelyHidden(toggle)
  assert(list.scrollableDistance==0 and list.commitCount==committed,"hiding toggle must not recommit list")
  toggle.handlers.OnEffectivelyHidden(toggle)
  assert(list.commitCount==committed,"already restored list must not recommit")
  parent:SetHidden(false);toggle.handlers.OnEffectivelyShown(toggle)
  assert(list.scrollableDistance==0 and list.commitCount==committed,"showing footer must not recommit list")
  toggle.handlers.OnEffectivelyShown(toggle)
  assert(list.commitCount==committed,"repeated shown callback must not recommit")
 end)
end
for _,case in ipairs({{1280,720,.75},{1920,1080,1},{2560,1440,1.25},{5120,2880,2}})do
 tests["preset_list_quick_footer_"..case[1]]=function()
  G.With(case[1],case[2],case[3],function(f)
   local ui,session=setup(f)
   session.view={state="idle",isEditor=false,selected={},missing={}}
   for i=1,2 do local p=ui.repo:NewDraft();p.name="Preset "..i;p.slots={[EQUIP_SLOT_HEAD]={kind="empty"}};assert(ui.repo:Save(p,0))end
   ui:Refresh()
   assert(ui.rows[1].title.font=="ZoFontGameBold")
   G.Disjoint(ui.rows[1].tick,ui.rows[1].title)
   assert(not ui.rows[1].tick.hidden and ui.rows[1].badge.text=="")
   ui.rows[1].handlers.OnMouseEnter();assert(not ui.rows[1].highlight.hidden)
   ui.rows[1].handlers.OnMouseExit();assert(ui.rows[1].highlight.hidden)
   assert(ui.newButton:GetTop()>=ui.rows[2]:GetBottom())
   G.Disjoint(ui.quickSave,ui.quickLoad);G.Contained(ui.quickBar,ui.content)
   G.Disjoint(ui.quickBar,ui.newButton);G.Disjoint(ui.quickBar,ui.list)
   local top=ui.quickBar:GetTop();local newTop=ui.newButton:GetTop()
   session.view.state="applying";ui:Refresh()
   assert(ui.quickBar:GetTop()==top and ui.newButton:GetTop()==newTop)
   assert(not ui.quickSave.enabled and not ui.quickLoad.enabled)
   session.view.state="idle"
   for i=3,30 do local p=ui.repo:NewDraft();p.name="Preset "..i;p.slots={[EQUIP_SLOT_HEAD]={kind="empty"}};assert(ui.repo:Save(p,0))end
   ui:Refresh()
   assert(ui.quickBar:GetTop()==top and ui.listChild:GetHeight()>ui.list:GetHeight())
   G.Contained(ui.newButton,ui.content);G.Disjoint(ui.newButton,ui.list);G.Disjoint(ui.quickBar,ui.newButton)
   assert(ui.quickSave.enabled and not ui.quickLoad.enabled)
   ui.repo:SaveQuick(ui.inventory:Capture(false).worn);ui:Refresh()
   assert(ui.quickLoad.enabled and #ui.repo:List()==30)
  end)
 end
end
tests.original_preset_background_expands_only_owner_width_independent_of_description=function()
 G.With(5120,2880,2,function(f)
  local bg=ZO_SharedWideLeftPanelBackground
  local left,right=bg:GetNamedChild("Left"),bg:GetNamedChild("Right")
  local originalLeft,originalRight=snapshot(left),snapshot(right)
  local character=snapshot(ZO_Character)
  local owner=snapshot(bg)
  local y,height=left:GetTop(),left:GetHeight()
  local ui=setup(f)
  local presetsLeft,presetsRight=snapshot(left),snapshot(right)
  local description=f:Control("Description",nil,nil,700,850)
  description:SetAnchor(TOPLEFT,ui.root,TOPRIGHT,12,0)
  ui.preview.control=description;ui.preview.visible=true
  ui:SetBackgroundExpanded(true)
  assert(left:GetTop()==y and left:GetHeight()==height,"native gradient must retain its height")
  assert(bg:GetLeft()==owner.rect.l and bg:GetRight()>=ui.root:GetRight())
  assert(left.w==originalLeft.w and right.w==originalRight.w,"native textures must not be resized")
  unchanged(left,presetsLeft);unchanged(right,presetsRight)
  assert(bg:GetRight()<=description:GetLeft(),"description must not extend native owner")
  assert(right:GetRight()<=ZO_SharedRightPanelBackground:GetNamedChild("Left"):GetLeft()-12*right:GetScale(),"background cap covers bag")
  assert(left:GetBottom()<description:GetBottom(),"long description must not extend equipment background")
  unchanged(ZO_Character,character)
  ui.preview.visible=false;ui:SetBackgroundExpanded(true)
  assert(left:GetLeft()<=GuiRoot:GetLeft())
  ui:SetBackgroundExpanded(false);unchanged(left,originalLeft);unchanged(right,originalRight)
  unchanged(ZO_Character,character)
 end)
end
tests.description_surface_has_fixed_feather_and_no_native_mutation=function()
 G.With(5120,2880,2,function(f)
  local native=ZO_SharedWideLeftPanelBackground
  local before=snapshot(native:GetNamedChild("Left"))
  local kw=Fake.Load({"Core.lua","SoftPanel.lua"})
  local panel=f:Control("DescriptionSurfaceTest",nil,nil,700,500)
  local surface=kw.SoftPanel.New(panel,"DescriptionSurfaceTestArt")
  surface:Layout(700,500)
  local tiles=surface.tiles
  local center=tiles[5]
  assert(center.texture=="eso-kana-addons/KanaWardrobe/assets/panel_feather.dds","surface needs explicit texture alpha, not untextured vertex tint")
  assert(center.textureCoords[1]==.25 and center.textureCoords[2]==.75)
  assert(tiles[1].textureCoords[1]==0 and tiles[1].textureCoords[2]==.25)
  local file=assert(io.open(ROOT.."/assets/panel_feather.dds","rb"));local dds=file:read('*a');file:close()
  assert(dds:sub(1,4)=='DDS ')
  local function alpha(x,y)return dds:byte(128+(y*64+x)*4+4)end
  assert(alpha(0,0)==0 and alpha(32,32)>=200 and alpha(32,32)<240,'surface must be readable but remain translucent')
  assert(alpha(32,0)==0 and alpha(63,32)==0,'edges must fade to transparent')
  assert(tiles[6]:GetRight()>panel:GetRight(),"feather must extend beyond content")
  local width,height=tiles[6]:GetWidth(),tiles[8]:GetHeight()
  surface:Layout(900,1000)
  assert(tiles[6]:GetWidth()==width and tiles[8]:GetHeight()==height,"resizing must not stretch feather")
  for _,tile in ipairs(tiles)do assert(tile.mouse==false and tile.layer==DL_BACKGROUND)end
  unchanged(native:GetNamedChild("Left"),before)
 end)
end
for _,profile in ipairs({{1280,720,.75},{1920,1080,1},{2560,1440,1.25},{5120,2880,2}})do
 tests['complete_description_page_safe_bounds_'..profile[1]]=function()
  G.With(profile[1],profile[2],profile[3],function(f)
   local scenes={}
   for _,page in ipairs({'inventory','skills','stats'})do
    local scene={}
    function scene:AddFragment()end
    function scene:RegisterCallback(_,fn)self.callback=fn end
    function scene:Fire(state)self.callback(nil,state)end
    scenes[page]=scene
   end
   f:Put('SCENE_MANAGER',{GetScene=function(_,page)return scenes[page]end})
   local function right(name,width)
    local c=f:Control(name,nil,nil,width,640);c:SetAnchor(RIGHT,GuiRoot,RIGHT,0,0);f:Put(name,c);return c
   end
   right('ZO_Skills',930);right('ZO_SharedRightBackground',960)
   right('ZO_StatsPanel',645);right('ZO_SharedStatsBackground',645)
   local advanced=f:Control('ZO_AdvancedStatsPanel',nil,nil,295,640)
   advanced:SetAnchor(TOPRIGHT,ZO_StatsPanel,TOPLEFT,0,0);advanced:SetHidden(true);f:Put('ZO_AdvancedStatsPanel',advanced)
   local kw=Fake.Load({'Core.lua','Slots.lua','BuildModel.lua','lang/en.lua','Presets.lua','Inventory.lua','SetModel.lua','Dialogs.lua','PageAdapters.lua','SelectionOverlay.lua','UI.lua'})
   local inv=kw.Inventory.New(Fake.New());local repo=kw.Presets.New({},'EU','@a','1','One')
   local session={view={state='idle',isEditor=false,selected={},missing={}}}
   function session:GetView()return self.view end
   function session:IsEditorActive()return false end
   function session:GetNativeOwnership()return {}end
   local preview={boundsCalls=0,refreshes=0}
   function preview:Hide()self.hidden=true;self.visible=false end
   function preview:Refresh()self.refreshes=self.refreshes+1 end
   function preview:SetSafeArea(bounds)self.boundsCalls=self.boundsCalls+1;self.area=bounds end
   local pages=kw.PageAdapters.New(_G);local ui=kw.UI.New(repo,session,preview,inv,{pages=pages})
   for _,page in ipairs({'inventory','skills','stats'})do
    scenes[page]:Fire(SCENE_SHOWN)
    local bounds=pages:Bounds(page)
    assert(bounds and preview.area,'description safe area was not handed off for '..page)
    local b=preview.area;assert(b.x==bounds.description.x and b.width==bounds.description.width and b.scale==profile[3])
    local calls=preview.boundsCalls;ui:LayoutPanel();assert(preview.boundsCalls==calls,'unchanged geometry repeated description handoff')
   end
   scenes.inventory:Fire(SCENE_SHOWN)
   local listKey=ui.panelGeometry;local oldWidth=preview.area.width;local calls=preview.boundsCalls
   ZO_PlayerInventory:ClearAnchors();ZO_PlayerInventory:SetAnchor(TOPLEFT,GuiRoot,RIGHT,-675,-375)
   ui:LayoutPanel()
   assert(ui.panelGeometry==listKey and preview.boundsCalls==calls+1 and preview.area.width<oldWidth,'description-only area change was ignored')
   scenes.stats:Fire(SCENE_SHOWN);local normal=preview.area.width
   advanced:SetHidden(false);ui:LayoutPanel()
   assert(preview.area==nil or preview.area.width<normal,'advanced Stats did not reduce description safe area')
  end)
 end
end
for _,profile in ipairs({{1280,720,.75},{1920,1080,1},{2560,1440,1.25},{5120,2880,2}})do
 tests['progress_track_fits_without_resizing_the_list_'..profile[1]]=function()
  G.With(profile[1],profile[2],profile[3],function(f)
   local ui,session=setup(f);local before=snapshot(ui.list)
   session.view.state='preparingEdit';session.view.progress={operationId=1,completed=0,total=4,stage='requesting'};ui:Refresh()
   session.view.progress.completed=2;ui:Refresh();ui:AnimateProgress(0);ui:AnimateProgress(.2)
   local track,fill=ui.progressTrack:Rect(),ui.progressFill:Rect()
   local dividerTop=ui.content:GetTop()+47*profile[3]
   assert(track.t>dividerTop+4*profile[3],'progress overlaps the native heading divider')
   assert(track.b+8*profile[3]<=ui.quickBar:GetTop(),'progress runs into quick-save buttons')
   assert(ui.progressStage and ui.progressStage:GetBottom()<=track.t-3*profile[3],'phase label must be separated from the bar')
   assert(math.abs(fill.r-fill.l-(track.r-track.l)/2)<.01,'scaled progress width drift')
   assert(fill.l>=track.l and fill.r<=track.r and not ui.progressTrack.hidden)
   unchanged(ui.list,before)
  end)
 end
end
return tests
