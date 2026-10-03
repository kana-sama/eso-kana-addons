local Fake=dofile(ROOT..'/tests/support/fake_eso.lua')
local BF=dofile(ROOT..'/tests/support/build_fixture.lua')
local AF=dofile(ROOT..'/tests/support/attribute_fixture.lua')
local function setup()
 local k=Fake.Load({'Core.lua','Slots.lua','lang/en.lua','BuildModel.lua','EquipmentPlan.lua','SkillState.lua','SkillAdapter.lua','AttributeAdapter.lua','Dialogs.lua','BuildPlanner.lua'})
 local f=AF.Attach(BF.InstallSkills(BF.New(),{{lineId=10,kind='active',id=51,purchased=true,morph=1},{lineId=10,kind='active',id=52,purchased=false,morph=0}}))
 local sa=k.SkillAdapter.New(f.api);local aa=k.AttributeAdapter.New(f.api);local c=sa:Catalogue();local attrs,budget=aa:Capture()
 local eq={worn={},byUid={},freeSlots=10};for _,slot in ipairs(k.Slots.Order)do eq.worn[slot]={kind='empty'}end
 local s={equipment=k.Copy(eq.worn),abilities=k.Copy(c.abilities),attributes=attrs,equipmentState=eq,budgets={skills=c.budgets.skills,mastery=c.budgets.mastery,attributes=budget}}
 return k,f,k.BuildPlanner.New({skills=sa,attributes=aa}),s,c
