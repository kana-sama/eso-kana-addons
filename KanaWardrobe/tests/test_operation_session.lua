local setup=dofile(ROOT..'/tests/support/operation_fixture.lua')
local function create(saved)
 local f=setup();assert(f.k.OperationSession,'operation sessions not implemented')
 f.services.operations=true
 f.services.checkDrafts=function()return true end
 f.saved=saved or f.repo.character
 f.session=f.k.Session.New(f.repo,f.inventory,f.k.EquipmentPlan,nil,f.protection,f.saved,{},function(name,payload)f.events:Emit(name,payload)end,f.services)
 f.x=f.session.operations
 function f:Tick(n)for i=1,n or 1 do self:Advance(2)end end
 function f:ReloadSession()
  self.saved=self.k.Copy(self.saved)
  self:ResetAttributesNative()
  self.skills=self.k.SkillAdapter.New(self.api,self.events,self.clock)
  self.attributes=self.k.AttributeAdapter.New(self.api,self.events)
  self.services.skills=self.skills;self.services.attributes=self.attributes
  self.session=self.k.Session.New(self.repo,self.inventory,self.k.EquipmentPlan,nil,self.protection,self.saved,{},nil,self.services)
  self.x=self.session.operations
 end
 function f:SavePreset(build,name)return assert(self.repo:PatchComponent(nil,'equipment',build.equipment and {op='replace',value=build.equipment}or nil,name or 'Test',nil))end
 return f
