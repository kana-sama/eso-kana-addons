local KW=KanaWardrobe
local S={};KW.OperationSteps=S
local I={};I.__index=I
function S.New(inventory,skills,attributes,events,clock,services)
 local self=setmetatable({inventory=inventory,skills=skills,attributes=attributes,events=events,clock=clock,services=services or {}},I)
 events:Subscribe('NativeAttributeRespecResult',function(payload)
  local state=attributes:GetSubmissionState()
  if state.sent and not state.resolved then self.attributeResult={token=state.token,result=payload.result}end
 end)
 return self
end
function I:Readiness()
 local api=self.inventory.api
 if api.IsUnitInCombat and api.IsUnitInCombat('player')then return KW.Problem('inCombat')end
 if api.IsUnitDeadOrReincarnating and api.IsUnitDeadOrReincarnating('player')then return KW.Problem('dead')end
 if api.IsBlockActive and api.IsBlockActive()then return KW.Problem('blocking')end
end
function I:Wait(names,timeout,check,done)
 local active=true;local handles={};local timer;local deadline=self.clock:NowMs()+timeout
 local function finish(result,problem)
  if not active then return end;active=false
  if timer then self.clock:Cancel(timer)end
  for _,h in ipairs(handles)do self.events:Unsubscribe(h)end
  done(result,problem)
 end
 local function poll()
  if not active then return end
  if timer then self.clock:Cancel(timer);timer=nil end
  local ok,result,problem=xpcall(function()return check(self.clock:NowMs()>=deadline)end,KW.OperationJournal.ErrorDetails)
  if not ok then finish(nil,KW.Problem('operationError',result))
  elseif result or problem then finish(result,problem)
  elseif active then timer=self.clock:Schedule(100,poll)end
 end
 local function queue()
  if not active then return end
  if timer then self.clock:Cancel(timer)end;timer=self.clock:Schedule(1,poll)
 end
 for _,name in ipairs(names)do handles[#handles+1]=self.events:Subscribe(name,queue)end
 timer=self.clock:Schedule(1,poll)
 return finish
end
local function sameRef(a,b)return a and b and a.kind==b.kind and (a.kind=='empty' or a.uid==b.uid)end
function I:GearBatch(step,op,report,done)
 local state=self.inventory:Capture('equipment')
 local receipts=KW.Copy(step.pending and step.pending.receipts or {})
 local pending={domain='equipment',receipts=receipts,maySent=false}
 local function reached(item,actual)
  local effects=item.effects or {[item.equipSlot]=item.target}
  for slot,value in pairs(effects)do if not sameRef(actual.worn[slot],value)then return false end end
  local source=receipts[item.uid]
  if source then
   local old=self.inventory:ReadSlot(source.bagId,source.slotIndex)
   if old and old.uid==item.uid then return false end
  end
  if item.kind=='unequip'then
   local location=actual.byUid[item.uid]
   if not location or location.bagId~=self.inventory.api.BAG_BACKPACK then return false end
  end
  for _,before in pairs(item.beforeEffects or {[item.equipSlot]=item.before})do
   if before.kind=='item' and before.uid~=item.uid then
    local location=actual.byUid[before.uid];local destination
    for slot,value in pairs(step.target)do if value.kind=='item' and value.uid==before.uid then destination=slot;break end end
    if not location or destination and (location.bagId~=BAG_WORN or location.slotIndex~=destination)
     or not destination and location.bagId~=BAG_BACKPACK then return false end
   end
  end
  return true
 end
 local function missing(actual)
  local items={}
  for _,item in ipairs(step.items)do if not reached(item,actual)then
   items[#items+1]={uid=item.uid,equipSlot=item.equipSlot,kind=item.kind,link=item.details.link,
    actual=KW.Copy(actual.worn[item.equipSlot]),source=KW.Copy(actual.byUid[item.uid])}
  end end
  return items
 end
 local function waitForRelease()
  self:Wait({'InventoryChanged'},5000,function(expired)
   local actual=self.inventory:Capture(false);local items=missing(actual)
   if #items==0 then return {actual=actual.worn}end
   if expired then return nil,KW.Problem('requestTimeout',{items=items})end
  end,done)
 end
 if #missing(state)==0 then done({actual=state.worn,already=true});return end
 for slot,before in pairs(step.before)do
  local actual=state.worn[slot]
  if not sameRef(actual,before)and not sameRef(actual,step.target[slot])then
   done(nil,KW.Problem('operationDependenciesChanged',{slot=slot,expected=before,actual=actual}));return
  end
 end
 -- Retry builds a fresh diff for this group's effects. Already confirmed
 -- members disappear, including the implicit half of a worn ring exchange.
 local plan,problem=KW.EquipmentPlan.Build(state,step.target,'apply',op.intent.capabilities or {})
 if not plan then done(nil,problem);return end
 if #plan.steps==0 then waitForRelease();return end
 for slot,value in pairs(plan.target)do
  if step.target[slot]==nil and not sameRef(value,state.worn[slot])then
   done(nil,KW.Problem('operationDependenciesChanged',{slot=slot,expected=state.worn[slot],actual=value}));return
  end
 end
 local runner=KW.EquipmentRunner.New(self.inventory,self.events,self.clock)
 local function checkpoint(batch)
  if batch then
   pending.batch=KW.Copy(batch);pending.maySent=true
   for _,item in ipairs(batch.batch or {})do if item.source then receipts[item.uid]=KW.Copy(item.source)end end
  end
  report(pending)
 end
 local id,err=runner:Start(plan,function(progress)checkpoint(progress.pending)end,function(result)
  checkpoint(result.pending)
  if result.status~='success'then done(nil,result.problem)
  elseif #missing(self.inventory:Capture(false))==0 then done({actual=result.actual})
  else waitForRelease()end
 end)
 if not id then done(nil,err)end
end
function I:Gear(step,op,report,done)
 -- Newly planned single-item steps use the same acknowledgement, explicit
 -- destination and native-error handling as batches. Persisted older steps
 -- without effects retain their original adapter for compatibility.
 if step.effects then
  local group={items={step},before=step.beforeEffects,target=step.effects,pending=step.pending}
  return self:GearBatch(group,op,function(pending)
   pending.kind=step.kind;pending.uid=step.uid;pending.equipSlot=step.equipSlot
   pending.source=pending.batch and KW.Copy(pending.batch.source) or step.pending and KW.Copy(step.pending.source)
   report(pending)
  end,done)
 end
 local state=self.inventory:Capture('equipment');local current=state.worn[step.equipSlot]
 local function reached(actual)
  if not sameRef(actual.worn[step.equipSlot],step.target)then return false end
  if step.kind=='unequip'then
   local location=actual.byUid[step.uid];return location and location.bagId==BAG_BACKPACK
  end
  local source=step.pending and step.pending.source
  if source then local item=self.inventory:ReadSlot(source.bagId,source.slotIndex);if item and item.uid==step.uid then return false end end
  if step.before and step.before.kind=='item' and step.before.uid~=step.uid then
   local displaced=actual.byUid[step.before.uid]
   if not displaced or displaced.bagId~=BAG_BACKPACK then return false end
  end
  return true
 end
 if reached(state)then done({actual=state.worn,already=true});return end
 if not sameRef(current,step.before)then done(nil,KW.Problem('operationDependenciesChanged',{slot=step.equipSlot,expected=step.before,actual=current}));return end
 local plan,err=KW.EquipmentPlan.Build(state,{[step.equipSlot]=step.target},'apply',op.intent.capabilities or {})
 if not plan then done(nil,err);return end
 if #plan.steps~=1 or plan.steps[1].kind~=step.kind or plan.steps[1].uid~=step.uid then
  done(nil,KW.Problem('operationDependenciesChanged',{slot=step.equipSlot,requiredSteps=plan.steps}));return
 end
 local pending={domain='equipment',kind=step.kind,uid=step.uid,equipSlot=step.equipSlot,before=KW.Copy(current),target=KW.Copy(step.target),
  source=KW.Copy(state.byUid[step.uid]),sentAt=self.clock:NowMs(),maySent=true}
 report(pending)
 local accepted,problem=self.inventory:Request(step)
 if not accepted then pending.maySent=false;report(pending);done(nil,problem);return end
 pending.sent=true;report(pending)
 self:Wait({'InventoryChanged'},5000,function(expired)
  local actual=self.inventory:Capture(false)
  if reached(actual)then return {actual=actual.worn}end
  if expired then
   pending.actual=actual.worn;pending.locations={requested=actual.byUid[step.uid]};report(pending)
   return nil,KW.Problem('operationUnconfirmed',{domain='equipment',slot=step.equipSlot,uid=step.uid,expected=step.target,actual=actual.worn[step.equipSlot],elapsed=5000})
  end
 end,done)
end
function I:Appearance(step,op,report,done)
 local adapter=self.services.appearance
 if not adapter then done(nil,KW.Problem('appearanceUnavailable'));return end
 local pending={domain='appearance',category=step.category,expected=step.target,refusals={}}
 local api=adapter.api;local retryCount=0;local cooldownDeadline;local shownSeconds
 local unsubscribe=self.events:Subscribe('AppearanceUseResult',function(payload)
  -- This flag is used by ESO for the success sound, not to correlate errors
  -- with requests. Filtering failures by it discards cooldown refusals.
  if pending.sent then
   pending.result=payload.result
   pending.lastResponse={result=payload.result,isAttemptingActivation=payload.isAttemptingActivation,receivedAt=self.clock:NowMs()}
   report(pending)
  end
 end)
 local function finish(result,err)self.events:Unsubscribe(unsubscribe);done(result,err)end
 local function showCountdown(now)
  pending.remainingMs=math.max(0,pending.retryAt-now)
  local seconds=math.ceil(pending.remainingMs/1000)
  if seconds~=shownSeconds then shownSeconds=seconds;report(pending)end
 end
 local function cooldown(remaining)
  local now=self.clock:NowMs();remaining=remaining or 0
  cooldownDeadline=cooldownDeadline or now+(remaining>0 and remaining+5000 or 30000)
  pending.phase='cooldown';pending.sent=false;pending.countdownKind=remaining>0 and 'cooldown' or 'retry'
  -- A server refusal may have no local cooldown timer. Back off between
  -- retries; this countdown is time to the next attempt, not a guessed cooldown.
  local delay=remaining>0 and remaining or math.min(4000,1000*2^math.min(retryCount,2))
  pending.retryAt=now+delay;pending.cooldownDeadline=cooldownDeadline;shownSeconds=nil;showCountdown(now)
  if now>=cooldownDeadline then return nil,KW.Problem('appearanceCooldownTimeout',KW.Copy(pending))end
 end
 local function unconfirmed(actual)
  report(pending)
  local details=KW.Copy(step.details or {})
  details.expected=step.target;details.actual=actual[step.category];details.result=pending.result
  details.actualName=adapter:Describe(step.category,details.actual).name
  if pending.result and api.GetString then details.reasonText=api.GetString('SI_COLLECTIBLEUSAGEBLOCKREASON',pending.result)end
  return nil,KW.Problem('appearanceUnconfirmed',details)
 end
 local function confirm(actual)
  pending.actual=actual[step.category]
  if pending.actual==step.target then return {actual=actual}end
  if api.COLLECTIBLE_USAGE_BLOCK_REASON_ON_COOLDOWN~=nil and pending.result==api.COLLECTIBLE_USAGE_BLOCK_REASON_ON_COOLDOWN then
   pending.refusals[#pending.refusals+1]={result=pending.result,sentAt=pending.sentAt,response=KW.Copy(pending.lastResponse),useId=pending.useId}
   local remaining=api.GetCollectibleCooldownAndDuration and api.GetCollectibleCooldownAndDuration(pending.useId) or 0
   local result,problem=cooldown(remaining);retryCount=retryCount+1
   return result,problem
  end
  if self.clock:NowMs()-pending.sentAt>=5000 then return unconfirmed(actual)end
 end
 self:Wait({'AppearanceChanged','AppearanceUseResult'},60000,function(expired)
  local actual,err=adapter:Capture();if not actual then return nil,err end
  pending.actual=actual[step.category]
  -- Check again before every retry: UseCollectible is a toggle.
  if pending.actual==step.target then return {actual=actual}end
  if pending.sent then return confirm(actual)end
  if op.pauseRequested then return {paused=true}end
  if expired then return nil,KW.Problem('appearanceCooldownTimeout',KW.Copy(pending))end
  local now=self.clock:NowMs()
  if pending.retryAt and now<pending.retryAt then showCountdown(now);return end
  local blocked=self:Readiness();if blocked then return nil,blocked end
  pending.phase='waiting';pending.sent=true;pending.sentAt=now;pending.result=nil;pending.lastResponse=nil
  pending.useId=step.target==0 and pending.actual or step.target
  pending.remainingMs=nil;pending.countdownKind=nil;pending.retryAt=nil
  local ok,problem=adapter:Request(step.category,step.target)
  if not ok then
   pending.sent=false
   if problem.code=='appearanceCooldown'then return cooldown(problem.details and problem.details.remainingMs)end
   report(pending);return nil,problem
  end
  report(pending)
  actual,err=adapter:Capture();if not actual then return nil,err end
  return confirm(actual)
 end,finish)
end
function I:Result(domain,state)
 if domain=='skills'then return state.result end
 local result=self.attributeResult
 return result and result.token==state.token and result.result or state.result
end
-- Explicit Continue/Start over permits local reconciliation, never a duplicate
-- send while the native cast is still active. Unknown is not a server refusal.
function I:Reconcile(domain,descriptor)
 local adapter=self[domain];local state=adapter:GetSubmissionState()
 if state.resolved then return true end
 local own=state.token and (state.sent or state.phase=='entry' or state.phase=='dispatching' or state.phase=='unknown')
 descriptor=own and state or descriptor
 if not descriptor or not descriptor.original or not descriptor.target then return true end
 local api=adapter.api
 for _,name in ipairs({'GetSkillRespecCastTimeRemainingMs','GetAttributeRespecCastTimeRemainingMs'})do
  if api[name] and api[name]()>0 then return nil,KW.Problem('operationUnconfirmed',{domain=domain,castRemaining=api[name]()})end
 end
 if own and not state.sent then
  local cleaned,problem=adapter:CancelSubmission();if not cleaned then return nil,problem end
  return true
 end
 local result=self:Result(domain,state)
 if own and result~=nil then
  local resolved=adapter:ResolveSubmission(result,state.token)
  if resolved then return true end
 end
 local facts,problem=adapter:GetRecoveryFacts(descriptor);if not facts then return nil,problem end
 local resolved;resolved,problem=adapter:ReconcileSubmission(descriptor,'acceptCurrent',facts)
 return resolved~=nil,problem
end
function I:Native(step,op,report,done)
 local domain=step.kind=='attributes' and 'attributes' or 'skills'
 local adapter=self[domain]
 local previous=step.pending and step.pending.descriptor
 local clean,problem=self:Reconcile(domain,previous)
 if not clean then done(nil,problem);return end
 local scope=domain=='skills' and 'abilities' or 'attributes'
 local target=step.kind=='bar' and {bars={[step.bar]=step.target}}or step.target
 local snapshot,catalogue,issue=self.services.capture(scope)
 if not snapshot then done(nil,issue or catalogue);return end
 if KW.BuildModel.Matches(snapshot,{[scope]=target})then done({actual=snapshot[scope],already=true});return end
 local request
 if domain=='skills'then request,problem=adapter:Prepare(snapshot.abilities,target,catalogue)
 else request,problem=adapter:Prepare(snapshot.attributes,target,snapshot.budgets.attributes)end
 if not request then done(nil,problem);return end
 local stateBefore=adapter:GetSubmissionState()
 local descriptor={original=KW.Copy(snapshot[scope]),target=KW.Copy(request.target),auxiliaryOriginal=KW.Copy(request.auxiliaryOriginal),
  auxiliaryTarget=KW.Copy(request.auxiliaryTarget),phase='dispatching',sent=false}
 local pending={domain=domain,descriptor=descriptor,maySent=true,sentAt=self.clock:NowMs()}
 report(pending)
 local issuing=true
 local progressHandle
 if domain=='skills'then progressHandle=self.events:Subscribe('SkillSubmissionChanged',function(state)
  if state.token~=stateBefore.token then pending.descriptor=KW.Copy(state);report(pending)end
 end)
 else progressHandle=self.events:Subscribe('NativeAttributeRespecResult',function(payload)
  local state=adapter:GetSubmissionState()
  if state.token~=stateBefore.token and state.sent and not state.resolved then
   state.result=payload.result;pending.descriptor=state;report(pending)
  end
 end)end
 local accepted,err=adapter:Submit(request);issuing=false
 local state=adapter:GetSubmissionState();local token=state.token
 pending.descriptor=state;pending.maySent=state.sent==true or state.phase=='dispatching';report(pending)
 local function complete(result,problem)
  if progressHandle then self.events:Unsubscribe(progressHandle);progressHandle=nil end
  done(result,problem)
 end
 if not accepted then complete(nil,err);return end
 self:Wait({'SkillSubmissionChanged','NativeSkillRespecResult','NativeAttributeRespecResult'},20000,function(expired)
  if issuing then return end
  local now=adapter:GetSubmissionState()
  if now.token~=token then return nil,KW.Problem('operationDependenciesChanged',{domain=domain,token=token,actualToken=now.token})end
  pending.descriptor=now;pending.descriptor.result=self:Result(domain,now)
  local cast=adapter.api[domain=='skills' and 'GetSkillRespecCastTimeRemainingMs' or 'GetAttributeRespecCastTimeRemainingMs']
  pending.castRemaining=cast and cast() or 0
  local result=pending.descriptor.result
  if now.resolved and not now.sent then report(pending);return nil,now.problem or KW.Problem('operationError',{domain=domain,phase=now.phase})end
  if result~=nil and pending.castRemaining==0 then
   local resolved,resolveProblem=adapter:ResolveSubmission(result,token)
   pending.descriptor=adapter:GetSubmissionState();pending.descriptor.result=result
   if resolved then
    report(pending)
    if result~=adapter.api.RESPEC_RESULT_SUCCESS then return nil,KW.Problem('nativeRespecRefused',{domain=domain,result=result,actual=pending.descriptor.original})end
    return {actual=pending.descriptor.target,result=result}
   end
   pending.verificationProblem=resolveProblem
  end
  -- Avoid copying the entire talent snapshot every animation frame.
  local stamp=tostring(now.phase)..':'..tostring(result)..':'..math.floor((pending.castRemaining or 0)/250)
  if pending.stamp~=stamp or expired then pending.stamp=stamp;report(pending)end
  if expired then
   local facts=adapter:GetRecoveryFacts(now);pending.actual=facts and facts.actual;report(pending)
   return nil,KW.Problem('operationUnconfirmed',{domain=domain,result=result,expected=target,actual=pending.actual,phase=now.phase,castRemaining=pending.castRemaining,reason=pending.verificationProblem})
  end
 end,complete)
end
function I:Verify(step,done)
 local snapshot,catalogue,problem=self.services.capture(step.target)
 if not snapshot then done(nil,problem or catalogue);return end
 local differences=KW.BuildModel.Differences(snapshot,step.target)
 for category,slots in pairs(step.auxiliaryTarget or {})do for slot,ref in pairs(slots)do
  local row=catalogue and catalogue.auxiliaryBars and catalogue.auxiliaryBars[category]and catalogue.auxiliaryBars[category][slot]
  if not row or not KW.BuildModel.Matches({abilities={bars={front={[1]=row.ref}}}},{abilities={bars={front={[1]=ref}}}})then
   differences[#differences+1]={domain='bars',category=category,slot=slot,expected=KW.Copy(ref),actual=row and KW.Copy(row.ref)}
  end
 end end
 if #differences>0 then
  -- Resolve names once from this capture, never by rescanning in the UI.
  local api=self.inventory.api
  local function itemName(ref)
   if not ref or ref.kind~='item'then return end
   if api.GetItemLinkName then
    local ok,name=pcall(api.GetItemLinkName,ref.link)
    if ok and type(name)=='string' and name~=''then return name end
   end
   return ref.link
  end
  for _,row in ipairs(differences)do
   if row.domain=='skills' then
    row.expectedName=KW.OperationPlan.SkillName(catalogue,row.key,row.expected)
    row.actualName=KW.OperationPlan.SkillName(catalogue,row.key,row.actual)
    row.name=row.expectedName or row.actualName
   elseif row.domain=='bars'then
    row.expectedName=KW.OperationPlan.SkillName(catalogue,row.expected and row.expected.skillKey,row.expected)
    row.actualName=KW.OperationPlan.SkillName(catalogue,row.actual and row.actual.skillKey,row.actual)
    if row.category and row.category==api.HOTBAR_CATEGORY_WEREWOLF then row.specialBar='werewolf'end
   elseif row.domain=='appearance' and self.services.appearance then
    local adapter=self.services.appearance
    row.name=adapter:Describe(row.field,row.expected).categoryName
    row.expectedName=adapter:Describe(row.field,row.expected).name;row.actualName=adapter:Describe(row.field,row.actual).name
   elseif row.domain=='equipment'then
    row.expectedName=itemName(row.expected);row.actualName=itemName(row.actual)
   end
  end
  done(nil,KW.Problem('operationMismatch',{differences=differences,expected=step.target,actual=KW.BuildModel.Normalize(snapshot),auxiliaryExpected=KW.Copy(step.auxiliaryTarget)}));return
 end
 done({actual=KW.BuildModel.Normalize(snapshot)})
end
function I:Run(step,op,report,done)
 if step.kind=='diff' or step.kind=='save' or step.kind=='mountDraft' or step.kind=='closeDraft' or step.kind=='openEditor' or step.kind=='finishEditor'then
  return self.services.localStep(step,op,report,done)
 end
 if step.kind=='verify'then return self:Verify(step,done)end
 local blocked=self:Readiness();if blocked then done(nil,blocked);return end
 if step.kind=='equip' or step.kind=='unequip'then return self:Gear(step,op,report,done)end
 if step.kind=='appearance'then return self:Appearance(step,op,report,done)end
 if step.kind=='equipBatch'then return self:GearBatch(step,op,report,done)end
 if step.kind=='attributes' or step.kind=='skills' or step.kind=='bar'then return self:Native(step,op,report,done)end
 done(nil,KW.Problem('invalidStep',{kind=step.kind}))
end
