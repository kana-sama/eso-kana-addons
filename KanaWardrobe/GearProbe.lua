local KW=KanaWardrobe
local G={};KW.GearProbe=G
local P={};P.__index=P
local function uid(item)return item and item.uid or 'empty'end

-- An explicit experiment, separate from the preset executor. Reloading never
-- replays requests. Two removals share one dispatch turn; restoration is serial
-- so that a restore failure cannot be mistaken for a removal-batch failure.
function G.New(api,saved,clock,inventory,report,canRun)
 local self=setmetatable({api=api,saved=saved,clock=clock,inventory=inventory,report=report,canRun=canRun},P)
 local r=saved.run
 if r and (r.status=='removing' or r.status=='restoring')then
  r.interruptedPhase=r.status;r.status='interrupted'
 end
 return self
end
function P:Worn()
 return KW.Slots.FromWorn(function(slot)return self.inventory:ReadSlot(self.api.BAG_WORN,slot)end)
end
function P:Log(text)
 local r=self.saved.run
 r.log[#r.log+1]=tostring(self.clock:NowMs())..' '..text
end
function P:Show(message)
 local r=self.saved.run
 local lines={'KanaWardrobe equipment batch probe','api='..tostring(self.api.GetAPIVersion()),message or ''}
 if r then
  for _,key in ipairs({'status','interruptedPhase','removalVerified','restored','matchesOriginal','error'})do
   lines[#lines+1]=key..'='..tostring(r[key])
  end
  for i,item in ipairs(r.items)do
   local location=self.inventory:Resolve(item.uid,true,false)
   lines[#lines+1]=string.format('item.%d.uid=%s wornSlot=%s reservedBagSlot=%s actual=%s',i,item.uid,item.equipSlot,item.bagSlot,
    location and (location.bagId..':'..location.slotIndex) or 'missing')
   lines[#lines+1]='item.'..i..'.link='..item.link
  end
  for _,slot in ipairs(KW.Slots.Order)do
   local original=r.original[slot]
   lines[#lines+1]='worn.'..slot..'.original='..(original.uid or 'empty')..' actual='..uid(self.inventory:ReadSlot(self.api.BAG_WORN,slot))
  end
  for i,line in ipairs(r.log)do lines[#lines+1]='event.'..i..'='..line end
  if not r.restored then lines[#lines+1]='Вернуть проверяемые предметы: /kw probe gearrestore' end
 end
 local text=table.concat(lines,'\n');self.saved.latestReport=text;self.saved.reportDisplayError=nil
 local ok,err=pcall(self.report,text)
 if not ok then self.saved.reportDisplayError=tostring(err)end
end
function P:Stop()
 self.active=false
 if self.timer then self.clock:Cancel(self.timer);self.timer=nil end
end
function P:Fail(reason)
 self:Stop();local r=self.saved.run
 if r then r.status='failed';r.error=tostring(reason);self:Log('failure: '..tostring(reason))end
 self:Show(tostring(reason))
 return nil,KW.Problem('gearProbe',{reason=tostring(reason)})
end
function P:Ready()
 if self.canRun and not self.canRun()then return nil,'Сначала завершите применение или редактирование пресета.'end
 if self.api.IsUnitInCombat('player')then return nil,'Проверка недоступна в бою.'end
 if self.api.IsUnitDeadOrReincarnating and self.api.IsUnitDeadOrReincarnating('player')then return nil,'Проверка недоступна, пока персонаж мёртв.'end
 if self.api.IsBlockActive()then return nil,'Отпустите блок перед проверкой.'end
 return true
end
function P:Schedule()
 self.timer=self.clock:Schedule(50,function()
  self.timer=nil
  local ok,err=pcall(function()self:Tick()end)
  if not ok then self:Fail(err)end
 end)
end
function P:Complete()
 local r=self.saved.run
 r.restored=true;r.matchesOriginal=KW.Slots.Equal(r.original,self:Worn());r.status='completed'
 self:Log('restoration verified; matchesOriginal='..tostring(r.matchesOriginal));self:Stop()
 self:Show(r.removalVerified and 'Пачка снята успешно. Проверяемые предметы возвращены.'
  or 'Предметы возвращены. Успех снятия пачкой не подтверждён.')
end
function P:RestoreNext()
 local r=self.saved.run
 local ready,reason=self:Ready();if not ready then return self:Fail(reason)end
 -- Validate all destinations before restoring anything. Never displace gear
 -- equipped by the player or another addon while the experiment was waiting.
 for _,item in ipairs(r.items)do
  local current=self.inventory:ReadSlot(self.api.BAG_WORN,item.equipSlot)
  if current and current.uid~=item.uid then
   return self:Fail('Возврат остановлен: ячейка '..item.equipSlot..' занята другим предметом ('..current.uid..').')
  end
 end
 for _,item in ipairs(r.items)do
  if uid(self.inventory:ReadSlot(self.api.BAG_WORN,item.equipSlot))~=item.uid then
   local source=self.inventory:Resolve(item.uid,true,false)
   if not source or source.bagId~=self.api.BAG_BACKPACK then return self:Fail('Предмет для возврата не найден в сумке: '..item.uid)end
   self.waiting=item;self.deadline=self.clock:NowMs()+5000
   self:Log('restore send uid='..item.uid..' from='..source.bagId..':'..source.slotIndex..' to='..item.equipSlot)
   local ok,problem=self.inventory:Request({kind='equip',uid=item.uid,equipSlot=item.equipSlot})
   if not ok then return self:Fail('Не удалось запросить возврат '..item.uid..': '..tostring(problem and problem.code))end
   self:Schedule();return true
  end
 end
 self:Complete();return true
end
function P:Tick()
 if not self.active then return end
 local r=self.saved.run
 if r.status=='removing'then
  local all=true;local observation={}
  for _,item in ipairs(r.items)do
   local worn=uid(self.inventory:ReadSlot(self.api.BAG_WORN,item.equipSlot))
   local bag=uid(self.inventory:ReadSlot(self.api.BAG_BACKPACK,item.bagSlot))
   if worn~='empty' and worn~=item.uid then return self:Fail('Проверка остановлена: ячейка '..item.equipSlot..' занята другим предметом ('..worn..').')end
   if worn~='empty' or bag~=item.uid then all=false end
   observation[#observation+1]=item.uid..' worn='..worn..' reserved='..bag
  end
  local observed=table.concat(observation,'; ')
  if self.observation~=observed then self.observation=observed;self:Log(observed)end
  if all then
   r.removalVerified=true;self:Log('both removals verified');r.status='restoring'
   self:RestoreNext();return
  end
 elseif r.status=='restoring' and self.waiting then
  local item=self.waiting
  if uid(self.inventory:ReadSlot(self.api.BAG_WORN,item.equipSlot))==item.uid then
   self:Log('restore verified uid='..item.uid);self.waiting=nil;self:RestoreNext();return
  end
 end
 if self.clock:NowMs()>=self.deadline then
  return self:Fail(r.status=='removing' and 'За 5 секунд оба снятия не подтвердились. Ниже — фактическое положение каждого предмета.'
   or 'За 5 секунд возврат предмета '..self.waiting.uid..' не подтвердился.')
 end
 self:Schedule()
end
function P:Start()
 local api=self.api;local prior=self.saved.run
 if prior and not prior.restored then return nil,'Предыдущая проверка не завершена. Сначала выполните /kw probe gearrestore.'end
 if type(api.GetBagSize)~='function' or type(api.CallSecureProtected)~='function'then return nil,'Нет API для проверки снятия в заданные ячейки.'end
 local items={}
 for _,slot in ipairs({api.EQUIP_SLOT_HEAD,api.EQUIP_SLOT_SHOULDERS,api.EQUIP_SLOT_CHEST,api.EQUIP_SLOT_HAND,
  api.EQUIP_SLOT_WAIST,api.EQUIP_SLOT_LEGS,api.EQUIP_SLOT_FEET})do
  local item=self.inventory:ReadSlot(api.BAG_WORN,slot)
  if item then
   local metadata=self.inventory:Metadata(item.link,item,false)
   if metadata.availableToEquip and not metadata.mythic and not metadata.uniqueEquipped and not metadata.bindingRequired then
    items[#items+1]={uid=item.uid,link=item.link,equipSlot=slot}
    if #items==2 then break end
   end
  end
 end
 if #items<2 then return nil,'Для проверки нужны два надетых обычных предмета брони, кроме мификов.'end
 local free={}
 for slot=0,api.GetBagSize(api.BAG_BACKPACK)-1 do
  if not self.inventory:ReadSlot(api.BAG_BACKPACK,slot)then free[#free+1]=slot;if #free==2 then break end end
 end
 if #free<2 then return nil,'Для проверки нужны две свободные ячейки сумки.'end
 for i,item in ipairs(items)do item.bagSlot=free[i]end
 self.saved.run={status='removing',items=items,original=self:Worn(),log={},removalVerified=false,restored=false}
 self.active=true;self.observation=nil;self.deadline=self.clock:NowMs()+5000
 -- No waits, callbacks or bag rescans between dispatches: both destinations
 -- were reserved above. Server acceptance is established only by Tick.
 for _,item in ipairs(items)do
  self:Log('remove send uid='..item.uid..' from='..item.equipSlot..' to='..item.bagSlot)
  local dispatched,result=api.CallSecureProtected('RequestMoveItem',api.BAG_WORN,item.equipSlot,api.BAG_BACKPACK,item.bagSlot,1)
  self:Log('remove dispatch='..tostring(dispatched)..' result='..tostring(result))
 end
 self:Schedule();return true
end
function P:Run(command)
 if command=='gearreport'then self:Show(self.saved.run and nil or 'Проверка ещё не запускалась. Команда: /kw probe gearbatch');return true end
 if self.active then
  local reason='Проверка уже выполняется. Дождитесь автоматического отчёта.'
  if self.api.d then self.api.d(reason)end
  return nil,KW.Problem('gearProbe',{reason=reason})
 end
 local ok,result,reason=pcall(function()
  local ready,blocked=self:Ready();if not ready then return nil,blocked end
  if command=='gearbatch'then return self:Start()end
  if command=='gearrestore' and self.saved.run then
   self.active=true;self.saved.run.status='restoring';self:Log('explicit restore requested')
   return self:RestoreNext()
  end
  return nil,'Нет сохранённой проверки для возврата.'
 end)
 if not ok then return self:Fail(result)end
 if not result and type(reason)=='string'then
  self:Show(reason);return nil,KW.Problem('gearProbe',{reason=reason})
 end
 return result,reason
end
return G
