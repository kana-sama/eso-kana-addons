-- Component-scoped native Stats draft; server result/actual timing belongs to BuildRunner.
local KW=KanaWardrobe
KW.AttributeAdapter={}
local Adapter={};Adapter.__index=Adapter
local keys={'health','magicka','stamina'}
local function need(object,name)
 assert(object and type(object[name])=='function','missing '..name)
 return object[name]
end
local function integer(value)return type(value)=='number' and value==value and value>=0 and value<math.huge and value==math.floor(value)end
local function valid(value)
 if type(value)~='table'then return false end
 for _,key in ipairs(keys)do if not integer(value[key])then return false end end
 return true
end
local function same(a,b)
 for _,key in ipairs(keys)do if a[key]~=b[key]then return false end end
 return true
end
local function copy(value)local out={};for _,key in ipairs(keys)do out[key]=value[key]end;return out end
local function attempt(fn)
 local ok,result,extra=pcall(fn)
 if ok then return result,extra end
 return nil,KW.Problem('attributeAdapterRefused',{reason=tostring(result)})
end
function KW.AttributeAdapter.New(api,events)
 return setmetatable({api=api,events=events,generation=0,submission={phase="idle",sent=false},submittedRequests=setmetatable({},{__mode='k'})},Adapter)
end
function Adapter:Ids()
 local api=self.api
 assert(api.ATTRIBUTE_HEALTH~=nil and api.ATTRIBUTE_MAGICKA~=nil and api.ATTRIBUTE_STAMINA~=nil,'missing attribute identifiers')
 return {api.ATTRIBUTE_HEALTH,api.ATTRIBUTE_MAGICKA,api.ATTRIBUTE_STAMINA}
end
function Adapter:Capture()
 return attempt(function()
  local api=self.api;local attributes={};local total=0
  local spent=need(api,'GetAttributeSpentPoints')
  for index,id in ipairs(self:Ids())do local value=spent(id);assert(integer(value),'invalid actual attribute points');attributes[keys[index]]=value;total=total+value end
  local unspent=need(api,'GetAttributeUnspentPoints')();assert(integer(unspent),'invalid attribute unspent points')
  attributes.unspentAtCapture=unspent;return attributes,total+unspent
 end)
end
function Adapter:Prepare(current,target,budget)
 return attempt(function()
  assert(valid(current) and valid(target) and integer(budget),'invalid absolute attributes or budget')
  local total=0;local deltas={}
  for _,key in ipairs(keys)do total=total+target[key];deltas[key]=target[key]-current[key]end
  assert(total<=budget,'insufficient attribute points')
  return {original=copy(current),target=copy(target),deltas=deltas,remaining=budget-total,budget=budget}
 end)
