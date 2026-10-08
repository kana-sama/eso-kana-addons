local KW=KanaWardrobe
local P={};KW.BuildPlanner=P
-- Runtime services are explicit. Bound methods use dot calls and never read live APIs.
local function encode(v)
 local t=type(v)
 if t~='table' then if t=='string' then return 's'..#v..':'..v end;return t..':'..tostring(v) end
 local keys={};for k,x in pairs(v)do if k~='native' and type(x)~='function' and type(x)~='userdata' then keys[#keys+1]=k end end
 table.sort(keys,function(a,b)return encode(a)<encode(b)end)
 local rows={};for _,k in ipairs(keys)do rows[#rows+1]=encode(k)..encode(v[k])end
 return '{'..table.concat(rows)..'}'
end
local function fail(code,details)return nil,KW.Problem(code,details or {})end
local function deficit(err)
 if err and err.details and err.details.required and err.details.available then err.details.deficit=math.max(0,err.details.required-err.details.available)end
 return nil,err
end
local function actual(snapshot)
 if type(snapshot)~="table" then return nil end
 return KW.BuildModel.Normalize(snapshot)
end
local function chestId(state,equipment)
 local ref=equipment and equipment[EQUIP_SLOT_CHEST];local item=ref and ref.kind=='item' and state and state.byUid and state.byUid[ref.uid]
 return item and item.metadata and item.metadata.itemId
end
local function extrasFor(request,requested,catalogue,current)
 local extras={};local bars=requested.bars or {}
 local function add(before,target,bar,slot,category)
  if encode(before)==encode(target) or before.kind~='skill'then return end
  local key=before.skillKey;local record=catalogue.byKey[key]
  local reason=target.kind=='empty' and 'skillSold' or 'skillMorph'
  local targetSlot
  if target.kind=='empty' and bar then
   for index,ref in pairs(request.target.bars[bar] or {})do
    if ref.kind=='skill' and ref.skillKey==key then reason='skillMoved';targetSlot=index;break end
   end
  end
  extras[#extras+1]={type='ability',skillKey=key,name=record and record.name or key,bar=bar,slot=slot,category=category,before=KW.Copy(before),target=KW.Copy(target),reason=reason,targetSlot=targetSlot}
 end
 for _,bar in ipairs({'front','back','werewolf'})do
  if current.bars[bar] and request.target.bars[bar] then
  for slot=1,6 do
   if not (bars[bar] and bars[bar][slot])then add(current.bars[bar][slot],request.target.bars[bar][slot],bar,slot,(catalogue.barMetadata[bar][slot] or {}).category)end
  end
  end
 end
 for _,change in ipairs(request.auxiliaryChanges or {})do
  if not change.automatic then add(change.before,change.target,nil,change.nativeSlot,change.category)end
 end
 table.sort(extras,function(a,b)return encode({a.bar,a.category,a.slot,a.skillKey})<encode({b.bar,b.category,b.slot,b.skillKey})end)
 return extras
end
function P.New(services)
 assert(type(services)=='table','explicit planner services required')
 local bound={}
 function bound.Build(snapshot,preset,catalogue,capabilities)
  local requested,err=KW.BuildModel.Normalize(preset);if not requested then return nil,err end
  local current=actual(snapshot);if type(current)~='table' or type(snapshot.budgets)~='table'then return fail('invalidBuildSnapshot')end
  local plan={requested=KW.Copy(requested),target=KW.BuildModel.Merge(current,requested),capabilities=KW.Copy(capabilities or {}),extras={}}
  if requested.appearance then
   if not services.appearance then return fail('appearanceUnavailable')end
   plan.appearanceRequest,err=services.appearance:Prepare(current.appearance,requested.appearance)
   if not plan.appearanceRequest then return nil,err end
  end
  if requested.attributes then
   local budget=snapshot.budgets.attributes
   if type(budget)~='number' or not services.attributes or not current.attributes then return fail('attributesUnavailable')end
   local required=requested.attributes.health+requested.attributes.magicka+requested.attributes.stamina
   if required>budget then return fail('insufficientAttributePoints',{required=required,available=budget,deficit=required-budget})end
   plan.attributeRequest,err=services.attributes:Prepare(current.attributes,requested.attributes,budget);if not plan.attributeRequest then return nil,err end
   plan.target.attributes=KW.Copy(plan.attributeRequest.target)
  end
  if requested.equipment then
   if not snapshot.equipmentState then return fail('invalidBuildSnapshot')end
   plan.equipmentPlan,err=KW.EquipmentPlan.Build(snapshot.equipmentState,requested.equipment,'apply',capabilities or {});if not plan.equipmentPlan then return nil,err end
   plan.target.equipment=KW.Copy(plan.equipmentPlan.target)
   for _,extra in ipairs(plan.equipmentPlan.extras)do local copy=KW.Copy(extra);copy.type='equipment';plan.extras[#plan.extras+1]=copy end
  end
  if requested.abilities then
   if not services.skills or not current.abilities or not catalogue or not catalogue.available or type(snapshot.budgets.skills)~='number' or type(snapshot.budgets.mastery)~='table'then return fail('skillsUnavailable')end
   if not snapshot.equipmentState then return fail('invalidBuildSnapshot')end
   local currentCrypt=chestId(snapshot.equipmentState,current.equipment)==194509
   local targetCrypt=chestId(snapshot.equipmentState,plan.target.equipment)==194509
   for _,bar in ipairs({'front','back'})do
    local wanted=requested.abilities.bars and requested.abilities.bars[bar] and requested.abilities.bars[bar][6]
    local before=current.abilities.bars[bar][6];local metadata=catalogue.barMetadata[bar][6]
    if wanted and targetCrypt then return fail('equipmentOverride',{bar=bar,slot=6,reason='targetCryptcanon'})end
    if wanted and encode(wanted)~=encode(before) and (currentCrypt or metadata.override or metadata.runtimeOverride)then return fail('equipmentOverride',{bar=bar,slot=6,reason=currentCrypt and 'removeCryptcanonManually' or 'unknownOverride'})end
   end
   local cat={};for key,value in pairs(catalogue)do cat[key]=value end;cat.budgets={skills=snapshot.budgets.skills,mastery=KW.Copy(snapshot.budgets.mastery)}
   plan.skillRequest,err=services.skills:Prepare(current.abilities,requested.abilities,cat);if not plan.skillRequest then return deficit(err)end
   plan.target.abilities=KW.Copy(plan.skillRequest.target)
   -- Verification facts survive removal of executable requests after confirmation.
   plan.verification={auxiliaryTarget=KW.Copy(plan.skillRequest.auxiliaryTarget)}
   for _,extra in ipairs(extrasFor(plan.skillRequest,requested.abilities,cat,current.abilities))do plan.extras[#plan.extras+1]=extra end
  end
  plan.dependencyKeys={}
  if requested.abilities then plan.dependencyKeys.abilities=encode({actual=current.abilities,budget={skills=snapshot.budgets.skills,mastery=snapshot.budgets.mastery},catalogue=catalogue,equipmentState=snapshot.equipmentState})end
  if requested.attributes then plan.dependencyKeys.attributes=encode({actual=current.attributes,budget=snapshot.budgets.attributes})end
  if requested.equipment then plan.dependencyKeys.equipment=encode(snapshot.equipmentState)end
  plan.extraKey=encode(plan.extras)
  plan.fingerprint=encode({requested=requested,actual=current,budgets=snapshot.budgets,equipmentState=snapshot.equipmentState,catalogue=requested.abilities and catalogue or nil,capabilities=capabilities or {},target=plan.target,extras=plan.extras})
  return plan
 end
 function bound.Revalidate(plan,snapshot,catalogue)
  if not plan or not plan.requested then return fail('invalidBuildSnapshot')end
  return bound.Build(snapshot,plan.requested,catalogue,plan.capabilities)
 end
 -- confirmed is a domain boolean map. Verification uses supplied actual facts;
 -- auxiliary actual refs must be present in the fresh runtime catalogue.
 function bound.RevalidateRemaining(plan,snapshot,catalogue,confirmed)
  local completed=KW.Copy(plan.confirmed or {})
  for domain,done in pairs(confirmed or {})do if done then completed[domain]=true end end
  confirmed=completed;local current=actual(snapshot);if not current then return fail('invalidBuildSnapshot')end
  local remaining=KW.Copy(plan.requested)
  for _,domain in ipairs({'abilities','attributes','equipment','appearance'})do
   local done=confirmed[domain] or (domain=='abilities' and confirmed.skills)
   if done then
    if not KW.BuildModel.Matches(current,{[domain]=plan.target[domain]})then return fail('confirmedBuildMismatch',{domain=domain})end
    if domain=='abilities' then
     for category,slots in pairs(plan.verification and plan.verification.auxiliaryTarget or {})do for slot,ref in pairs(slots)do
      local row=catalogue and catalogue.auxiliaryBars and catalogue.auxiliaryBars[category] and catalogue.auxiliaryBars[category][slot]
      if not row or encode(row.ref)~=encode(ref)then return fail('confirmedBuildMismatch',{domain='auxiliary',category=category,slot=slot})end
     end end
    end
    remaining[domain]=nil
   end
  end
  local fresh,err=bound.Build(snapshot,remaining,catalogue,plan.capabilities);if not fresh then return nil,err end
  for domain,key in pairs(fresh.dependencyKeys)do if key~=plan.dependencyKeys[domain]then return fail('buildDependenciesChanged',{domain=domain})end end
  if not KW.BuildModel.Matches(fresh.target,plan.target)then return fail('buildDependenciesChanged')end
  local allowed={};for _,extra in ipairs(plan.extras)do allowed[encode(extra)]=true end
  for _,extra in ipairs(fresh.extras)do if not allowed[encode(extra)]then return fail('buildDependenciesChanged')end end
  fresh.target=KW.Copy(plan.target);fresh.requested=KW.Copy(plan.requested);fresh.extras=KW.Copy(plan.extras);fresh.extraKey=plan.extraKey;fresh.fingerprint=plan.fingerprint;fresh.dependencyKeys=KW.Copy(plan.dependencyKeys);fresh.verification=KW.Copy(plan.verification);fresh.confirmed=KW.Copy(completed)
  return fresh
 end
 return bound
end
