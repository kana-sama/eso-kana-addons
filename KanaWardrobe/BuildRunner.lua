local KW=KanaWardrobe
local Runner={};KW.BuildRunner=Runner
local Instance={};Instance.__index=Instance
local phases={'skills','attributes','equipment'}
local domains={skills='abilities',attributes='attributes',equipment='equipment'}
local requestKeys={skills='skillRequest',attributes='attributeRequest',equipment='equipmentPlan'}
function Runner.New(skills,attributes,equipment,events,clock,services)
 return setmetatable({skills=skills,attributes=attributes,equipment=equipment,events=events,clock=clock,services=services or {},generation=0},Instance)
end
function Instance:IsBusy()return self.operation~=nil end
function Instance:Capture(scope)
 if type(self.services.capture)~='function'then return nil,KW.Problem('invalidBuildSnapshot')end
 local snapshot,catalogue,problem=self.services.capture(scope or self.operation and self.operation.plan.requested)
 if not snapshot then return nil,problem or catalogue or KW.Problem('invalidBuildSnapshot')end
 return snapshot,catalogue
end
function Instance:Pending(op)
 if op.adapterToken then
  local state=(op.phase=='skills' and self.skills or self.attributes):GetSubmissionState()
  state.sentAt=state.sentAt or op.sentAt
  if op.result~=nil then state.result=op.result end
  return state
 end
 return KW.Copy(op.pending)
end
function Instance:Finish(op,status,problem)
 if self.operation~=op then return end
 local pending=self:Pending(op)
 self.operation=nil
 for timer in pairs(op.timers)do self.clock:Cancel(timer)end
 for _,listener in ipairs(op.listeners)do self.events:Unsubscribe(listener)end
 if op.adapterToken and not op.confirmed[op.phase] and not (pending and pending.resolved)then
  local adapter=op.phase=='skills' and self.skills or self.attributes
  adapter:CancelSubmission()
  pending=self:Pending(op)
 end
 if op.phase=='equipment' and self.equipment and self.equipment:IsBusy()then self.equipment:Stop(problem or 'stopped')end
 if pending and pending.phase=='unknown'then status='paused';problem=problem or pending.problem end
 local ok,actual=pcall(function()return self:Capture(op.plan.requested)end)
 if not ok or not actual then actual=op.actual end
 local result={status=status,phase=op.phase,operationId=op.id,confirmed=KW.Copy(op.confirmed),actual=KW.Copy(actual),problem=problem,
  pending=KW.Copy(pending),equipmentFailure=op.equipmentFailure}
 if status=='applied'then result.pending=nil end
 if op.onDone then op.onDone(result)end
end
function Instance:Run(op,fn)
 local ok,err=pcall(fn)
 if not ok and self.operation==op then
  local pending=self:Pending(op)
  self:Finish(op,pending and pending.sent and 'paused' or 'failed',KW.Problem('buildRunnerError',{error=tostring(err)}))
 end
end
function Instance:Later(op,delay,fn)
 local token
 token=self.clock:Schedule(delay,function()
  op.timers[token]=nil
  if self.operation==op then self:Run(op,fn)end
 end)
 op.timers[token]=true;return token
end
function Instance:QueueCheck(op)
 if self.operation~=op or op.checkTimer then return end
 op.checkTimer=self:Later(op,1,function()op.checkTimer=nil;self:Check(op)end)
end
function Instance:Progress(op,stage,pending)
 if self.operation~=op then return false end
 if op.onProgress then
  local completed,total=0,0
  for phase,units in pairs(op.progressUnits)do
   total=total+units
   if op.confirmed[phase]then completed=completed+units
   elseif phase=='equipment' and op.equipmentProgress and op.equipmentProgress.total>0 then
    completed=completed+units*math.min(1,op.equipmentProgress.completed/op.equipmentProgress.total)
   end
  end
  local partial=not op.confirmed[op.phase] and (op.castProgress or 0)*(op.progressUnits[op.phase]or 0)or 0
  local ratio=total>0 and math.min(1,(completed+partial)/total)or 0
  local ok,err=pcall(op.onProgress,{operationId=op.id,phase=op.phase,stage=stage,completed=completed,total=total,ratio=ratio,
   confirmed=KW.Copy(op.confirmed),actual=KW.Copy(op.actual),pending=KW.Copy(pending),fingerprint=op.plan.fingerprint,equipmentProgress=KW.Copy(op.equipmentProgress)})
  if self.operation~=op then return false end
  if not ok then self:Finish(op,'failed',KW.Problem('progressObserverError',{phase=op.phase,stage=stage,error=tostring(err)}));return false end
 end
 return self.operation==op