end
return {
 native_skill_cancel_releases_editor_before_or_after_page_hiding=function()
  for _,resetFirst in ipairs({false,true})do
   local f=create();local key='10:active:51'
   local p=assert(f.repo:PatchComponent(nil,'abilities',{op='replace',value={skills={[key]={kind='active',purchased=true,morph=2}}}},'Morph'))
   assert(f.session:BeginEdit(p.id,false,'skills'));f:Tick(5)
   assert(f.session:IsEditorActive() and f.skills:CaptureDraft().skills[key].morph==2)
   local global=f.api.SKILLS_AND_ACTION_BAR_MANAGER
   if resetFirst then global:ResetInterface()end
   f.session:OnNativePageState('skills','hiding')
   -- ESO resets the editor in OnHidden, which can follow our HIDING callback.
   if not resetFirst then global:ResetInterface()end
   f:Tick(6)
   assert(not f.x:GetView(),'confirmed native cancel left a failed operation')
   assert(not f.skills:GetNativeOwnership() and not f.session.journal)
   f.session:OnNativePageState('skills','showing')
   assert(f.session:BeginEdit(p.id,false,'skills'));f:Tick(5)
   assert(f.session:IsEditorActive() and f.skills:CaptureDraft().skills[key].morph==2)
   assert(#f.requests.skills==0 and f.skillObjects[1]:GetCurrentMorphSlot()==1)
  end
 end,
 new_edit_releases_a_cancelled_skill_draft_after_failed_cleanup=function()
  for _,page in ipairs({'skills','inventory','stats'})do
   local f=create()
   local p=assert(f.repo:PatchComponent(nil,'abilities',{op='replace',value={skills={['10:active:51']={kind='active',purchased=true,morph=2}}}},'Morph'))
   assert(f.session:BeginEdit(p.id,false,'skills'));f:Tick(5)
   f.session:OnNativePageState('skills','hiding')
   f.api.SKILLS_AND_ACTION_BAR_MANAGER:ResetInterface();f.foreignPending=true
   f:Tick(6);assert(f.x:GetView().status=='failed' and f.skills:GetNativeOwnership())
   f.foreignPending=false
   f.session:OnNativePageState(page,'showing')
   assert(f.session:BeginEdit(p.id,false,page));f:Tick(6)
   assert(f.session:IsEditorActive(),'old cancelled draft blocked editing on '..page)
   assert(#f.requests.skills==0 and f.attributeSends==0 and #f.api.requests==0)
  end
 end,
 automatic_werewolf_binding_has_an_executable_step_when_talents_already_match=function()
  local f=create();f.skillObjects[1].spec.ultimate=true
  f.overrides={['3:8']=f.skillObjects[1]};f.api.ACTION_BAR_ASSIGNMENT_MANAGER:ResetPlayerHotbars()
  local p=assert(f.repo:PatchComponent(nil,'abilities',{op='replace',value={skills={['10:active:51']={kind='active',purchased=true,morph=1}}}},'Same talent'))
  assert(f.session:Apply(p.id));f:Tick(2)
  local packet=f.requests.skills[1];assert(packet and #packet.bars==1 and packet.bars[1].bar==3 and packet.bars[1].slot==8)
  f.actualBars[3][8]={type=1,id=511};f.api.ACTION_BAR_ASSIGNMENT_MANAGER:ResetPlayerHotbars()
  f.events:Emit('NativeSkillRespecResult',{result=0});f:Tick(8)
  assert(not f.x:GetView(),'automatic binding was verified without an execution step')
 end,
 quick_save_skips_werewolf_bar_when_line_is_unavailable=function()
  local f=create();f.werewolfAvailable=false
  assert(f.session:QuickSave());assert(not f.repo:Get(f.k.Presets.QUICK_ID).abilities.bars.werewolf)
 end,
 werewolf_selection_is_optional_and_survives_editor_save=function()
  local f=create();f.actualBars[3][3]={type=1,id=511};f.api.ACTION_BAR_ASSIGNMENT_MANAGER:ResetPlayerHotbars()
  assert(f.session:BeginNew('skills'));f:Tick(5)
  assert(f.session:IsEditorActive())
  assert(not f.session.draft:GetPresetBuild().abilities.bars or not f.session.draft:GetPresetBuild().abilities.bars.werewolf)
  assert(f.session:SetSelected('bars',{bar='werewolf',slot=1},true))
  assert(f.session:SetSelected('bars',{bar='werewolf',slot=2},true))
  assert(f.session:GetSelected('bars',{bar='werewolf',slot=1}))
  assert(f.session:Save());f:Tick(8)
  assert(not f.x:GetView() and not f.skills.mounted)
  local saved=f.repo:List()[1].abilities.bars.werewolf
  assert(saved[1].skillKey=='10:active:51' and saved[2].kind=='empty' and saved[3]==nil)
  assert(#f.requests.skills==0 and f.api.GetSlotBoundId(3,3)==511)
 end,
 werewolf_step_can_resume_after_reload_and_only_sends_remaining_changes=function()
  local f=create();local ref={kind='skill',skillKey='10:active:51',expectedMorph=1}
  local p=assert(f.repo:PatchComponent(nil,'abilities',{op='replace',value={bars={werewolf={[1]=ref,[2]={kind='empty'}}}}},'Wolf'))
  assert(f.session:Apply(p.id));f:Tick(2)
  local packet=f.requests.skills[1];assert(packet and #packet.skills==0 and #packet.bars==1 and packet.bars[1].bar==3)
  f.x:Pause();f:ReloadSession()
  assert(f.x:GetView().status=='paused')
  -- The server completed while the interface was reloading.
  f.actualBars[3][3]={type=1,id=511};f.api.ACTION_BAR_ASSIGNMENT_MANAGER:ResetPlayerHotbars()
  assert(f.x:Continue());f:Tick(8)
  assert(not f.x:GetView() and #f.requests.skills==1,'resume resent an already completed bar')
  assert(f.k.BuildModel.Matches({abilities=f.skills:Capture()},p))
 end,
 quick_save_omits_the_native_fixed_werewolf_ultimate=function()
  local f=create();f.skillObjects[1].spec.ultimate=true
  f.overrides={['3:8']=f.skillObjects[1]};f.api.ACTION_BAR_ASSIGNMENT_MANAGER:ResetPlayerHotbars()
  assert(f.session:QuickSave());local q=f.repo:Get(f.k.Presets.QUICK_ID)
  assert(q.abilities.bars.werewolf and not q.abilities.bars.werewolf[6],'fixed ultimate became a preset constraint')
 end,
 apply_remorphs_unselected_bar_without_stopping_for_consent=function()
  local f=create();f.actualBars[1][5]={type=1,id=511};f.api.ACTION_BAR_ASSIGNMENT_MANAGER:ResetPlayerHotbars()
  local p=assert(f.repo:PatchComponent(nil,'abilities',{op='replace',value={skills={['10:active:51']={kind='active',purchased=true,morph=2}}}},'Morph'))
  assert(f.session:Apply(p.id));f:Tick()
  assert(f.x:GetView().status=='running' and f.x:GetView().steps[1].status=='done','implicit morph stopped the plan')
 end,
 reload_between_mount_and_open_recreates_only_local_draft=function()
  local f=create();local p=assert(f.repo:PatchComponent(nil,'attributes',{op='replace',value={health=0,magicka=0,stamina=64}},'Attrs'))
  f.session:BeginEdit(p.id,false,'stats');f:Tick(2)
  assert(f.x.operation.steps[f.x.operation.index].kind=='openEditor' and f.attributes.mounted)
  f.x:Pause();f:ReloadSession();assert(not f.attributes.mounted)
  f.x:Continue();f:Tick(4)
  assert(f.session:IsEditorActive() and f.attributes.mounted,'editor opened without its native draft')
  assert(f.attributes:CaptureDraft().stamina==64 and f.attributeSends==0)
  f.session:Save();f:Tick(6);assert(not f.x:GetView() and not f.attributes.mounted)
 end,
 restart_and_reload_preserve_pre_editor_equipment_for_cancel=function()
  local f=create();f:AddItem('old1',EQUIP_SLOT_RING1,true);f:AddItem('old2',EQUIP_SLOT_RING2,true)
  local a=f:AddItem('new1',3);local b=f:AddItem('new2',4)
  local p=f:SavePreset({equipment={[EQUIP_SLOT_RING1]=a,[EQUIP_SLOT_RING2]=b}})
  f.session:BeginEdit(p.id,false,'inventory');f:Tick(2);f.x:Pause();f:AckGear(1)
  assert(f.x:GetView().status=='pausing','pause must wait for the whole sent batch')
  f:AckGear(2)
  assert(f.x:GetView().status=='paused')
  f:ReloadSession();assert(f.x:Restart());f:Tick(6)
  assert(f.session:IsEditorActive());assert(f.session:Cancel());f:Tick(2)
  local acknowledged=2
  for i=1,12 do
   local op=f.x.operation
   if #f.api.requests>acknowledged then acknowledged=acknowledged+1;f:AckGear(acknowledged)else f:Tick()end
  end
  assert(not f.x:GetView())
  local actual=f.inventory:Capture(false).worn
  assert(actual[EQUIP_SLOT_RING1].uid=='old1' and actual[EQUIP_SLOT_RING2].uid=='old2','restart lost the pre-editor baseline')
 end,
 save_before_diff_can_resume_after_reload_without_losing_editor=function()
  for _,page in ipairs({'inventory','stats'})do
   local f=create();f:AddItem('ring',EQUIP_SLOT_RING1,true)
   if page=='stats'then
    local p=assert(f.repo:PatchComponent(nil,'attributes',{op='replace',value={health=0,magicka=0,stamina=64}},'Attrs'))
    f.session:BeginEdit(p.id,false,page)
   else f.session:BeginNew(page)end
   f:Tick(4);assert(f.session:IsEditorActive())
   local expected=f.session.draft:GetPresetBuild()
   assert(f.session:Save());assert(f.x:Pause());assert(not f.x.operation.intent.editor)
   f:ReloadSession();local reads=#f.captures
   assert(f.x:GetView().status=='paused' and #f.captures==reads)
   assert(f.x:Continue());f:Tick(8)
   assert(not f.x:GetView(),'save before diff failed after reload: '..tostring(f.x.operation and f.x.operation.steps[f.x.operation.index].problem.code))
   local stored=f.repo:List();assert(#stored==1 and f.k.BuildModel.Matches(stored[1],expected))
   assert(#f.api.requests==0 and f.attributeSends==0 and #f.requests.skills==0)
  end
 end,
 unchecked_unavailable_skills_are_not_sent_by_save_apply=function()
  local f=create();local key='99:active:999'
  local p=assert(f.repo:PatchComponent(nil,'attributes',{op='replace',value={health=0,magicka=0,stamina=64}},'Missing skill'))
  p=assert(f.repo:PatchComponent(p.id,'abilities',{op='replace',value={skills={[key]={kind='active',purchased=true,morph=0}},bars={front={[1]={kind='skill',skillKey=key,expectedMorph=0}}}}},p.name,p.revision))
  f.session:BeginEdit(p.id,false,'skills');f:Tick(4);assert(f.session:IsEditorActive())
  assert(f.session:SetSelected('skills',key,false));assert(f.session:SetSelected('bars',{bar='front',slot=1},false))
  f.session:SaveAndApply();f:Tick(8)
  assert(not f.x:GetView(),'unchecked unavailable skill blocked native apply')
  assert(not f.repo:Get(p.id).abilities and f.repo:Get(p.id).attributes.stamina==64)
  assert(#f.requests.skills==0 and f.attributeSends==0)
 end,
 missing_gear_editor_can_omit_reference_and_save_other_part=function()
  local f=create();local p=f:SavePreset({equipment={[EQUIP_SLOT_RING1]={kind='item',uid='lost',link='lost'}}})
  p=assert(f.repo:PatchComponent(p.id,'attributes',{op='replace',value={health=10,magicka=20,stamina=34}},p.name,p.revision))
  f.session:BeginEdit(p.id,true,'inventory');f:Tick(4)
  assert(f.session:GetView().state=='editing')
  assert(f.session:ResolveMissing(EQUIP_SLOT_RING1,'omit'))
  f.session:Save();f:Tick(6)
  assert(not f.x:GetView() and not f.repo:Get(p.id).equipment and f.repo:Get(p.id).attributes)
 end,
 apply_opens_before_capture_and_failure_keeps_list_available=function()
  local f=create();local p=f:SavePreset({equipment={[EQUIP_SLOT_RING1]={kind='item',uid='lost',link='lost'}}})
  assert(f.session:Apply(p.id));assert(f.x:GetView().steps[1].status=='pending' and #f.captures==0)
  f:Tick();assert(f.x:GetView().status=='failed' and f.x:GetView().steps[1].problem)
  assert(f.session:GetView().state=='idle' and not f.session:GetView().isEditor)
  assert(f.session:Apply(p.id))
 end,
 gear_edit_save_restore_isolated_from_other_components=function()
  local f=create();local old=f:AddItem('old',EQUIP_SLOT_RING1,true);local new=f:AddItem('new',3)
  local p=f:SavePreset({equipment={[EQUIP_SLOT_RING1]=new}})
  f.skills.Catalogue=function()error('gear must not inspect skills')end;f.attributes.Capture=function()error('gear must not inspect attributes')end
  assert(f.session:BeginEdit(p.id,false,'inventory'));f:Tick(2);f:AckGear();f:Tick(3)
  assert(f.session:GetView().state=='editing' and not f.x:GetView())
  assert(f.session:Save());f:Tick(3);f:AckGear();f:Tick(4)
  assert(not f.x:GetView() and f.session:GetView().state=='idle')
  assert(f.inventory:Capture(false).worn[EQUIP_SLOT_RING1].uid=='old')
 end,
 attribute_editor_save_closes_draft_without_applying=function()
  local f=create();local p=assert(f.repo:PatchComponent(nil,'attributes',{op='replace',value={health=0,magicka=0,stamina=64}},'Attrs'))
  assert(f.session:BeginEdit(p.id,false,'stats'));f:Tick(4)
  assert(f.session:GetView().state=='editing' and f.attributeSends==0 and f.attributes.mounted)
  assert(f.session:Save());f:Tick(5)
  assert(not f.attributes.mounted and f.attributeSends==0 and not f.x:GetView())
  assert(f.actualAttributes[1]==10)
 end,
 save_and_apply_does_not_restore_gear=function()
  local f=create();f:AddItem('old',EQUIP_SLOT_RING1,true);local ref=f:AddItem('new',3)
  local p=f:SavePreset({equipment={[EQUIP_SLOT_RING1]=ref}})
  f.session:BeginEdit(p.id,false,'inventory');f:Tick(2);f:AckGear();f:Tick(3)
  f.session:SaveAndApply();f:Tick(6)
  assert(not f.x:GetView() and #f.api.requests==1 and f.inventory:Capture(false).worn[EQUIP_SLOT_RING1].uid=='new')
 end,
 save_observer_failure_retry_does_not_duplicate_commit=function()
  local f=create();f:AddItem('ring',EQUIP_SLOT_RING1,true)
  f.session:BeginNew('inventory');f:Tick(4);assert(f.session:GetView().state=='editing')
  f.repo.emit=function()error('observer failed')end
  f.session:Save();f:Tick(2);assert(f.x:GetView().status=='failed' and #f.repo:List()==1)
  local rev=f.repo:List()[1].revision
  f.repo.emit=function()end;assert(f.x:Continue());f:Tick(6)
  assert(not f.x:GetView() and #f.repo:List()==1 and f.repo:List()[1].revision==rev)
 end,
 old_recovery_is_archived_without_locking_list_or_scanning=function()
  local f=create({journal={version=2,kind='apply',name='Old',target={attributes={health=0,magicka=0,stamina=64}},problem={code='oldFailure'}}})
  assert(#f.captures==0 and not f.saved.journal and f.saved.legacyOperations[1].problem.code=='oldFailure')
  assert(f.x:GetView().status=='paused' and f.session:GetView().state=='idle')
 end,
 reload_preserves_editor_and_cancels_without_reapplying_draft=function()
  local f=create();local p=assert(f.repo:PatchComponent(nil,'attributes',{op='replace',value={health=0,magicka=0,stamina=64}},'Attrs'))
  f.session:BeginEdit(p.id,false,'stats');f:Tick(4)
  local saved=f.k.Copy(f.saved);local g=create(saved)
  assert(#g.captures==0 and g.x:GetView().status=='paused' and g.attributeSends==0)
  g.x:Continue();g:Tick(5);assert(not g.x:GetView() and not g.session.journal)
 end,
 view_and_page_open_never_recalculate=function()
  local f=create();f.services.capture=function()error('not a UI read')end
  f.session:OnNativePageState('skills','showing');for i=1,20 do assert(f.session:GetView().state=='idle')end
 end,
}
