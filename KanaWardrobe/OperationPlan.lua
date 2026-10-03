local KW=KanaWardrobe
local P={};KW.OperationPlan=P
local function skillName(catalogue,key,state)
 local record=catalogue and catalogue.byKey[key];if not record then return end
 if record.kind=='passive' and record.native and type(record.native.GetRankData)=='function'then
  local rank=math.max(1,state and state.rank or 1)
  local ok,name=pcall(function()return record.native:GetRankData(rank):GetName()end)
  if ok and type(name)=='string' and name~=''then return name end
 end
 local morph=state and (state.expectedMorph or state.morph)
 if morph~=nil and record.native and type(record.native.GetMorphData)=='function'then
  local ok,name=pcall(function()return record.native:GetMorphData(morph):GetName()end)
  if ok and type(name)=='string' and name~=''then return name end
 end
 return record.name
end
P.SkillName=skillName
function P.Build(snapshot,requested,services,capabilities,catalogue)
 local plan,problem=services.buildPlanner.Build(snapshot,requested,catalogue,capabilities)
 if not plan then return nil,problem end
 local result={steps={},target={},scope={},extras={},extraKey=plan.extraKey}
 local notices={}
 for _,extra in ipairs(plan.extras)do
  if extra.type=='ability' and (extra.bar=='front' or extra.bar=='back' or extra.bar=='werewolf')then
   -- An omitted bar slot imposes no constraint on the selected talent change.
   -- Its resulting morph/removal is useful information, not another permission.
   local notice=KW.Copy(extra)
   notice.beforeName=skillName(catalogue,extra.skillKey,extra.before)
   notice.targetName=skillName(catalogue,extra.skillKey,extra.target)
   notices[#notices+1]=notice
  else result.extras[#result.extras+1]=KW.Copy(extra)end
 end
 local function add(kind,data)
  data=data or {};data.kind=kind;data.id=kind..':'..(#result.steps+1);result.steps[#result.steps+1]=data
 end
 if plan.equipmentPlan then
  local gear=plan.equipmentPlan;local worn=KW.Copy(gear.before)
  result.scope.equipment=true;result.target.equipment={}
  for slot in pairs(plan.requested.equipment)do result.target.equipment[slot]=KW.Copy(gear.target[slot])end
  for _,extra in ipairs(gear.extras)do result.target.equipment[extra.fromSlot]=KW.Copy(gear.target[extra.fromSlot])end
  local batch,batchId
  local function flush()
   if not batch then return end
   if #batch==1 then add(batch[1].kind,batch[1])
   else
    local before,target,items={},{},{}
    for _,item in ipairs(batch)do
     before[item.equipSlot]=KW.Copy(item.before);target[item.equipSlot]=KW.Copy(item.target)
     items[#items+1]=KW.Copy(item.details)
    end
    add('equipBatch',{items=batch,before=before,target=target,details={items=items}})
   end
   batch=nil
  end
  for _,step in ipairs(gear.steps)do
   local after=step.kind=='equip' and KW.Copy(gear.target[step.equipSlot])or {kind='empty'}
   local location=snapshot.equipmentState.byUid[step.uid]
   if step.kind~='equip' or not step.batchId or step.batchId~=batchId then flush()end
   local item={kind=step.kind,uid=step.uid,equipSlot=step.equipSlot,before=KW.Copy(worn[step.equipSlot]),target=after,
    details={uid=step.uid,slot=step.equipSlot,link=location and location.link or '',before=KW.Copy(worn[step.equipSlot]),target=after}}
   if step.kind=='equip'then batch=batch or {};batch[#batch+1]=item;batchId=step.batchId
   else add(step.kind,item);batchId=nil end
   worn[step.equipSlot]=after
  end
  flush()
 end
 if plan.attributeRequest then
  result.scope.attributes=true;result.target.attributes=KW.Copy(plan.attributeRequest.target)
  if not KW.BuildModel.Matches(snapshot,{attributes=plan.attributeRequest.target})then
   add('attributes',{target=KW.Copy(plan.attributeRequest.target),details={before=KW.Copy(snapshot.attributes),target=KW.Copy(plan.attributeRequest.target)}})
  end
 end
 if plan.skillRequest then
  local request=plan.skillRequest
  result.scope.abilities=true;result.target.abilities=KW.Copy(plan.requested.abilities)
  result.target.abilities.skills=result.target.abilities.skills or {}
  result.target.abilities.bars=result.target.abilities.bars or {}
  local talents={skills={}};local details={changes={},notices=notices}
  for _,change in ipairs(request.skillChanges)do
   talents.skills[change.key]=KW.Copy(change.target)
   result.target.abilities.skills[change.key]=KW.Copy(change.target)
   local record=catalogue.byKey[change.key]
   details.changes[#details.changes+1]={key=change.key,name=record and record.name,before=KW.Copy(change.before),target=KW.Copy(change.target),
    beforeName=skillName(catalogue,change.key,change.before),targetName=skillName(catalogue,change.key,change.target)}
  end
  if next(talents.skills)then
   -- A selected mastery line is a complete allocation. Sending only changed
   -- passives makes Prepare interpret already-learned selections as refunds.
   talents.skills=KW.Copy(result.target.abilities.skills)
   add('skills',{target=talents,details=details})
  end
  for _,bar in ipairs({'front','back','werewolf'})do
   local target={};local changes={}
   for _,change in ipairs(request.barChanges)do if change.bar==bar then
    local ref=KW.Copy(change.target);target[change.slot]=ref
    result.target.abilities.bars[bar]=result.target.abilities.bars[bar]or {};result.target.abilities.bars[bar][change.slot]=ref
    changes[#changes+1]={slot=change.slot,target=ref,targetName=skillName(catalogue,ref.skillKey,ref)}
   end end
   -- Morph propagation is done by the talent request itself. Keep its final
   -- reference in verification but only assign bars explicitly requested here.
   local explicit=plan.requested.abilities.bars and plan.requested.abilities.bars[bar]
   if (explicit or #request.skillChanges==0) and next(target)then add('bar',{bar=bar,target=target,details={bar=bar,changes=changes}})end
  end
  result.auxiliaryTarget=KW.Copy(request.auxiliaryTarget)
 end
 add('verify',{target=KW.Copy(result.target),auxiliaryTarget=result.auxiliaryTarget})
 return result
end