end
function Instance:Revalidate(op)
 local snapshot,catalogue=self:Capture()
 if not snapshot then return nil,catalogue end
 op.actual=snapshot
 if type(self.services.revalidateRemaining)~='function'then return nil,KW.Problem('invalidBuildSnapshot')end
 local plan,problem=self.services.revalidateRemaining(op.plan,snapshot,catalogue,op.confirmed)
 if not plan then return nil,problem end
 op.plan=plan;return plan
end
function Instance:ConfirmedMatch(op,snapshot,catalogue)
 for phase in pairs(op.confirmed)do
  local domain=domains[phase]
  if domain and not KW.BuildModel.Matches(snapshot,{[domain]=op.plan.target[domain]})then return false end
 end
 if op.confirmed.skills then
  for category,slots in pairs(op.plan.verification and op.plan.verification.auxiliaryTarget or {})do
   for slot,ref in pairs(slots)do
    local row=catalogue and catalogue.auxiliaryBars and catalogue.auxiliaryBars[category] and catalogue.auxiliaryBars[category][slot]
    if not row or not KW.BuildModel.Matches({abilities={bars={front={[1]=row.ref}}}},{abilities={bars={front={[1]=ref}}}})then return false end
   end
  end
 end
 return true
end
function Instance:Confirmed(op)
 if self.operation~=op then return end
 if op.deadlineTimer then self.clock:Cancel(op.deadlineTimer);op.timers[op.deadlineTimer]=nil;op.deadlineTimer=nil end
 op.confirmed[op.phase]=true;op.adapterToken=nil;op.pending=nil;op.result=nil;op.sentAt=nil
 op.cooldownStarted=nil
 local snapshot,problem=self:Capture()
 if not snapshot then self:Finish(op,'paused',problem);return end
 op.actual=snapshot
 if not self:Progress(op,'confirmed')then return end
 op.index=op.index+1;self:Advance(op)
end
function Instance:WaitForCooldown(op,adapter,result)
 local code=adapter.api[op.phase=='skills' and 'RESPEC_RESULT_ON_COOLDOWN_SKILLS' or 'RESPEC_RESULT_ON_COOLDOWN_ATTRIBUTES']
 if code==nil or result~=code then return false end
 -- ESO exposes the refusal, but no respec-cooldown timer. Retry only a
 -- definitively rejected request, at a bounded rate, and revalidate before it.
 op.cooldownStarted=op.cooldownStarted or self.clock:NowMs()
 if self.clock:NowMs()-op.cooldownStarted>=60000 then return false end
 if op.deadlineTimer then self.clock:Cancel(op.deadlineTimer);op.timers[op.deadlineTimer]=nil;op.deadlineTimer=nil end
 op.pending=adapter:GetSubmissionState()
 op.adapterToken=nil;op.result=nil;op.sentAt=nil
 op.castDuration=nil;op.castProgress=nil;op.castPercent=nil
 if self:Progress(op,'cooldown',op.pending)then
  self:Later(op,5000,function()self:Advance(op)end)
 end
 return true
