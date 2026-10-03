local KW=KanaWardrobe
local J=KW.OperationJournal
local X={};KW.OperationExecutor=X
local I={};I.__index=I
function X.New(saved,clock,handlers,onChanged,onComplete,onFailure)
 return setmetatable({saved=saved,clock=clock,handlers=handlers,onChanged=onChanged,onComplete=onComplete,onFailure=onFailure,
  operation=J.Load(saved),generation=0},I)
end
function I:IsBusy()
 local op=self.operation;return op~=nil and (op.status=='running' or op.status=='pausing')
end
function I:GetView()
 local op=self.operation;if not op then return end
 local view={id=op.id,status=op.status,visible=op.visible,index=op.index,name=op.intent.name,kind=op.intent.kind,steps={},pauseRequested=op.pauseRequested}
 for i,s in ipairs(op.steps)do
  view.steps[i]={id=s.id,kind=s.kind,status=s.status,title=s.title,details=KW.Copy(s.details),problem=KW.Copy(s.problem),
   attempt=#(s.attempts or {}),pending=KW.Copy(s.pending)}
 end
 return view
end
function I:Publish()
 self.saved.operation=self.operation and J.Plain(self.operation) or nil
 if self.onChanged then
  local ok,err=pcall(self.onChanged,self:GetView())
  if not ok then self.saved.operationObserverError=tostring(err)end
 end
end
function I:SetVisible(visible)
 if self.operation then self.operation.visible=visible==true;self:Publish()end
end
function I:Start(intent)
 if self:IsBusy()then self:SetVisible(true);return nil,KW.Problem('operationBusy')end
 if self.operation then
  intent=J.Plain(intent);intent.previous=intent.previous or {}
  for _,s in ipairs(self.operation.steps)do
   if s.pending and s.pending.domain and s.pending.descriptor then intent.previous[s.pending.domain]=J.Plain(s.pending.descriptor)end
  end
  J.Archive(self.saved,self.operation)
 end
 self.generation=self.generation+1
 self.saved.operationSerial=(self.saved.operationSerial or 0)+1
 self.operation={version=1,id=self.saved.operationSerial,intent=J.Plain(intent),status='running',visible=true,index=1,
  startedAt=self.clock:NowMs(),steps={{id='diff',kind='diff',status='pending',attempts={}}}}
 self:Publish();self:Queue();return true
end
function I:Queue()
 local op=self.operation;local generation=self.generation
 self.clock:Schedule(1,function()
  if self.operation==op and self.generation==generation and op.status=='running'then self:RunCurrent()end
 end)
end
function I:RunCurrent()
 local op=self.operation;local step=op.steps[op.index]
 local generation=self.generation
 step.attempts=step.attempts or {}
 local attempt={startedAt=self.clock:NowMs()};step.attempts[#step.attempts+1]=attempt
 step.status='running';step.problem=nil
 local finished=false
 local function current()return not finished and self.operation==op and self.generation==generation and op.steps[op.index]==step end
 local function report(facts)
  if not current()then return false end
  step.pending=J.Plain(facts);attempt.pending=J.Plain(facts);self:Publish();return true
 end
 local function done(result,problem)
  if not current()then return end
  -- Capture native evidence now, before the failed attempt is persisted and
  -- before the UI can change scenes. Diagnostics must not replace the failure.
  if problem and self.onFailure then
   local ok,err=pcall(self.onFailure,problem,op,step)
   if not ok then
    problem.details=problem.details or {};problem.details.diagnosticError=tostring(err)
   end
  end
  local valid,plainResult,plainProblem=pcall(function()return J.Plain(result),J.Plain(problem)end)
  if not valid then result=nil;problem=KW.Problem('operationError',{error=tostring(plainResult)})
  else result,problem=plainResult,plainProblem end
  finished=true;attempt.finishedAt=self.clock:NowMs()
  attempt.result=result;attempt.problem=problem
  if problem then
   step.problem=J.Plain(problem);step.status=problem.code=='operationUnconfirmed' and 'unconfirmed' or 'failed'
   op.status='failed';op.hadFailure=true;op.visible=true;op.pauseRequested=false;self:Publish();return
  end
  step.status='done';step.problem=nil;step.pending=nil
  if step.kind=='diff' and result then
   op.target=J.Plain(result.target);op.scope=J.Plain(result.scope);op.context=J.Plain(result.context)
   op.steps={step}
   for _,nextStep in ipairs(result.steps or {})do
    local copy=J.Plain(nextStep);copy.status='pending';copy.attempts={};op.steps[#op.steps+1]=copy
   end
  end
  if op.index==#op.steps then
   if self.onComplete then
    local ok,err=xpcall(function()self.onComplete(op)end,J.ErrorDetails)
    if not ok then
     step.status='failed';step.problem=KW.Problem('operationError',err);attempt.problem=J.Plain(step.problem)
     op.status='failed';op.hadFailure=true;op.visible=true;self:Publish();return
    end
   end
   op.status='complete';op.finishedAt=self.clock:NowMs()
   if op.hadFailure then J.Archive(self.saved,op)end
   self.operation=nil;self:Publish();return
  end
  op.index=op.index+1
  op.status=op.pauseRequested and 'paused' or 'running';op.pauseRequested=false
  self:Publish();if op.status=='running'then self:Queue()end
 end
 self:Publish()
 local ok,err=xpcall(function()self.handlers:Run(step,op,report,done)end,J.ErrorDetails)
 if not ok then done(nil,KW.Problem('operationError',err))end
end
function I:Pause()
 local op=self.operation;if not op then return false end
 if op.status=='running'then
  local step=op.steps[op.index]
  if step.status=='running'then op.pauseRequested=true;op.status='pausing'
  else op.status='paused'end
  self:Publish()
 end
 return true
end
function I:Continue()
 local op=self.operation;if not op or self:IsBusy()then return nil,KW.Problem('operationBusy')end
 local step=op.steps[op.index]
 if step.problem and step.problem.code=='operationConsent'then op.intent.consent=step.problem.details.key end
 self.generation=self.generation+1;op.status='running';op.visible=true;op.pauseRequested=false
 self:Publish();self:Queue();return true
end
function I:Restart()
 if not self.operation or self:IsBusy()then return nil,KW.Problem('operationBusy')end
 local intent=J.Plain(self.operation.intent);intent.consent=nil
 return self:Start(intent)
end
