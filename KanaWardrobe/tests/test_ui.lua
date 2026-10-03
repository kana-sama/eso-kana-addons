local Fake=dofile(ROOT.."/tests/support/fake_eso.lua")
local function setup()
 local kw=Fake.Load({"Core.lua","SoftPanel.lua","Slots.lua","lang/en.lua","Presets.lua","Inventory.lua","SetModel.lua","Dialogs.lua","PageAdapters.lua","SelectionOverlay.lua","UI.lua"})
 assert(kw.UI and kw.Dialogs,"UI/dialog implementation missing")
 local api=Fake.New(); local inv=kw.Inventory.New(api)
 local repo=kw.Presets.New({},"EU","@a","1","One")
 local session={view={state="idle",selected={},missing={},isEditor=false},calls={}}
 function session:GetView() return self.view end
 function session:IsEditorActive()return self.view.isEditor end
 function session:GetSelected(domain,key)if type(domain)=="number"then key=domain end;return self.view.selected[key]==true end
 for _,method in ipairs({"Apply","BeginEdit","BeginNew","Save","Cancel","Pause","Resume","Recover","RejectConfirmation","Confirm","SetName","SetSelected","ResolveMissing"}) do
  session[method]=function(self,...) self.calls[#self.calls+1]={method,...}; return true end
 end
 local preview={Hide=function(self) self.hidden=true end}
 return kw,repo,session,inv,api,preview
end
local function add(repo,name,slots)
 local p=repo:NewDraft();p.name=name;p.slots=slots;return assert(repo:Save(p,0))
end
local function withNative(fn)
 local old={};local function put(k,v)old[k]={_G[k]};_G[k]=v end
 local all={};local function control(name,parent)
  local c={name=name,parent=parent,anchors={},handlers={},children={},w=248,h=640,hidden=false}
  function c:GetNamedChild(n)if not self.children[n]then self.children[n]=control(self.name..n,self)end;return self.children[n]end
  function c:SetAnchor(...)self.anchors[#self.anchors+1]={...}end
  function c:ClearAnchors()self.anchors={}end
  function c:GetNumAnchors()return #self.anchors end
  function c:GetAnchor(n)return true,table.unpack(self.anchors[n+1])end
  function c:GetDimensions()return self.w,self.h end
  function c:SetDimensions(w,h)self.w=w;self.h=h end
  function c:SetHeight(h)self.h=h end
  function c:SetWidth(w)self.w=w end
  function c:GetHeight()return self.h end
  function c:GetWidth()return self.w end
  function c:GetScale()return 1 end
  function c:GetLeft()return self.x or 0 end
  function c:GetTop()return self.y or 0 end
  function c:GetRight()return self:GetLeft()+self.w end
  function c:IsHidden()return self.hidden end
  function c:GetTextHeight()return math.max(18,math.ceil(#(self.text or "")/math.max(1,self.w/8))*18)end
  function c:SetHidden(h)self.hidden=h end
  function c:SetEnabled(v)self.enabled=v end
  function c:SetHandler(k,f)self.handlers[k]=f end
  function c:SetText(t)self.text=t end
  function c:SetAlpha(v)self.alpha=v end
  function c:SetHorizontalAlignment(v)self.align=v end
  function c:SetColor(...)self.color={...}end
  function c:SetNormalTexture(texture)self.normalTexture=texture end
  function c:SetPressedTexture(texture)self.pressedTexture=texture end
  function c:SetDrawLevel(level)self.level=level end
  for _,method in ipairs({"SetVertexColors","SetTextureCoords","SetTexture","SetClampedToScreen","SetCenterColor","SetEdgeColor","SetEdgeTexture","SetDrawLayer","SetMouseEnabled","SetFont","SetMaxLineCount","SetWrapMode","SetResizeToFitDescendents"})do c[method]=function()end end
  all[name]=c;return c
 end
 for _,k in ipairs({"TOPLEFT","TOPRIGHT","BOTTOMLEFT","BOTTOMRIGHT","RIGHT","LEFT","TOP","BOTTOM","CT_CONTROL","CT_LABEL","CT_BUTTON","SCENE_HIDDEN","SCENE_HIDING","SCENE_SHOWING","SCENE_SHOWN"})do put(k,k)end
 put("GuiRoot",control("GuiRoot"));GuiRoot.w=1920;GuiRoot.h=1080
 put("WINDOW_MANAGER",{CreateControl=function(_,n,p)return control(n,p)end,CreateControlFromVirtual=function(_,n,p)return control(n,p)end})
 put("KanaWardrobePanel",control("KanaWardrobePanel"));put("ZO_Character",control("ZO_Character"))
 put("ZO_CharacterWindowStatsScroll",control("ZO_CharacterWindowStatsScroll"))
 for _,name in ipairs({"Head","Shoulder","Chest","Glove","Belt","Leg","Foot","Neck","Ring1","Ring2","MainHand","OffHand","BackupMain","BackupOff"})do
  local n="ZO_CharacterEquipmentSlots"..name;put(n,control(n));_G[n]:SetAnchor(TOPLEFT,ZO_Character,TOPLEFT,4,40,7)
 end
 put("ZO_CharacterWeaponsSection",control("ZO_CharacterWeaponsSection"));ZO_CharacterWeaponsSection:SetAnchor(TOPLEFT,ZO_Character,TOPLEFT,0,400,7)
 local scene={AddFragment=function()end,RegisterCallback=function(self,_,cb)self.callback=cb end}
 put("SCENE_MANAGER",{GetScene=function()return scene end})
 put("ZO_SimpleSceneFragment",{New=function(_,c)return {control=c}end})
 put("ZO_CheckButton_SetToggleFunction",function(c,f)c.toggle=f end)
 put("ZO_CheckButton_SetCheckState",function(c,v)c.checked=v end)
 put("ZO_CheckButton_SetLabelText",function(c,v)c.labelText=v end)
 put("ZO_CheckButton_SetEnableState",function(c,v)c.enabled=v end)
 put("ZO_PlayerInventory",nil)
 local ok,err=pcall(fn,all,scene,put)
 for k,v in pairs(old)do _G[k]=v[1]end
 if not ok then error(err)end
end
local function realConfirming(kw,repo,inventory,api)
 dofile(ROOT.."/EquipmentPlan.lua");dofile(ROOT.."/Session.lua")
 api.bags[BAG_WORN][EQUIP_SLOT_RING2]={uid="ring",link="ring"};api.descriptions.ring={equipType=EQUIP_TYPE_RING}
 local preset=add(repo,"Moves ring",{[EQUIP_SLOT_RING1]={kind="item",uid="ring",link="ring"}})
 local runner={IsBusy=function()return false end,Start=function()error("stale dialog sent equipment request")end}
 local function reload()return kw.Session.New(repo,inventory,kw.EquipmentPlan,runner,{},repo.character,{})end
 local session=reload();assert(session:Apply(preset.id));assert(session:GetView().state=="confirming")
 return session,reload
end
local function dialogRuntime(put)
 local rt={definitions={},queue={},timers={},shows=0}
 put("zo_callLater",function(cb)rt.timers[#rt.timers+1]=cb end)
 function rt:Drain()while #self.timers>0 do local cb=table.remove(self.timers,1);cb()end end
 put("ZO_Dialogs_RegisterCustomDialog",function(id,def)rt.definitions[id]=def end)
 put("ZO_Dialogs_ShowDialog",function(id,data)
  rt.shows=rt.shows+1;local d={name=id,data=data}
  if rt.active then rt.queue[#rt.queue+1]=d else rt.active=d end
 end)
 function rt:Release(d,noChoice)
  if self.active~=d then return end
  self.active=nil
  if noChoice and self.definitions[d.name]then self.definitions[d.name].noChoiceCallback(d)end
  if not self.active and #self.queue>0 then self.active=table.remove(self.queue,1)end
 end
 function rt:Click(index)
  local d=assert(self.active);self.definitions[d.name].buttons[index].callback(d)
  self:Release(d,false)
 end
 put("ZO_Dialogs_ReleaseAllDialogsOfName",function(id,filter)
  for n=#rt.queue,1,-1 do local d=rt.queue[n];if d.name==id and filter(d.data)then table.remove(rt.queue,n)end end
  local d=rt.active;if d and d.name==id and filter(d.data)then rt:Release(d,true)end
 end)
 return rt
end
return {
 progress_colors_and_frame_driven_fill_do_not_use_nonexistent_vertex_mask=function()
  withNative(function(_,_,put)
   put('VERTEX_POINTS_ALL',nil)
   local create=WINDOW_MANAGER.CreateControl
   WINDOW_MANAGER.CreateControl=function(self,...)
    local c=create(self,...)
    c.SetVertexColors=function(_,mask)
     assert(type(mask)=='number','ESO has individual vertex flags, no global VERTEX_POINTS_ALL')
    end
    return c
   end
   local k,r,s,inv,_,preview=setup();local ui=k.UI.New(r,s,preview,inv);ui.visible=true
   local track,fill=ui.progressTrack,ui.progressFill
   assert(track.color and fill.color,'solid textures must have explicit colors')
   assert(track.color[1]<fill.color[1] and track.color[2]<fill.color[2] and track.color[3]<fill.color[3],
    'white track conceals the growing fill')
   local progress={operationId=1,phase='equipment',stage='confirmed',completed=0,total=4}
   s.view={state='applying',selected={},missing={},progress=progress}
   ui:Refresh();ui.root.handlers.OnUpdate(ui.root,0)
   assert(fill.hidden and not track.hidden)
   for step=1,3 do
    progress.completed=step;ui:Refresh()
    local before=fill:GetWidth()
    local now=step*.4
    ui.root.handlers.OnUpdate(ui.root,now-.3)
    assert(fill:GetWidth()>before and fill:GetWidth()<track:GetWidth()*step/4,'fill jumps or fails to animate')
    ui.root.handlers.OnUpdate(ui.root,now)
    assert(math.abs(fill:GetWidth()-track:GetWidth()*step/4)<.01 and not fill.hidden,
     'confirmed progress does not reach the visible fill')
   end
   progress.phase='attributes';progress.ratio=.9
   ui:Refresh();ui.root.handlers.OnUpdate(ui.root,1.3);ui.root.handlers.OnUpdate(ui.root,1.6)
   assert(ui.progressStage.text=='Attributes' and math.abs(fill:GetWidth()-.9*track:GetWidth())<.01)
  end)
 end,
 progress_bar_finishes_smoothly_and_does_not_claim_failed_completion=function()
  withNative(function()
   local k,r,s,inv,_,preview=setup();local ui=k.UI.New(r,s,preview,inv);ui.visible=true
   s.view={state='applying',selected={},missing={},progress={operationId=1,completed=1,total=2,stage='requesting'}}
   ui:Refresh();ui:AnimateProgress(0);ui:AnimateProgress(.2)
   s.view={state='idle',selected={},missing={}};ui:OnSessionFinished({outcome='applied'})
   ui:AnimateProgress(.3);assert(ui.progressValue>.5 and ui.progressValue<1 and not ui.progressTrack.hidden)
   ui:AnimateProgress(.5);assert(ui.progressValue==1)
   ui:AnimateProgress(.7);assert(ui.progressTrack.alpha>0 and ui.progressTrack.alpha<1,'completion should fade gently')
   ui:AnimateProgress(.9);assert(ui.progressTrack.hidden)
   s.view={state='applying',selected={},missing={},progress={operationId=2,completed=0,total=2,stage='requesting'}};ui:Refresh()
   s.view={state='idle',selected={},missing={}};ui:OnSessionFinished({outcome='failed',problem=k.Problem('sheathTimeout')})
   ui:Refresh();assert(ui.progressTrack.hidden and ui.progressValue==0)
  end)
 end,
 attribute_progress_shows_phase_and_percentage=function()
  withNative(function()
   local k,r,s,inv,_,preview=setup();local ui=k.UI.New(r,s,preview,inv);ui.visible=true
   s.view={state='applying',selected={},missing={},progress={operationId=1,phase='attributes',stage='waiting',completed=0,total=1,ratio=.45}}
   ui:Refresh();ui:AnimateProgress(0);ui:AnimateProgress(.2)
   assert(not ui.progressTrack.hidden and ui.progressStage.text=='Attributes' and ui.progressLabel.text=='45%')
   assert(ui.progressValue==.45,'cast progress was ignored')
  end)
 end,
 cooldown_progress_explains_wait_without_a_fake_countdown=function()
  withNative(function()
   local k,r,s,inv,_,preview=setup();local ui=k.UI.New(r,s,preview,inv);ui.visible=true
   s.view={state='applying',selected={},missing={},progress={operationId=1,phase='attributes',stage='cooldown',completed=1,total=3,ratio=1/3}}
   ui:Refresh();ui:AnimateProgress(0);ui:AnimateProgress(.2)
   assert(ui.progressStage.text=='Attributes · cooldown')
   assert(ui.progressLabel.text=='33%' and math.abs(ui.progressValue-1/3)<.001)
  end)
 end,
 running_progress_never_claims_100_percent_before_outcome=function()
  withNative(function()
   local k,r,s,inv,_,preview=setup();local ui=k.UI.New(r,s,preview,inv);ui.visible=true
   s.view={state='applying',selected={},missing={},progress={operationId=1,phase='equipment',stage='confirmed',completed=2,total=2,ratio=1}}
   ui:Refresh();assert(ui.progressTarget<1 and ui.progressLabel.text=='99%')
   s.view={state='idle',selected={},missing={}}
   ui:OnSessionFinished({outcome='applied'});ui:AnimateProgress(0);ui:AnimateProgress(.3)
   assert(ui.progressValue==1 and ui.progressLabel.text=='100%')
  end)
 end,
 progress_bar_animates_confirmed_steps_without_moving_the_list=function()
  withNative(function()
   local k,r,s,inv,_,preview=setup();local ui=k.UI.New(r,s,preview,inv);ui.visible=true;ui:Refresh()
   local before=ui.list.anchors[1][5]
   s.view={state='applying',selected={},missing={},progress={operationId=1,stage='requesting',completed=0,total=4}}
   ui:Refresh();assert(not ui.progressTrack.hidden and ui.progressValue==0)
   s.view.progress.completed=2;ui:Refresh();assert(ui.progressValue==0)
   ui:AnimateProgress(0);ui:AnimateProgress(.1)
   assert(ui.progressValue>0 and ui.progressValue<.5,'confirmation should animate rather than jump')
   assert(ui.list.anchors[1][5]==before,'progress must not move the list')
   ui:AnimateProgress(.3);assert(ui.progressValue==.5)
   s.view.progress.operationId=2;s.view.progress.completed=0;ui:Refresh();assert(ui.progressValue==0)
   s.view={state='idle',selected={},missing={}};ui:Refresh();assert(ui.progressTrack.hidden)
  end)
 end,
 ui_editor_controls_stay_visible_through_prepare_and_restore=function()
  local kw,r,s,i,a,p=setup()
  withNative(function(_,scene)
   s.view.isEditor=true;s.view.state="editing"
   local ui=kw.UI.New(r,s,p,i);scene.callback(nil,SCENE_SHOWN)
   local bottom=ui.editorScroll.anchors[2][5]
   for _,state in ipairs({"preparingEdit","restoring","editing"})do
    s.view.state=state;ui:Refresh()
    assert(not ui.newButton.hidden and not ui.allButton.hidden and not ui.footer.hidden)
    assert(ui.editorScroll.anchors[2][5]==bottom,"editor resized during equipment request")
    assert(ui.allButton.enabled==(state=="editing"))
   end
  end)
 end,
 ui_fast_hover_only_opens_latest_row=function()
  local kw,r,s,i,a,p=setup();add(r,"A",{[0]={kind="empty"}});add(r,"B",{[0]={kind="empty"}})
  withNative(function(_,scene,put)
   local timers={};put("zo_callLater",function(fn,delay)timers[#timers+1]={fn=fn,delay=delay}end)
   put("MouseIsOver",function()return true end)
   local shown={};p.Show=function(_,anchor)shown[#shown+1]=anchor end
   local ui=kw.UI.New(r,s,p,i);scene.callback(nil,SCENE_SHOWN)
   timers={}
   ui.rows[1].handlers.OnMouseEnter();ui.rows[2].handlers.OnMouseEnter()
   for _,timer in ipairs(timers)do assert(timer.delay==60);timer.fn()end
   assert(#shown==1 and shown[1]==ui.rows[2],"stale hover must not flash a previous preset")
  end)
 end,
 ui_hover_does_not_open_after_pointer_has_left=function()
  local kw,r,s,i,a,p=setup();add(r,"A",{[0]={kind="empty"}})
  withNative(function(_,scene,put)
   local timers={};put("zo_callLater",function(fn)timers[#timers+1]=fn end)
   put("MouseIsOver",function()return false end)
   p.ContainsMouse=function()return false end;p.Show=function()error("opened after mouse left")end
   local ui=kw.UI.New(r,s,p,i);scene.callback(nil,SCENE_SHOWN)
   ui.rows[1].handlers.OnMouseEnter();ui.rows[1].handlers.OnMouseExit()
   for _,fn in ipairs(timers)do fn()end
   assert(p.hidden)
  end)
 end,
 ui_set_preview_only_describes_items_in_hovered_preset=function()
  local kw,r,s,i,a,p=setup()
  for n=1,180 do a.bags[BAG_BACKPACK][n]={uid="item"..n,link="ring"}end
  local preset=add(r,"A",{[EQUIP_SLOT_RING1]={kind="item",uid="item1",link="ring"}})
  local calls=0;local original=i.Metadata
  i.Metadata=function(self,...)calls=calls+1;return original(self,...)end
  local ui=kw.UI.New(r,s,p,i);ui:Refresh();assert(calls==0)
  ui:Summary(preset);assert(calls==1,"hover generated descriptions for unrelated bag items: "..calls)
 end,
 ui_new_button_and_list_stay_put_while_applying=function()
  local kw,r,s,i,a,p=setup();add(r,"A",{[0]={kind="empty"}})
  withNative(function(_,scene)
   local ui=kw.UI.New(r,s,p,i);scene.callback(nil,SCENE_SHOWN)
   local y=ui.list.anchors[1][5]
   for _,state in ipairs({"applying","confirming","restoring","idle"})do
    s.view.state=state;ui:Refresh()
    assert(not ui.newButton.hidden,"new button disappeared during "..state)
    assert(ui.list.anchors[1][5]==y,"list moved during "..state)
    assert(ui.newButton.enabled==(state=="idle"))
   end
  end)
 end,
 ui_hover_survives_exit_when_pointer_still_over_row=function()
  local kw,r,s,i,a,p=setup();add(r,"A",{[0]={kind="empty"}})
  withNative(function(_,scene,put)
   local timers={};local shown=0
   put("zo_callLater",function(fn)timers[#timers+1]=fn end)
   put("MouseIsOver",function()return true end)
   p.ContainsMouse=function()return false end;p.Show=function()shown=shown+1 end
   local ui=kw.UI.New(r,s,p,i);scene.callback(nil,SCENE_SHOWN)
   local row=ui.rows[1];row.handlers.OnMouseEnter();row.handlers.OnMouseExit()
   local pending=timers;timers={};for _,fn in ipairs(pending)do fn()end
   assert(shown==1,"synthetic mouse exit cancelled pending set preview")
  end)
 end,
 ui_local_notifications_do_not_repeat_on_refresh=function()
  local kw,r,s,i,a,p=setup();local messages={}
  a.d=function(message)messages[#messages+1]=message end
  local ui=kw.UI.New(r,s,p,i)
  ui:OnSessionFinished({outcome="cancelled"})
  assert(#messages==1 and messages[1]:find(kw.Strings.OUTCOME_cancelled,1,true))
  for _=1,5 do ui:Refresh()end
  assert(#messages==1,"refresh must not replay completion")
  s.view.problem=kw.Problem("inCombat");ui:Refresh()
  assert(#messages==2 and messages[2]:find(kw.Strings.PROBLEMS.inCombat,1,true))
  for _=1,5 do s.view.problem=kw.Problem("inCombat");ui:Refresh()end
  ui:Problem(s.view.problem)
  assert(#messages==2,"same session error must not flood chat")
  s.view.problem=nil;ui:Refresh();s.view.problem=kw.Problem("inCombat");ui:Refresh()
  assert(#messages==3,"a new occurrence must still be reported")
  ui:OnSessionFinished({outcome="cancelled",problem=s.view.problem})
  assert(#messages==3,"failure must not also claim successful cancellation")
 end,
 ui_blocked_preset_reports_the_specific_reason_locally=function()
  local kw,r,s,i,a,p=setup();local messages={};a.d=function(message)messages[#messages+1]=message end
  local preset=add(r,"Missing",{[EQUIP_SLOT_HEAD]={kind="item",uid="lost",link="lost"}})
  local ui=kw.UI.New(r,s,p,i);ui:Refresh();ui:RowClick(preset.id,1)
  assert(#s.calls==0 and #messages==1 and messages[1]:find(kw.Strings.MISSING_HELP,1,true))
 end,
 ui_multiple_partial_matches_and_stable_order=function()
  local kw,r,s,i,a,p=setup();a.bags[0][0]={uid="head",link="head"}
  add(r,"First",{[0]={kind="item",uid="head",link="head"}})
  add(r,"Second",{[1]={kind="empty"}})
  add(r,"Missing",{[11]={kind="item",uid="lost",link="lost"}})
  local ui=kw.UI.New(r,s,p,i); local v=ui:Refresh()
  assert(v.rows[1].name=="First" and v.rows[2].name=="Second")
  assert(v.rows[1].matches and v.rows[2].matches and not v.rows[3].matches)
  assert(#v.rows[3].missing==1 and not v.rows[3].canApply)
 end,
 ui_hover_keeps_worn_tick_and_has_no_redundant_name_popup=function()
  local kw,r,s,i,a,p=setup();add(r,"Plain name",{[EQUIP_SLOT_HEAD]={kind="empty"}})
  withNative(function(all,scene,put)
   local callbacks={};local popups=0;local previews=0
   put("zo_callLater",function(fn)callbacks[#callbacks+1]=fn end)
   put("InitializeTooltip",function()popups=popups+1 end)
   put("SetTooltipText",function()end)
   p.Show=function()previews=previews+1 end
   local ui=kw.UI.New(r,s,p,i);scene.callback(nil,SCENE_SHOWN)
   local row=ui.rows[1];assert(not row.more and not all.KanaWardrobeRow1More)
   assert(row.badge.text=="" and not row.tick.hidden)
   row.handlers.OnMouseEnter()
   for _,fn in ipairs(callbacks)do fn()end
   assert(previews==1 and popups==0,"hover should show set preview, without repeating preset name")
   assert(row.badge.text=="" and not row.tick.hidden,"worn tick must not change on hover")
  end)
 end,
 ui_context_menu_does_not_equip=function()
  local kw,r,s,i,a,p=setup();local preset=add(r,"A",{[0]={kind="empty"}})
  local ui=kw.UI.New(r,s,p,i);local actions=ui:RowClick(preset.id,2)
  assert(#actions==3 and actions[1].label==kw.Strings.EDIT and actions[2].label==kw.Strings.DUPLICATE and actions[3].label==kw.Strings.DELETE)
  actions[2].run()
  local copies=r:List();assert(#copies==2 and copies[2].name=='A (copy)' and ui:FindRow(copies[2].id))
  assert(copies[2].id~=preset.id and copies[2].equipment[0].kind=='empty')
  assert(#s.calls==0 and #a.requests==0)
  ui:RowClick(preset.id,1);assert(s.calls[1][1]=="Apply")
 end,
 ui_editor_flags_missing_and_pause_gate_actions=function()
  local kw,r,s,i,a,p=setup();local ui=kw.UI.New(r,s,p,i)
  s.view={state="editing",isEditor=true,selected={[0]=true},missing={[0]={uid="lost",link="lost"}}}
  local v=ui:Refresh();assert(not v.canNew and not v.canSave and v.canCancel)
  s.view.missing={};assert(ui:Refresh().canSave)
  s.view.paused=true;assert(not ui:Refresh().canSave)
  s.view.state="restoring";assert(not ui:Refresh().canCancel)
  ui:OnSceneHidden();assert(s.calls[#s.calls][1]=="Pause")
 end,
 ui_refresh_captures_inventory_only_once=function()
  local kw,r,s,i,a,p=setup()
  for n=1,5 do add(r,tostring(n),{[0]={kind="item",uid="missing"..n,link="link"}}) end
  local captures=0;local capture=i.Capture;i.Capture=function(self) captures=captures+1;return capture(self) end
  local ui=kw.UI.New(r,s,p,i);captures=0;ui:Refresh();assert(captures==1)
 end,
 ui_page_and_inventory_fragment_opening_coalesce_to_one_list_refresh=function()
  local kw,r,s,i,a,p=setup();add(r,'Gear',{[EQUIP_SLOT_RING1]={kind='empty'}})
  withNative(function(_,scene,put)
   local timers={};put('zo_callLater',function(cb)timers[#timers+1]=cb end)
   put('SCENE_FRAGMENT_SHOWING','fragmentShowing');put('SCENE_FRAGMENT_SHOWN','fragmentShown')
   local fragment={IsShowing=function()return true end}
   function fragment:RegisterCallback(_,cb)self.callback=cb end
   put('INVENTORY_FRAGMENT',fragment)
   SCENE_MANAGER.IsShowing=function()return true end
   local ui=kw.UI.New(r,s,p,i)
   local captures=0;local capture=i.Capture
   i.Capture=function(self,...)captures=captures+1;return capture(self,...)end
   scene.callback(nil,SCENE_SHOWING);fragment.callback(nil,SCENE_FRAGMENT_SHOWING)
   fragment.callback(nil,SCENE_FRAGMENT_SHOWN);scene.callback(nil,SCENE_SHOWN)
   assert(captures==0 and #timers==1,'opening synchronously rebuilt the list for every native transition')
   timers[1]()
   assert(captures==1 and not ui.content.hidden and ui.rows[1].title.text=='Gear')
  end)
 end,
 ui_layout_restores_all_anchors_without_drift=function()
  local kw,r,s,i,a,p=setup();local ui=kw.UI.New(r,s,p,i)
  local c={anchors={{10,"parent",20,3,4,7},{30,"other",40,5,6,8}},w=42,h=43}
  function c:GetNumAnchors()return #self.anchors end
  function c:GetAnchor(n)return true,table.unpack(self.anchors[n+1])end
  function c:GetDimensions()return self.w,self.h end
  function c:ClearAnchors()self.anchors={}end
  function c:SetAnchor(...)self.anchors[#self.anchors+1]={...}end
  function c:SetDimensions(w,h)self.w=w;self.h=h end
  for n=1,10 do ui:RememberLayout(c);c:ClearAnchors();c:SetAnchor(1,"x",2,44,55);c:SetDimensions(99,99);ui:RestoreLayout() end
  assert(#c.anchors==2 and c.anchors[1][4]==3 and c.anchors[2][6]==8 and c.w==42 and c.h==43)
 end,
 ui_extras_dialog_precise_and_rejection_safe=function()
  local kw,r,s,i,a,p=setup();local before=i:Capture().worn
  local plan={extras={{link="Shield",fromSlot=EQUIP_SLOT_OFF_HAND,reason="twoHanded"},{link="Ring",fromSlot=EQUIP_SLOT_RING1,toSlot=EQUIP_SLOT_RING2,reason="sourceMove"}}}
  local text=kw.Dialogs.ExtrasText(plan)
  assert(text:find("Shield",1,true) and text:find("backpack",1,true) and text:find("I",1,true))
  assert(text:find("Ring",1,true) and text:find("vacated",1,true))
  local rejected=false;local d=kw.Dialogs.ConfirmExtras(plan,"A",function()error("unexpected")end,function()rejected=true end)
  d.reject();assert(rejected and kw.Slots.Equal(before,i:Capture().worn))
  local deletion=kw.Dialogs.ConfirmDelete({name="Test"},function()end)
  assert(deletion.body:find("Test",1,true) and deletion.body:find("locked",1,true) and deletion.safeFirst)
 end,
 ui_native_layout_children_and_pause_restore=function()
  local kw,r,s,i,a,p=setup()
  withNative(function(controls,scene)
   local ui=kw.UI.New(r,s,p,i)
   local before={anchors=ZO_CharacterWeaponsSection.anchors,w=ZO_CharacterWeaponsSection.w,h=ZO_CharacterWeaponsSection.h}
   s.view={state="editing",isEditor=true,selected={[0]=true},missing={}}
   scene.callback(nil,SCENE_SHOWN)
   assert(not ui.content.hidden and ui.checks[0].checked and not ui.checks[0].hidden)
   local n=0;for _ in pairs(ui.checks)do n=n+1 end;assert(n==14)
   assert(ZO_CharacterWeaponsSection.anchors==before.anchors and ZO_CharacterWeaponsSection.w==before.w and ZO_CharacterWeaponsSection.h==before.h)
   scene.callback(nil,SCENE_HIDDEN)
   assert(ui.content.hidden and next(ui.checks)==nil)
   assert(ZO_CharacterWeaponsSection.anchors[1][5]==400 and s.calls[#s.calls][1]=="Pause")
   -- Fragment/root visibility cannot override the child's independent gate.
   ui.root:SetHidden(false);assert(ui.content.hidden)
  end)
 end,
 ui_problem_localization_has_safe_fallback=function()
  local kw=setup();local message=kw.Dialogs.Problem({code="mystery",details={stack="SECRET STACK"}})
  assert(message:find("mystery",1,true) and not message:find("SECRET STACK",1,true))
  assert(kw.Dialogs.Problem({code="unresolvedMissing"})~=kw.Strings.UNKNOWN_PROBLEM)
 end,
 native_refusal_message_explains_the_actual_server_result=function()
  withNative(function(_,_,put)
   local kw=setup();local unavailable=false
   put('GetString',function(id,result)
    if unavailable then error('unavailable')end
    assert(id=='SI_RESPECRESULT' and result==75)
    return 'Attribute respec is currently on cooldown.'
   end)
   assert(kw.Dialogs.Problem({code='nativeRespecRefused',details={domain='attributes',result=75}})==
    'Attribute respec is currently on cooldown. '..kw.Strings.BUILD_RETRY_PRESET)
   unavailable=true
   assert(kw.Dialogs.Problem({code='nativeRespecRefused',details={result=75}})==kw.Strings.PROBLEMS.nativeRespecRefused)
  end)
 end,

 ui_shared_filter_toggle_and_editor_bypass=function()
  local kw,r,s,i,a,p=setup()
  withNative(function()
   local ui=kw.UI.New(r,s,p,i)
   local filters={enabled=true,bypass=false,context="bankDeposit"}
   function filters:GetContexts()return {{context="backpack",active=self.context=="backpack"},{context="bankDeposit",active=self.context=="bankDeposit"}}end
   function filters:IsEnabled()return self.enabled end
   function filters:IsBypassed()return self.bypass end
   function filters:SetEnabled(v)self.enabled=v end
   function filters:HiddenCount(context)return context=="bankDeposit" and 12 or 3 end
   local a=ui:RegisterHideToggle(ui.content,"backpack",filters)
   local b=ui:RegisterHideToggle(ui.content,"bankDeposit",filters)
   assert(a==b and a.checked and a.labelText:find("12",1,true) and not a.hidden)
   filters.bypass=true;ui:RefreshToggles();assert(not a.enabled)
   filters.bypass=false;filters.context="backpack";ui:RefreshToggles();assert(a.enabled and a.labelText:find("3",1,true))
  end)
 end,

 ui_summary_uses_current_item_link_without_changing_preset=function()
  local kw,r,s,i,a,p=setup()
  local preset=add(r,"Upgraded",{[0]={kind="item",uid="item",link="old"}})
  local captures=0
  i.Capture=function()captures=captures+1;return {worn={},byUid={item={link="upgraded",metadata={valid=true,setId=7,max=5,bonuses={},availableToEquip=true,physicalAvailable=true}}}}end
  local ui=kw.UI.New(r,s,p,i);local summary=ui:Summary(preset)
  assert(captures==1 and summary.sets[1].representativeLink=="upgraded")
  assert(r:Get(preset.id).slots[0].link=="old")
 end,

 ui_reload_confirming_journal_does_not_show_stale_extras=function()
  local kw,r,_,i,a,p=setup();local session,reload=realConfirming(kw,r,i,a)
  session=reload();assert(session:GetView().state=="recovery" and session:GetView().confirmation)
  withNative(function(_,scene,put)
   local rt=dialogRuntime(put);local ui=kw.UI.New(r,session,p,i);scene.callback(nil,SCENE_SHOWN)
   assert(rt.shows==0 and not ui.recoverButton.hidden and not rt.active,"recovery must remain accessible without stale modal")
  end)
 end,
 ui_pause_retires_extras_and_old_callbacks_cannot_consume_resumed_confirmation=function()
  local kw,r,_,i,a,p=setup();local session=realConfirming(kw,r,i,a)
  withNative(function(_,scene,put)
   local rt=dialogRuntime(put);local ui=kw.UI.New(r,session,p,i);scene.callback(nil,SCENE_SHOWN);rt:Drain()
   local stale=assert(rt.active);assert(session:Pause("sceneHidden"));ui:Refresh()
   assert(not rt.active and not ui.resumeButton.hidden,"pause must retire active extras")
   assert(session:Resume());ui:Refresh();local current=assert(rt.active)
   rt.definitions[stale.name].buttons[2].callback(stale);stale.data.reject();rt:Drain()
   assert(rt.active==current and session:GetView().state=="confirming" and #a.requests==0)
   rt:Click(1);rt:Drain()
   assert(session:GetView().state=="idle" and not rt.active and #rt.queue==0 and rt.shows==2,"reject must not requeue before native release")
  end)
 end,
 ui_pause_removes_queued_extras_without_rejecting_session=function()
  local kw,r,_,i,a,p=setup();local session=realConfirming(kw,r,i,a)
  withNative(function(_,scene,put)
   local rt=dialogRuntime(put);local foreign={name="FOREIGN",data={}};rt.active=foreign
   local ui=kw.UI.New(r,session,p,i);scene.callback(nil,SCENE_SHOWN);rt:Drain();assert(#rt.queue==1)
   assert(session:Pause("sceneHidden"));ui:Refresh()
   assert(#rt.queue==0 and rt.active==foreign and session:GetView().paused,"only our queued confirmation should be retired")
   rt:Release(foreign,false);assert(not rt.active)
  end)
 end,
 ui_opening_context_menu_cancels_pending_hover_timer=function()
  local kw,r,s,i,a,p=setup();local preset=add(r,"A",{[0]={kind="empty"}})
  withNative(function(_,scene,put)
   local timers={};put("zo_callLater",function(cb)timers[#timers+1]=cb end)
   local shows=0;p.Show=function()shows=shows+1 end
   local ui=kw.UI.New(r,s,p,i);scene.callback(nil,SCENE_SHOWN)
   local row=ui:FindRow(preset.id);ui:Hover(row,ui.rows[1]);ui:ContextMenu(row)
   for _,cb in ipairs(timers)do cb()end
   assert(shows==0 and #s.calls==0,"pending hover must not reopen preview over the menu")
  end)
 end,

 ui_changed_confirmation_is_presented_only_after_native_modal_release=function()
  local kw,r,_,i,a,p=setup();local session=realConfirming(kw,r,i,a)
  withNative(function(_,scene,put)
   local rt=dialogRuntime(put);local ui=kw.UI.New(r,session,p,i);scene.callback(nil,SCENE_SHOWN);rt:Drain()
   local preset=r:List()[1];preset.name="Renamed";assert(r:Save(preset,preset.revision))
   rt:Click(2)
   assert(not rt.active and #rt.queue==0,"callback must not synchronously requeue a confirmation")
   rt:Drain()
   assert(rt.shows==2 and rt.active and #rt.queue==0 and session:GetView().problem.code=="confirmationChanged")
   rt:Click(1);rt:Drain();assert(session:GetView().state=="idle" and #a.requests==0)
  end)
 end,

 ui_repair_action_labels_respect_selected_locale=function()
  local kw=setup();local old=GetCVar
  GetCVar=function()return 'en'end;dofile(ROOT..'/lang/ru.lua')
  local english=kw.Strings.REPAIR_REMOVE=='Remove reference' and kw.Strings.REPAIR_REPLACE=='Replace with current draft'
  GetCVar=function()return 'ru'end;dofile(ROOT..'/lang/ru.lua')
  local russian=kw.Strings.REPAIR_REMOVE=='Удалить ссылку' and kw.Strings.REPAIR_REPLACE=='Заменить текущим выбором'
  GetCVar=old;assert(english and russian)
 end,
 ui_build_actions_and_problem_codes_are_localized=function()
  local kw=setup()
  for _,key in ipairs({"SAVE_AND_APPLY","ATTRIBUTES_INCLUDE","RECOVERY_ACTIONS","RECOVER_confirmActualTarget","RECOVER_acceptCurrent","RECOVER_remaining","RECOVER_restore","RECOVER_relinquishUnsent"})do
   assert(kw.Strings[key] and kw.Strings[key]~="","missing action label "..key)
  end
  for _,code in ipairs({"buildRequestTimeout","buildSubmissionUnresolved","nativeRespecRefused","attributeCastPending","foreignAttributeDraft","invalidEditorPage","editorDomainMismatch","invalidSelection","invalidComponentPatch","nativeDraftUnavailable","skillSubmissionUncertain","attributeSubmissionUncertain"})do
   assert(kw.Dialogs.Problem({code=code})~=kw.Strings.UNKNOWN_PROBLEM,"missing problem "..code)
  end
 end,

}
