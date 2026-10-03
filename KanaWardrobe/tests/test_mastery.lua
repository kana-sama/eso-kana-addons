local Fake=dofile(ROOT..'/tests/support/fake_eso.lua')
local BF=dofile(ROOT..'/tests/support/build_fixture.lua')
local function setup(reverse)
 local k=Fake.Load({'Core.lua','Slots.lua','lang/en.lua','BuildModel.lua','SkillState.lua','SkillAdapter.lua','Presets.lua','Dialogs.lua','UI.lua'})
 local f=BF.InstallSkillDrafts(BF.InstallSkills(BF.New(),{
  {lineId=352,kind='passive',id=10,purchased=true,rank=1,mastery=true,masteryPoints=2,masterySpent=2},
  {lineId=352,kind='passive',id=11,purchased=not reverse,rank=1,mastery=true},
  {lineId=352,kind='passive',id=12,purchased=reverse==true,rank=1,mastery=true},
  {lineId=353,kind='passive',id=20,purchased=true,rank=1,mastery=true,masteryPoints=1,masterySpent=1},
  {lineId=10,kind='passive',id=30,purchased=true,rank=1},
 }))
 f.skillPoints=0
 f.events=k.Core.NewEvents()
 local adapter=k.SkillAdapter.New(f.api,f.events,f.clock)
 local wanted=reverse and '352:passive:111' or '352:passive:121'
 local removed=reverse and '352:passive:121' or '352:passive:111'
 local target={skills={['352:passive:101']={kind='passive',rank=1},[wanted]={kind='passive',rank=1}}}
 return k,f,adapter,target,wanted,removed
end
return {
 mastery_swap_refunds_omitted_passive_before_purchase_with_zero_free_points=function()
  for _,reverse in ipairs({false,true})do
   local _,f,a,target,wanted,removed=setup(reverse)
   local current=assert(a:Capture())
   local request,err=a:Prepare(current,target)
   assert(request,err and err.code)
   assert(request.masteryDelta[352]==0 and request.pointDelta==0 and request.requiresRespec)
   assert(#request.skillChanges==2 and request.skillChanges[1].key==removed and request.skillChanges[2].key==wanted)
   assert(request.target.skills[removed].rank==0 and request.target.skills[wanted].rank==1)
   assert(request.target.skills['353:passive:201'].rank==1 and request.target.skills['10:passive:301'].rank==1)
   assert(not target.skills[removed] and current.skills[removed].rank==1,'planning mutated saved or actual state')
   assert(a:MountDraft(target))
   assert(table.concat(f.draftOperations,',')=='Sell,Purchase','mastery was bought before refund')
   local draft=assert(a:CaptureDraft())
   assert(draft.skills[removed].rank==0 and draft.skills[wanted].rank==1)
   assert(#f.requests.skills==0 and a:Capture().skills[removed].rank==1,'editor applied the draft')
   assert(a:DiscardDraft())
   assert(a:Capture().skills[removed].rank==1)
  end
 end,
 mastery_submission_contains_refund_before_purchase_in_one_request=function()
  local _,f,a,target=setup()
  local request,err=a:Prepare(a:Capture(),target);assert(request,err and err.code)
  assert(a:Submit(request));f:SkillEntryReady();f:Advance(1)
  assert(#f.requests.skills==1)
  local sent=f.requests.skills[1].skills
  assert(#sent==2 and sent[1].id==111 and sent[1].removal==true)
  assert(sent[2].id==121 and sent[2].removal==false)
 end,
 mastery_refunds_include_rank_reductions_and_explicit_disables=function()
  local _,f,a,target,_,removed=setup()
  f.skillObjects[2].spec.rank=2;f.skillLines[352].spec.masteryPoints=3;f.skillLines[352].spec.masterySpent=3
  target.skills[removed]={kind='passive',rank=1}
  assert(a:MountDraft(target))
  assert(table.concat(f.draftOperations,',')=='DecreaseRank,Purchase')
  assert(a:DiscardDraft())
  target.skills[removed].rank=0
  assert(a:MountDraft(target))
  local draft=assert(a:CaptureDraft())
  assert(draft.skills[removed].rank==0)
 end,
 genuine_mastery_deficit_still_rejects_without_changes=function()
  local _,f,a,target,_,removed=setup()
  target.skills[removed]={kind='passive',rank=1}
  local request,err=a:Prepare(a:Capture(),target)
  assert(not request and err.code=='insufficientMasteryPoints' and err.details.required==1 and err.details.available==0)
  assert(#f.requests.skills==0 and #f.draftOperations==0 and not f.entryRequests)
 end,
 no_mastery_selection_preserves_all_mastery_passives=function()
  local _,_,a=setup()
  for _,target in ipairs({{bars={front={[1]={kind='empty'}}}},{skills={['10:passive:301']={kind='passive',rank=0}}}})do
   local request=assert(a:Prepare(a:Capture(),target))
   assert(request.target.skills['352:passive:101'].rank==1 and request.target.skills['352:passive:111'].rank==1)
   assert(request.target.skills['353:passive:201'].rank==1 and not next(request.masteryDelta))
  end
 end,
 active_checkmark_requires_absent_mastery_passives_to_be_disabled_without_native_reads=function()
  local k,f,a,target,_,removed=setup()
  -- One selected passive already matches, but the old allocation has an extra.
  target.skills['352:passive:121']=nil
  local preset={id='test',name='Mastery',abilities=target}
  local repo={List=function()return {preset}end,Get=function()end}
  local session={GetView=function()return {state='idle',selected={}}end}
  local ui=k.UI.New(repo,session,nil,{api=f.api},{})
  local display=k.SkillState.ReadDisplay(f.api)
  a.Catalogue=function()error('full catalogue on display')end
  f.api.GetAvailableSkillPoints=function()error('budget read on display')end
  assert(not ui:Model({worn={},byUid={}},{abilities=display.abilities},display).rows[1].matches)
  display.abilities.skills[removed].rank=0
  assert(ui:Model({worn={},byUid={}},{abilities=display.abilities},display).rows[1].matches)
 end,
}