end
return {
 attributes_deficit_blocks_every_domain=function()
  local _,f,p,s,c=setup();local q,e=p.Build(s,{attributes={health=67,magicka=0,stamina=0}},c,{})
  assert(not q and e.code=='insufficientAttributePoints' and e.details.deficit==1);assert(#f.requests.attributes==0 and #f.requests.skills==0)
 end,
 skills_deficit_blocks_every_domain=function()
  local _,f,p,s,c=setup();s.budgets.skills=0;c.budgets.skills=0
  local q,e=p.Build(s,{abilities={skills={['10:active:52']={kind='active',purchased=true,morph=2}}}},c,{})
  assert(not q and e.code=='insufficientSkillPoints' and e.details.deficit==2);assert(#f.requests.skills==0)
 end,
 unselected_bar_clear_requires_specific_consent=function()
  local k,_,p,s,c=setup();s.abilities.bars.front[3]={kind='skill',skillKey='10:active:51',expectedMorph=1};c.abilities=k.Copy(s.abilities)
  local q=assert(p.Build(s,{abilities={skills={['10:active:51']={kind='active',purchased=false}}}},c,{}))
  assert(#q.extras==1 and q.extras[1].bar=='front' and q.extras[1].slot==3 and q.extras[1].target.kind=='empty');assert(k.Dialogs.ExtrasText(q):find('51',1,true))
 end,
 revalidation_changes_budget_fingerprint=function()
  local _,_,p,s,c=setup();local q=assert(p.Build(s,{attributes={health=0,magicka=0,stamina=64}},c,{}));s.budgets.attributes=67
  local r=assert(p.Revalidate(q,s,c));assert(r.fingerprint~=q.fingerprint)
 end,
 remaining_excludes_confirmed_attributes_and_rejects_wrong_actual=function()
  local k,_,p,s,c=setup();local q=assert(p.Build(s,{attributes={health=0,magicka=0,stamina=64}},c,{}))
  assert(not p.RevalidateRemaining(q,s,c,{attributes=true}));s.attributes=k.Copy(q.target.attributes)
  local r=assert(p.RevalidateRemaining(q,s,c,{attributes=true}));assert(not r.attributeRequest and r.fingerprint==q.fingerprint)
 end,
 gear_only_does_not_require_adapters=function()
  local k,_,_,s=setup();local p=k.BuildPlanner.New({});assert(p.Build(s,{equipment={}},nil,{}))
 end,
 morph_change_lists_all_affected_unselected_slots=function()
  local k,_,p,s,c=setup();for _,bar in ipairs({'front','back'})do s.abilities.bars[bar][3]={kind='skill',skillKey='10:active:51',expectedMorph=1}end
  c.auxiliaryBars[2][3]={ref={kind='skill',skillKey='10:active:51',expectedMorph=1},category=2,nativeSlot=3,mutable=true,eligible=true}
  local q=assert(p.Build(s,{abilities={skills={['10:active:51']={kind='active',purchased=true,morph=2}}}},c,{}))
  assert(#q.extras==3 and #q.skillRequest.auxiliaryChanges==1);for _,extra in ipairs(q.extras)do assert(extra.before.expectedMorph==1 and extra.target.expectedMorph==2)end
 end,
 override_ultimate_uses_target_equipment=function()
  local _,_,p,s,c=setup();local ref={kind='item',uid='crypt',link='crypt'}
  s.equipmentState.byUid.crypt={uid='crypt',link='crypt',bagId=BAG_BACKPACK,slotIndex=4,metadata={itemId=194509,equipType=EQUIP_TYPE_CHEST,valid=true,availableToEquip=true,staticEquipable=true,mythic=true}}
  local q,e=p.Build(s,{equipment={[EQUIP_SLOT_CHEST]=ref},abilities={bars={front={[6]={kind='skill',skillKey='10:active:51',expectedMorph=1}}}}},c,{})
  assert(not q and e.code=='equipmentOverride' and e.details.reason=='targetCryptcanon')
 end,
 current_crypt_requires_manual_removal_before_skill_phase=function()
  local _,_,p,s,c=setup();local ref={kind='item',uid='crypt',link='crypt'};s.equipment[EQUIP_SLOT_CHEST]=ref;s.equipmentState.worn[EQUIP_SLOT_CHEST]=ref
  s.equipmentState.byUid.crypt={uid='crypt',link='crypt',bagId=BAG_WORN,slotIndex=EQUIP_SLOT_CHEST,metadata={itemId=194509,equipType=EQUIP_TYPE_CHEST,valid=true,staticEquipable=true}}
  s.abilities.bars.front[6]={kind='skill',skillKey='10:active:51',expectedMorph=1}
  local q,e=p.Build(s,{equipment={[EQUIP_SLOT_CHEST]={kind='empty'}},abilities={bars={front={[6]={kind='empty'}}}}},c,{})
  assert(not q and e.code=='equipmentOverride' and e.details.reason=='removeCryptcanonManually')
 end,
 explicit_bar_morph_conflict_and_unpurchased_ref_refuse=function()
  local _,_,p,s,c=setup()
  assert(not p.Build(s,{abilities={bars={front={[3]={kind='skill',skillKey='10:active:52',expectedMorph=0}}}}},c,{}))
  assert(not p.Build(s,{abilities={bars={front={[3]={kind='skill',skillKey='10:active:51',expectedMorph=2}}}}},c,{}))
 end,
 consent_tracks_availability_revision_and_uid_position=function()
  local _,_,p,s,c=setup();local preset={abilities={skills={['10:active:51']={kind='active',purchased=true,morph=2}}}}
  local q=assert(p.Build(s,preset,c,{}));c.revision=c.revision+1
  assert(p.Revalidate(q,s,c).fingerprint~=q.fingerprint)
  c.byKey['10:active:51'].morphUnlocked[2]=false;assert(not p.Revalidate(q,s,c))
  local g=assert(p.Build(s,{equipment={}},nil,{}));s.equipmentState.byUid.x={uid='x',bagId=BAG_BACKPACK,slotIndex=7,metadata={itemId=1}}
  assert(p.Revalidate(g,s,nil).fingerprint~=g.fingerprint)
 end,
 remaining_retains_absolute_attribute_target_after_skill_confirmation=function()
  local k,_,p,s,c=setup();local q=assert(p.Build(s,{abilities={skills={['10:active:51']={kind='active',purchased=true,morph=2}}},attributes={health=0,magicka=0,stamina=64}},c,{}))
  s.abilities=k.Copy(q.target.abilities);s.budgets.skills=s.budgets.skills-1
  local r=assert(p.RevalidateRemaining(q,s,c,{skills=true}));assert(not r.skillRequest and r.attributeRequest.target.stamina==64 and r.fingerprint==q.fingerprint)
 end,
 legacy_gear_dialog_still_formats_dependency=function()
  local k=setup();local text=k.Dialogs.ExtrasText({extras={{uid='x',fromSlot=EQUIP_SLOT_HEAD,link='item',reason='mythic'}}});assert(text:find('item',1,true))
 end,

 remaining_refuses_external_budget_change=function()
  local k,_,p,s,c=setup();local q=assert(p.Build(s,{abilities={skills={['10:active:51']={kind='active',purchased=true,morph=2}}},attributes={health=0,magicka=0,stamina=64}},c,{}));s.abilities=k.Copy(q.target.abilities);s.budgets.attributes=67
  local r,e=p.RevalidateRemaining(q,s,c,{skills=true});assert(not r and e.code=='buildDependenciesChanged')
 end,
 deficit_dialog_displays_numbers=function()
  local k=setup();assert(k.Dialogs.Problem({code='insufficientSkillPoints',details={required=3,available=1,deficit=2}}):find('Required 3, available 1, deficit 2',1,true))
 end,

 remaining_refuses_uid_movement_after_attribute_confirmation=function()
  local k,_,p,s,c=setup();local q=assert(p.Build(s,{equipment={},attributes={health=0,magicka=0,stamina=64}},c,{}));s.attributes=k.Copy(q.target.attributes)
  s.equipmentState.byUid.x={uid='x',bagId=BAG_BACKPACK,slotIndex=8,metadata={itemId=1}}
  local r,e=p.RevalidateRemaining(q,s,c,{attributes=true});assert(not r and e.code=='buildDependenciesChanged')
 end,
 confirmed_auxiliary_actual_is_required=function()
  local k,_,p,s,c=setup();c.auxiliaryBars[2][3]={ref={kind='skill',skillKey='10:active:51',expectedMorph=1},category=2,nativeSlot=3,mutable=true,eligible=true}
  local q=assert(p.Build(s,{abilities={skills={['10:active:51']={kind='active',purchased=false}}}},c,{}));s.abilities=k.Copy(q.target.abilities)
  local r,e=p.RevalidateRemaining(q,s,c,{skills=true});assert(not r and e.code=='confirmedBuildMismatch')
  c.auxiliaryBars[2][3].ref={kind='empty'};assert(p.RevalidateRemaining(q,s,c,{skills=true}))
 end,
 no_implicit_refund_of_unselected_skill=function()
  local _,_,p,s,c=setup();s.budgets.skills=0
  local q,e=p.Build(s,{abilities={skills={['10:active:52']={kind='active',purchased=true,morph=0}}}},c,{})
  assert(not q and e.code=='insufficientSkillPoints' and s.abilities.skills['10:active:51'].purchased)
 end,
 unknown_override_relevant_change_refuses=function()
  local _,_,p,s,c=setup();c.barMetadata.front[6].runtimeOverride='unknown';local q,e=p.Build(s,{abilities={bars={front={[6]={kind='skill',skillKey='10:active:51',expectedMorph=1}}}}},c,{})
  assert(not q and e.code=='equipmentOverride' and e.details.reason=='unknownOverride')
 end,

 chained_remaining_keeps_confirmed_auxiliary_verification=function()
  local k,_,p,s,c=setup();c.auxiliaryBars[2][3]={ref={kind='skill',skillKey='10:active:51',expectedMorph=1},category=2,nativeSlot=3,mutable=true,eligible=true}
  local q=assert(p.Build(s,{abilities={skills={['10:active:51']={kind='active',purchased=false}}},attributes={health=0,magicka=0,stamina=64}},c,{}))
  s.abilities=k.Copy(q.target.abilities);c.auxiliaryBars[2][3].ref={kind='empty'}
  local r=assert(p.RevalidateRemaining(q,s,c,{skills=true}));assert(not r.skillRequest and r.attributeRequest)
  s.attributes=k.Copy(q.target.attributes);c.auxiliaryBars[2][3].ref={kind='skill',skillKey='10:active:51',expectedMorph=1}
  local final,e=p.RevalidateRemaining(r,s,c,{attributes=true});assert(not final and e.code=='confirmedBuildMismatch')
  c.auxiliaryBars[2][3].ref={kind='empty'};assert(p.RevalidateRemaining(r,s,c,{attributes=true}))
 end,
 override_dialog_distinguishes_reasons=function()
  local k=setup();local unknown=k.Dialogs.Problem({code='equipmentOverride',details={reason='unknownOverride'}})
  local target=k.Dialogs.Problem({code='equipmentOverride',details={reason='targetCryptcanon'}})
  local current=k.Dialogs.Problem({code='equipmentOverride',details={reason='removeCryptcanonManually'}})
  assert(unknown:find('supported rule',1,true) and not unknown:find('Cryptcanon',1,true));assert(target:find('target',1,true) and not target:find('manually',1,true));assert(current:find('manually',1,true))
 end,

}
