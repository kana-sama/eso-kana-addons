local K=KanaStatSources
K.CaptureEquipment={}
function K.CaptureEquipment.Identity(equipment)
    local out={};for i,e in ipairs(equipment)do out[i]={slot=e.slot,link=e.link}end
    return K.Core.Signature(out)
end
function K.CaptureEquipment.ReadInfo(api,capabilities)
    local errors={};local read=K.Core.Reader(api,errors,capabilities);local out={}
    for slot=api.EQUIP_SLOT_ITERATION_BEGIN or 0,api.EQUIP_SLOT_ITERATION_END or -1 do
        local link=read('GetItemLink',api.BAG_WORN,slot,api.LINK_STYLE_DEFAULT)
        if link and link~='' then out[#out+1]={slot=slot,link=link}end
    end
    return out,errors
end
-- These independent native readings are diagnostic only. They never replace
-- a source amount or run while hovering a stat; a full dump requests them.
function K.CaptureEquipment.Audit(api,equipment,capabilities)
    local out={equipmentAudit={},setAudit={}};local errors={};local read=K.Core.Reader(api,errors,capabilities)
    local function bonus(fn,...)
        local required,description,perfected=read(fn,...)
        return {required=required,description=description,perfected=perfected}
    end
    for _,item in ipairs(equipment or {})do
        local r={slot=item.slot,link=item.link,statValue=read('GetItemStatValue',api.BAG_WORN,item.slot),weaponPower=read('GetItemLinkWeaponPower',item.link)}
        out.equipmentAudit[#out.equipmentAudit+1]=r
        local hasSet,_,count,_,_,id=read('GetItemLinkSetInfo',item.link,true)
        if hasSet and id then
            r.setId=id;r.equippedBonuses={};r.unequippedBonuses={}
            for i=1,count or 0 do
                r.equippedBonuses[i]=bonus('GetItemLinkSetBonusInfo',item.link,true,i)
                r.unequippedBonuses[i]=bonus('GetItemLinkSetBonusInfo',item.link,false,i)
            end
            if not out.setAudit[id]then
                local set={bonuses={}};out.setAudit[id]=set
                for i=1,count or 0 do set.bonuses[i]=bonus('GetItemSetBonusInfo',id,i)end
            end
        end
    end
    return out,errors
end
function K.CaptureEquipment.Read(api,capabilities)
    local data={equipment={},sets={}},errors
    errors={};local read=K.Core.Reader(api,errors,capabilities)
    local first,last=api.EQUIP_SLOT_ITERATION_BEGIN,api.EQUIP_SLOT_ITERATION_END
    if not first or not last then errors[#errors+1]={api='equip slots',reason='slot iteration unavailable'};return data,errors end
    for slot=first,last do
        local link=read('GetItemLink',api.BAG_WORN,slot,api.LINK_STYLE_DEFAULT)
        if link and link~='' then
            local r={slot=slot,link=link,name=read('GetItemLinkName',link),id=read('GetItemLinkItemId',link),icon=read('GetItemLinkIcon',link)}
            r.slotName=read('GetString','SI_EQUIPSLOT',slot)
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
                -- Read each item's own level/quality values once per equipment
                -- change. Equipped descriptions already average the set and
                -- cannot be used as inputs to the damage averaging rule.
                r.setBonuses={}
                for i=1,count or 0 do
                    local required,description,isPerfect=read('GetItemLinkSetBonusInfo',link,false,i)
                    r.setBonuses[#r.setBonuses+1]={index=i,required=required,description=description,perfected=isPerfect}
                end
                local set=data.sets[id]
                if not set then
                    set={id=id,familyId=r.familyId,name=name,icon=r.icon,normal=normal,perfected=perfect,max=max,bonuses={}}
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
