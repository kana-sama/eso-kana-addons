local Fake=dofile(ROOT..'/tests/support/fake_eso.lua')
local G=dofile(ROOT..'/tests/support/geometry_controls.lua')
local function setup(f,page)
 local k=Fake.Load({'Core.lua','SoftPanel.lua','Slots.lua','lang/en.lua','Presets.lua','Inventory.lua','SetModel.lua','Dialogs.lua','SkillState.lua','PageAdapters.lua','SelectionOverlay.lua','UI.lua'})
 assert(k.SelectionOverlay,'missing SelectionOverlay module')
 local api=Fake.New();api.skillRequests={}
 local scenes={inventory=f.scene}
 for _,name in ipairs({'skills','stats'})do
  scenes[name]={AddFragment=function()end,RegisterCallback=function(self,_,cb)self.callback=cb end,IsShowing=function()return true end}
 end
 f:Put('SCENE_MANAGER',{GetScene=function(_,name)return scenes[name]end})
 local root=f:Control('ZO_Skills',GuiRoot,nil,580,600);root:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,650,120);f:Put('ZO_Skills',root)
 local bg=f:Control('ZO_SharedRightBackground',GuiRoot,nil,700,600);bg:SetAnchor(TOPLEFT,root,TOPLEFT,0,0);f:Put('ZO_SharedRightBackground',bg)
 local list=f:Control('SkillsList',root);list.activeControls={}
 local function skill(id,kind,auto,ranks)
  local s={id=id,kind=kind or 'active',auto=auto,ranks=ranks or 1}
  function s:GetSkillLineData()return {GetId=function()return 10 end,IsAvailable=function()return true end}end
  function s:IsCraftedAbility()return self.kind=='crafted'end
  function s:IsPassive()return self.kind=='passive'end
  function s:GetProgressionId()return self.id end
  function s:GetCraftedAbilityId()return self.id end
  function s:GetRankData()return {GetAbilityId=function()return self.id end}end
  function s:IsAutoGrant()return self.auto==true end
  function s:GetNumRanks()return self.ranks end
  function s:CanPointAllocationsBeAltered()return self.alterable==true end
  return s
 end
 local row=f:Control('NativeSkillRow',list,nil,580,70);row:SetAnchor(TOPLEFT,root,TOPLEFT,0,50)
 local slot=f:Control('NativeSkillRowSlot',row,nil,56,56);slot:SetAnchor(LEFT,row,LEFT,117,0);row.children.Slot=slot
 local icon=f:Control('NativeSkillRowSlotIcon',slot);icon:SetAnchor(TOPLEFT,slot,TOPLEFT,2,2);icon:SetAnchor(BOTTOMRIGHT,slot,BOTTOMRIGHT,-2,-2);slot.children.Icon=icon
 row.dataEntry={typeId=1,data={skillData=skill(51)}};list.activeControls[1]=row
 slot:SetHandler('OnDragStart',function()api.skillRequests[#api.skillRequests+1]='drag'end)
 slot:SetHandler('OnMouseDoubleClick',function()api.skillRequests[#api.skillRequests+1]='purchase'end)
 local nativeHandlers={drag=slot:GetHandler('OnDragStart'),purchase=slot:GetHandler('OnMouseDoubleClick')}
 local buttons={}
 for i=1,6 do
  local outer=f:Control('NativeAssignable'..i,root,nil,56,56);outer:SetAnchor(TOPLEFT,root,TOPLEFT,64*(i-1),520)
  local button=f:Control(outer.name..'Button',outer);button:SetAnchorFill(outer)
  local bi=f:Control(outer.name..'Icon',outer);bi:SetAnchor(TOPLEFT,outer,TOPLEFT,2,2);bi:SetAnchor(BOTTOMRIGHT,outer,BOTTOMRIGHT,-2,-2)
  button:SetHandler('OnDragStart',nativeHandlers.drag);button:SetHandler('OnMouseUp',nativeHandlers.purchase)
  buttons[i]={button=button,icon=bi,slotId=i+2}
 end
 f:Put('SKILLS_WINDOW',{control=root,skillList=list,assignableActionBar={buttons=buttons}})
 for name,val in pairs({HOTBAR_CATEGORY_PRIMARY=0,HOTBAR_CATEGORY_BACKUP=1,HOTBAR_CATEGORY_OVERLOAD=2,HOTBAR_CATEGORY_WEREWOLF=3,ACTION_BAR_FIRST_NORMAL_SLOT_INDEX=2,ACTION_BAR_ULTIMATE_SLOT_INDEX=7,SKILL_POINT_ALLOCATION_MODE_FULL=2,MOUSE_BUTTON_INDEX_LEFT=1})do f:Put(name,val)end
 local bars={category=0,locked={},immutable={},override={}}
 function bars:GetCurrentHotbarCategory()return self.category end
 function bars:GetHotbar()return {IsSlotLocked=function(_,s)return self.locked[s]end,IsSlotMutable=function(_,s)return not self.immutable[s]end,GetOverrideSkillDataForSlot=function(_,s)return self.override[s]end}end
 f:Put('ACTION_BAR_ASSIGNMENT_MANAGER',bars)
 f:Put('ZO_ScrollList_GetData',function(c)return c.dataEntry and c.dataEntry.data end)
 local selection={equipment={},skills={['10:active:51']=true},bars={front={[1]=true,[6]=true},back={[2]=true}}}
 for _,s in ipairs(k.Slots.Order)do selection.equipment[s]=true end
 local component=page=='skills'and 'abilities'or 'equipment'
 local session={view={state='editing',isEditor=true,name='Preset',page=page,component=component,selection=selection,selected=selection.equipment,missing={},draft={abilities={skills={['10:active:51']={kind='active',purchased=true,morph=1}},bars={front={},back={}}}}},active=true,reads=0,calls={}}
 function session:GetView()self.reads=self.reads+1;return self.view end
 function session:IsEditorActive()return self.active end
 function session:GetSelected(domain,key)
  if domain=='bars'then return selection.bars[key.bar]and selection.bars[key.bar][key.slot]==true end
  return selection[domain]and selection[domain][key]==true or false
 end
 function session:SetSelected(domain,key,value)
  if type(domain)=="number"then value=key;key=domain;domain="equipment"end
  self.calls[#self.calls+1]={domain,key,value}
  if domain=='bars'then selection.bars[key.bar][key.slot]=value else selection[domain][key]=value end
  return true
 end
 local inventory=k.Inventory.New(api);local repo=k.Presets.New({},'EU','a','c','Kana');local pages=k.PageAdapters.New(api)
 local ui=k.UI.New(repo,session,{Hide=function()end},inventory,{pages=pages})
 ui.page=page;ui.visible=true;ui:Refresh()
 return {k=k,api=api,ui=ui,session=session,selection=selection,row=row,slot=slot,icon=icon,buttons=buttons,bars=bars,skill=skill,handlers=nativeHandlers,list=list}
end
local function find(ui,parent)
 for _,overlay in pairs(ui.selectionOverlays or {})do if overlay.control.parent==parent then return overlay end end
 error('selection overlay missing for '..parent.name)
end
local function click(overlay)overlay.control.handlers.OnClicked(overlay.control,MOUSE_BUTTON_INDEX_LEFT or 1)end
return {
 werewolf_native_slots_have_their_own_corner_selection=function()
  G.With(1920,1080,1,function(f)
   local t=setup(f,'skills');t.selection.bars.werewolf={}
   t.bars.category=HOTBAR_CATEGORY_WEREWOLF;t.ui:RefreshSelectionOverlays()
   local first=find(t.ui,t.buttons[1].button)
   assert(not first.control.hidden,'werewolf checkbox missing');click(first)
   assert(t.selection.bars.werewolf[1] and not t.selection.bars.back[1])
   t.bars.override[8]={};t.ui:RefreshSelectionOverlays()
   assert(not find(t.ui,t.buttons[6].button).enabled,'native forced ultimate must stay read-only')
   t.bars.category=HOTBAR_CATEGORY_PRIMARY;t.ui:RefreshSelectionOverlays()
   assert(first.control.checked)
  end)
 end,
 native_update_timestamp_is_throttled_and_own_show_restarts_cached_editor=function()
  G.With(1920,1080,1,function(f)
   local t=setup(f,'skills');local n=0;local scalar=t.session.GetSelected
   t.session.GetSelected=function(self,...)n=n+1;return scalar(self,...)end
   local handler=t.ui.overlayUpdate.handlers.OnUpdate
   handler(t.ui.overlayUpdate,100);local first=n;assert(first>0)
   handler(t.ui.overlayUpdate,100.01);assert(n==first,'native OnUpdate gives absolute time, not elapsed')
   handler(t.ui.overlayUpdate,100.11);assert(n>first)
   t.ui.overlayUpdate.handlers.OnEffectivelyHidden(t.ui.overlayUpdate)
   assert(not t.ui.overlayUpdate.handlers.OnUpdate)
   assert(t.ui.overlayUpdate.handlers.OnEffectivelyShown,'own shown restart missing')(t.ui.overlayUpdate)
   assert(t.ui.overlayUpdate.handlers.OnUpdate and not find(t.ui,t.slot).control.hidden)
  end)
 end,
 equipment_checkbox_retains_existing_numeric_set_selected_call=function()
  G.With(1920,1080,1,function(f)
   local t=setup(f,'inventory');local o=find(t.ui,ZO_CharacterEquipmentSlotsHead)
   function t.session:SetSelected(slot,value)
    assert(type(slot)=='number' and type(value)=='boolean','legacy equipment setter receives numeric slot and boolean')
    t.selection.equipment[slot]=value;return true
   end
   click(o);assert(t.selection.equipment[EQUIP_SLOT_HEAD]==false and #t.api.requests==0)
  end)
 end,
 effective_content_hide_disposes_updates_without_waiting_for_scene_callback=function()
  G.With(1920,1080,1,function(f)
   local t=setup(f,'skills');local o=find(t.ui,t.slot)
   local hide=assert(t.ui.overlayUpdate.handlers.OnEffectivelyHidden,'effective hide callback missing')
   hide(t.ui.overlayUpdate)
   assert(o.control.hidden and not o.control.handlers.OnClicked and not t.ui.overlayUpdate.handlers.OnUpdate)
  end)
 end,
 repeated_editor_cycles_reuse_own_controls_without_accumulating_hidden_children=function()
  G.With(1920,1080,1,function(f)
   local t=setup(f,'skills');local count=0
   for _ in pairs(f.controls)do count=count+1 end
   for _=1,8 do t.ui:ClearSelectionOverlays();t.ui:Refresh()end
   local after=0;for _ in pairs(f.controls)do after=after+1 end
   assert(after==count,'each editor cycle allocated new permanently hidden controls')
  end)
 end,
 locked_or_overridden_current_slot_does_not_toggle_stale_selection=function()
  G.With(1920,1080,1,function(f)
   local t=setup(f,'skills');local o=find(t.ui,t.buttons[1].button)
   t.bars.locked[3]=true;t.ui:RefreshSelectionOverlays();assert(not o.control.enabled and not o.control.checked)
   click(o);assert(#t.session.calls==0)
   t.bars.locked[3]=nil;t.bars.override[3]=t.skill(90);t.ui:RefreshSelectionOverlays();assert(not o.control.enabled)
   t.bars.override[3]=nil;t.bars.immutable[3]=true;t.ui:RefreshSelectionOverlays();assert(not o.control.enabled)
   t.bars.immutable[3]=nil;t.ui:RefreshSelectionOverlays();assert(o.control.enabled and o.control.checked)
  end)
 end,
 removing_visible_pool_row_retires_handlers_and_page_change_blocks_old_click=function()
  G.With(1920,1080,1,function(f)
   local t=setup(f,'skills');local o=find(t.ui,t.slot)
   t.list.activeControls={};t.ui:RefreshSelectionOverlays();assert(o.control.hidden and not o.control.handlers.OnClicked)
   t.list.activeControls={t.row};t.ui:RefreshSelectionOverlays();local fresh=find(t.ui,t.slot)
   assert(fresh~=o and fresh.control.checked)
   t.ui.page='inventory';click(fresh);assert(#t.session.calls==0 and fresh.control.hidden)
  end)
 end,
 overlay_bind_and_destroy_never_reanchor_parent_or_keep_click_handler=function()
  G.With(1920,1080,1,function(f)
   local t=setup(f,'skills');local before=t.buttons[2].icon.anchors
   local o=t.k.SelectionOverlay.New(t.buttons[2].button,function()return {domain='bars',key={bar='front',slot=2},selected=true}end,function()end)
   o:Bind(t.buttons[2].icon);o:Refresh();G.Contained(o.control,t.buttons[2].icon)
   assert(t.buttons[2].icon.anchors==before);o:Destroy();o:Destroy()
   assert(o.control.hidden and not o.control.enabled and not o.control.checked and not o.control.handlers.OnClicked)
  end)
 end,
 overlay_inside_every_equipment_icon=function()
  for _,scale in ipairs({.75,1,1.25,2})do G.With(2560,1440,scale,function(f)
   local t=setup(f,'inventory');local n=0
   for _,native in ipairs(f.equipment)do
    if not native.name:find('Costume')and not native.name:find('Poison')then
     local o=find(t.ui,native);G.Contained(o.control,native:GetNamedChild('Icon'));assert(o.control.w==18 and o.control.h==18);n=n+1
    end
   end
   assert(n==14)
  end)end
 end,
 pooled_skill_row_uses_current_key=function()
  G.With(1920,1080,1,function(f)
   local t=setup(f,'skills');local o=find(t.ui,t.slot);assert(o.control.checked)
   t.row.dataEntry.data.skillData=t.skill(52)
   click(o);assert(t.selection.skills['10:active:52']==true and t.selection.skills['10:active:51']==true)
   assert(t.session.calls[1][2]=='10:active:52')
  end)
 end,
 checkbox_click_does_not_equip_purchase_or_drag=function()
  G.With(1920,1080,1,function(f)
   local t=setup(f,'skills');click(find(t.ui,t.slot));click(find(t.ui,t.buttons[1].button))
   assert(#t.api.requests==0 and #t.api.skillRequests==0)
   assert(t.slot:GetHandler('OnDragStart')==t.handlers.drag and t.slot:GetHandler('OnMouseDoubleClick')==t.handlers.purchase)
   assert(t.buttons[1].button:GetHandler('OnDragStart')==t.handlers.drag)
   t.slot.handlers.OnDragStart(t.slot);assert(#t.api.skillRequests==1)
  end)
 end,
 normal_bar_swap_resolves_current_category_and_ultimate_empty_icons=function()
  G.With(1920,1080,1,function(f)
   local t=setup(f,'skills');local first=find(t.ui,t.buttons[1].button);local ult=find(t.ui,t.buttons[6].button)
   assert(first.control.checked and ult.control.checked)
   -- Native ZO_ActionSlot_ClearSlot hides the empty icon texture only.
   t.buttons[6].icon:SetHidden(true);t.ui:RefreshSelectionOverlays()
   assert(not ult.control.hidden and ult.control.enabled and ult.control.checked,'empty ultimate slot still needs selection')
   t.bars.category=HOTBAR_CATEGORY_BACKUP;click(first)
   assert(t.selection.bars.back[1]==true and t.selection.bars.front[1]==true)
   t.ui:RefreshSelectionOverlays();assert(find(t.ui,t.buttons[2].button).control.checked and not ult.control.checked)
   click(ult);assert(t.selection.bars.back[6]==true)
   t.bars.category=HOTBAR_CATEGORY_OVERLOAD;t.ui:RefreshSelectionOverlays();assert(first.control.hidden and not first.control.checked)
   local calls=#t.session.calls;click(first);assert(#t.session.calls==calls)
  end)
 end,
 current_ineligible_or_released_rows_clear_selection_without_stale_click=function()
  G.With(1920,1080,1,function(f)
   local t=setup(f,'skills');local o=find(t.ui,t.slot)
   for _,s in ipairs({t.skill(60,'crafted'),t.skill(61,'passive',true,1),t.skill(62,'active',true)})do
    t.row.dataEntry.data.skillData=s;t.ui:RefreshSelectionOverlays();assert(not o.control.enabled and not o.control.checked)
    local n=#t.session.calls;click(o);assert(#t.session.calls==n)
   end
   t.row.dataEntry.data.skillData=t.skill(63,'passive',true,2);t.ui:RefreshSelectionOverlays();assert(o.control.enabled)
   t.row.dataEntry=nil;t.ui:RefreshSelectionOverlays();assert(o.control.hidden and not o.control.checked)
   t.row.dataEntry={typeId=1,data={skillData=t.skill(51)}};t.row:SetHidden(true);t.ui:RefreshSelectionOverlays();assert(o.control.hidden and not o.control.checked)
  end)
 end,
 refresh_reads_no_whole_view_capture_or_catalogue_and_disposes_outside_editor=function()
  G.With(1920,1080,1,function(f)
   local t=setup(f,'skills');local o=find(t.ui,t.slot);local handler=assert(t.ui.overlayUpdate.handlers.OnUpdate)
   local reads=t.session.reads;t.session.GetView=function()error('per tick GetView')end
   t.ui.inventory.Capture=function()error('per tick capture')end;t.k.SkillState.Read=function()error('per tick catalogue')end
   t.k.Copy=function()error('per tick map copy')end
   for _=1,5 do handler(t.ui.overlayUpdate,1)end
   assert(t.session.reads==reads)
   t.session.active=false;handler(t.ui.overlayUpdate,1)
   assert(o.control.hidden and not o.control.mouse and not o.control.handlers.OnClicked)
   assert(not t.ui.overlayUpdate.handlers.OnUpdate and next(t.ui.selectionOverlays)==nil)
  end)
 end,
 editor_hide_clears_transient_loop_and_does_not_move_native_geometry=function()
  G.With(1920,1080,1,function(f)
   local before={};for _,c in ipairs(f.equipment)do before[c]={rect=c:Rect(),anchor=c.anchors[1],w=c.w,h=c.h}end
   local t=setup(f,'inventory');local check=t.ui.checks[EQUIP_SLOT_MAIN_HAND]
   for c,b in pairs(before)do local r=c:Rect();for k,v in pairs(b.rect)do assert(r[k]==v)end;assert(c.anchors[1]==b.anchor and c.w==b.w and c.h==b.h)end
   t.ui:OnSceneHidden('inventory');assert(check.hidden and not t.ui.overlayUpdate.handlers.OnUpdate)
   assert(next(t.ui.selectionOverlays)==nil)
  end)
 end,
}
