local Fake=dofile(ROOT..'/tests/support/fake_eso.lua')
local BF=dofile(ROOT..'/tests/support/build_fixture.lua')
local AF=dofile(ROOT..'/tests/support/attribute_fixture.lua')
local function setup()
 local k=Fake.Load({'Core.lua','Slots.lua','lang/en.lua','BuildModel.lua','Presets.lua','Inventory.lua','EquipmentPlan.lua','EquipmentRunner.lua','Protection.lua','SkillState.lua','SkillAdapter.lua','AttributeAdapter.lua','BuildPlanner.lua','BuildRunner.lua','BuildDraft.lua','BuildJournal.lua','Session.lua'})
 local f=AF.Attach(BF.InstallSkills(BF.New(),{{lineId=10,kind='active',id=51,purchased=true,morph=1}}));BF.InstallSkillDrafts(f)
 f.k=k;f.events=k.Core.NewEvents();f.skills=k.SkillAdapter.New(f.api,f.events,f.clock);f.attributes=k.AttributeAdapter.New(f.api,f.events)
 f.inventory=k.Inventory.New(f.api);f.repo=k.Presets.New({},'EU','a','c','Kana');f.protection=k.Protection.New(f.repo,f.inventory)
 f.gear=k.EquipmentRunner.New(f.inventory,f.events,f.clock);f.planner=k.BuildPlanner.New({skills=f.skills,attributes=f.attributes})
 function f:Capture(component)
  local eq=self.inventory:Capture('equipment');local c=self.skills:Catalogue();local a,b=self.attributes:Capture()
  return {equipment=k.Copy(eq.worn),abilities=k.Copy(c.abilities),attributes=a,equipmentState=eq,budgets={skills=c.budgets.skills,mastery=c.budgets.mastery,attributes=b}},c
 end
 f.services={capture=function(component)return f:Capture(component)end,buildPlanner=f.planner,skills=f.skills,attributes=f.attributes,checkDrafts=function()return true end}
 f.services.buildRunner=k.BuildRunner.New(f.skills,f.attributes,f.gear,f.events,f.clock,{capture=f.services.capture,revalidateRemaining=f.planner.RevalidateRemaining})
 function f:Reload()self.session=k.Session.New(self.repo,self.inventory,k.EquipmentPlan,self.gear,self.protection,self.repo.character,{},nil,self.services)end
 f.api.IsUnitDeadOrReincarnating=function()return false end
 f.services.requestPage=function(page)
  f.requestedPage=page
  if not f.continuePage then
   local old=f.session:GetView().page
   if old then f.session:OnNativePageState(old,'hiding')end
   f.session:OnNativePageState(page,'showing')
  end
  return true
 end
 f:Reload();return f
end
local function journal(f)
 return {version=2,kind='apply',operation='apply',state='recovery',phase='skills',original=f:Capture(),target={abilities=f.skills:Capture()},confirmed={},pending={phase='dispatching',token=1,sent=false,original=f.skills:Capture(),target=f.skills:Capture()},maySent=true}
