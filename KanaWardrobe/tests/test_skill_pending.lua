local Fake=dofile(ROOT..'/tests/support/fake_eso.lua')
local BF=dofile(ROOT..'/tests/support/build_fixture.lua')
local AF=dofile(ROOT..'/tests/support/attribute_fixture.lua')
local function setup()
 local k=Fake.Load({'Core.lua','Slots.lua','lang/en.lua','BuildModel.lua','SkillState.lua','SkillAdapter.lua','AttributeAdapter.lua'})
 local f=AF.Attach(BF.InstallSkills(BF.New(),{
  {lineId=10,kind='active',id=3905,purchased=true,morph=2,chainedAbilityIds={[2]={39073}}},
  {lineId=10,kind='active',id=2909,purchased=true,morph=1},
  {lineId=10,kind='active',id=2880,purchased=true,morph=0,chainedAbilityIds={[0]={28799}}},
  {lineId=50,kind='active',id=152,purchased=true,morph=2,ultimate=true},
 }))
 f.events=k.Core.NewEvents();BF.InstallSkillDrafts(f)
 f.actualBars[1][4]={type=1,id=39052};f.actualBars[1][5]={type=1,id=29091};f.actualBars[1][7]={type=1,id=28800}
 BF.InstallEffectiveSlotIds(f,{[39052]=39067,[29091]=29078,[28800]=28798})
 return k,f,k.SkillAdapter.New(f.api,f.events,f.clock),k.AttributeAdapter.New(f.api,f.events)
