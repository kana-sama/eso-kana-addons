local KW=KanaWardrobe
local S={};KW.GearProbeSuite=S
local P={};P.__index=P
local function short(value)
 local text=tostring(value);local n=math.min(#text,1500)
 while n<#text and text:byte(n+1)>=128 and text:byte(n+1)<192 do n=n-1 end
 return text:sub(1,n)
end
local function same(a,b)return a and b and a.kind==b.kind and (a.kind=='empty' or a.uid==b.uid)end
local function reason(problem)return problem and (problem.code or short(problem)) or 'no result'end
function S.New(options)
 local self=setmetatable(options,P)
 self.restoreRunner=KW.EquipmentRunner.New(self.inventory,self.events,self.clock)
 local run=self.saved.suite
 if run and run.status=='running'then
  run.status='interrupted';run.matchesOriginal=false
  run.error='Перезагрузка прервала проверку; автоматических запросов после неё не было.'
 end
 return self
end
function P:State()return self.inventory:Capture(false)end
function P:Ready()
 if self.api.IsUnitInCombat('player')then return nil,'Персонаж в бою.'end
 if self.api.IsUnitDeadOrReincarnating('player')then return nil,'Персонаж мёртв.'end
 if self.api.IsBlockActive()then return nil,'Персонаж держит блок.'end
 return true
end
function P:Later(delay,fn)
 self.timer=self.clock:Schedule(delay,function()
  self.timer=nil;if not self.active then return end
  local ok,err=pcall(fn)
  if not ok then
   if self.mode=='setup' or self.mode=='restore'then self:StopWithError(short(err))
   else self:FinishCase('failed','Lua: '..short(err))end
  end
 end)
end
function P:Notify(text)if self.api.d then self.api.d('KanaWardrobe: '..text)end end
function P:SetActive(value)
 self.active=value
 if self.onActiveChanged then self.onActiveChanged(value)end
end
function P:Show(message)
 local run=self.saved.suite;local lines={'KanaWardrobe equipment experiment suite',message or ''}
 if run then
  lines[#lines+1]='api='..tostring(run.api)..' status='..run.status..' matchesOriginal='..tostring(run.matchesOriginal)
  if run.error then lines[#lines+1]='error='..run.error end
  for _,e in ipairs(run.errors or {})do lines[#lines+1]=e.name..' '..e.code..' '..(e.text or '')end
  for i,c in ipairs(run.cases)do
   lines[#lines+1]=i..'. '..c.id..' ['..c.status..'] '..c.title
   if c.skip or c.error then lines[#lines+1]=short(c.skip or c.error)end
   for j,p in ipairs(c.phases)do
    lines[#lines+1]='  phase.'..j..' '..tostring(p.status)..' requests='..#p.requests..' elapsedMs='..tostring(p.elapsedMs)
    for _,r in ipairs(p.requests)do
     lines[#lines+1]='  '..r.method..' '..r.uid..' '..r.sourceBag..':'..r.sourceSlot..' -> '..r.destBag..':'..r.destSlot..' at='..r.sentAt..' dispatch='..tostring(r.dispatch)
    end
    if p.actual and p.expected then for _,slot in ipairs(KW.Slots.Order)do
     if not same(p.actual[slot],p.expected[slot])then
      lines[#lines+1]='  slot.'..slot..' expected='..tostring(p.expected[slot].uid or 'empty')..' actual='..tostring(p.actual[slot].uid or 'empty')
     end
    end end
    for _,e in ipairs(p.errors or {})do lines[#lines+1]='  '..e.name..' '..e.code..' '..(e.text or '')end
   end
  end
  if not run.matchesOriginal then lines[#lines+1]='Вернуть исходную экипировку: /kw probe gearsuiterestore'end
 end
 lines[#lines+1]='Полный журнал: SavedVariables/KanaWardrobe.lua -> gearProbeJournal.suite. /reloadui запишет его на диск.'
 -- ESO drops individual SavedVariables strings over 2000 bytes. Keep the
 -- summary as short lines, with structured phase evidence separately.
 for i,line in ipairs(lines)do lines[i]=short(line)end
 self.saved.suiteReportLines=lines
 local ok,err=pcall(self.report,table.concat(lines,'\n'))
 if not ok then self.saved.suiteReportError=short(err)end
end
function P:StopWithError(message)
 local run=self.saved.suite
 run.status='interrupted';run.error=short(message);run.matchesOriginal=KW.Slots.Equal(run.original,self:State().worn)
 self:SetActive(false)
 if self.timer then self.clock:Cancel(self.timer);self.timer=nil end
 self.restoreRunner:Stop('probeStopped')
 self:Show('Проверка остановлена: '..run.error)
 return nil,KW.Problem('gearProbe',{reason=run.error})
end
function P:NativeError(name,code,text)
 if not self.active then return end
 local run=self.saved.suite;local c=run.cases[run.index];local p=c and c.phases[#c.phases]
 local errors=p and self.mode=='test' and p.errors or run.errors
 if #errors<100 then errors[#errors+1]={name=short(name),code=short(code),text=short(text or ''),at=self.clock:NowMs()}end
end
function P:ApplyKnown(target,mode,done)
 self.mode=mode
 local ready,blocked=self:Ready();if not ready then return self:StopWithError(blocked)end
 local state=self.inventory:Capture('equipment')
 if mode=='restore' and KW.Slots.Equal(state.worn,target)then done();return end
 -- Restore uses the existing conservative executor, keeping the unverified
 -- batch experiments out of the path that recovers the player's equipment.
 local run=self.saved.suite
 -- The full-bag experiment can only be reversed in a full bag after its
 -- forward swap has actually been observed. This never changes production
 -- planner capabilities or applies to another suite run.
 local caps={fullBagEquipSwap=mode=='restore' and run.observedFullBagSwap==true}
 local plan,problem=KW.EquipmentPlan.Build(state,target,mode=='restore' and 'restore' or 'apply',caps)
 if not plan then
  if mode=='setup'then self:FinishCase('skipped','Подготовка невозможна: '..reason(problem))
  else self:StopWithError('Не удалось составить возврат исходных вещей: '..reason(problem))end
  return
 end
 local c=run.cases[run.index]
 local evidence={before=KW.Copy(plan.before),target=KW.Copy(plan.target),steps=KW.Copy(plan.steps),started=self.clock:NowMs()}
 if c then c[mode]=evidence else run.restore=evidence end
 if #plan.steps>0 then run.matchesOriginal=false end
 local id,err=self.restoreRunner:Start(plan,function(progress)evidence.progress=progress.phase;evidence.completed=progress.completed end,function(result)
  if not self.active then return end
  evidence.result=KW.Copy(result);evidence.finished=self.clock:NowMs()
  if result.status=='success'then self:Later(100,done)
  elseif mode=='setup'then self:Later(500,function()self:FinishCase('failed','Подготовка не завершилась: '..reason(result.problem))end)
  else self:StopWithError('Возврат исходной экипировки не завершился: '..reason(result.problem))end
 end)
 if not id then self:StopWithError('Не удалось запустить '..mode..': '..reason(err))end
end
function P:FinishCase(status,message)
 local run=self.saved.suite;local c=run.cases[run.index]
 c.status=status;c.error=message and short(message) or nil
 if status=='skipped'then c.skip=c.error end
 self:Notify(c.title..': '..(status=='passed' and 'подтверждено' or status=='skipped' and 'пропущено' or 'не подтвердилось')..'. Возвращаю исходный эквип.')
 self:ApplyKnown(run.original,'restore',function()
  c.restored=KW.Slots.Equal(run.original,self:State().worn)
  if not c.restored then self:StopWithError('После возврата экипировка отличается от исходной.');return end
  run.matchesOriginal=true
  if self.stopRequested then run.status='stopped';self:SetActive(false);self:Show('Проверка остановлена. Исходная экипировка возвращена.')
  else run.index=run.index+1;self:Later(100,function()self:NextCase()end)end
 end)
end
function P:NextCase()
 local run=self.saved.suite;local c=run.cases[run.index]
 if not c then
  run.status='completed';run.matchesOriginal=KW.Slots.Equal(run.original,self:State().worn);run.finished=self.clock:NowMs()
  self:SetActive(false);self:Show('Все доступные проверки завершены. Исходная экипировка '..(run.matchesOriginal and 'возвращена.' or 'НЕ восстановлена.'));return
 end
 if c.skip then c.status='skipped';run.index=run.index+1;self:Later(1,function()self:NextCase()end);return end
 if self.stopRequested then self:FinishCase('skipped','Остановлено пользователем.');return end
 self:Notify('Проверка '..run.index..'/'..#run.cases..': '..c.title)
 c.status='running';self.batchIndex=1
 self:ApplyKnown(c.setup,'setup',function()self:StartBatch()end)
end
function P:StartBatch()
 self.mode='test'
 local ready,blocked=self:Ready();if not ready then return self:StopWithError(blocked)end
 local run=self.saved.suite;local c=run.cases[run.index];local spec=c.batches[self.batchIndex]
 if not spec then return self:FinishCase('passed')end
 if self.stopRequested then return self:FinishCase('skipped','Остановлено пользователем.')end
 local state=self:State();local expected=KW.Copy(state.worn)
 for slot,value in pairs(spec.expected)do expected[slot]=KW.Copy(value)end
 local requests,free={},{}
 for slot=0,self.api.GetBagSize(self.api.BAG_BACKPACK)-1 do
  if not self.inventory:ReadSlot(self.api.BAG_BACKPACK,slot)then free[#free+1]=slot end
 end
 local nextFree=1
 -- Resolve and validate the whole batch before issuing its first request.
 for _,a in ipairs(spec.actions)do
  local loc=state.byUid[a.uid]
  if not loc or loc.bagId~=self.api.BAG_WORN and loc.bagId~=self.api.BAG_BACKPACK then return self:FinishCase('failed','Не найден предмет '..a.uid)end
  if self.api.ZO_InventorySlot_WillItemBecomeBoundOnEquip(loc.bagId,loc.slotIndex)then return self:FinishCase('skipped','Предмет потребует привязки к персонажу.')end
  local r={uid=a.uid,sourceBag=loc.bagId,sourceSlot=loc.slotIndex}
  if a.kind=='unequip'then
   if loc.bagId~=self.api.BAG_WORN or loc.slotIndex~=a.equipSlot then return self:FinishCase('failed','Изменилось положение снимаемой вещи '..a.uid)end
   if not free[nextFree]then return self:FinishCase('skipped','Недостаточно свободных ячеек для этой пачки.')end
   r.method='RequestMoveItem';r.destBag=self.api.BAG_BACKPACK;r.destSlot=free[nextFree];nextFree=nextFree+1
  else
   r.method=a.method=='ww' and 'EquipItem' or 'RequestEquipItem';r.destBag=self.api.BAG_WORN;r.destSlot=a.equipSlot
  end
  requests[#requests+1]=r
 end
 local p={status='running',freeSlots=state.freeSlots,before=KW.Copy(state.worn),expected=expected,requests=requests,errors={},observations={},started=self.clock:NowMs()}
 c.phases[#c.phases+1]=p;run.matchesOriginal=false;self.lastObservation=nil
 for _,r in ipairs(requests)do
  r.sentAt=self.clock:NowMs()
  local ok,value=pcall(function()
   if r.method=='RequestMoveItem'then return self.api.CallSecureProtected(r.method,r.sourceBag,r.sourceSlot,r.destBag,r.destSlot,1)
   elseif r.method=='EquipItem'then return self.api.EquipItem(r.sourceBag,r.sourceSlot,r.destSlot)
   else return self.api.RequestEquipItem(r.sourceBag,r.sourceSlot,r.destBag,r.destSlot)end
  end)
  r.dispatch=ok;r.returnValue=short(value);if not ok then r.error=short(value);p.dispatchError=true end
 end
 self:Later(50,function()self:PollBatch()end)
end
function P:PollBatch()
 local run=self.saved.suite;local c=run.cases[run.index];local p=c.phases[#c.phases];local state=self:State()
 local signature={};local locations={};local present=true
 for _,slot in ipairs(KW.Slots.Order)do signature[#signature+1]=state.worn[slot].uid or '-'end
 for id in pairs(run.tracked)do
  local loc=state.byUid[id]
  if loc then locations[id]={bag=loc.bagId,slot=loc.slotIndex};signature[#signature+1]=id..':'..loc.bagId..':'..loc.slotIndex
  else present=false;signature[#signature+1]=id..':missing'end
 end
 table.sort(signature);signature=table.concat(signature,'|')
 if signature~=self.lastObservation then
  self.lastObservation=signature
  if #p.observations<60 then p.observations[#p.observations+1]={at=self.clock:NowMs(),worn=KW.Copy(state.worn),locations=locations}end
 end
 local matched=KW.Slots.Equal(p.expected,state.worn) and present
 for _,r in ipairs(p.requests)do if r.method=='RequestMoveItem'then
  local loc=locations[r.uid];if not loc or loc.bag~=r.destBag or loc.slot~=r.destSlot then matched=false end
 end end
 local elapsed=self.clock:NowMs()-p.started
 if matched and not p.dispatchError or elapsed>=5000 then
  p.elapsedMs=elapsed;p.actual=KW.Copy(state.worn);p.locations=locations;p.status=matched and not p.dispatchError and 'passed' or 'failed'
  if c.id=='full_bag' and p.freeSlots==0 and p.status=='passed'then run.observedFullBagSwap=true end
  if p.status=='passed'then self.batchIndex=self.batchIndex+1;self:Later(50,function()self:StartBatch()end)
  else self:Later(500,function()self:FinishCase('failed',p.dispatchError and 'Исключение при отправке запроса; детали сохранены.' or 'За 5 секунд ожидаемое положение вещей не подтвердилось; фактическое положение и ответы ESO сохранены.')end)end
 else self:Later(50,function()self:PollBatch()end)end
end
function P:Run(command)
 if command=='gearsuitereport'then self:Show();return true end
 if command=='gearsuitestop' and self.active then self.stopRequested=true;self:Notify('Остановлю проверки после текущего действия и верну экипировку.');return true end
 if self.active then return nil,KW.Problem('gearProbe',{reason='Набор проверок уже выполняется.'})end
 local ready,blocked=self:Ready()
 if not ready or self.canRun and not self.canRun()then
  return nil,KW.Problem('gearProbe',{reason=blocked or 'Сначала завершите применение или редактирование пресета.'})
 end
 local run=self.saved.suite
 if command=='gearsuiterestore'then
  if not run then return nil,KW.Problem('gearProbe',{reason='Нет сохранённой исходной экипировки.'})end
  self:SetActive(true);self.stopRequested=true
  self:ApplyKnown(run.original,'restore',function()
   run.matchesOriginal=KW.Slots.Equal(run.original,self:State().worn);run.status='restored'
   self:SetActive(false);self:Show('Исходная экипировка возвращена.')
  end);return true
 end
 if run and not run.matchesOriginal then return nil,KW.Problem('gearProbe',{reason='Сначала верните экипировку предыдущей проверки: /kw probe gearsuiterestore'})end
 if type(self.api.GetBagSize)~='function' or type(self.api.CallSecureProtected)~='function'then return nil,KW.Problem('gearProbe',{reason='Нет API для проверки перемещений.'})end
 local state=self.inventory:Capture('equipment');local cases=KW.GearProbeCases.Build(state,self.api)
 if run then self.saved.suiteHistory=self.saved.suiteHistory or {};table.insert(self.saved.suiteHistory,1,run);self.saved.suiteHistory[4]=nil end
 run={status='running',api=self.api.GetAPIVersion(),original=KW.Copy(state.worn),cases=cases,index=1,tracked={},errors={},started=self.clock:NowMs(),matchesOriginal=true}
 for _,value in pairs(run.original)do if value.uid then run.tracked[value.uid]=true end end
 for _,c in ipairs(cases)do
  if not c.skip then
   for _,value in pairs(c.setup)do if value.uid then run.tracked[value.uid]=true end end
   for _,batch in ipairs(c.batches)do for _,a in ipairs(batch.actions)do run.tracked[a.uid]=true end end
  end
 end
 self.saved.suite=run;self.stopRequested=false;self:SetActive(true)
 self:Later(1,function()self:NextCase()end);return true
end
return S
