local Fake=dofile(ROOT..'/tests/support/fake_eso.lua')
local BF=dofile(ROOT..'/tests/support/build_fixture.lua')
local AF=dofile(ROOT..'/tests/support/attribute_fixture.lua')
local function setup()
 local k=Fake.Load({'Core.lua','Slots.lua','lang/en.lua','BuildModel.lua','Presets.lua','Inventory.lua','EquipmentPlan.lua','EquipmentRunner.lua','Protection.lua','SkillState.lua','SkillAdapter.lua','AttributeAdapter.lua','BuildPlanner.lua','BuildRunner.lua','BuildDraft.lua','BuildJournal.lua','Session.lua','Dialogs.lua','PageAdapters.lua','UI.lua'})
 local f=AF.Attach(BF.InstallSkills(BF.New(),{{lineId=10,kind='active',id=51,purchased=true,morph=1}}));BF.InstallSkillDrafts(f)
 f.api.IsUnitDeadOrReincarnating=function()return false end;f.api.CanItemBePlayerLocked=function()return true end;f.api.IsItemPlayerLocked=function(b,s)return f.api.bags[b][s].locked end;f.api.SetItemIsPlayerLocked=function(b,s,v)f.api.bags[b][s].locked=v end
 f.k=k;f.events=k.Core.NewEvents();f.skills=k.SkillAdapter.New(f.api,f.events,f.clock);f.attributes=k.AttributeAdapter.New(f.api,f.events)
 f.inventory=k.Inventory.New(f.api);f.repo=k.Presets.New({},'EU','a','c','Kana',function(n,p)if f.observer then f.observer(n,p)end end);f.protection=k.Protection.New(f.repo,f.inventory)
 f.gear=k.EquipmentRunner.New(f.inventory,f.events,f.clock);f.planner=k.BuildPlanner.New({skills=f.skills,attributes=f.attributes})
 function f:Capture(component)
  local eq=self.inventory:Capture('equipment');local c=self.skills:Catalogue();local a,b=self.attributes:Capture()
  return {equipment=k.Copy(eq.worn),abilities=k.Copy(c.abilities),attributes=a,equipmentState=eq,budgets={skills=c.budgets.skills,mastery=c.budgets.mastery,attributes=b},catalogueRevision=c.revision},c
 end
 f.services={capture=function(component)return f:Capture(component)end,buildPlanner=f.planner,skills=f.skills,attributes=f.attributes,checkDrafts=function()return true end}
 f.services.buildRunner=k.BuildRunner.New(f.skills,f.attributes,f.gear,f.events,f.clock,{capture=f.services.capture,revalidateRemaining=f.planner.RevalidateRemaining})
 function f:Reload()self.session=k.Session.New(self.repo,self.inventory,k.EquipmentPlan,self.gear,self.protection,self.repo.character,{},nil,self.services)end
 function f:Preset(parts,name)local d=self.repo:NewDraft();d.name=name or 'Test';for key,v in pairs(parts)do d[key]=v end;d.slots=nil;return assert(self.repo:Save(d,0))end
 f:Reload();return f