end
return {
 equipment_failure_after_other_phases_is_saved_in_equipment_log=function()
  local f=setup();local p=f.repo:NewDraft();p.name='Missing weapon'
  f.api.bags[BAG_BACKPACK][3]={uid='sword',link='sword'}
  f.api.descriptions.sword={equipType=EQUIP_TYPE_ONE_HAND}
  p.slots={[EQUIP_SLOT_MAIN_HAND]={kind='item',uid='sword',link='sword'}}
  p.abilities=f.skills:Capture();p.attributes=f.attributes:Capture()
  local saved=assert(f.repo:Save(p,0));assert(f.session:Apply(saved.id));f:Advance(5101)
  local log=assert(f.repo.character.equipmentFailures,'build runner skipped the equipment failure log')
  local last=log[#log]
  assert(last.problem.code=='requestTimeout' and last.pending.batch[1].uid=='sword')
  assert(last.confirmed.skills and last.confirmed.attributes)
  assert(last.locations.sword.bagId==BAG_BACKPACK and last.diagnostics)
 end,
 unsent_skill_entry_timeout_keeps_presets_usable_without_recovery=function()
  local f=setup();local p=f.repo:NewDraft();p.name='Entry';p.slots=nil
  p.abilities={skills={['10:active:51']={kind='active',purchased=true,morph=2}}}
  local saved=assert(f.repo:Save(p,0));assert(f.session:Apply(saved.id))
  f:Advance(5101);f:Advance(2)
  assert(f.session:GetView().state=='idle','unsent timeout must not leave a recovery lock')
  assert(f.session:GetView().problem.code=='skillEntryTimeout' and not f.repo.character.journal)
  assert(#f.requests.skills==0 and f.attributeSends==0 and #f.api.requests==0)
  assert(f.session:BeginEdit(saved.id,false,'inventory'));assert(f.session:Cancel())
  assert(f.session:Apply(saved.id));f:SkillEntryReady();f:Advance(2)
  assert(#f.requests.skills==1)
 end,
 reload_releases_unsent_cancelled_entry_without_mutation_or_catalogue_scan=function()
  local f=setup();local j=journal(f)
  j.phase='recovery';j.maySent=false;j.requestStage='entry';j.problem=f.k.Problem('skillEntryTimeout')
  j.pending.phase='cancelled';j.pending.cancelledGeneration=2
  f.repo.character.journal=j;f:Reload()
  f.skills.Catalogue=function()error('unsent entry needs no talent scan')end
  assert(f.session:OnPlayerActivated())
  assert(f.session:GetView().state=='idle' and not f.repo.character.journal)
  assert(f.repo.character.lastInterruptedBuild.pending.sent==false)
  assert(#f.requests.skills==0 and f.attributeSends==0 and #f.api.requests==0)
 end,
 reload_keeps_uncertain_skill_dispatch_distinct_from_unsent_entry=function()
  for _,phase in ipairs({'dispatching','unknown','waiting'})do
   local f=setup();local j=journal(f);j.phase='recovery'
   j.pending.phase=phase;j.pending.sent=phase=='waiting';j.requestStage='dispatching'
   f.repo.character.journal=j;f:Reload();assert(not f.session:OnPlayerActivated())
   assert(f.session:GetView().state=='recovery')
  end
 end,
 loaded_attribute_cooldown_refusal_releases_without_manual_recovery=function()
  local f=setup();local j=journal(f)
  j.phase='recovery';j.requestStage='waiting';j.confirmed={skills=true}
  j.pending={phase='failed',sent=true,token=1,result=75,original={health=10,magicka=20,stamina=34},target={health=0,magicka=0,stamina=64}}
  j.target.attributes=f.k.Copy(j.pending.target);j.problem=f.k.Problem('nativeRespecRefused',{domain='attributes',result=75})
  f.repo.character.journal=j;f:Reload()
  f.skills.Catalogue=function()error('must not recheck confirmed skills')end
  assert(f.session:OnPlayerActivated())
  assert(f.session:GetView().state=='idle' and not f.repo.character.journal and f.repo.character.lastInterruptedBuild.pending.result==75)
  assert(f.attributeSends==0 and #f.requests.skills==0 and f.session:GetView().problem.details.result==75)
 end,
 loaded_refusal_does_not_release_when_actual_or_cast_is_unresolved=function()
  for _,change in ipairs({'actual','cast','result'})do
   local f=setup();local j=journal(f);j.phase='recovery'
   j.pending={phase='failed',sent=true,token=1,result=75,original={health=10,magicka=20,stamina=34},target={health=0,magicka=0,stamina=64}}
   if change=='actual'then f.actualAttributes={11,19,34}elseif change=='cast'then f.attributeCast=1 else j.pending.result=nil end
   f.repo.character.journal=j;f:Reload();assert(not f.session:OnPlayerActivated())
   assert(f.session:GetView().state=='recovery' and f.repo.character.journal)
  end
 end,
 refusal_with_already_confirmed_skills_keeps_session_usable=function()
  local f=setup();local p=f.repo:NewDraft();p.name='Refusal';p.slots=nil
  p.abilities=f.skills:Capture();p.attributes={health=0,magicka=0,stamina=64}
  local saved=assert(f.repo:Save(p,0));assert(f.session:Apply(saved.id))
  f.events:Emit('NativeAttributeRespecResult',{result=14});f:Advance(101)
  assert(f.session:GetView().state=='idle' and not f.repo.character.journal)
  assert(f.session:Apply(saved.id) and f.attributeSends==2)
 end,
 activated_releases_loaded_equipment_failure_without_replaying_or_scanning_skills=function()
  local f=setup();local j=journal(f)
  j.phase='recovery';j.maySent=false;j.requestStage='waiting';j.confirmed={skills=true,attributes=true}
  j.target.equipment=f.inventory:Capture(false).worn
  j.pending={kind='unequip',equipSlot=4,uid='old-weapon',before=j.original.equipment,expected=j.target.equipment}
  j.problem=f.k.Problem('externalChange');f.repo.character.journal=j;f:Reload()
  f.skills.Catalogue=function()error('activation must not scan talents')end
  f.api.SKILLS_AND_ACTION_BAR_MANAGER.isDirty=true
  assert(f.session:OnPlayerActivated())
  assert(f.session:GetView().state=='idle' and not f.repo.character.journal)
  assert(f.repo.character.lastInterruptedBuild.pending.uid=='old-weapon')
  assert(f.api.SKILLS_AND_ACTION_BAR_MANAGER.isDirty,'unrelated native draft was reset')
  assert(#f.requests.skills==0 and f.attributeSends==0 and #f.api.requests==0)
 end,
 activated_does_not_release_native_submission_or_editor_recovery=function()
  for _,kind in ipairs({'skills','attributes','editor'})do
   local f=setup();local j=journal(f)
   if kind=='attributes'then j.phase='attributes';j.pending={sent=true,token=1,original={health=10,magicka=20,stamina=34},target={health=0,magicka=0,stamina=64}} end
   if kind=='editor'then
    j.kind='new';j.operation='editor';j.page='inventory';j.component='equipment';j.name='Draft'
    j.maySent=false;j.phase='recovery';j.pending={kind='unequip',equipSlot=4,uid='old'}
   end
   f.repo.character.journal=j;f:Reload();f.session:OnPlayerActivated()
   assert(f.session:GetView().state=='recovery' and f.repo.character.journal,kind)
  end
 end,
 recovery_accepts_current_build_with_automatic_werewolf_binding_then_can_edit=function()
  local f=setup();local category=f.api.HOTBAR_CATEGORY_WEREWOLF
  f.skillObjects[1].spec.ultimate=true;f.overrides={[category..':8']=f.skillObjects[1]}
  f.actualBars[category][8]={type=1,id=511};BF.InstallEffectiveSlotIds(f,{})
  local j=journal(f);j.pending.sent=true;j.pending.phase='waiting'
  j.pending.target.skills['10:active:51'].morph=2;j.target.abilities=f.k.Copy(j.pending.target)
  j.pending.auxiliaryOriginal={[category]={[8]={kind='skill',skillKey='10:active:51',expectedMorph=1}}}
  j.pending.auxiliaryTarget={[category]={[8]={kind='skill',skillKey='10:active:51',expectedMorph=2}}}
  f.skillObjects[1].spec.morph=2;f.actualBars[category][8]=nil
  f.api.SKILLS_AND_ACTION_BAR_MANAGER:ResetRespecState()
  f.repo.character.journal=j;f:Reload()
  assert(f.api.SKILLS_AND_ACTION_BAR_MANAGER:HasAnyPendingChanges())
  local ok,err=f.session:Recover('acceptCurrent',f.session:GetRecoveryView().recoveryKey)
  assert(ok,err and err.code)
  assert(f.session:GetView().state=='idle' and not f.repo.character.journal)
  assert(#f.requests.skills==0 and f.attributeSends==0,'accept current does not apply anything')
  assert(f.session:BeginNew('skills'))
 end,
 recovery_presentation_and_page_changes_never_reinspect_native_state=function()
  local f=setup();f.repo.character.journal=journal(f);f:Reload()
  local reads=0;local capture=f.services.capture
  f.services.capture=function(...)reads=reads+1;return capture(...)end
  for _,page in ipairs({'skills','inventory','stats'})do
   f.session:OnNativePageState(page,'showing')
   for _=1,7 do
    local view=f.session:GetView();assert(view.state=='recovery' and view.recovery,'recovery action must stay visible')
   end
  end
  assert(reads==0,'page presentation performed '..reads..' native recovery inspections')
  assert(#f.requests.skills==0 and f.attributeSends==0)
 end,

 attribute_acknowledgment_keeps_affected_auxiliary_mismatch_in_recovery=function()
  local f=setup();f.actualBars[2][3]={type=1,id=511};f.api.ACTION_BAR_ASSIGNMENT_MANAGER:ResetPlayerHotbars()
  local j=journal(f);j.phase='attributes';j.requestStage='waiting';j.pending={phase='waiting',token=1,sent=true,original={health=10,magicka=20,stamina=34},target={health=0,magicka=0,stamina=64}}
  j.target.attributes=j.pending.target;j.confirmed={skills=true};j.verification={auxiliaryTarget={[2]={[3]={kind='skill',skillKey='10:active:51',expectedMorph=2}}}}
  f.actualAttributes={0,0,64};f.repo.character.journal=j;f:Reload();assert(f.session:GetRecoveryView().recovery.remaining.abilities)
  assert(f.session:Recover('confirmActualTarget',f.session:GetRecoveryView().recoveryKey));assert(f.repo.character.journal and f.session:GetView().state=='recovery' and f.session:GetRecoveryView().recovery.remaining.abilities and #f.requests.skills==0 and f.attributeSends==0)
  assert(f.repo.character.journal.confirmed.skills);local ok,e=f.session:Recover('remaining',f.session:GetRecoveryView().recoveryKey);assert(not ok and e.code=='confirmedBuildMismatch' and #f.requests.skills==0 and f.attributeSends==0)
 end,
 attribute_acknowledgment_key_binds_auxiliary_changes_before_and_during_cleanup=function()
  for _,during in ipairs({false,true})do
   local f=setup();f.actualBars[2][3]={type=1,id=511};f.api.ACTION_BAR_ASSIGNMENT_MANAGER:ResetPlayerHotbars()
   local j=journal(f);j.phase='attributes';j.requestStage='waiting';j.pending={phase='waiting',token=1,sent=true,original={health=10,magicka=20,stamina=34},target={health=0,magicka=0,stamina=64}};j.target.attributes=j.pending.target
   j.verification={auxiliaryTarget={[2]={[3]={kind='skill',skillKey='10:active:51',expectedMorph=1}}}};f.actualAttributes={0,0,64};f.repo.character.journal=j;f:Reload();local key=f.session:GetRecoveryView().recoveryKey
   if during then
    f.api.STATS.mode=f.api.ATTRIBUTE_POINT_ALLOCATION_MODE_FULL;local set=f.api.STATS.SetAttributePointAllocationMode
    f.api.STATS.SetAttributePointAllocationMode=function(stats,mode)set(stats,mode);if mode==0 then f.actualBars[2][3]={type=0,id=0};f.api.ACTION_BAR_ASSIGNMENT_MANAGER:ResetPlayerHotbars()end end
   else f.actualBars[2][3]={type=0,id=0};f.api.ACTION_BAR_ASSIGNMENT_MANAGER:ResetPlayerHotbars()end
   local ok,e=f.session:Recover('confirmActualTarget',key);assert(not ok and e.code=='recoveryChanged' and f.repo.character.journal and f.session:GetView().state=='recovery')
  end
 end,
 remaining_preserves_confirmed_normal_and_auxiliary_endpoints_during_future_phases=function()
  for _,change in ipairs({'normal','auxiliary'})do
   local f=setup();f.actualBars[2][3]={type=1,id=511};f.api.ACTION_BAR_ASSIGNMENT_MANAGER:ResetPlayerHotbars()
   local j=journal(f);j.pending=nil;j.maySent=false;j.requestStage=nil;j.confirmed={skills=true};j.target.attributes={health=0,magicka=0,stamina=64}
   j.verification={auxiliaryTarget={[2]={[3]={kind='skill',skillKey='10:active:51',expectedMorph=1}}}};f.repo.character.journal=j;f:Reload()
   assert(f.session:Recover('remaining',f.session:GetRecoveryView().recoveryKey));assert(f.attributeSends==1 and #f.requests.skills==0)
   assert(f.repo.character.journal.confirmed.skills and f.repo.character.journal.verification.auxiliaryTarget[2][3].expectedMorph==1)
   if change=='normal'then f.skillObjects[1].spec.morph=2 else f.actualBars[2][3]={type=0,id=0}end
   f.actualAttributes={0,0,64};f.attributeUnspent=2;f.events:Emit('NativeAttributeRespecResult',{result=0});f:Advance(101)
   assert(f.repo.character.journal and f.session:GetView().state=='recovery' and f.attributeSends==1 and #f.requests.skills==0,change)
  end
 end,
 malformed_committing_identity_revision_and_phase_never_crash_or_erase_storage=function()
  for _,field in ipairs({'revision','negative','infinite','fraction','presetId','name','candidate','phase'})do
   local f=setup();local p=f.repo:NewDraft();p.name='Stored';p.slots=nil;p.attributes={health=10,magicka=20,stamina=34};local stored=assert(f.repo:Save(p,0))
   local j={version=2,kind='edit',operation='editor',state='recovery',phase='committing',saveCommitted=false,page='stats',component='attributes',presetId=stored.id,name=stored.name,revision=stored.revision-1,original={attributes=stored.attributes},commitCandidate={attributes=stored.attributes}}
   if field=='revision'then j.revision=nil elseif field=='negative'then j.revision=-1 elseif field=='infinite'then j.revision=math.huge elseif field=='fraction'then j.revision=.5 elseif field=='presetId'then j.presetId=nil elseif field=='name'then j.name={} elseif field=='candidate'then j.commitCandidate=nil else j.phase='invented' end
   f.repo.character.journal=j;local ok,e=pcall(f.Reload,f);assert(ok,e);assert(f.session:GetView().problem.code=='invalidJournal' and f.repo.character.journal==j and #f.requests.skills==0 and f.attributeSends==0,field)
  end
 end,

 editor_recovery_requires_affected_auxiliary_target=function()
  local f=setup();f.actualBars[2][3]={type=1,id=511};f.api.ACTION_BAR_ASSIGNMENT_MANAGER:ResetPlayerHotbars()
  local p=f.repo:NewDraft();p.name='Aux';p.slots=nil;p.abilities={skills={['10:active:51']={kind='active',purchased=true,morph=2}}};local saved=assert(f.repo:Save(p,0))
  assert(f.session:BeginEdit(saved.id,false,'skills'));f.session:Pause('test');f.skillObjects[1].spec.morph=2
  assert(not f.session:Recover('confirmActualTarget',f.session:GetRecoveryView().recoveryKey) and f.repo.character.journal and #f.requests.skills==0)
 end,

 whole_apply_scene_navigation_updates_page_without_cancelling_coordinator=function()
  local f=setup();local d=f.repo:NewDraft();d.name='Whole';d.slots=nil;d.abilities={skills={['10:active:51']={kind='active',purchased=true,morph=2}}};local preset=assert(f.repo:Save(d,0))
  assert(f.session:Apply(preset.id));assert(f.services.buildRunner:IsBusy());f.session:OnNativePageState('stats','hiding');f.session:OnNativePageState('skills','showing')
  assert(f.session:GetView().page=='skills' and f.services.buildRunner:IsBusy() and not f.session.draft and #f.requests.skills==0)
 end,

 recovery_actions_expose_explicit_choices_without_scheduling_remaining=function()
  local f=setup();f.repo.character.journal=journal(f);f:Reload();local view=f.session:GetRecoveryView();local actions={}
  for _,action in ipairs(view.recovery.actions)do actions[action]=true end
  assert(actions.acceptCurrent and actions.confirmActualTarget and not actions.remaining and not actions.restore and not actions.relinquishUnsent)
  f:Advance(20000);assert(#f.requests.skills==0 and f.attributeSends==0)
 end,

 recovery_key_encoding_cannot_confuse_strings_with_map_entries=function()
  local f=setup();local a={a='foo;string:b=string:bar'};local b={a='foo',b='bar'}
  assert(f.k.BuildJournal.Key(a)~=f.k.BuildJournal.Key(b))
 end,
 editor_recovery_cleanup_uses_saved_target_after_actual_changes=function()
  local f=setup();assert(f.session:BeginNew('skills'));local allocator=f.skillObjects[1]:GetPointAllocator();assert(allocator:Unmorph());assert(allocator:Morph(2))
  f.session:Pause('test');assert(not f.session:Recover('confirmActualTarget',f.session:GetRecoveryView().recoveryKey));assert(f.skillObjects[1].spec.morph==1 and #f.requests.skills==0)
 end,
 unsupported_native_components_do_not_block_gear_recovery_adoption=function()
  local f=setup();f.api.GetAttributeRespecCastTimeRemainingMs=nil;f.api.GetSkillRespecCastTimeRemainingMs=nil
  f.services.capture=function()local e=f.inventory:Capture('equipment');return {equipment=e.worn,equipmentState=e,budgets={}},{}end
  local actual=f.inventory:Capture('equipment').worn
  f.repo.character.journal={version=2,kind='apply',operation='apply',state='recovery',phase='recovery',original={equipment=actual},target={equipment=actual},confirmed={}}
  f:Reload();assert(f.session:Recover('acceptCurrent',f.session:GetRecoveryView().recoveryKey));assert(f.session:GetView().state=='idle' and #f.requests.skills==0 and f.attributeSends==0)
 end,

 core_ready_scene_bridge_cleans_before_stock_hidden_and_continue_keeps_editor=function()
  local f=setup();local k=f.k;local api=f.api;local scenes={}
  api.SCENE_HIDING='HIDING';api.SCENE_SHOWING='SHOWING';api.SCENE_MANAGER={}
  for _,page in ipairs({'inventory','skills','stats'})do scenes[page]={RegisterCallback=function(self,event,fn)self.callback=fn end}end
  function api.SCENE_MANAGER:GetScene(page)return scenes[page]end
  function api.SCENE_MANAGER:Show(page)
   self.requested=page
   if self.current and not f.continuePage then scenes[self.current].callback(nil,api.SCENE_HIDING)end
   if not f.continuePage then self.current=page;scenes[page].callback(nil,api.SCENE_SHOWING)end
  end
  api.GetWorldName=function()return 'EU'end;api.GetDisplayName=function()return 'a'end;api.GetCurrentCharacterId=function()return 'c'end;api.GetUnitName=function()return 'Kana'end;api.GetAPIVersion=function()return 101050 end
  api.ZO_SavedVars={NewAccountWide=function()return {}end};api.SLASH_COMMANDS={}
  api.EVENT_MANAGER={RegisterForEvent=function()end,RegisterForUpdate=function()end,UnregisterForUpdate=function()end}
  k.SetPreview={New=function()return {}end};k.UI={New=function()return {ScheduleRefresh=function()end,Problem=function()end,OnSessionFinished=function()end,RefreshToggles=function()end}end}
  k.ItemTooltips={New=function()return {Attach=function()end,Invalidate=function()end}end}
  k.InventoryFilters={New=function()return {Attach=function()end,GetContexts=function()return {}end}end}
  local runtime=k.Core.Initialize(api);api.SCENE_MANAGER:Show('skills');assert(runtime.session:BeginNew('skills'));f.continuePage=true
  assert(runtime.session:SwitchPage('stats'));assert(runtime.session:GetView().page=='skills' and runtime.skills.mounted)
  f.continuePage=false;assert(runtime.session:SwitchPage('stats'));api.SKILLS_AND_ACTION_BAR_MANAGER:ResetInterface();api.SKILLS_AND_ACTION_BAR_MANAGER:OnUpdate()
  assert(runtime.session:GetView().state=='idle' and runtime.session:GetView().page=='stats' and not runtime.skills.mounted and #f.requests.skills==0)
 end,

 session_relinquishment_persists_resolution_and_returns_native_ownership=function()
  local f=setup();local request=assert(f.skills:Prepare(f.skills:Capture(),{skills={['10:active:51']={kind='active',purchased=true,morph=2}}}))
  assert(f.skills:Submit(request));f:SkillEntryReady();local allocator=f.skillObjects[1]:GetPointAllocator();assert(allocator:Unmorph());assert(allocator:Morph(2));assert(not f.skills:CancelSubmission())
  local j=journal(f);j.pending=f.skills:GetSubmissionState();j.requestStage='dispatching';f.repo.character.journal=j;f:Reload()
  assert(f.session:Recover('relinquishUnsent',f.session:GetRecoveryView().recoveryKey));assert(f.repo.character.journal and f.repo.character.journal.relinquished and not next(f.session:GetNativeOwnership()) and f.api.SKILLS_AND_ACTION_BAR_MANAGER.isDirty)
 end,
 editor_reload_does_not_mount_and_foreign_dirty_is_not_reset=function()
  local f=setup();assert(f.session:BeginNew('skills'));local dirty=f.api.SKILLS_AND_ACTION_BAR_MANAGER.isDirty
  f:Reload();assert(not f.session.draft and f.session:GetView().state=='recovery');f.api.SKILLS_AND_ACTION_BAR_MANAGER.isDirty=true
  assert(not f.session:Recover('acceptCurrent',f.session:GetRecoveryView().recoveryKey));assert(f.api.SKILLS_AND_ACTION_BAR_MANAGER.isDirty and f.attributeSends==0 and #f.requests.skills==0)
 end,
 clean_editor_reload_can_adopt_without_hydration=function()
  local f=setup();assert(f.session:BeginNew('stats'));local saved=f.k.Copy(f.repo.character.journal);assert(f.attributes:DiscardDraft());f.repo.character.journal=saved;f:Reload()
  assert(not f.session.draft and not f.attributes.mounted);assert(f.session:Recover('acceptCurrent',f.session:GetRecoveryView().recoveryKey));assert(f.session:GetView().state=='idle' and f.attributeSends==0)
 end,
 remaining_revalidates_budgets_and_never_reverses_paid_parts=function()
  local f=setup();local j=journal(f);j.pending=nil;j.maySent=false;j.target={attributes={health=66,magicka=0,stamina=0}};f.repo.character.journal=j;f:Reload();f.attributeUnspent=0
  local ok,e=f.session:Recover('remaining',f.session:GetRecoveryView().recoveryKey);assert(not ok and e.code=='insufficientAttributePoints' and f.attributeSends==0 and #f.requests.skills==0)
  assert(f.session:Recover('restore',f.session:GetRecoveryView().recoveryKey));assert(f.attributeSends==0 and #f.requests.skills==0)
 end,
 attribute_cast_and_actual_failure_keeps_ongoing_strict_resolve=function()
  local f=setup();local req=assert(f.attributes:Prepare(f.attributes:Capture(),{health=0,magicka=0,stamina=64},66));assert(f.attributes:Submit(req));local state=f.attributes:GetSubmissionState()
  f.actualAttributes={0,0,64};assert(not f.attributes:ResolveSubmission(nil,state.token));f.attributeCast=5;assert(not f.attributes:ReconcileSubmission(state,'actualTarget',f.attributes:GetRecoveryFacts()))
  f.attributeCast=0;assert(f.attributes:ReconcileSubmission(state,'actualTarget',f.attributes:GetRecoveryFacts()));assert(f.attributeSends==1)
 end,

 recovery_replacement_journal_is_never_overwritten_after_cleanup=function()
  local f=setup();f.repo.character.journal=journal(f);f:Reload();local replacement
  f.events:Subscribe('SkillSubmissionChanged',function(state)
   if state.phase=='reconciled'then replacement=journal(f);replacement.name='Replacement';f.repo.character.journal=replacement end
  end)
  assert(not f.session:Recover('acceptCurrent',f.session:GetRecoveryView().recoveryKey));assert(f.repo.character.journal==replacement and f.repo.character.journal.name=='Replacement')
 end,
 ownership_exit_rejects_a_replaced_local_editor=function()
  local f=setup();assert(f.session:BeginNew('skills'));assert(f.skills:DiscardDraft());assert(f.skills:MountDraft(f.skills:Capture()))
  f.session:OnNativePageState('skills','hiding');assert(f.skills.mounted and f.session:GetView().state=='recovery' and #f.requests.skills==0)
 end,
 runtime_cancelled_unsent_relinquishes_foreign_draft_without_touching_it=function()
  local f=setup();local request=assert(f.skills:Prepare(f.skills:Capture(),{skills={['10:active:51']={kind='active',purchased=true,morph=2}}}))
  assert(f.skills:Submit(request));f:SkillEntryReady()
  local allocator=f.skillObjects[1]:GetPointAllocator();assert(allocator:Unmorph());assert(allocator:Morph(2))
  f.api.SKILL_LINE_ASSIGNMENT_MANAGER={IsAnyChangePending=function()return true end}
  assert(not f.skills:CancelSubmission());local state=f.skills:GetSubmissionState()
  local wrong=f.k.Copy(state);wrong.token=wrong.token+1;assert(not f.skills:RelinquishUnsentDraft(wrong))
  assert(f.skills:RelinquishUnsentDraft(state));assert(not f.skills:GetNativeOwnership() and f.api.SKILLS_AND_ACTION_BAR_MANAGER:HasAnyPendingChanges() and f.api.SKILLS_AND_ACTION_BAR_MANAGER.isDirty and #f.requests.skills==0)
  assert(not f.skills:RelinquishUnsentDraft(state))
 end,
 reload_dispatching_false_cannot_relinquish_or_repeat_send=function()
  local f=setup();f.repo.character.journal=journal(f);f:Reload()
  assert(f.session:GetNativeOwnership().skills.possibleSent)
  assert(not f.session:Recover('relinquishUnsent',f.session:GetRecoveryView().recoveryKey));f:Advance(20000)
  assert(f.session:GetView().state=='recovery' and #f.requests.skills==0)
 end,
 attribute_requesting_checkpoint_is_possible_send_without_token=function()
  local f=setup();local j=journal(f);j.phase='attributes';j.requestStage='requesting';j.maySent=false
  j.pending={phase='attributes',sent=false,original={health=10,magicka=20,stamina=34},target={health=0,magicka=0,stamina=64}};j.target={attributes=j.pending.target}
  f.repo.character.journal=j;f:Reload();assert(f.session:GetNativeOwnership().attributes.possibleSent)
  assert(not f.session:Recover('remaining',f.session:GetRecoveryView().recoveryKey) and f.attributeSends==0)
 end,
 repeated_adoption_has_no_request_and_new_points_require_fresh_key=function()
  local f=setup();f.repo.character.journal=journal(f);f:Reload();local key=f.session:GetRecoveryView().recoveryKey;f.attributeUnspent=3
  assert(not f.session:Recover('acceptCurrent',key));assert(f.session:Recover('acceptCurrent',f.session:GetRecoveryView().recoveryKey));assert(not f.session:Recover('acceptCurrent',key));assert(#f.requests.skills==0 and f.attributeSends==0)
 end,
 attribute_recovery_checks_token_signed_foreign_and_cleanup_callbacks=function()
  local f=setup();local req=assert(f.attributes:Prepare(f.attributes:Capture(),{health=0,magicka=0,stamina=64},66));assert(f.attributes:Submit(req));f.attributes:CancelSubmission()
  f.actualAttributes={0,0,64};local state=f.attributes:GetSubmissionState();local facts=f.attributes:GetRecoveryFacts();local wrong=f.k.Copy(state);wrong.token=state.token+1
  assert(not f.attributes:ReconcileSubmission(wrong,'actualTarget',facts))
  f.api.STATS.attributeControls[1].pointLimitedSpinner.addedPoints=1;f.api.STATS.attributeControls[2].pointLimitedSpinner.addedPoints=-1
  assert(not f.attributes:ReconcileSubmission(state,'actualTarget',facts));f:ResetAttributesNative()
  f.api.STATS.mode=f.api.ATTRIBUTE_POINT_ALLOCATION_MODE_FULL;local set=f.api.STATS.SetAttributePointAllocationMode
  f.api.STATS.SetAttributePointAllocationMode=function(stats,mode)set(stats,mode);if mode==0 then f.actualAttributes[1]=1 end end
  assert(not f.attributes:ReconcileSubmission(state,'actualTarget',facts) and f.attributes.submitting and f.attributeSends==1)
 end,
 journal_invalid_resolution_cannot_end_possible_send_ownership=function()
  local f=setup();local j=journal(f);j.resolution={released=true};assert(not f.k.BuildJournal.Read(j))
 end,

 recovery_cast_token_auxiliary_and_facts_are_guards=function()
  local f=setup();local request=assert(f.skills:Prepare(f.skills:Capture(),{skills={['10:active:51']={kind='active',purchased=true,morph=2}}}))
  assert(f.skills:Submit(request));f:SkillEntryReady();f:Advance(1);f.skills:CancelSubmission();f.skillObjects[1].spec.morph=2
  local state=f.skills:GetSubmissionState();local facts=f.skills:GetRecoveryFacts(state);local wrong=f.k.Copy(state);wrong.token=wrong.token+1
  assert(not f.skills:ReconcileSubmission(wrong,'actualTarget',facts));assert(f.skills:SubmissionLocked())
  f.attributeCast=2;assert(not f.skills:ReconcileSubmission(state,'actualTarget',facts));f.attributeCast=0
  f.api.STATS.attributeControls[1].pointLimitedSpinner.addedPoints=1;f.api.STATS.attributeControls[2].pointLimitedSpinner.addedPoints=-1
  assert(not f.skills:ReconcileSubmission(state,'actualTarget',facts));f:ResetAttributesNative()
  f.skillPoints=9;assert(not f.skills:ReconcileSubmission(state,'actualTarget',facts));assert(#f.requests.skills==1)
 end,
 recovery_auxiliary_target_is_required=function()
  local f=setup();f.actualBars[2][3]={type=1,id=511};f.api.ACTION_BAR_ASSIGNMENT_MANAGER:ResetPlayerHotbars()
  local request=assert(f.skills:Prepare(f.skills:Capture(),{skills={['10:active:51']={kind='active',purchased=true,morph=2}}}))
  assert(f.skills:Submit(request));f:SkillEntryReady();f:Advance(1);f.skills:CancelSubmission();f.skillObjects[1].spec.morph=2
  local state=f.skills:GetSubmissionState();assert(next(state.auxiliaryTarget));local facts=f.skills:GetRecoveryFacts(state)
  assert(not f.skills:ReconcileSubmission(state,'actualTarget',facts) and f.skills:SubmissionLocked());assert(#f.requests.skills==1)
 end,
 recovery_cleanup_callback_change_retains_record=function()
  local f=setup();local j=journal(f);f.repo.character.journal=j;f:Reload();f.api.SKILLS_AND_ACTION_BAR_MANAGER:SetSkillPointAllocationMode(f.api.SKILL_POINT_ALLOCATION_MODE_FULL)
  local global=f.api.SKILLS_AND_ACTION_BAR_MANAGER;global:RegisterCallback('SkillPointAllocationModeChanged',function()f.skillObjects[1].spec.morph=2 end)
  local ok=f.session:Recover('acceptCurrent',f.session:GetRecoveryView().recoveryKey)
  assert(not ok and f.repo.character.journal and f.session:GetView().state=='recovery' and #f.requests.skills==0 and global.mode==f.api.SKILL_POINT_ALLOCATION_MODE_FULL)
 end,
 owned_exit_actual_or_cross_cast_change_never_cleans=function()
  for _,change in ipairs({'actual','cast'})do
   local f=setup();assert(f.session:BeginNew('skills'));f.api.SKILLS_AND_ACTION_BAR_MANAGER.isDirty=true
   if change=='actual'then f.skillObjects[1].spec.morph=2 else f.attributeCast=5 end
   f.session:OnNativePageState('skills','hiding')
   assert(f.session:GetView().state=='recovery' and f.skills.mounted and f.api.SKILLS_AND_ACTION_BAR_MANAGER.mode==f.api.SKILL_POINT_ALLOCATION_MODE_FULL and #f.requests.skills==0)
  end
 end,
 journal_drops_nested_snapshots_and_foreign_editor_selection=function()
  local f=setup();local j=journal(f);j.kind='new';j.name='New';j.page='stats';j.component='attributes';j.operation='editor';j.pending=nil
  j.original.attributes={health=10,magicka=20,stamina=34};j.selection={equipment={[EQUIP_SLOT_HEAD]=true},attributes=true}
  j.editorPlan={target={attributes={health=10,magicka=20,stamina=34}},equipmentState={byUid={secret={native=function()end}}}}
  local saved={};assert(f.k.BuildJournal.Write(saved,j));assert(not saved.journal.editorPlan.equipmentState and not saved.journal.selection.equipment)
 end,
 malformed_pending_refuses_reload_without_native_cleanup=function()
  local f=setup();local j=journal(f);j.pending.token={};f.repo.character.journal=j;f:Reload()
  assert(f.session:GetView().problem.code=='invalidJournal' and not next(f.session:GetNativeOwnership()) and #f.requests.skills==0)
 end,

 all_six_page_transitions_end_current_editor_without_submission=function()
  for _,from in ipairs({'inventory','skills','stats'})do for _,to in ipairs({'inventory','skills','stats'})do if from~=to then
   local f=setup();assert(f.session:BeginNew(from))
   -- Gear exits require an explicit accepted decision before native HIDING.
   -- The source-shaped Core/dialog integration covers Save/Cancel/Continue;
   -- this fixture exercises cleanup after the user's Cancel choice.
   if from=='inventory'then assert(f.session:Cancel())end
   assert(f.session:SwitchPage(to));local view=f.session:GetView()
   assert(view.state=='idle' and view.page==to and not f.session.draft and not f.skills.mounted and not f.attributes.mounted,from..'->'..to)
   assert(#f.requests.skills==0 and f.attributeSends==0)
  end end end
 end,
 native_continue_keeps_original_page_editor=function()
  local f=setup();assert(f.session:BeginNew('skills'));f.continuePage=true;assert(f.session:SwitchPage('stats'))
  assert(f.session:GetView().state=='editing' and f.session:GetView().page=='skills' and f.skills.mounted and not f.attributes.mounted)
 end,
 page_leave_does_not_clear_foreign_pending=function()
  local f=setup();assert(f.session:BeginNew('skills'));f.foreignSubclassPending=true
  f.api.SKILL_LINE_ASSIGNMENT_MANAGER={IsAnyChangePending=function()return true end}
  f.session:OnNativePageState('skills','hiding')
  assert(f.session:GetView().state=='recovery' and f.skills.mounted and f.api.SKILLS_AND_ACTION_BAR_MANAGER.mode==f.api.SKILL_POINT_ALLOCATION_MODE_FULL and #f.requests.skills==0,tostring(f.session:GetView().state)..' '..tostring(f.skills.mounted)..' '..tostring(f.api.SKILLS_AND_ACTION_BAR_MANAGER.mode)..' '..#f.requests.skills)
 end,
 owned_dirty_cleanup_never_autosends=function()
  local f=setup();assert(f.session:BeginNew('skills'));f.api.SKILLS_AND_ACTION_BAR_MANAGER.isDirty=true
  f.session:OnNativePageState('skills','hiding');f.api.SKILLS_AND_ACTION_BAR_MANAGER:ResetInterface();f.api.SKILLS_AND_ACTION_BAR_MANAGER:OnUpdate()
  assert(f.session:GetView().state=='idle' and #f.requests.skills==0 and not f.skills.mounted)
 end,
 stock_attribute_reset_first_releases_only_matching_owner=function()
  local f=setup();local original=f.attributes:Capture();assert(f.attributes:MountDraft(original));local owner=f.attributes:GetNativeOwnership();f:ResetAttributesNative()
  assert(not f.attributes:ReleaseAfterNativeExit(owner.token+1,original));assert(f.attributes.mounted)
  assert(f.attributes:ReleaseAfterNativeExit(owner.token,original));assert(not f.attributes.mounted and f.attributeSends==0)
 end,
 reload_after_skills_before_attributes_reconciles_actual=function()
  local f=setup();local j=journal(f);j.target.attributes={health=0,magicka=0,stamina=64};j.pending.target.skills['10:active:51'].morph=2;j.target.abilities=j.pending.target
  f.repo.character.journal=j;f.skillObjects[1].spec.morph=2;f:Reload();local view=f.session:GetRecoveryView()
  assert(view.state=='recovery' and view.recovery.confirmed.abilities and view.recovery.remaining.attributes and view.recovery.unresolved)
  assert(f.session:Recover('confirmActualTarget',view.recoveryKey));assert(f.session:GetView().state=='recovery' and not f.session:GetRecoveryView().recovery.unresolved and f.attributeSends==0)
  assert(f.session:Recover('remaining',f.session:GetRecoveryView().recoveryKey));assert(f.attributeSends==1 and #f.requests.skills==0)
 end,
 blocked_recovery_has_reason_without_retry_loop=function()
  local f=setup();f.repo.character.journal=journal(f);f:Reload();f.attributeCast=5;local key=f.session:GetRecoveryView().recoveryKey
  local ok,e=f.session:Recover('acceptCurrent',key);assert(not ok and e and f.repo.character.journal)
  f:Advance(20000);assert(f.attributeSends==0 and #f.requests.skills==0 and f.session:GetView().state=='recovery')
 end,
 late_attribute_success_finishes_exact_target=function()
  local f=setup();local a=f.attributes:Capture();local req=assert(f.attributes:Prepare(a,{health=0,magicka=0,stamina=64},66));assert(f.attributes:Submit(req));f.attributes:CancelSubmission()
  local j=journal(f);j.phase='attributes';j.target={attributes=req.target};j.pending=f.attributes:GetSubmissionState();j.requestStage='waiting';f.repo.character.journal=j;f:Reload()
  assert(not f.session:Recover('confirmActualTarget',f.session:GetRecoveryView().recoveryKey));f.actualAttributes={0,0,64};f.attributeUnspent=2
  assert(f.session:Recover('confirmActualTarget',f.session:GetRecoveryView().recoveryKey));assert(f.session:GetView().state=='idle' and f.attributeSends==1 and not f.attributes.submitting)
 end,
 recovery_wrong_key_never_releases_or_sends=function()
  local f=setup();f.repo.character.journal=journal(f);f:Reload();local ok,e=f.session:Recover('acceptCurrent','stale');assert(not ok and e.code=='recoveryChanged' and f.repo.character.journal and #f.requests.skills==0)
 end,
 corrupt_reload_cannot_claim_native_ownership=function()
  local f=setup();f.repo.character.journal={version=2,kind='apply',original={attributes={health=-1,magicka=0,stamina=0}}};f:Reload()
  assert(f.session:GetView().problem.code=='invalidJournal' and not next(f.session:GetNativeOwnership()))
 end,
 legacy_journal_remains_equipment_only=function()
  local f=setup();local gear=f.k.Session.New(f.repo,f.inventory,f.k.EquipmentPlan,f.gear,f.protection,f.repo.character,{})
  assert(gear:BeginNew());local raw=f.repo.character.journal;assert(raw.version==1);f:Reload()
  assert(f.session.journal.version==1 and not f.session.journal.original.abilities and f.session:GetView().state=='recovery')
 end,
 journal_whitelists_plain_actual_and_possible_send=function()
  local f=setup();local j=journal(f);j.original.equipmentState={byUid={secret={native=function()end}}};j.catalogue={native=function()end}
  local saved={};assert(f.k.BuildJournal.Write(saved,j));assert(not saved.journal.original.equipmentState and not saved.journal.catalogue and saved.journal.maySent)
  local read=assert(f.k.BuildJournal.Read(saved.journal,f.repo));assert(read.pending.sent==false and read.maySent)
 end,
 journal_rejects_corruption_without_erasing_storage=function()
  local f=setup();local saved={journal=17};local j,e=f.k.BuildJournal.Read(saved.journal,f.repo);assert(not j and e.code=='invalidJournal' and saved.journal==17)
  local broken=journal(f);broken.pending.target={skills={bad={kind='active',purchased=true,morph=1}}};assert(not f.k.BuildJournal.Read(broken,f.repo))
 end,
 journal_editor_only_retains_its_component=function()
  local f=setup();local j=journal(f);j.operation='editor';j.kind='edit';j.presetId='p';j.revision=1;j.name='Edit';j.page='stats';j.component='attributes';j.target=f:Capture();j.experiment=f:Capture();j.selection={attributes=true};j.pending=nil
  local s={};assert(f.k.BuildJournal.Write(s,j));assert(s.journal.original.attributes and not s.journal.original.abilities and not s.journal.target.equipment)
 end,
 actual_reconciliation_is_not_a_native_result=function()
  local f=setup();local actual=f.skills:Capture();local request=assert(f.skills:Prepare(actual,{skills={['10:active:51']={kind='active',purchased=true,morph=2}}}))
  assert(f.skills:Submit(request));f:SkillEntryReady();f:Advance(1);assert(#f.requests.skills==1);f.skills:CancelSubmission()
  f.skillObjects[1].spec.morph=2
  local state=f.skills:GetSubmissionState();local facts=f.skills:GetRecoveryFacts(state)
  local resolved=assert(f.skills:ReconcileSubmission(state,'actualTarget',facts));assert(resolved.nativeOutcome=='unknown' and f.skills:GetSubmissionState().resolved and #f.requests.skills==1)
 end,
 stock_reset_first_requires_matching_owner_and_never_autosends=function()
  local f=setup();local original=f.skills:Capture();assert(f.skills:MountDraft(original));local owner=f.skills:GetNativeOwnership()
  local global=f.api.SKILLS_AND_ACTION_BAR_MANAGER;global:ResetInterface();global.isDirty=true
  assert(not f.skills:ReleaseAfterNativeExit(owner.token+1,original));assert(f.skills.mounted and global.isDirty)
  assert(f.skills:ReleaseAfterNativeExit(owner.token,original));global:OnUpdate();assert(not f.skills.mounted and #f.requests.skills==0)
 end,
}
