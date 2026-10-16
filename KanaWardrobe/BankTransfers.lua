local KW=KanaWardrobe
local Bank={};KW.BankTransfers=Bank
local Instance={};Instance.__index=Instance
local function items(preset)
 local result,seen={},{}
 for _,slot in ipairs(KW.Slots.Order)do
  local ref=(preset.equipment or preset.slots or {})[slot]
  if ref and ref.kind=='item' and not seen[ref.uid]then
   seen[ref.uid]=true;result[#result+1]=ref
  end
 end
 return result
end
local function carried(location,api)
 return location and (location.bagId==api.BAG_BACKPACK or location.bagId==api.BAG_WORN)
end
function Bank.Presence(preset,snapshot,api)
 local refs=items(preset);local present=true
 for _,ref in ipairs(refs)do if not carried(snapshot.byUid[ref.uid],api)then present=false end end
 return {inBag=present,count=#refs}
end
function Bank.New(options)
 local self=setmetatable({repo=options.repo,inventory=options.inventory,events=options.events,clock=options.clock,
  saved=options.saved or {},active=options.active or function()return {}end,canRun=options.canRun},Instance)
 self.view=KW.Copy(self.saved.bankTransferJournal or {status='idle'})
 if self.view.status=='running'then self.view.status='interrupted';self.saved.bankTransferJournal=KW.Copy(self.view)end
 self.events:Subscribe('InventoryChanged',function()self:Check()end)
 self.events:Subscribe('BankClosed',function()if self:IsBusy()then self:Finish('interrupted',KW.Problem('bankClosed'))end end)
 return self
end
function Instance:IsBusy()return self.operation~=nil end
function Instance:GetView()return self.view end
function Instance:Publish()
 self.saved.bankTransferJournal=KW.Copy(self.view)
 self.events:Emit('BankTransferChanged',self.view)
end
function Instance:Readiness()
 local api=self.inventory.api
 if not api.IsBankOpen() or api.GetBankingBag()~=api.BAG_BANK then return KW.Problem('bankClosed')end
 if self.canRun and not self.canRun()then return KW.Problem('busy')end
 if api.IsUnitInCombat('player')then return KW.Problem('inCombat')end
 if api.IsUnitDeadOrReincarnating and api.IsUnitDeadOrReincarnating('player')then return KW.Problem('dead')end
end
function Instance:Plan(id,snapshot)
 local api=self.inventory.api;local preset=self.repo:Get(id)
 if not preset then return nil,KW.Problem('presetMissing')end
 local active=self.active(snapshot)
 if active[id]then return nil,KW.Problem('bankActivePreset')end
 local presence=Bank.Presence(preset,snapshot,api)
 if presence.count==0 then return nil,KW.Problem('bankNoEquipment')end
 local deposit=presence.inBag;local keep={}
 if deposit then
  -- Membership alone does not protect an item. Only another *complete*
  -- carried preset does, so both user examples follow actual inventory state.
  for _,other in ipairs(self.repo:List())do
   if other.id~=id and (active[other.id] or Bank.Presence(other,snapshot,api).inBag)then
    for _,ref in ipairs(items(other))do keep[ref.uid]=true end
   end
  end
 end
 local moves,missing={},{}
 for _,ref in ipairs(items(preset))do
  local location=snapshot.byUid[ref.uid]
  if deposit then
   if not keep[ref.uid]then moves[#moves+1]={uid=ref.uid,link=ref.link,source=KW.Copy(location)}end
  elseif not carried(location,api)then
   if location and (location.bagId==api.BAG_BANK or location.bagId==api.BAG_SUBSCRIBER_BANK)then
    moves[#moves+1]={uid=ref.uid,link=ref.link,source=KW.Copy(location)}
   else missing[#missing+1]={uid=ref.uid,link=ref.link}end
  end
 end
 if #missing>0 then return nil,KW.Problem('bankItemsMissing',{items=missing})end
 if #moves==0 then return nil,KW.Problem('bankSharedOnly')end
 local bags=deposit and {api.BAG_BANK}or {api.BAG_BACKPACK}
 if deposit and api.IsESOPlusSubscriber and api.IsESOPlusSubscriber()then bags[#bags+1]=api.BAG_SUBSCRIBER_BANK end
 local destinations={}
 for _,bag in ipairs(bags)do
  for slot=0,api.GetBagSize(bag)-1 do
   if not self.inventory:ReadSlot(bag,slot)then destinations[#destinations+1]={bagId=bag,slotIndex=slot}end
   if #destinations>=#moves then break end
  end
  if #destinations>=#moves then break end
 end
 if #destinations<#moves then
  return nil,KW.Problem('bankDestinationFull',{direction=deposit and 'deposit'or 'withdraw',needed=#moves,available=#destinations})
 end
 for i,move in ipairs(moves)do move.destination=destinations[i]end
 return {presetId=id,name=preset.name,direction=deposit and 'deposit'or 'withdraw',moves=moves,revision=preset.revision}
end
function Instance:Finish(status,problem)
 if self.timer then self.clock:Cancel(self.timer);self.timer=nil end
 if self.dispatchTimer then self.clock:Cancel(self.dispatchTimer);self.dispatchTimer=nil end
 self.operation=nil;self.view.status=status;self.view.problem=problem
 self:Publish()
end
function Instance:Start(id)
 if self:IsBusy()then return nil,KW.Problem('busy')end
 local problem=self:Readiness()
 local plan
 if not problem then plan,problem=self:Plan(id,self.inventory:Capture(false))end
 if not plan then
  self.view={status='failed',presetId=id,problem=problem};self:Publish();return nil,problem
 end
 self.sequence=(self.sequence or 0)+1
 self.view={status='running',id='bank:'..self.clock:NowMs()..':'..self.sequence,presetId=id,name=plan.name,
  direction=plan.direction,completed=0,total=#plan.moves,plan=KW.Copy(plan)}
 self.operation=plan;self:Publish()
 self:ScheduleDispatch()
 if self.view.status~='running' and self.view.status~='completed'then return nil,self.view.problem end
 return true
end
function Instance:ScheduleCheck()
 if self.timer or not self.operation then return end
 self.timer=self.clock:Schedule(100,function()self.timer=nil;self:Check()end)
end
function Instance:ScheduleDispatch()
 local op=self.operation;if not op or self.dispatchTimer then return end
 -- Leave a frame for input, native inventory updates and the progress bar.
 -- Later batches do not wait for acknowledgements from earlier batches.
 self.dispatchTimer=self.clock:Schedule(32,function()
  self.dispatchTimer=nil;if self.operation==op then self:Dispatch()end
 end)
end
function Instance:ValidateMove(move)
 local source,destination=move.source,move.destination
 local current=self.inventory:ReadSlot(source.bagId,source.slotIndex)
 if not current or current.uid~=move.uid then return KW.Problem('sourceChanged',{uid=move.uid,link=move.link})end
 if self.inventory:ReadSlot(destination.bagId,destination.slotIndex)then
  return KW.Problem('bankSlotChanged',{uid=move.uid,link=move.link})
 end
end
function Instance:Dispatch()
 local op=self.operation;if not op then return end
 local first=(self.view.dispatched or 0)+1
 local problem=self:Readiness()
 if problem then self:Finish('interrupted',problem);return end
 local preset=self.repo:Get(op.presetId)
 if not preset or preset.revision~=op.revision then self:Finish('failed',KW.Problem('revisionConflict'));return end
 if op.direction=='deposit'then
  local state=self.inventory:Capture(false);local active=self.active(state)
  if active[op.presetId]then self:Finish('failed',KW.Problem('bankActivePreset'));return end
  local protected={}
  for _,other in ipairs(self.repo:List())do
   if active[other.id]then
    for _,ref in ipairs(items(other))do protected[ref.uid]=true end
   end
  end
  for index=first,#op.moves do
   local move=op.moves[index]
   if protected[move.uid]then self:Finish('failed',KW.Problem('bankActivePreset'));return end
  end
 end
 -- Revalidate unsent moves after each yield. Sent moves may already have
 -- changed their slots and are verified separately by Check.
 for index=first,#op.moves do
  local move=op.moves[index]
  problem=self:ValidateMove(move)
  if problem then self:Finish('failed',problem);return end
 end
 local api=self.inventory.api
 if type(api.CallSecureProtected)~='function'then self:Finish('failed',KW.Problem('buildCapabilityUnavailable'));return end
 -- RequestMoveItem is private. Even checking its function value taints the
 -- call; dispatch its name through the public secure entry point only.
 self.dispatching=true
 self.view.dispatched=self.view.dispatched or 0
 for index=first,math.min(first+2,#op.moves)do
  local move=op.moves[index]
  -- A synchronous native callback may close the bank or occupy a reserved
  -- slot. Stop unsent requests without touching unrelated items.
  problem=self:Readiness()or self:ValidateMove(move)
  if problem then self.dispatching=false;self:Finish('failed',problem);return end
  local source,destination=move.source,move.destination
  move.sentAt=self.clock:NowMs();self.view.plan.moves[index].sentAt=move.sentAt
  local ok,accepted=pcall(api.CallSecureProtected,'RequestMoveItem',source.bagId,source.slotIndex,destination.bagId,destination.slotIndex,1)
  if self.operation~=op then self.dispatching=false;return end
  if not ok or accepted==false then
   self.dispatching=false
   self:Finish('failed',KW.Problem('bankMoveRejected',{uid=move.uid,link=move.link,error=not ok and tostring(accepted)or nil}));return
  end
  self.view.dispatched=index
 end
 self.dispatching=false
 self:Check()
 if self.operation==op and self.view.dispatched<#op.moves then self:ScheduleDispatch()end
end
function Instance:Check()
 local op=self.operation;if not op or self.dispatching or not self.view.dispatched then return end
 local problem=self:Readiness()
 if problem then self:Finish('interrupted',problem);return end
 local completed,pending,timeout=0,{},nil
 for index,move in ipairs(op.moves)do
  local source,destination=move.source,move.destination
  local actual=self.inventory:ReadSlot(destination.bagId,destination.slotIndex)
  local original=self.inventory:ReadSlot(source.bagId,source.slotIndex)
  local confirmed=move.sentAt and actual and actual.uid==move.uid and (not original or original.uid~=move.uid)or false
  local entry=self.view.plan.moves[index];entry.confirmed=confirmed
  entry.actual={source=KW.Copy(original),destination=KW.Copy(actual)}
  if confirmed then completed=completed+1
  else
   pending[#pending+1]=KW.Copy(entry)
   if move.sentAt and self.clock:NowMs()-move.sentAt>=5000 then timeout=timeout or entry end
  end
 end
 local changed=self.view.completed~=completed or not self.view.pending
 self.view.completed=completed;self.view.pending=#pending>0 and pending or nil
 if completed==#op.moves then self:Finish('completed')
 elseif timeout then
  self.view.actual=KW.Copy(timeout.actual)
  self:Finish('failed',KW.Problem('bankMoveTimeout',{uid=timeout.uid,link=timeout.link,direction=op.direction}))
 else
  if changed then self:Publish()end
  if self.operation==op then self:ScheduleCheck()end
 end
end
