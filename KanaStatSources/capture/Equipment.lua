local K=KanaStatSources
K.CaptureEquipment={}
function K.CaptureEquipment.Read(api,capabilities)
    local data={equipment={},sets={}},errors
    errors={};local read=K.Core.Reader(api,errors,capabilities)
    local first,last=api.EQUIP_SLOT_ITERATION_BEGIN,api.EQUIP_SLOT_ITERATION_END
    if not first or not last then errors[#errors+1]={api='equip slots',reason='slot iteration unavailable'};return data,errors end
    for slot=first,last do
        local link=read('GetItemLink',api.BAG_WORN,slot,api.LINK_STYLE_DEFAULT)
        if link and link~='' then
            local r={slot=slot,link=link,name=read('GetItemLinkName',link),id=read('GetItemLinkItemId',link)}
            r.slotName=read('GetString','SI_EQUIPSLOT',slot)
            if slot==api.EQUIP_SLOT_RING1 or slot==api.EQUIP_SLOT_RING2 then r.slotName=(r.slotName or '')..' '..(slot==api.EQUIP_SLOT_RING1 and '1' or '2')end
            for field,fn in pairs({armorType='GetItemLinkArmorType',weaponType='GetItemLinkWeaponType',equipType='GetItemLinkEquipType',level='GetItemLinkRequiredLevel',cp='GetItemLinkRequiredChampionPoints',quality='GetItemLinkDisplayQuality',condition='GetItemLinkCondition',charges='GetItemLinkNumEnchantCharges',enchantId='GetItemLinkFinalEnchantId'}) do r[field]=read(fn,link) end
            r.armorRating=read('GetItemLinkArmorRating',link,true);r.weaponPower=read('GetItemLinkWeaponPower',link)
            local traitId,traitDescription=read('GetItemLinkTraitInfo',link)
            r.trait={id=traitId,description=traitDescription,name=traitId and read('GetString','SI_ITEMTRAITTYPE',traitId)}
            local _,enchantName,enchantDescription=read('GetItemLinkEnchantInfo',link)
            r.enchant={name=enchantName,description=enchantDescription,hasCharges=read('DoesItemLinkHaveEnchantCharges',link)}
            local hasSet,name,count,normal,max,id,perfect=read('GetItemLinkSetInfo',link,true)
            if hasSet and id then
                local family=read('GetItemSetUnperfectedSetId',id)
                r.setId=id;r.familyId=family and family>0 and family or id
                local set=data.sets[id]
                if not set then
                    set={id=id,familyId=r.familyId,name=name,normal=normal,perfected=perfect,max=max,bonuses={}}
                    data.sets[id]=set
                    for i=1,count or 0 do
                        local required,description,isPerfect=read('GetItemLinkSetBonusInfo',link,true,i)
                        set.bonuses[#set.bonuses+1]={index=i,required=required,description=description,perfected=isPerfect}
                    end
                end
            end
            r.poison=read('IsItemAffectedByPairedPoison',slot)
            data.equipment[#data.equipment+1]=r
        end
    end
    return data,errors
end