end
function Adapter:Controls()
 local stats=self.api.STATS;assert(stats and stats.attributeControls,'native Stats controls unavailable; open Stats first')
 local controls={}
 for _,id in ipairs(self:Ids())do
  local control=stats.attributeControls[id];local spinner=control and control.pointLimitedSpinner
  need(spinner,'GetPoints');need(spinner,'GetAllocatedPoints');need(spinner,'SetAddedPointsByTotalPoints');need(spinner,'ResetAddedPoints')
  controls[#controls+1]=spinner
 end
 return stats,controls
end
function Adapter:CheckForeign(exceptOwned)
 local api=self.api
 local skills=api.SKILLS_AND_ACTION_BAR_MANAGER
 if skills then assert(not KW.SkillState.HasPendingChanges(api) and not skills.isDirty,'native skill changes pending')end
 if not exceptOwned then
  local stats=api.STATS
  if stats and stats.attributeControls then
   for _,id in ipairs(self:Ids())do local c=stats.attributeControls[id];assert(c and need(c.pointLimitedSpinner,'GetAllocatedPoints')(c.pointLimitedSpinner)==0,'native attribute changes pending')end
  elseif stats then
   assert(not stats.initialized and type(stats.OnShowing)=='function','native attribute pending state unavailable')
  end
 end
 local gamepad=api.GAMEPAD_STATS
 if gamepad then
  if gamepad.attributeData then
   for _,id in ipairs(self:Ids())do assert(gamepad.attributeData[id] and gamepad.attributeData[id].addedPoints==0,'gamepad attribute changes pending')end
  else assert(not gamepad.deferredInitialized and type(gamepad.PerformDeferredInitializationRoot)=='function','gamepad pending state unavailable')end
 end
end
function Adapter:Guard()
 local api=self.api
 assert(not self.IsSessionIdle or self.IsSessionIdle(),'equipment session not idle')
 assert(not api.IsUnitInCombat or not api.IsUnitInCombat('player'),'in combat')
 assert(not api.IsUnitDead or not api.IsUnitDead('player'),'dead')
 assert(need(api,'GetAttributeRespecCastTimeRemainingMs')()==0,'native attribute cast pending')
 assert(not api.GetSkillRespecCastTimeRemainingMs or api.GetSkillRespecCastTimeRemainingMs()==0,'native skill cast pending')
end
function Adapter:CaptureDraft()
 return attempt(function()
  assert(self.mounted,'no owned attribute draft')
  local _,controls=self:Controls();local value={}
  for index,spinner in ipairs(controls)do value[keys[index]]=spinner:GetPoints()+spinner:GetAllocatedPoints()end
  assert(valid(value),'invalid native attribute draft');return value
 end)
end
function Adapter:DetachCallbacks()
 for _,entry in ipairs(self.callbacks or {})do entry.spinner:UnregisterCallback('OnValueChanged',entry.fn)end
 self.callbacks={}
end
function Adapter:MountDraft(target,changed)
 local result,problem=attempt(function()
  assert(not self.mounted and not self.submitting,'attribute editor already active')
  self:Guard();self:CheckForeign(false)
  local original,budget=self:Capture();assert(original,'attribute capture unavailable')
  local request,err=self:Prepare(original,target,budget);assert(request,err and err.details.reason)
  local api=self.api;local stats,controls=self:Controls()
  for _,name in ipairs({'GetAttributePointAllocationMode','SetAttributePointAllocationMode','GetAttributeRespecPaymentType','SetAttributeRespecPaymentType','UpdateSpendablePoints'})do need(stats,name)end
  assert(api.ATTRIBUTE_POINT_ALLOCATION_MODE_FULL~=nil and api.ATTRIBUTE_POINT_ALLOCATION_MODE_PURCHASE_ONLY~=nil and api.RESPEC_PAYMENT_TYPE_GOLD~=nil,'missing attribute mode/payment constants')
  for _,spinner in ipairs(controls)do need(spinner.pointsSpinner,'RegisterCallback');need(spinner.pointsSpinner,'UnregisterCallback')end
  local priorMode=stats:GetAttributePointAllocationMode();local priorPayment=stats:GetAttributeRespecPaymentType()
  assert(priorMode~=nil and priorPayment~=nil,'unreadable native attribute mode/payment')
  self.mountGeneration=(self.mountGeneration or 0)+1;self.ownerToken=self.mountGeneration;self.original=original;self.priorMode=priorMode;self.priorPayment=priorPayment;self.mounted=true;self.hydrating=true;self.callbacks={}
  stats:SetAttributePointAllocationMode(api.ATTRIBUTE_POINT_ALLOCATION_MODE_FULL);stats:SetAttributeRespecPaymentType(api.RESPEC_PAYMENT_TYPE_GOLD)
  stats:UpdateSpendablePoints()
  -- Native absolute setters spend the shared pool; refund decreases first.
  for pass=1,2 do
   for index,spinner in ipairs(controls)do
    local value=request.target[keys[index]]
    if (pass==1 and value<spinner:GetPoints())or(pass==2 and value>=spinner:GetPoints())then spinner:SetAddedPointsByTotalPoints(value)end
   end
  end
  -- SetAddedPointsByTotalPoints changes deltas; native reinitialization displays them.
  stats:UpdateSpendablePoints()
  local captured=self:CaptureDraft();assert(captured and same(captured,request.target),'native hydration clamped attribute target')
  for _,spinner in ipairs(controls)do
   local fn=function()
    if self.mounted and not self.hydrating and not self.submitting and changed then local draft,issue=self:CaptureDraft();changed(draft,issue)end
   end
   spinner.pointsSpinner:RegisterCallback('OnValueChanged',fn);self.callbacks[#self.callbacks+1]={spinner=spinner.pointsSpinner,fn=fn}
  end
  self.hydrating=false;return true
 end)
 if not result and self.hydrating then self.hydrating=false;local cleaned,cleanup=self:DiscardDraft();if not cleaned then return nil,cleanup end end
 return result,problem
end
function Adapter:DiscardDraft()
 return attempt(function()
  if not self.mounted then return true end
  assert(not self.submitting,'attribute submission unresolved; verify actual before cleanup')
  self:Guard();self:CheckForeign(true)
  local actual=self:Capture();assert(actual,'attribute capture unavailable');assert(same(actual,self.cleanupActual or self.original),'actual attributes changed during editing')
  local stats,controls=self:Controls()
  self.hydrating=true
  for _,spinner in ipairs(controls)do spinner:ResetAddedPoints()end
  stats:UpdateSpendablePoints()
  for _,spinner in ipairs(controls)do assert(spinner:GetAllocatedPoints()==0,'native attribute cleanup uncertain')end
  self:DetachCallbacks()
  stats:SetAttributeRespecPaymentType(self.priorPayment);stats:SetAttributePointAllocationMode(self.priorMode)
  -- Mode setters only fire callbacks; keyboard Stats does not refresh its
  -- spinner limits or keybind strip from those callbacks.
  stats:UpdateSpendablePoints()
  local strip=self.api.KEYBIND_STRIP
  if strip and stats.keybindButtons then need(strip,'UpdateKeybindButtonGroup')(strip,stats.keybindButtons)end
  assert(stats:GetAttributePointAllocationMode()==self.priorMode,'native attribute mode cleanup uncertain')
  self.hydrating=false;self.mounted=false;self.original=nil;self.cleanupActual=nil;return true
 end)
end
function Adapter:UnmountDraft()return self:DiscardDraft()end
function Adapter:Submit(request)
 local accepted,problem=attempt(function()
  assert(type(request)=='table' and not self.submittedRequests[request] and not self.submitting,'attribute request already submitted')
  self:Guard();self:CheckForeign(self.mounted)
  local actual,budget=self:Capture();assert(actual,'attribute capture unavailable')
  assert(valid(request.original) and same(actual,request.original),'stale actual attributes')
  local prepared,err=self:Prepare(actual,request.target,budget);assert(prepared,err and err.details.reason)
  if self.mounted then
   assert(same(actual,self.original),'owned attribute editor actual conflict')
   local stats=self.api.STATS
   assert(stats:GetAttributePointAllocationMode()==self.api.ATTRIBUTE_POINT_ALLOCATION_MODE_FULL and stats:GetAttributeRespecPaymentType()==self.api.RESPEC_PAYMENT_TYPE_GOLD,'owned attribute mode/payment changed')
   local draft,issue=self:CaptureDraft();assert(draft,issue and issue.details.reason);assert(same(draft,prepared.target),'request differs from current attribute experiment')
  end
  assert(self.api.RESPEC_PAYMENT_TYPE_GOLD~=nil and self.api.RESPEC_RESULT_SUCCESS~=nil,'missing attribute payment/result constants')
  local send=need(self.api,'SendAttributePointAllocationRequest')
  self.submittedRequests[request]=true;self.submitting=true;self.generation=self.generation+1
  self.submission={phase='waiting',sent=true,token=self.generation,original=copy(actual),target=copy(prepared.target)}
  send(self.api.RESPEC_PAYMENT_TYPE_GOLD,prepared.deltas.health,prepared.deltas.magicka,prepared.deltas.stamina)
  return true
 end)
 if not accepted and self.submitting and self.submission.phase=='waiting' then self.submission.phase='unknown';self.submission.problem=problem end
 return accepted,problem
end
function Adapter:GetSubmissionState()return KW.Copy(self.submission)end
function Adapter:ResolveSubmission(result,token)
 local resolved,problem=attempt(function()
  assert(self.submitting and self.submission.sent,'no unresolved attribute submission')
  assert(token==self.submission.token or token==nil and self.generation==1,'stale attribute submission token')
  assert(type(result)=='number' and result==result and result>-math.huge and result<math.huge and result==math.floor(result),'missing native attribute result')
  self.submission.result=result
  assert(self.api.RESPEC_RESULT_SUCCESS~=nil,'missing native success constant')
  assert(need(self.api,'GetAttributeRespecCastTimeRemainingMs')()==0,'attribute cast still active')
  local actual=self:Capture();assert(actual,'actual attributes unavailable')
  local successful=result==self.api.RESPEC_RESULT_SUCCESS
  assert(same(actual,successful and self.submission.target or self.submission.original),'native result and actual attributes disagree')
  self.submission.phase=successful and 'confirmed' or 'failed';self.submission.problem=nil
  self.submission.resolved=true
  self.submitting=false
  if self.mounted then self.cleanupActual=copy(actual)end
  return true
 end)
 if not resolved and self.submitting then self.submission.phase='unknown';self.submission.problem=problem end
 return resolved,problem
end
function Adapter:CancelSubmission(reason)
 if not self.submitting then return true end
 local problem=KW.Problem('attributeSubmissionUncertain',{reason=reason or 'cancelled after send'})
 self.submission.phase='unknown';self.submission.problem=problem
 return nil,problem -- A sent packet cannot be retracted or silently released.
end
function Adapter:Matches(target)
 local actual=self:Capture();return valid(target) and actual~=nil and same(actual,target) or false
end
-- Local recovery uses fresh actuals and never substitutes a native result.
function Adapter:GetNativeOwnership()
 if self.mounted then return {token=self.ownerToken,phase='editor',page='stats',possibleSent=false}end
 if self.submitting then return {token=self.submission.token,phase=self.submission.phase,page='stats',possibleSent=self.submission.sent==true}end
end
function Adapter:RecoveryGuard()
 return attempt(function()
  local api=self.api
  assert(need(api,'GetAttributeRespecCastTimeRemainingMs')()==0,'native attribute cast pending')
  assert(not api.GetSkillRespecCastTimeRemainingMs or api.GetSkillRespecCastTimeRemainingMs()==0,'native skill cast pending')
  self:CheckForeign(false)
  local lines=api.SKILL_LINE_ASSIGNMENT_MANAGER
  assert(not lines or not need(lines,'IsAnyChangePending')(lines),'native subclass changes pending')
  return true
 end)
end
function Adapter:GetRecoveryFacts()
 local actual,budget=self:Capture();if not actual then return nil,budget end
 return {actual=copy(actual),budget=budget}
end
function Adapter:ReleaseAfterNativeExit(token,original)
 return attempt(function()
  assert(self.mounted and token==self.ownerToken and valid(original) and same(original,self.original),'stale editor ownership')
  assert(not self.submitting,'attribute submission unresolved')
  local clean,problem=self:RecoveryGuard();assert(clean,problem and problem.details.reason)
  local stats=self.api.STATS;assert(need(stats,'GetAttributePointAllocationMode')(stats)==self.api.ATTRIBUTE_POINT_ALLOCATION_MODE_PURCHASE_ONLY,'native attribute page has not reset')
  local actual=self:Capture();assert(actual and same(actual,original),'actual attributes changed during native exit')
  self:DetachCallbacks();self.mounted=false;self.original=nil;self.cleanupActual=nil
  return true
 end)
end
function Adapter:ReconcileSubmission(descriptor,action,expectedFacts)
 return attempt(function()
  assert(not self.mounted and type(descriptor)=='table' and valid(descriptor.original) and valid(descriptor.target),'invalid recovery descriptor')
  assert(action=='actualTarget' or action=='acceptCurrent','invalid recovery action')
  local state=self.submission
  if self.submitting then
   assert(descriptor.token==state.token and same(descriptor.original,state.original) and same(descriptor.target,state.target),'stale attribute recovery token')
  end
  local clean,problem=self:RecoveryGuard();assert(clean,problem and problem.details.reason)
  local facts,issue=self:GetRecoveryFacts();assert(facts,issue and issue.code)
  assert(expectedFacts and same(facts.actual,expectedFacts.actual) and facts.budget==expectedFacts.budget,'recovery facts changed')
  assert(action~='actualTarget' or same(facts.actual,descriptor.target),'actual attributes do not match exact target')
  local stats=self.api.STATS
  if stats then
   local mode=need(stats,'GetAttributePointAllocationMode')(stats)
   assert(mode==self.api.ATTRIBUTE_POINT_ALLOCATION_MODE_FULL or mode==self.api.ATTRIBUTE_POINT_ALLOCATION_MODE_PURCHASE_ONLY,'unknown attribute allocation mode')
   if mode==self.api.ATTRIBUTE_POINT_ALLOCATION_MODE_FULL then stats:SetAttributePointAllocationMode(self.api.ATTRIBUTE_POINT_ALLOCATION_MODE_PURCHASE_ONLY)end
  end
  local fresh=self:GetRecoveryFacts();clean,problem=self:RecoveryGuard()
  if not fresh or not same(fresh.actual,facts.actual) or fresh.budget~=facts.budget or not clean then
   if stats then stats:SetAttributePointAllocationMode(self.api.ATTRIBUTE_POINT_ALLOCATION_MODE_FULL)end
   error('recovery facts changed during cleanup')
  end
  self.submitting=false;state.phase='reconciled';state.resolved=true
  return {resolution=action,actual=facts.actual,nativeOutcome=state.result==nil and 'unknown' or state.result,released=true}
 end)
end
return KW.AttributeAdapter
