local Fake=dofile(ROOT..'/tests/support/fake_eso.lua')
local function setup()
 local k=Fake.Load({'Core.lua','Slots.lua','lang/en.lua','BuildModel.lua','Presets.lua','BuildDraft.lua','AppearanceAdapter.lua'})
 local active={[1]=101,[2]=0};local calls={}
 local api={COLLECTIBLE_CATEGORY_TYPE_COSTUME=1,COLLECTIBLE_CATEGORY_TYPE_HAT=2,GAMEPLAY_ACTOR_CATEGORY_PLAYER=0}
 api.GetActiveCollectibleByType=function(category)return active[category] or 0 end
 api.GetCollectibleCategoryType=function(id)return id<200 and 1 or 2 end
 api.IsCollectibleUnlocked=function(id)return id~=199 end
 api.IsCollectibleUsable=function()return true end
 api.GetCollectibleName=function(id)return 'Item '..id end
 api.GetCollectibleIcon=function(id)return 'icon'..id end
 api.UseCollectible=function(id) calls[#calls+1]=id;local c=api.GetCollectibleCategoryType(id);active[c]=active[c]==id and 0 or id end
 return k,k.AppearanceAdapter.New(api),active,calls,api
end
return {
 appearance_preserves_explicit_empty_and_omitted_categories=function()
  local k=setup();local p=assert(k.BuildModel.Normalize({appearance={[1]=0}}))
  assert(p.appearance[1]==0 and p.appearance[2]==nil)
  assert(k.BuildModel.HasParts(p))
  assert(k.BuildModel.Matches({appearance={[1]=0,[2]=201}},p))
  assert(not k.BuildModel.Matches({appearance={[1]=101}},p))
  assert(#k.BuildModel.Differences({appearance={[1]=101}},p)==1)
  assert(not k.BuildModel.Normalize({appearance={[1]=-1}}))
 end,
 appearance_selection_and_other_components_survive_save=function()
  local k=setup();local preset={id=1,name='test',attributes={health=64,magicka=0,stamina=0},appearance={[1]=0}}
  local draft=assert(k.BuildDraft.New({appearance={[1]=101,[2]=201}},preset,'collectionsBook'))
  assert(draft:GetSelection().appearance[1] and not draft:GetSelection().appearance[2])
  assert(draft:SetSelected('appearance',2,true));assert(draft:SetValue('appearance',2,0))
  local result=assert(k.BuildDraft.PresetCandidate(preset,'appearance',draft:GetPresetBuild()))
  assert(result.appearance[1]==0 and result.appearance[2]==0 and result.attributes.health==64)
 end,
 appearance_retry_does_not_toggle_completed_item=function()
  local _,a,active,calls=setup();assert(a:Request(1,102));assert(active[1]==102)
  assert(a:Request(1,102));assert(#calls==1 and active[1]==102)
  assert(a:Request(1,0));assert(active[1]==0)
  assert(a:Request(1,0));assert(#calls==2)
 end,
 appearance_diff_validates_before_sending=function()
  local _,a,_,calls=setup();local plan=assert(a:Prepare(a:Capture(),{[1]=102,[2]=0}))
  assert(#plan.changes==1 and plan.changes[1].category==1)
  assert(not a:Prepare(a:Capture(),{[1]=201}))
  assert(not a:Prepare(a:Capture(),{[1]=199}))
  assert(not a:Prepare(a:Capture(),{[99]=0}))
  assert(#calls==0)
 end,
 appearance_repository_patches_keep_other_parts=function()
  local k=setup();local repo=k.Presets.New({},'EU','a','c','name')
  local p=assert(repo:PatchComponents(nil,{appearance={op='replace',value={[1]=0}},attributes={op='replace',value={health=64,magicka=0,stamina=0}}},'test'))
  assert(p.appearance[1]==0 and p.attributes.health==64)
  local changed=assert(repo:PatchComponent(p.id,'appearance',{op='replace',value={[2]=201}},p.name,p.revision))
  assert(changed.appearance[2]==201 and changed.appearance[1]==nil and changed.attributes.health==64)
 end,
}