end
return {
 actual_weapon_variants_allow_editor_and_application_without_a_foreign_draft=function()
  local k,f,adapter=setup();local api=f.api;local global=api.SKILLS_AND_ACTION_BAR_MANAGER
  f.actualBars[1][4]={type=1,id=28799};f.actualBars[1][6]={type=1,id=39073};f.actualBars[1][7]=nil
  BF.InstallEffectiveSlotIds(f,{}) -- report: 28799 -> 28800, 39073 -> 39052
  assert(global:HasAnyPendingChanges() and not global.isDirty)
  assert(not k.SkillState.HasPendingChanges(api),'unchanged weapon variants must not block a preset')
  local original=adapter:Capture()
  assert(original.bars.back[2].skillKey=='10:active:2880' and original.bars.back[2].expectedMorph==0)
  assert(original.bars.back[4].skillKey=='10:active:3905' and original.bars.back[4].expectedMorph==2)
  assert(adapter:MountDraft(original));assert(adapter:DiscardDraft())
  assert(#f.requests.skills==0 and api.GetSlotBoundId(4,1)==28799 and api.GetSlotBoundId(6,1)==39073)
  local request=assert(adapter:Prepare(original,{skills={['10:active:2909']={kind='active',purchased=true,morph=2}}}))
  assert(adapter:Submit(request));f:SkillEntryReady();f:Advance(1)
  assert(#f.requests.skills==1)
  f.skillObjects[2].spec.morph=2;f.actualBars[1][5].id=29092
  global:ResetRespecState();f.events:Emit('NativeSkillRespecResult',{result=0})
  assert(adapter:ResolveSubmission(0,adapter:GetSubmissionState().token))
  assert(not adapter:SubmissionLocked() and api.GetSlotBoundId(4,1)==28799)
 end,
 weapon_variant_equivalence_does_not_hide_real_bar_or_morph_edits=function()
  for _,kind in ipairs({'differentSkill','differentMorph','unlearned','unmapped','unreadable'})do
   local k,f=setup();local api=f.api
   f.actualBars[1][4]={type=1,id=39073};BF.InstallEffectiveSlotIds(f,{})
   if kind=='differentSkill'then f.hotbars[1]:AssignSkillToSlot(4,f.skillObjects[2])
   elseif kind=='differentMorph'then f.skillObjects[1].spec.morph=1
   elseif kind=='unlearned'then f.skillObjects[1].spec.purchased=false
   else
    local lookup=api.SKILLS_DATA_MANAGER.GetProgressionDataByAbilityId
    api.SKILLS_DATA_MANAGER.GetProgressionDataByAbilityId=function(self,id)
     if id==39073 then if kind=='unreadable'then error('cannot resolve variant')else return nil end end
     return lookup(self,id)
    end
   end
   api.SKILLS_AND_ACTION_BAR_MANAGER.isDirty=false
   assert(k.SkillState.HasPendingChanges(api),kind..' must remain protected')
   assert(#f.requests.skills==0)
  end
 end,
 pending_read_failure_keeps_its_cause_for_diagnostics=function()
  local k,f=setup()
  f.api.GetSlotBoundId=function()error('native slot unavailable')end
  local blocked,cause=k.SkillState.HasPendingChanges(f.api)
  assert(blocked and type(cause)=='string' and cause:find('native slot unavailable',1,true))
 end,
 native_forced_werewolf_slot_is_not_a_foreign_draft=function()
  local k,f,adapter=setup();local api=f.api;local category=api.HOTBAR_CATEGORY_WEREWOLF
  f.overrides={[category..':8']=f.skillObjects[4]};api.ACTION_BAR_ASSIGNMENT_MANAGER:ResetPlayerHotbars()
  assert(api.GetSlotType(8,category)==0 and api.GetSlotBoundId(8,category)==0)
  assert(f.hotbars[category]:DoesSlotHavePendingChanges(8) and api.SKILLS_AND_ACTION_BAR_MANAGER:HasAnyPendingChanges())
  assert(not k.SkillState.HasPendingChanges(api),'automatic forced binding must not block recovery')
  assert(not adapter:ForeignDraftProblem(api.SKILLS_AND_ACTION_BAR_MANAGER))
  local original=adapter:Capture();assert(adapter:MountDraft(original));assert(adapter:DiscardDraft())
  api.SKILLS_AND_ACTION_BAR_MANAGER:OnUpdate()
  assert(#f.requests.skills==0 and api.GetSlotBoundId(8,category)==0,'reading/closing must not send a repair')
 end,
 forced_slot_exception_does_not_hide_real_or_unproven_edits=function()
  for _,kind in ipairs({'noRule','runtimeMismatch','otherSkill','morph','unlearned','ordinaryBar','dirty','lines','unreadable'}) do
   local k,f,adapter=setup();local api=f.api;local category=api.HOTBAR_CATEGORY_WEREWOLF
   f.overrides={[category..':8']=f.skillObjects[4]};api.ACTION_BAR_ASSIGNMENT_MANAGER:ResetPlayerHotbars()
   if kind=='noRule'then api.GetSkillProgressionIdForHotbarSlotOverrideRule=function()return 0 end
   elseif kind=='runtimeMismatch'then f.hotbars[category].GetOverrideSkillDataForSlot=function()return f.skillObjects[1]end
   elseif kind=='otherSkill'then f.hotbars[category]:GetSlotData(8).skill=f.skillObjects[1]
   elseif kind=='morph'then f.skillObjects[4]:GetPointAllocator():Morph(1);api.SKILLS_AND_ACTION_BAR_MANAGER.isDirty=false
   elseif kind=='unlearned'then f.skillObjects[4].spec.purchased=false
   elseif kind=='ordinaryBar'then f.overrides={['0:8']=f.skillObjects[4]};api.ACTION_BAR_ASSIGNMENT_MANAGER:ResetPlayerHotbars()
   elseif kind=='dirty'then api.SKILLS_AND_ACTION_BAR_MANAGER.isDirty=true
   elseif kind=='lines'then api.SKILL_LINE_ASSIGNMENT_MANAGER={IsAnyChangePending=function()return true end}
   else api.GetSkillProgressionIdForHotbarSlotOverrideRule=function()error('unavailable')end end
   local problem=adapter:ForeignDraftProblem(api.SKILLS_AND_ACTION_BAR_MANAGER)
   assert(problem and problem.code=='foreignSkillDraft',kind)
   assert(#f.requests.skills==0)
  end
 end,
 next_skill_apply_synchronizes_empty_forced_slot_in_same_request=function()
  for _,targetMorph in ipairs({1,2}) do
   local _,f,adapter=setup();local api=f.api;local category=api.HOTBAR_CATEGORY_WEREWOLF
   f.overrides={[category..':8']=f.skillObjects[4]};api.ACTION_BAR_ASSIGNMENT_MANAGER:ResetPlayerHotbars()
   local request=assert(adapter:Prepare(adapter:Capture(),{skills={['50:active:152']={kind='active',purchased=true,morph=targetMorph}}}))
   assert(#request.barChanges==1 and request.barChanges[1].bar=='werewolf','missing automatic native binding')
   assert(request.werewolfOriginal[6].kind=='empty')
   assert(request.target.bars.werewolf[6].expectedMorph==targetMorph)
   local ok,err=adapter:Submit(request);assert(ok,err and err.code)
   if targetMorph~=2 then f:SkillEntryReady();f:Advance(1)end
   assert(#f.requests.skills==1)
   local count=0
   for _,change in ipairs(f.requests.skills[1].bars)do
    if change.bar==category and change.slot==8 then assert(change.id==1520+targetMorph);count=count+1 end
   end
   assert(count==1)
  end
 end,
 reported_unchanged_bar_bindings_allow_skill_editor_and_clean_exit=function()
  local k,f,adapter=setup();local global=f.api.SKILLS_AND_ACTION_BAR_MANAGER
  assert(global:HasAnyPendingChanges() and not global.isDirty and global.mode==0)
  local actual=adapter:Capture()
  local ok,err=adapter:MountDraft(actual);assert(ok,err and err.code)
  assert(adapter:DiscardDraft());assert(global.mode==0 and not global.isDirty and not adapter:GetNativeOwnership())
  global:OnUpdate();assert(#f.requests.skills==0)
  assert(k.BuildModel.Matches({abilities=adapter:Capture()},{abilities=actual}))
  assert(adapter:MountDraft(actual));assert(adapter:UnmountDraft());assert(global.mode==0)
 end,
 effective_id_difference_does_not_block_attribute_draft=function()
  local _,f,_,attributes=setup()
  local ok,err=attributes:MountDraft({health=0,magicka=0,stamina=64});assert(ok,err and err.code)
  assert(attributes:DiscardDraft());assert(f.api.STATS.mode==0 and f.attributeSends==0)
  assert(f.actualAttributes[1]==10 and f.actualBars[1][4].id==39052)
 end,
 real_edits_remain_protected_alongside_effective_id_difference=function()
  for _,kind in ipairs({'binding','empty','morph','dirty','mode','lines','otherManager','unreadable'})do
   local _,f,adapter=setup();local api=f.api;local global=api.SKILLS_AND_ACTION_BAR_MANAGER
   if kind=='binding'then f.hotbars[1]:AssignSkillToSlot(4,f.skillObjects[2]);global.isDirty=false
   elseif kind=='empty'then f.hotbars[1]:ClearSlot(4);global.isDirty=false
   elseif kind=='morph'then f.skillObjects[1]:GetPointAllocator():Morph(1);global.isDirty=false
   elseif kind=='dirty'then global.isDirty=true
   elseif kind=='mode'then global:SetSkillPointAllocationMode(api.SKILL_POINT_ALLOCATION_MODE_FULL)
   elseif kind=='lines'then api.SKILL_LINE_ASSIGNMENT_MANAGER={IsAnyChangePending=function()return true end};table.insert(global.managers,api.SKILL_LINE_ASSIGNMENT_MANAGER)
   elseif kind=='otherManager'then f.foreignPending=true
   else api.GetSlotBoundId=function()error('native slot unavailable')end end
   local before=#f.draftOperations;local mode=global.mode
   local problem=adapter:ForeignDraftProblem(global)
   assert(problem and problem.code=='foreignSkillDraft',kind..' must stay protected')
   assert(#f.draftOperations==before and global.mode==mode and #f.requests.skills==0)
  end
 end,
 skill_submission_and_confirmation_accept_unchanged_effective_variants=function()
  local _,f,adapter=setup();local api=f.api;local global=api.SKILLS_AND_ACTION_BAR_MANAGER
  -- Change a skill not responsible for the persistent ID aliases.
  local request=assert(adapter:Prepare(adapter:Capture(),{skills={['10:active:2880']={kind='active',purchased=true,morph=1}}}))
  local ok,err=adapter:Submit(request);assert(ok,err and err.code)
  f:SkillEntryReady();f:Advance(1);assert(#f.requests.skills==1)
  f.skillObjects[3].spec.morph=1;f.actualBars[1][7].id=28801
  global:ResetRespecState();f.events:Emit('NativeSkillRespecResult',{result=0})
  assert(adapter:ResolveSubmission(0,adapter:GetSubmissionState().token))
  assert(global.mode==0 and not global.isDirty and not adapter:SubmissionLocked())
  global:OnUpdate();assert(#f.requests.skills==1)
 end,
}
