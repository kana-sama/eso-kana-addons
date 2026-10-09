local KW=KanaWardrobe
local C={};KW.GearProbeCases=C
local function empty()return {kind='empty'}end
local function ref(item)return {kind='item',uid=item.uid,link=item.link}end
local function action(kind,item,slot,method)return {kind=kind,uid=item.uid,equipSlot=slot,method=method}end
local function phase(actions,expected)return {actions=actions,expected=expected}end

-- Descriptions of experiments, not production capability flags. Even a passed
-- case records one observed execution; it does not enable an API assumption.
function C.Build(state,api)
 local cases,items={},{}
 local armorSlots={api.EQUIP_SLOT_HEAD,api.EQUIP_SLOT_SHOULDERS,api.EQUIP_SLOT_CHEST,api.EQUIP_SLOT_HAND,
  api.EQUIP_SLOT_WAIST,api.EQUIP_SLOT_LEGS,api.EQUIP_SLOT_FEET}
 local typeSlots={
  [api.EQUIP_TYPE_HEAD]=api.EQUIP_SLOT_HEAD,[api.EQUIP_TYPE_SHOULDERS]=api.EQUIP_SLOT_SHOULDERS,
  [api.EQUIP_TYPE_CHEST]=api.EQUIP_SLOT_CHEST,[api.EQUIP_TYPE_HAND]=api.EQUIP_SLOT_HAND,
  [api.EQUIP_TYPE_WAIST]=api.EQUIP_SLOT_WAIST,[api.EQUIP_TYPE_LEGS]=api.EQUIP_SLOT_LEGS,
  [api.EQUIP_TYPE_FEET]=api.EQUIP_SLOT_FEET,[api.EQUIP_TYPE_NECK]=api.EQUIP_SLOT_NECK,
  [api.EQUIP_TYPE_RING]=api.EQUIP_SLOT_RING1,
 }
 for _,item in pairs(state.byUid)do
  local m=item.metadata
  if (item.bagId==api.BAG_WORN or item.bagId==api.BAG_BACKPACK) and m and m.staticEquipable and not m.bindingRequired then
   items[#items+1]=item
  end
 end
 table.sort(items,function(a,b)if a.bagId~=b.bagId then return a.bagId<b.bagId end;return a.slotIndex<b.slotIndex end)
 local eligible={};for _,item in ipairs(items)do eligible[item.uid]=item end
 local function worn(slot)local r=state.worn[slot];return r and eligible[r.uid]end
 local function ordinary(item)return item and not item.metadata.mythic and not item.metadata.uniqueEquipped end
 local armor,all={},{}
 for _,slot in ipairs(armorSlots)do local item=worn(slot);if ordinary(item)then armor[#armor+1]=item end end
 for _,slot in ipairs(KW.Slots.Order)do local item=worn(slot);if item then all[#all+1]=item end end
 local function add(id,title,setup,batches,skip)
  local c={id=id,title=title,setup=setup or {},batches=batches or {},skip=skip,status='pending',phases={}}
  cases[#cases+1]=c;return c
 end
 local function roundtrip(list,method,repeats)
  local batches={}
  for _=1,repeats or 1 do
   local remove,equip,gone,back={},{},{},{}
   for _,item in ipairs(list)do
    local slot=item.slotIndex
    remove[#remove+1]=action('unequip',item,slot);equip[#equip+1]=action('equip',item,slot,method)
    gone[slot]=empty();back[slot]=ref(item)
   end
   batches[#batches+1]=phase(remove,gone);batches[#batches+1]=phase(equip,back)
  end
  return batches
 end
 local armorSkip=#armor<2 and 'Нужны хотя бы два надетых обычных предмета брони.' or nil
 add('armor_batch','Броня пачкой: снять и надеть, два повтора',nil,roundtrip(armor,nil,2),armorSkip)
 add('armor_batch_ww','Броня пачкой через EquipItem, как в WW',nil,roundtrip(armor,'ww'),armorSkip or (not api.EquipItem and 'EquipItem недоступен.' or nil))
 local transformed=api.IsPlayerInWerewolfForm and api.IsPlayerInWerewolfForm()
 add('all_equipment','Весь надетый эквип одной пачкой',nil,roundtrip(all),#all<2 and 'Нужно хотя бы два предмета.' or transformed and 'Персонаж в форме вервольфа.' or nil)

 local replacements,targets,used={},{},{}
 for _,slot in ipairs(KW.Slots.Order)do
  local old=worn(slot)
  if ordinary(old) and typeSlots[old.metadata.equipType]then
   for _,item in ipairs(items)do
    if item.bagId==api.BAG_BACKPACK and ordinary(item) and not used[item.uid] and item.metadata.equipType==old.metadata.equipType then
     replacements[#replacements+1]=action('equip',item,slot);targets[slot]=ref(item);used[item.uid]=true;break
    end
   end
  end
 end
 add('replacements','Замена вещей из сумки без предварительного снятия',nil,{phase(replacements,targets)},#replacements<2 and 'Нужны хотя бы две подходящие сменные вещи в сумке.' or nil)
 if #armor>=2 then
  local a,b=armor[1],armor[2];local sa,sb=a.slotIndex,b.slotIndex
  add('mixed_empty','Снятие и надевание в пустой слот в одной пачке',{[sa]=empty()},
   {phase({action('unequip',b,sb),action('equip',a,sa)},{[sa]=ref(a),[sb]=empty()}),phase({action('equip',b,sb)},{[sb]=ref(b)})})
 else add('mixed_empty','Смешанная пачка с пустым слотом',nil,nil,armorSkip)end
 local replacement=replacements[1];local remove
 if replacement then for _,item in ipairs(armor)do if item.slotIndex~=replacement.equipSlot then remove=item;break end end end
 if remove then
  add('mixed_replacement','Снятие и замена занятого слота в одной пачке',nil,
   {phase({action('unequip',remove,remove.slotIndex),replacement},{[remove.slotIndex]=empty(),[replacement.equipSlot]=targets[replacement.equipSlot]})})
 else add('mixed_replacement','Смешанная пачка с заменой вещи',nil,nil,'Нет сменной вещи и независимого занятого слота брони.')end

 local rings,mythics,onehand,offhand,twohand={},{},nil,nil,nil
 for _,item in ipairs(items)do
  local m=item.metadata
  if ordinary(item)then
   if m.equipType==api.EQUIP_TYPE_RING then rings[#rings+1]=item end
   if m.equipType==api.EQUIP_TYPE_ONE_HAND and not onehand then onehand=item
   elseif m.equipType==api.EQUIP_TYPE_OFF_HAND and not offhand then offhand=item
   elseif m.equipType==api.EQUIP_TYPE_TWO_HAND and not twohand then twohand=item end
  elseif m.mythic and typeSlots[m.equipType]then mythics[#mythics+1]=item end
 end
 local l,r=api.EQUIP_SLOT_RING1,api.EQUIP_SLOT_RING2
 if rings[1]then
  local a=rings[1]
  add('ring_move','Прямой перенос надетого кольца в пустой слот',{[l]=ref(a),[r]=empty()},
   {phase({action('equip',a,r)},{[l]=empty(),[r]=ref(a)})})
 else add('ring_move','Прямой перенос кольца',nil,nil,'Нет обычного кольца.')end
 if rings[2]then
  local a,b=rings[1],rings[2];local setup={[l]=ref(a),[r]=ref(b)};local swapped={[l]=ref(b),[r]=ref(a)}
  add('ring_swap','Обмен двух надетых колец одним запросом',setup,{phase({action('equip',a,r)},swapped)})
  add('ring_swap_bag','Обмен колец: снять пачкой, затем надеть пачкой',setup,
   {phase({action('unequip',a,l),action('unequip',b,r)},{[l]=empty(),[r]=empty()}),phase({action('equip',a,r),action('equip',b,l)},swapped)})
 else
  add('ring_swap','Обмен колец одним запросом',nil,nil,'Нужны два обычных кольца.')
  add('ring_swap_bag','Обмен колец через сумку',nil,nil,'Нужны два обычных кольца.')
 end
 if mythics[2]then
  local a,b=mythics[1],mythics[2]
  local sa=a.bagId==api.BAG_WORN and a.slotIndex or typeSlots[a.metadata.equipType]
  local sb=typeSlots[b.metadata.equipType]
  local target={[sa]=empty()};target[sb]=ref(b)
  add('mythic_direct','Замена мифика без снятия старого',{[sa]=ref(a)},{phase({action('equip',b,sb)},target)})
  local removeActions,equipActions,gone={action('unequip',a,sa)},{action('equip',b,sb)},{[sa]=empty()}
  for _,item in ipairs(armor)do
   local slot=item.slotIndex
   if slot~=sa and slot~=sb and #removeActions<3 then
    removeActions[#removeActions+1]=action('unequip',item,slot);gone[slot]=empty()
    equipActions[#equipActions+1]=action('equip',item,slot);target[slot]=ref(item)
   end
  end
  add('mythic_staged','Мифик: снять старый, затем надеть новый с бронёй пачкой',{[sa]=ref(a)},
   {phase(removeActions,gone),phase(equipActions,target)})
 else
  add('mythic_direct','Мифик без предварительного снятия',nil,nil,'Нужны два доступных мифика.')
  add('mythic_staged','Мифик с предварительным снятием',nil,nil,'Нужны два доступных мифика.')
 end
 local main,off=api.EQUIP_SLOT_MAIN_HAND,api.EQUIP_SLOT_OFF_HAND
 local weaponSkip=transformed and 'Персонаж в форме вервольфа.' or nil
 if onehand and offhand and twohand then
  add('twohand_clear','Двуручное оружие без предварительного снятия щита',{[main]=ref(onehand),[off]=ref(offhand)},
   {phase({action('equip',twohand,main)},{[main]=ref(twohand),[off]=empty()})},weaponSkip)
  add('twohand_pair','Смена двуручного оружия на оружие и щит одной пачкой',{[main]=ref(twohand),[off]=empty()},
   {phase({action('equip',onehand,main),action('equip',offhand,off)},{[main]=ref(onehand),[off]=ref(offhand)})},weaponSkip)
 else
  add('twohand_clear','Автоматическое снятие щита',nil,nil,'Нужны двуручное оружие, одноручное оружие и щит.')
  add('twohand_pair','Оружие и щит одной пачкой',nil,nil,'Нужны двуручное оружие, одноручное оружие и щит.')
 end
 local weapon=onehand or twohand;local back=api.EQUIP_SLOT_BACKUP_MAIN
 if weapon then
  local availability=state.slotAvailability and state.slotAvailability[back]
  add('weapon_transfer','Прямой перенос оружия на другую панель',{[main]=ref(weapon),[off]=empty(),[back]=empty(),[api.EQUIP_SLOT_BACKUP_OFF]=empty()},
   {phase({action('equip',weapon,back)},{[main]=empty(),[back]=ref(weapon)})},weaponSkip or availability and availability.available==false and 'Вторая панель недоступна.' or nil)
 else add('weapon_transfer','Перенос оружия между панелями',nil,nil,'Нет подходящего оружия.')end
 local fullSkip=state.freeSlots~=0 and 'Сумка не заполнена; специально заполнять её проверка не будет.' or not replacement and 'Нет подходящей сменной вещи.' or nil
 add('full_bag','Замена вещи при полностью заполненной сумке',nil,
  replacement and {phase({replacement},{[replacement.equipSlot]=targets[replacement.equipSlot]})} or {},fullSkip)
 if state.freeSlots==0 then for _,c in ipairs(cases)do
  if c.id~='full_bag' and not c.skip then c.skip='Нет места для подготовки и возврата; в полной сумке проверяется только прямая замена.'end
 end end
 return cases
end
return C