end
function Instance:Advance(op)
 if self.operation~=op then return end
 -- Skipped domains have no dependencies to refresh.
 while phases[op.index] and not op.plan[requestKeys[phases[op.index]]]do op.index=op.index+1 end
 local plan,problem=self:Revalidate(op)
 if not plan then self:Finish(op,'paused',problem);return end
 op.phase=phases[op.index]
 op.castDuration=nil;op.castProgress=nil;op.castPercent=nil
 if not op.phase then op.phase='complete';self:Finish(op,'applied');return end
 local request=plan[requestKeys[op.phase]]
 if not request then op.index=op.index+1;self:Advance(op);return end
 local unchanged
 if op.phase=='skills'then unchanged=#request.skillChanges==0 and #request.barChanges==0 and #(request.auxiliaryChanges or {})==0
 elseif op.phase=='attributes'then unchanged=self.attributes:Matches(request.target)
 else unchanged=#request.steps==0 end
 if unchanged then self:Confirmed(op);return end
 local original=op.actual[domains[op.phase]]
 op.pending={phase=op.phase,sent=false,original=KW.Copy(original),target=KW.Copy(request.target),auxiliaryOriginal=KW.Copy(request.auxiliaryOriginal),auxiliaryTarget=KW.Copy(request.auxiliaryTarget)}
 if not self:Progress(op,'requesting',op.pending)then return end
 -- Journal observers can stop, throw, or edit live facts. Rebuild before dispatch.
 plan,problem=self:Revalidate(op)
 if not plan then self:Finish(op,'paused',problem);return end
 request=plan[requestKeys[op.phase]]
 op.request=KW.Copy(request)
 if op.phase=='equipment'then
  local phaseToken=op.index
  local equipmentStartedAt=self.clock:NowMs()
  local accepted,err=self.equipment:Start(request,function(progress)
   if self.operation~=op or op.index~=phaseToken then return end
   op.pending=KW.Copy(progress.pending)
   op.equipmentProgress={completed=progress.completed or 0,total=progress.total or 0}
   local gearOnly=not op.plan.requested.abilities and not op.plan.requested.attributes
   local function progressCapture()
    if gearOnly then return {equipment=self.equipment.inventory:Capture(false).worn}end
    return self:Capture()
   end
   local snapshot,catalogue=progressCapture();assert(snapshot,'equipment progress capture unavailable')
   op.actual=snapshot
   if not self:Progress(op,progress.phase,op.pending)then return end
   snapshot,catalogue=progressCapture();assert(snapshot,'equipment progress capture unavailable')
   if not self:ConfirmedMatch(op,snapshot,catalogue)then self:Finish(op,'paused',KW.Problem('confirmedBuildMismatch'));return end
  end,function(result)
   if self.operation~=op or op.index~=phaseToken then return end
   op.pending=KW.Copy(result.pending)
   if result.status=='success'then self:Run(op,function()self:Confirmed(op)end)
   else
    result.confirmed=KW.Copy(op.confirmed)
    op.equipmentFailure={plan=KW.Copy(request),result=result,startedAt=equipmentStartedAt}
    self:Finish(op,result.status=='failed' and 'failed' or 'paused',result.problem)
   end
  end)
  if self.operation~=op or op.index~=phaseToken then return end
  if not accepted then self:Finish(op,'failed',err)end
  return
 end
 local adapter=op.phase=='skills' and self.skills or self.attributes
 local before=self.clock:NowMs();op.issuing=true
 local accepted,err=adapter:Submit(request)
 op.issuing=false
 if self.operation~=op then return end
 local state=adapter:GetSubmissionState();op.adapterToken=state.token
 if op.phase=='attributes' and state.sent then op.sentAt=before end
 if not accepted then self:Finish(op,state.sent and 'paused' or 'failed',err);return end
 op.pending=state
 state.sentAt=state.sentAt or op.sentAt
 if not self:Progress(op,state.sent and 'waiting' or 'entry',state)then return end
 self:QueueCheck(op)
end
function Instance:Check(op)
 if self.operation~=op or op.issuing or not op.adapterToken then return end
 local adapter=op.phase=='skills' and self.skills or self.attributes
 local state=adapter:GetSubmissionState()
 if state.token~=op.adapterToken then self:Finish(op,'paused',KW.Problem('buildStateChanged'));return end
 op.pending=state
 if state.phase=='failed' or state.phase=='cancelled' or state.phase=='unknown'then
  self:Finish(op,(state.sent or state.phase=='unknown') and 'paused' or 'failed',state.problem or KW.Problem('skillSubmissionUncertain'));return
 end
 if not state.sent then return end
 -- Native remaining cast time gives a useful visual estimate, but only the
 -- result + actual-state verification below can complete this operation.
 local cast=adapter.api[op.phase=='skills' and 'GetSkillRespecCastTimeRemainingMs' or 'GetAttributeRespecCastTimeRemainingMs']
 local remaining=type(cast)=='function' and cast()or 0
 if type(remaining)=='number' and (remaining>0 or op.castDuration)then
  op.castDuration=math.max(op.castDuration or 0,remaining)
  op.castProgress=math.max(op.castProgress or 0,.9*(1-math.max(0,remaining)/op.castDuration))
  local percent=math.floor(op.castProgress*100)
  if percent~=op.castPercent then
   op.castPercent=percent
   if not self:Progress(op,'waiting',state)then return end
  end
 end
 op.sentAt=op.sentAt or state.sentAt or self.clock:NowMs()
 if not op.deadlineTimer then
  op.deadlineTimer=self:Later(op,math.max(0,op.sentAt+15000-self.clock:NowMs()),function()
   op.deadlineTimer=nil;self:Check(op)
  end)
 end
 local result=op.phase=='skills' and state.result or op.result
 if result~=nil then
  local success=result==adapter.api.RESPEC_RESULT_SUCCESS
  local expected=success and state.target or state.original
  local descriptor={auxiliaryTarget=success and state.auxiliaryTarget or state.auxiliaryOriginal}
  local matches=op.phase=='skills' and adapter:Matches(expected,descriptor) or op.phase=='attributes' and adapter:Matches(expected)
  if matches and type(cast)=='function' and cast()==0 then
   local resolved=adapter:ResolveSubmission(result,op.adapterToken)
   if self.operation~=op then return end
   if resolved then
    if success then self:Confirmed(op)
    elseif not self:WaitForCooldown(op,adapter,result)then self:Finish(op,'failed',KW.Problem('nativeRespecRefused',{domain=op.phase,result=result}))end
    return
   end
  end
 end
 if self.clock:NowMs()-op.sentAt>=15000 then self:Finish(op,'paused',KW.Problem('buildRequestTimeout',{domain=op.phase}));return end
