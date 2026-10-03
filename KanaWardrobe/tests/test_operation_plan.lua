local setup=dofile(ROOT..'/tests/support/operation_fixture.lua')
local function create()local f=setup();assert(f.k.OperationPlan,'diff step planner is not implemented');return f end
return {
 relocated_werewolf_slot_notice_describes_a_move_not_an_unlearned_skill=function()
  local f=create();f.actualBars[3][3]={type=1,id=511};f.api.ACTION_BAR_ASSIGNMENT_MANAGER:ResetPlayerHotbars()
  local p=assert(f:Plan({abilities={bars={werewolf={[2]={kind='skill',skillKey='10:active:51',expectedMorph=1}}}}}))
  assert(#p.extras==0 and p.steps[1].bar=='werewolf' and p.steps[1].target[1].kind=='empty')
 end,
 werewolf_bar_step_follows_talent_changes_and_names_the_bar=function()
  local f=create();local p=assert(f:Plan({abilities={skills={['10:active:51']={kind='active',purchased=true,morph=2}},
   bars={werewolf={[1]={kind='skill',skillKey='10:active:51',expectedMorph=2}}}}}))
  assert(#p.extras==0 and #p.steps==3)
  assert(p.steps[1].kind=='skills' and p.steps[2].kind=='bar' and p.steps[2].bar=='werewolf' and p.steps[3].kind=='verify')
  assert(p.target.abilities.bars.werewolf[1].expectedMorph==2)
  dofile(ROOT..'/Dialogs.lua');dofile(ROOT..'/OperationWindow.lua')
  assert(f.k.OperationWindow.StepTitle(p.steps[2])=='Set action bar · Werewolf')
 end,
 independent_equips_share_one_step_without_removals=function()
  local f=create();f:AddItem('old1',EQUIP_SLOT_RING1,true);f:AddItem('old2',EQUIP_SLOT_RING2,true)
  local a=f:AddItem('a',2);local b=f:AddItem('b',3)
  local p=assert(f:Plan({equipment={[EQUIP_SLOT_RING1]=a,[EQUIP_SLOT_RING2]=b}}))
  assert(#p.steps==2 and p.steps[1].kind=='equipBatch' and #p.steps[1].items==2)
  assert(p.steps[1].before[EQUIP_SLOT_RING1].uid=='old1' and p.steps[1].target[EQUIP_SLOT_RING2].uid=='b')
 end,
 relocating_item_and_mythic_are_released_before_their_batch=function()
  local f=create();local moving=f:AddItem('moving',EQUIP_SLOT_RING1,true)
  f:AddItem('mythicOld',EQUIP_SLOT_HEAD,true,EQUIP_TYPE_HEAD);f.api.descriptions.mythicOld.quality=99
  local mythic=f:AddItem('mythicNew',3,false,EQUIP_TYPE_NECK);f.api.descriptions.mythicNew.quality=99
  local p=assert(f:Plan({equipment={[EQUIP_SLOT_RING2]=moving,[EQUIP_SLOT_NECK]=mythic}}))
  local released={}
  for _,step in ipairs(p.steps)do
   if step.kind=='unequip'then released[step.uid]=true end
   for _,item in ipairs(step.items or (step.kind=='equip' and {step}or {}))do
    if item.uid=='moving'then assert(released.moving)end
    if item.uid=='mythicNew'then assert(released.mythicOld)end
   end
  end
 end,
 unselected_bar_morph_is_named_information_not_consent=function()
  local f=create();f.skillObjects[1].spec.morph=2
  f.skillObjects[1].spec.names={[1]='Inspired Scholarship',[2]='Recuperative Treatise'}
  f.actualBars[1][5]={type=1,id=512};f.api.ACTION_BAR_ASSIGNMENT_MANAGER:ResetPlayerHotbars()
  local p=assert(f:Plan({abilities={skills={['10:active:51']={kind='active',purchased=true,morph=1}},
   bars={front={[1]={kind='skill',skillKey='10:active:51',expectedMorph=1}}}}}))
  assert(#p.extras==0,'ordinary morph propagation still requires consent')
  local note=p.steps[1].details.notices[1]
  assert(note.bar=='back' and note.beforeName=='Recuperative Treatise' and note.targetName=='Inspired Scholarship')
  assert(p.target.abilities.bars.back[3].expectedMorph==1,'informational notice must not remove morph verification')
  dofile(ROOT..'/Dialogs.lua');dofile(ROOT..'/OperationWindow.lua')
  local body=f.k.OperationWindow.StepBody(p.steps[1])
  assert(body:find('Recuperative Treatise',1,true) and body:find('Inspired Scholarship',1,true))
  assert(not body:find('expectedMorph',1,true) and not body:find('10:active:51',1,true) and not body:find('purchased=',1,true))
 end,
 unlearning_clears_unselected_bar_without_confirmation=function()
  local f=create();f.actualBars[1][5]={type=1,id=511};f.api.ACTION_BAR_ASSIGNMENT_MANAGER:ResetPlayerHotbars()
  local p=assert(f:Plan({abilities={skills={['10:active:51']={kind='active',purchased=false}}}}))
  assert(#p.extras==0 and p.target.abilities.bars.back[3].kind=='empty')
  assert(p.steps[1].details.notices[1].reason=='skillSold')
 end,
 direct_replacement_is_one_request_not_remove_then_equip=function()
  local f=create();f:AddItem('old',EQUIP_SLOT_RING1,true);local ref=f:AddItem('new',2)
  local p=assert(f:Plan({equipment={[EQUIP_SLOT_RING1]=ref}}))
  assert(#p.steps==2 and p.steps[1].kind=='equip' and p.steps[1].before.uid=='old' and p.steps[2].kind=='verify')
 end,
 gear_only_never_reads_skills=function()
  local f=create();f.skills.Catalogue=function()error('gear-only scanned skills')end
  local ref=f:AddItem('new',2);assert(f:Plan({equipment={[EQUIP_SLOT_RING1]=ref}}))
 end,
 relocation_and_mythic_have_explicit_dependencies=function()
  local f=create();local ref=f:AddItem('ring',EQUIP_SLOT_RING1,true)
  local p=assert(f:Plan({equipment={[EQUIP_SLOT_RING2]=ref}}));assert(p.steps[1].kind=='unequip' and p.steps[2].kind=='equip')
  f=create();f:AddItem('old',EQUIP_SLOT_RING1,true);ref=f:AddItem('new',2)
  f.api.descriptions.old.quality=99;f.api.descriptions.new.quality=99
  p=assert(f:Plan({equipment={[EQUIP_SLOT_RING2]=ref}}));assert(p.steps[1].kind=='unequip' and p.steps[2].kind=='equip')
 end,
 all_preflight_finishes_before_gear_changes=function()
  local f=create();local ref=f:AddItem('new',2)
  local p,e=f:Plan({equipment={[EQUIP_SLOT_RING1]=ref},attributes={health=1000,magicka=0,stamina=0}})
  assert(not p and e.code=='insufficientAttributePoints' and #f.api.requests==0)
 end,
 phases_follow_gear_attributes_talents_bars_then_verify=function()
  local f=create();local ref=f:AddItem('new',2)
  local p=assert(f:Plan({equipment={[EQUIP_SLOT_RING1]=ref},attributes={health=0,magicka=0,stamina=64},
   abilities={skills={['10:active:51']={kind='active',purchased=true,morph=2}},bars={front={[1]={kind='skill',skillKey='10:active:51',expectedMorph=2}}}}}))
  local kinds={};for _,s in ipairs(p.steps)do kinds[#kinds+1]=s.kind end
  assert(table.concat(kinds,',')=='equip,attributes,skills,bar,verify',table.concat(kinds,','))
  assert(p.steps[3].target.skills['10:active:51'].morph==2 and not p.steps[3].target.bars)
 end,
 unchanged_intent_has_only_verification=function()
  local f=create();local ref=f:AddItem('ring',EQUIP_SLOT_RING1,true)
  local p=assert(f:Plan({equipment={[EQUIP_SLOT_RING1]=ref}}));assert(#p.steps==1 and p.steps[1].kind=='verify')
 end,
}