end
return {
 bar_morph_without_a_selected_talent_is_local_to_the_editor=function()
  local f=setup();local key='10:active:51'
  local p=f:Preset({abilities={bars={front={[3]={kind='skill',skillKey=key,expectedMorph=2}}}}})
  local ok,problem=f.session:BeginEdit(p.id,false,'skills');assert(ok,problem and problem.code)
  assert(f.skills:CaptureDraft().skills[key].morph==2 and not f.session:GetSelected('skills',key))
  assert(f.session:Cancel())
  assert(f.skillObjects[1]:GetCurrentMorphSlot()==1 and #f.requests.skills==0 and f.repo:Get(p.id).revision==p.revision)
 end,
 session_publishes_attribute_progress_without_equipment=function()
  local f=setup();local p=f:Preset({attributes={health=0,magicka=0,stamina=64}})
  assert(f.session:Apply(p.id))
  local progress=f.session:GetView().progress
  assert(progress and progress.phase=='attributes' and progress.total==1 and progress.completed==0 and progress.ratio==0,'attribute-only progress is missing from the UI view')
 end,
 stale_completion_does_not_accept_exit_for_an_active_editor=function()
  local f=setup();local transitions,rejects=0,0;local scene={AcceptHideScene=function()transitions=transitions+1 end,RejectHideScene=function()rejects=rejects+1 end}
  local ui=f.k.UI.New(f.repo,f.session,nil,f.inventory);local save
  f.k.Dialogs.CloseEditor=function(s)save=s;return {active=true}end
  assert(f.session:BeginNew('inventory'));ui:CloseEditor(scene)
  -- A late outcome event must not close a still-active editor or resolve its prompt.
  ui:OnSessionFinished({outcome='saved'});assert(transitions==0 and rejects==0 and ui.closeDecision)
  assert(f.session:SetSelected('equipment',EQUIP_SLOT_HEAD,true))
  f.session.emit=function(name,payload)
   if name=='SessionFinished'then assert(f.session:BeginNew('stats'));ui:OnSessionFinished(payload)end
  end
  save();assert(transitions==0 and rejects==1 and not ui.closeDecision and f.session:GetView().page=='stats')
 end,
 new_editor_does_not_invent_saved_missing_references_for_unavailable_actual_entries=function()
  local f=setup();f.skillObjects[1].spec.purchased=false;f.skillLines[10].spec.available=false
  assert(f.session:BeginNew('skills'));assert(not next(f.session:GetView().missing));assert(not f.session:GetSelected('skills','10:active:51'));assert(f.session:Cancel())
 end,
 unchecked_unresolved_refs_can_be_omitted_without_silently_changing_selected_intent=function()
  for _,apply in ipairs({false,true})do
   local f=setup();local key='99:active:999';local p=f:Preset({attributes={health=0,magicka=0,stamina=64},abilities={skills={[key]={kind='active',purchased=true,morph=0}},bars={front={[1]={kind='skill',skillKey=key,expectedMorph=0}}}}})
   assert(f.session:BeginEdit(p.id,false,'skills'));assert(f.session:SetSelected('skills',key,false));assert(f.session:SetSelected('bars',{bar='front',slot=1},false))
   assert(f.session:GetView().draft.abilities.skills[key] and f.session:GetView().missing['bar:front:1'])
   local ui=f.k.UI.New(f.repo,f.session,nil,f.inventory);assert(ui:Refresh().canSave and ui:Refresh().canSaveAndApply)
   local ok,e;if apply then ok,e=f.session:SaveAndApply()else ok,e=f.session:Save()end;assert(ok,e and e.code)
   assert(not f.repo:Get(p.id).abilities and f.repo:Get(p.id).attributes.stamina==64 and f.session:GetView().state=='idle');assert(#f.requests.skills==0 and f.attributeSends==0)
  end
 end,
 gear_confirmation_cleanup_does_not_remove_a_later_foreign_callback=function()
  local f=setup();local scene={}
  function scene:SetHideSceneConfirmationCallback(cb)self.hideSceneConfirmationCallback=cb end
  function scene:HasHideSceneConfirmation()return self.hideSceneConfirmationCallback~=nil end
  function scene:AcceptHideScene()error('unexpected stale transition')end
  function scene:RejectHideScene()error('unexpected stale transition')end
  f.api.SCENE_MANAGER={GetScene=function()return scene end};local pages=f.k.PageAdapters.New(f.api);f.k.UI.New(f.repo,f.session,nil,f.inventory,{pages=pages})
  f.session.emit=function()pages:RefreshOwnership()end
  assert(f.session:BeginNew('inventory'));local old=scene.hideSceneConfirmationCallback;assert(old)
  local foreign=function()end;scene:SetHideSceneConfirmationCallback(foreign);assert(f.session:Cancel());assert(scene.hideSceneConfirmationCallback==foreign and not pages.equipmentExit);old(scene)
 end,
 missing_reference_editor_does_not_weaken_whole_apply_or_quickload_preflight=function()
  local f=setup();local build={equipment={[EQUIP_SLOT_HEAD]={kind='empty'}},attributes={health=0,magicka=0,stamina=64},abilities={skills={['99:active:999']={kind='active',purchased=true,morph=0}}}}
  local p=f:Preset(build);local ok,e=f.session:Apply(p.id);assert(not ok and e.code=='skillUnavailable');assert(f.repo:SaveQuick(build));ok,e=f.session:QuickLoad();assert(not ok and e.code=='skillUnavailable')
  assert(#f.requests.skills==0 and f.attributeSends==0 and #f.api.requests==0 and f.session:GetView().state=='idle')
 end,
 all_and_none_keep_explicit_empty_selection_editable=function()
  local f=setup();assert(f.session:BeginNew('inventory'));local ui=f.k.UI.New(f.repo,f.session,nil,f.inventory)
  ui:SelectAll(true);for _,slot in ipairs(f.k.Slots.Order)do assert(f.session:GetSelected(slot))end
  ui:SelectAll(false);for _,slot in ipairs(f.k.Slots.Order)do assert(not f.session:GetSelected(slot))end;assert(f.session:Cancel())
  assert(f.session:BeginNew('skills'));ui:SelectAll(true);assert(f.session:GetSelected('bars',{bar='front',slot=1}));ui:SelectAll(false);assert(not f.session:GetSelected('skills','10:active:51') and not f.session:GetSelected('bars',{bar='front',slot=1}));assert(f.session:Cancel())
 end,
 gear_native_exit_three_choices_gate_transition_and_restore_callback=function()
  for _,choice in ipairs({'continue','save','cancel','escape'})do
   local f=setup();local scene={};local transitions,prompts,rejects=0,0,0
   function scene:SetHideSceneConfirmationCallback(cb)self.hideSceneConfirmationCallback=cb end
   function scene:HasHideSceneConfirmation()return self.hideSceneConfirmationCallback~=nil end
   function scene:AcceptHideScene()transitions=transitions+1;assert(f.session:GetView().state=='idle');f.session:OnNativePageState('inventory','hiding')end
   function scene:RejectHideScene()rejects=rejects+1 end
   f.api.SCENE_MANAGER={GetScene=function(_,page)if page=='inventory'then return scene end end}
   local pages=f.k.PageAdapters.New(f.api);local ui=f.k.UI.New(f.repo,f.session,nil,f.inventory,{pages=pages})
   f.session.emit=function(name,payload)if name=='SessionFinished'then ui:OnSessionFinished(payload)else pages:RefreshOwnership()end end
   local dialog;f.k.Dialogs.CloseEditor=function(save,cancel,continue)prompts=prompts+1;dialog={save=save,cancel=cancel,continue=continue};return {active=true}end
   assert(f.session:BeginNew('inventory'));assert(f.session:SetSelected('equipment',EQUIP_SLOT_HEAD,true));assert(f.session:SetName('Unsaved'));assert(scene:HasHideSceneConfirmation())
   local callback=scene.hideSceneConfirmationCallback;callback(scene,'skills');callback(scene,'stats');ui:CloseEditor();assert(prompts==1 and transitions==0 and f.session:GetView().state=='editing')
   dialog[choice=='escape' and 'continue' or choice]();dialog.save();dialog.cancel()
   if choice=='continue' or choice=='escape'then assert(transitions==0 and rejects==1 and f.session:GetView().state=='editing' and f.session:GetView().name=='Unsaved');assert(#f.repo:List()==0);assert(f.session:Cancel())
   else assert(transitions==1 and #f.repo:List()==(choice=='save' and 1 or 0))end
   assert(not scene:HasHideSceneConfirmation());assert(#f.requests.skills==0 and f.attributeSends==0)
  end
 end,
 gear_native_exit_preserves_foreign_callback_and_unexpected_hide_preserves_journal=function()
  local f=setup();local foreign=function()end;local scene={hideSceneConfirmationCallback=foreign}
  function scene:SetHideSceneConfirmationCallback(cb)self.hideSceneConfirmationCallback=cb end
  function scene:HasHideSceneConfirmation()return self.hideSceneConfirmationCallback~=nil end
  f.api.SCENE_MANAGER={GetScene=function()return scene end};local pages=f.k.PageAdapters.New(f.api)
  local ui=f.k.UI.New(f.repo,f.session,nil,f.inventory,{pages=pages});assert(f.session:BeginNew('inventory'));pages:RefreshOwnership();assert(scene.hideSceneConfirmationCallback==foreign)
  assert(f.session:OnNativePageState('inventory','hiding'));assert(f.session:GetView().state=='recovery' and f.repo.character.journal and #f.repo:List()==0);assert(scene.hideSceneConfirmationCallback==foreign)
 end,
 new_defaults_include_only_filled_but_allows_explicit_empty_off=function()
  local f=setup();local actual={equipment={[0]={kind='empty'},[1]={kind='item',uid='x',link='x'}},abilities={skills={['10:active:51']={kind='active',purchased=true,morph=1},['10:active:52']={kind='active',purchased=false},['10:passive:61']={kind='passive',rank=0},['10:passive:62']={kind='passive',rank=2}},bars={front={[1]={kind='empty'},[2]={kind='skill',skillKey='10:active:51',expectedMorph=1}},back={[1]={kind='empty'}}}}}
  local gear=f.k.BuildDraft.New(actual,nil,'inventory');assert(not gear.selection.equipment[0] and gear.selection.equipment[1]);assert(gear.build.equipment[0].kind=='empty');assert(gear:SetSelected('equipment',0,true));assert(gear:GetPresetBuild().equipment[0].kind=='empty')
  local d=f.k.BuildDraft.New(actual,nil,'skills');assert(d.selection.skills['10:active:51'] and d.selection.skills['10:passive:62']);assert(not d.selection.skills['10:active:52'] and not d.selection.skills['10:passive:61'] and not d.selection.bars.front[1] and not d.selection.bars.back[1]);assert(d.selection.bars.front[2]);assert(d:SetSelected('skills','10:active:52',true));assert(d:SetSelected('front',1,true));assert(d:GetPresetBuild().abilities.skills['10:active:52'].purchased==false and d:GetPresetBuild().abilities.bars.front[1].kind=='empty')
  local absent=f.k.BuildDraft.New(actual,{id='existing'},'skills');assert(not next(absent.selection.skills) and not next(absent.selection.bars.front));local saved=f.k.Copy(actual);saved.id='existing';d=f.k.BuildDraft.New(actual,saved,'skills');assert(d.selection.skills['10:active:52'] and d.selection.skills['10:passive:61'] and d.selection.bars.front[1]);gear=f.k.BuildDraft.New(actual,saved,'inventory');assert(gear.selection.equipment[0])
 end,
 missing_saved_skills_and_bars_remain_repairable_without_silent_loss=function()
  local f=setup();local key='99:active:999';local p=f:Preset({equipment={[0]={kind='empty'}},attributes={health=0,magicka=0,stamina=64},abilities={skills={[key]={kind='active',purchased=true,morph=2},['10:active:51']={kind='active',purchased=true,morph=2}},bars={front={[1]={kind='skill',skillKey=key,expectedMorph=2}}}}})
  local ok,e=f.session:BeginEdit(p.id,false,'skills');assert(ok,e and e.code);local v=f.session:GetView();assert(v.state=='editing' and v.draft.abilities.skills[key].morph==2 and v.draft.abilities.bars.front[1].skillKey==key)
  assert(v.missing['skill:'..key].ref.morph==2 and v.missing['bar:front:1'].ref.skillKey==key)
  assert(f.skills:CaptureDraft().skills['10:active:51'].morph==2 and not f.skills:CaptureDraft().skills[key]);assert(f.skills:CaptureDraft().bars.front[1].kind=='empty')
  ok,e=f.session:Save();assert(not ok and e.code=='unresolvedMissing');ok,e=f.session:SaveAndApply();assert(not ok and e.code=='unresolvedMissing');assert(f.repo:Get(p.id).revision==p.revision)
  assert(f.session:GetView().draft.abilities.bars.front[1].skillKey==key);assert(f.session:Cancel());assert(f.repo:Get(p.id).abilities.skills[key].morph==2 and f.repo:Get(p.id).abilities.bars.front[1].skillKey==key);assert(#f.requests.skills==0 and f.attributeSends==0)
  assert(f.session:BeginEdit(p.id,false,'skills'));assert(f.session:ResolveMissingAbility('skill:'..key,'replace','10:active:51'));assert(f.session:ResolveMissingAbility('bar:front:1','omit'));assert(f.session:Save());local saved=f.repo:Get(p.id);assert(not saved.abilities.skills[key] and saved.abilities.skills['10:active:51'].morph==2 and not saved.abilities.bars);assert(saved.equipment[0].kind=='empty' and saved.attributes.stamina==64)
 end,
 missing_bar_can_be_deliberately_replaced_by_native_slot=function()
  local f=setup();local key='99:active:999';local p=f:Preset({abilities={bars={back={[2]={kind='skill',skillKey=key,expectedMorph=0}}}}})
  local ok,e=f.session:BeginEdit(p.id,false,'skills');assert(ok,e and e.code);assert(not f.session:ResolveMissingAbility('bar:back:2','replace'))
  f.api.ACTION_BAR_ASSIGNMENT_MANAGER:GetHotbar(f.api.HOTBAR_CATEGORY_BACKUP):AssignSkillToSlot(4,f.skillObjects[1])
  assert(f.session:GetView().draft.abilities.bars.back[2].skillKey==key);assert(f.session:ResolveMissingAbility('bar:back:2','replace'));assert(f.session:Save());assert(f.repo:Get(p.id).abilities.bars.back[2].skillKey=='10:active:51');assert(#f.requests.skills==0)
 end,
 scalar_selection_query_reads_only_current_component_without_copy_or_capture=function()
  local f=setup();assert(f.session:BeginNew('skills'))
  assert(f.session:SetSelected('skills','10:active:51',false));assert(f.session:SetSelected('bars',{bar='front',slot=1},false))
  assert(f.session:SetSelected('bars',{bar='back',slot=1},true))
  local copy,view,capture=f.k.Copy,f.session.GetView,f.services.capture
  f.k.Copy=function()error('scalar query copied a map')end;f.session.GetView=function()error('scalar query read whole view')end
  f.services.capture=function()error('scalar query captured actual')end
  local ok,problem=pcall(function()
   assert(f.session:GetSelected('skills','10:active:51')==false)
   assert(f.session:GetSelected('bars',{bar='front',slot=1})==false)
   assert(f.session:GetSelected('bars',{bar='back',slot=1})==true)
   for _,key in ipairs({{bar='overload',slot=1},{bar='front',slot=0},{bar='front',slot=7},{bar='front',slot=1.5}})do assert(f.session:GetSelected('bars',key)==false)end
   assert(f.session:GetSelected('skills',{})==false and f.session:GetSelected('equipment',EQUIP_SLOT_HEAD)==false)
  end)
  f.k.Copy=copy;f.session.GetView=view;f.services.capture=capture;assert(ok,problem)
  assert(f.session:Cancel());assert(f.session:GetSelected('bars',{bar='back',slot=1})==false)
  assert(f.session:BeginNew('inventory'));assert(f.session:GetSelected(EQUIP_SLOT_HEAD)==false)
  assert(f.session:GetSelected('skills','10:active:51')==false)
 end,
 scalar_selection_query_retains_legacy_numeric_equipment_contract=function()
  local f=setup();local legacy=f.k.Session.New(f.repo,f.inventory,f.k.EquipmentPlan,f.gear,f.protection,f.repo.character,{})
  assert(legacy:BeginNew());assert(legacy:SetSelected(EQUIP_SLOT_HEAD,true));assert(legacy:GetSelected(EQUIP_SLOT_HEAD)==true)
  assert(legacy:SetSelected(EQUIP_SLOT_HEAD,false));assert(legacy:GetSelected('equipment',EQUIP_SLOT_HEAD)==false)
  assert(legacy:GetSelected('skills','10:active:51')==false and legacy:GetSelected({},nil)==false)
  assert(legacy:Cancel());assert(legacy:GetSelected(EQUIP_SLOT_HEAD)==false)
 end,
 patch_nil_preserves_remove_deletes_and_empty_rejected=function()
  local f=setup();local p=f:Preset({attributes={health=0,magicka=0,stamina=0},abilities={skills={['10:active:51']={kind='active',purchased=true,morph=1}}}})
  local r=assert(f.repo:PatchComponent(p.id,'attributes',nil,'Renamed',p.revision));assert(r.attributes.health==0 and r.name=='Renamed')
  r=assert(f.repo:PatchComponent(p.id,'attributes',{op='remove'},nil,r.revision));assert(not r.attributes and r.abilities)
  assert(not f.repo:PatchComponent(p.id,'abilities',{op='remove'},nil,r.revision))
 end,
 save_current_component_preserves_other_parts_and_discards_without_send=function()
  local f=setup();local p=f:Preset({attributes={health=0,magicka=0,stamina=64},abilities={skills={['10:active:51']={kind='active',purchased=true,morph=1}}}})
  assert(f.session:BeginEdit(p.id,false,'stats'));assert(f.session:GetView().component=='attributes')
  assert(f.session:Save());local stored=f.repo:Get(p.id);assert(stored.attributes.stamina==64 and stored.abilities.skills['10:active:51'].morph==1);assert(f.attributeSends==0 and #f.requests.skills==0 and not f.attributes.mounted)
 end,
 new_preset_contains_only_current_part_and_zero_values=function()
  local f=setup();assert(f.session:BeginNew('stats'));assert(f.session:Save());local p=f.repo:List()[1];assert(p.attributes and p.attributes.health==10 and not p.equipment and not p.abilities)
 end,
 attributes_checkbox_removes_only_current_component=function()
  local f=setup();local p=f:Preset({attributes={health=0,magicka=0,stamina=64},abilities={skills={['10:active:51']={kind='active',purchased=true,morph=1}}}})
  assert(f.session:BeginEdit(p.id,false,'stats'));assert(f.session:SetAttributesEnabled(false));assert(f.session:Save());assert(not f.repo:Get(p.id).attributes and f.repo:Get(p.id).abilities)
 end,
 full_quick_capture_is_actual_and_refuses_editor=function()
  local f=setup();assert(f.session:QuickSave());local p=f.repo:Get(f.k.Presets.QUICK_ID);assert(p.equipment and p.abilities and p.attributes and p.attributes.health==10)
  assert(f.session:BeginNew('stats'));assert(not f.session:QuickSave());assert(f.session:Cancel());assert(f.attributeSends==0)
 end,
 save_apply_saves_selected_but_applies_unselected_experiment_only=function()
  local f=setup();assert(f.session:BeginNew('stats'));assert(f.session:SetAttributesEnabled(false));assert(not f.session:SaveAndApply()) -- new empty save rejected
  assert(f.session:SetAttributesEnabled(true));assert(f.session:SaveAndApply());assert(f.attributeSends==0) -- unchanged experiment is noop
 end,
 new_commit_observer_reload_keeps_assigned_id_without_duplicate=function()
  local f=setup();assert(f.session:BeginNew('stats'));f.observer=function()f:Reload();error('observer failure')end
  local ok,e=f.session:Save();assert(not ok and e.code=='commitObserverError');assert(#f.repo:List()==1 and f.repo.character.journal.saveCommitted and f.repo.character.journal.presetId==f.repo:List()[1].id)
 end,
 draft_rejects_foreign_domain_and_projects_selection=function()
  local f=setup();local s=f:Capture();local d=assert(f.k.BuildDraft.New(s,{},'stats'));assert(not d:SetSelected('equipment',EQUIP_SLOT_HEAD,true));assert(d:SetAttributesEnabled(false));assert(not d:GetPresetBuild().attributes);assert(d:GetBuild().attributes.health==10)
 end,
 save_apply_unchecked_attributes_preserves_other_parts_and_sends_once=function()
  local f=setup();local p=f:Preset({attributes={health=10,magicka=20,stamina=34},abilities={skills={['10:active:51']={kind='active',purchased=true,morph=1}}}})
  assert(f.session:BeginEdit(p.id,false,'stats'));assert(f.session:SetAttributesEnabled(false))
  f.api.STATS.attributeControls[1].pointLimitedSpinner:SetAddedPointsByTotalPoints(0)
  f.api.STATS.attributeControls[2].pointLimitedSpinner:SetAddedPointsByTotalPoints(0)
  f.api.STATS.attributeControls[3].pointLimitedSpinner:SetAddedPointsByTotalPoints(64)
  assert(f.session:SaveAndApply());assert(f.attributeSends==1 and #f.requests.skills==0 and #f.api.requests==0 and not f.attributes.mounted)
  local saved=f.repo:Get(p.id);assert(not saved.attributes and saved.abilities)
  f.events:Emit('NativeAttributeRespecResult',{result=14});f:Advance(101)
  -- Save completed and the editor was unmounted before sending. A verified
  -- refusal must keep that saved preset without locking it in recovery.
  assert(f.session:GetView().state=='idle' and f.repo:Get(p.id).revision==p.revision+1)
  assert(not f.attributes.mounted and not f.repo.character.journal and not f.session.draft)
  assert(f.repo.character.lastInterruptedBuild.saveCommitted and f.session:GetView().problem.details.result==14)
  assert(f.session:BeginEdit(p.id,false,'stats'));assert(f.session:Cancel())
 end,
 save_skills_discards_own_pending_and_never_respecs_actual=function()
  local f=setup();local p=f:Preset({abilities={skills={['10:active:51']={kind='active',purchased=true,morph=2}}},attributes={health=0,magicka=0,stamina=64}})
  assert(f.session:BeginEdit(p.id,false,'skills'));assert(f.skills:CaptureDraft().skills['10:active:51'].morph==2)
  assert(f.session:Save());assert(f.repo:Get(p.id).abilities.skills['10:active:51'].morph==2 and f.skillObjects[1].spec.morph==1)
  assert(#f.requests.skills==0 and f.attributeSends==0 and f.api.SKILLS_AND_ACTION_BAR_MANAGER.mode==0)
 end,
 cleanup_failure_after_save_retains_record_and_never_sends=function()
  local f=setup();assert(f.session:BeginNew('stats'));f.api.STATS.attributeControls[1].pointLimitedSpinner.ResetAddedPoints=function()error('cleanup fail')end
  local ok= f.session:SaveAndApply();assert(not ok and #f.repo:List()==1 and f.session:GetView().state=='recovery' and f.attributeSends==0)
 end,
 revision_conflict_and_foreign_pending_do_not_write=function()
  local f=setup();local p=f:Preset({attributes={health=0,magicka=0,stamina=64}});assert(f.session:BeginEdit(p.id,false,'stats'))
  assert(f.repo:PatchComponent(p.id,'attributes',nil,'Other',p.revision));assert(not f.session:Save());assert(f.repo:Get(p.id).name=='Other' and f.attributeSends==0)
  assert(f.session:Cancel());f.services.checkDrafts=function()return nil,f.k.Problem('foreignAttributeDraft')end
  assert(not f.session:QuickSave() and not f.session:BeginNew('stats'))
 end,
 missing_current_reference_requires_explicit_resolution=function()
  local f=setup();local p=f:Preset({equipment={[EQUIP_SLOT_HEAD]={kind='item',uid='missing',link='missing'}}})
  local begin,why=f.session:BeginEdit(p.id,true,'inventory');assert(begin,why and why.code);local ok,e=f.session:Save();assert(not ok and e.code=='unresolvedMissing')
  assert(f.session:ResolveMissing(EQUIP_SLOT_HEAD,'empty'));local saved,problem=f.session:Save();assert(saved,problem and problem.code);assert(f.repo:Get(p.id).equipment[EQUIP_SLOT_HEAD].kind=='empty')
 end,
 current_skill_auxiliary_consent_is_required_before_mount=function()
  local f=setup();f.actualBars[2][3]={type=1,id=511};f.api.ACTION_BAR_ASSIGNMENT_MANAGER:ResetPlayerHotbars()
  local p=f:Preset({abilities={skills={['10:active:51']={kind='active',purchased=false}}}})
  assert(f.session:BeginEdit(p.id,false,'skills'));local view=f.session:GetView();assert(view.state=='confirming' and view.confirmation.plan.extras[1].category==2 and not f.skills.mounted)
  assert(f.session:Confirm(view.confirmation.plan.extraKey));assert(f.skills.mounted and #f.requests.skills==0);assert(f.session:Cancel());assert(f.actualBars[2][3].id==511)
 end,
 new_patch_uses_nil_revision_and_callback_precedes_public_emit=function()
  local f=setup();local seen;f.observer=function(_,event)assert(seen and seen.id==event.presetId)end
  local p=assert(f.repo:PatchComponent(nil,'attributes',{op='replace',value={health=0,magicka=0,stamina=0}},'Zero',nil,function(preset)seen=preset;assert(f.repo:Get(preset.id).revision==1)end))
  assert(p.id==seen.id and p.attributes.health==0);assert(not f.repo:PatchComponent(nil,'attributes',nil,'Bad',0))
 end,

 gear_save_restores_only_gear_and_keeps_native_parts=function()
  local f=setup();f.api.bags[BAG_WORN][EQUIP_SLOT_HEAD]={uid='old',link='old'};f.api.descriptions.old={equipType=EQUIP_TYPE_HEAD}
  f.api.bags[BAG_BACKPACK][1]={uid='new',link='new'};f.api.descriptions.new={equipType=EQUIP_TYPE_HEAD}
  assert(f.session:BeginNew('inventory'))
  f.api.bags[BAG_BACKPACK][2]=f.api.bags[BAG_WORN][EQUIP_SLOT_HEAD];f.api.bags[BAG_WORN][EQUIP_SLOT_HEAD]=f.api.bags[BAG_BACKPACK][1];f.api.bags[BAG_BACKPACK][1]=nil
  assert(f.session:Save());assert(f.repo:List()[1].equipment[EQUIP_SLOT_HEAD].uid=='new' and #f.api.requests==1)
  local request=f.api.requests[1];assert(request[1]=='equip');f.api.bags[BAG_BACKPACK][3]=f.api.bags[BAG_WORN][EQUIP_SLOT_HEAD];f.api.bags[BAG_WORN][EQUIP_SLOT_HEAD]=f.api.bags[request[2]][request[3]];f.api.bags[request[2]][request[3]]=nil
  f.inventory:Refresh();f:Advance(101);assert(f.session:GetView().state=='idle' and f.api.bags[BAG_WORN][EQUIP_SLOT_HEAD].uid=='old' and f.attributeSends==0 and #f.requests.skills==0)
 end,
 save_apply_skill_journal_has_dispatching_token_before_packet=function()
  local f=setup();local p=f:Preset({abilities={skills={['10:active:51']={kind='active',purchased=true,morph=2}}},attributes={health=0,magicka=0,stamina=64}})
  assert(f.session:BeginEdit(p.id,false,'skills'));local dispatched=false
  f.session.emit=function()
   local j=f.repo.character.journal
   if j and j.pending and j.pending.phase=='dispatching'then dispatched=true;assert(j.pending.token and j.maySent and not f.packetPrepareCalls)end
  end
  assert(f.session:SaveAndApply());assert(not f.skills.mounted and #f.requests.skills==0 and f.attributeSends==0)
  f:SkillEntryReady();f:Advance(1);assert(dispatched and #f.requests.skills==1 and f.attributeSends==0 and #f.api.requests==0)
 end,
 whole_apply_checks_attribute_deficit_before_skill_entry=function()
  local f=setup();local p=f:Preset({abilities={skills={['10:active:51']={kind='active',purchased=true,morph=2}}},attributes={health=67,magicka=0,stamina=0}})
  local ok,e=f.session:Apply(p.id);assert(not ok and e.code=='insufficientAttributePoints' and #f.requests.skills==0 and not f.entryRequests and f.attributeSends==0)
 end,
 quick_rejects_incomplete_capture_and_does_not_save_pending_values=function()
  local f=setup();f.services.capture=function()local s,c=f:Capture();s.attributes=nil;return s,c end
  local ok,e=f.session:QuickSave();assert(not ok and e.code=='buildCapabilityUnavailable' and not f.repo:Get(f.k.Presets.QUICK_ID))
 end,

 save_apply_requires_auxiliary_consent_after_selected_save=function()
  local f=setup();f.actualBars[2][3]={type=1,id=511};f.api.ACTION_BAR_ASSIGNMENT_MANAGER:ResetPlayerHotbars()
  local p=f:Preset({abilities={skills={['10:active:51']={kind='active',purchased=true,morph=1}}}})
  assert(f.session:BeginEdit(p.id,false,'skills'));local allocator=f.skillObjects[1]:GetPointAllocator();assert(allocator:Unmorph());assert(allocator:Morph(2))
  assert(f.session:SaveAndApply());local view=f.session:GetView();assert(view.saved and view.state=='confirming' and not f.skills.mounted and #f.requests.skills==0)
  assert(view.confirmation.plan.extras[1].category==2);assert(f.session:Confirm(view.confirmation.plan.extraKey));f:SkillEntryReady();f:Advance(1);assert(#f.requests.skills==1)
 end,
 save_apply_lock_observer_budget_change_blocks_commit=function()
  local f=setup();assert(f.session:BeginNew('stats'));local protect=f.protection.EnsureBuild
  f.protection.EnsureBuild=function(self,build)local ok,e=protect(self,build);f.attributeUnspent=3;return ok,e end
  local ok,e=f.session:SaveAndApply();assert(not ok and #f.repo:List()==0 and e.code=='buildStateChanged' and f.attributeSends==0)
 end,

 malformed_modern_journal_is_blocked_without_constructor_error=function()
  local f=setup();f.repo.character.journal=17;f:Reload();assert(f.session:GetView().state=='recovery' and f.session:GetView().problem.code=='invalidJournal')
 end,
 confirmation_rejects_changed_stored_preset_before_mount_or_apply=function()
  local f=setup();f.actualBars[2][3]={type=1,id=511};f.api.ACTION_BAR_ASSIGNMENT_MANAGER:ResetPlayerHotbars()
  local p=f:Preset({abilities={skills={['10:active:51']={kind='active',purchased=false}}}})
  assert(f.session:Apply(p.id));local key=f.session:GetView().confirmation.plan.extraKey;assert(f.repo:PatchComponent(p.id,'abilities',nil,'Changed',p.revision))
  local ok,e=f.session:Confirm(key);assert(not ok and e.code=='revisionConflict' and #f.requests.skills==0 and not f.entryRequests)
 end,

 quick_protection_observer_foreign_cast_or_busy_preserves_old_snapshot=function()
  for _,kind in ipairs({'pending','cast','busy'})do
   local f=setup();assert(f.session:QuickSave());local old=f.repo:Get(f.k.Presets.QUICK_ID);local checks=0
   f.services.checkDrafts=function()
    checks=checks+1
    if f.api.STATS.attributeControls[1].pointLimitedSpinner.addedPoints~=0 then return nil,f.k.Problem('foreignAttributeDraft')end
    if f.attributeCast and f.attributeCast>0 then return nil,f.k.Problem('attributeCastPending')end
    return true
   end
   f.protection.EnsureBuild=function()
    if kind=='pending'then f.api.STATS.attributeControls[1].pointLimitedSpinner.addedPoints=1
    elseif kind=='cast'then f.attributeCast=5
    else f.services.buildRunner.IsBusy=function()return true end end
    return true
   end
   local saved,e=f.session:QuickSave();assert(not saved and e and f.repo:Get(f.k.Presets.QUICK_ID).revision==old.revision,kind)
   if kind~='busy'then assert(checks==2)end
  end
 end,
 quick_protection_observer_cannot_reenter_an_editor_or_quick_write=function()
  local f=setup();local nestedQuick,nestedEditor
  f.protection.EnsureBuild=function()
   nestedQuick=f.session:QuickSave();nestedEditor=f.session:BeginNew('stats');return true
  end
  assert(f.session:QuickSave());assert(not nestedQuick and not nestedEditor and f.session:GetView().state=='idle' and f.repo:Get(f.k.Presets.QUICK_ID).revision==1)
 end,

 quick_public_commit_observer_is_still_reentrancy_guarded=function()
  local f=setup();local calls=0;local nested
  f.observer=function()
   calls=calls+1;if calls==1 then nested=f.session:BeginNew('stats')end
  end
  assert(f.session:QuickSave());assert(not nested and f.session:GetView().state=='idle')
 end,

}