end
function Instance:Start(plan,onProgress,onDone)
 if self.operation then return nil,KW.Problem('busy')end
 if self.equipment and self.equipment:IsBusy()then return nil,KW.Problem('busy')end
 for _,adapter in pairs({self.skills,self.attributes})do
  local state=adapter:GetSubmissionState()
  if state.phase=='entry' or state.phase=='dispatching' or state.phase=='waiting' or state.phase=='unknown' or
   adapter==self.skills and state.sent and not state.resolved then return nil,KW.Problem('buildSubmissionUnresolved')end
 end
 if type(plan)~='table' or type(plan.target)~='table' or type(plan.requested)~='table'then return nil,KW.Problem('invalidBuildSnapshot')end
 self.generation=self.generation+1
 local confirmed=KW.Copy(plan.confirmed or {});if confirmed.abilities then confirmed.skills=true;confirmed.abilities=nil end
 -- Count work once so changing phases cannot reset the bar or report gear as
 -- the entire build. Already-matching domains contribute no phantom steps.
 local units={}
 local skills=plan.skillRequest
 if skills and (#skills.skillChanges>0 or #skills.barChanges>0 or #(skills.auxiliaryChanges or {})>0)then units.skills=1 end
 local attributes=plan.attributeRequest
 if attributes and not KW.BuildModel.Matches({attributes=attributes.original},{attributes=attributes.target})then units.attributes=1 end
 if plan.equipmentPlan and #plan.equipmentPlan.steps>0 then units.equipment=#plan.equipmentPlan.steps end
 local op={id=self.generation,index=1,plan=KW.Copy(plan),confirmed=confirmed,progressUnits=units,timers={},listeners={},onProgress=onProgress,onDone=onDone}
 self.operation=op
 for _,name in ipairs({'SkillSubmissionChanged','NativeSkillRespecResult','NativeAttributeRespecResult'})do
  local event=name
  op.listeners[#op.listeners+1]=self.events:Subscribe(event,function(payload)
   if self.operation~=op then return end
   if event=='SkillSubmissionChanged' and op.phase=='skills' and payload.phase=='dispatching' and
    (op.issuing or payload.token==op.adapterToken)then
    op.adapterToken=payload.token;op.pending=KW.Copy(payload)
    if not self:Progress(op,'dispatching',payload)then return end
    local plan,problem=self:Revalidate(op)
    if not plan then self:Finish(op,'paused',problem);return end
   end
   if event=='SkillSubmissionChanged' and op.phase=='skills' and payload.phase=='waiting' and
    payload.sent and payload.token==op.adapterToken and not op.issuing then
    op.sentAt=payload.sentAt
    if not self:Progress(op,'waiting',payload)then return end
   end
   if event=='NativeAttributeRespecResult' and op.phase=='attributes'then
    local state=self.attributes:GetSubmissionState()
    if state.sent and (op.issuing or state.token==op.adapterToken)then op.result=payload.result end
   end
   self:QueueCheck(op)
  end)
 end
 local function poll()
  self:Check(op)
  if self.operation==op then self:Later(op,100,poll)end
 end
 self:Later(op,100,poll)
 self:Run(op,function()self:Advance(op)end)
 return true
end
function Instance:Stop(reason)
 local op=self.operation;if not op then return end
 self:Finish(op,'paused',type(reason)=='table' and reason or KW.Problem(reason or 'stopped'))
end
return Runner
