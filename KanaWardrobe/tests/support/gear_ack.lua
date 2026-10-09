-- Native effects observed by the API 101051 equipment suite.
return function(api,q,index)
 local bag,slot=q[2],q[3];local item=assert(api.bags[bag][slot],'request source missing')
 if q[1]=='equip'then
  local old=api.bags[BAG_WORN][q[5]]
  api.bags[bag][slot]=old;api.bags[BAG_WORN][q[5]]=item
  if api.GetItemLinkEquipType(item.link)==EQUIP_TYPE_TWO_HAND then
   local off=q[5]==EQUIP_SLOT_MAIN_HAND and EQUIP_SLOT_OFF_HAND or q[5]==EQUIP_SLOT_BACKUP_MAIN and EQUIP_SLOT_BACKUP_OFF
   if off and api.bags[BAG_WORN][off]then
    local cell=800+index;while api.bags[BAG_BACKPACK][cell]do cell=cell+1 end
    api.bags[BAG_BACKPACK][cell]=api.bags[BAG_WORN][off];api.bags[BAG_WORN][off]=nil;api.free=api.free-1
   end
  end
 elseif q[1]=='move'then
  assert(not api.bags[q[4]][q[5]],'reserved cell occupied')
  api.bags[bag][slot]=nil;api.bags[q[4]][q[5]]=item;api.free=api.free-1
 else
  api.bags[BAG_BACKPACK][900+index]=item;api.bags[BAG_WORN][slot]=nil;api.free=api.free-1
 end
end
