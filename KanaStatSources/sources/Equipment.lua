local K=KanaStatSources
local E={};K.Sources.Equipment=E
function E.Active(item,s)
    local c=s.constants or {};local bar=(s.context or {}).bar
    if item.slot==c.EQUIP_SLOT_BACKUP_MAIN or item.slot==c.EQUIP_SLOT_BACKUP_OFF then return bar=='back' end
    if item.slot==c.EQUIP_SLOT_MAIN_HAND or item.slot==c.EQUIP_SLOT_OFF_HAND then return bar=='front' end
    return true
end
local traits={JEWELRY_HEALTHY={'maxHealth'},JEWELRY_ARCANE={'maxMagicka'},JEWELRY_ROBUST={'maxStamina'},JEWELRY_PROTECTIVE={'physicalResistance','spellResistance'},ARMOR_PROSPEROUS={'healthRecovery','magickaRecovery','staminaRecovery'},ARMOR_IMPENETRABLE={'criticalResistance'},WEAPON_PRECISE={'weaponCritical','spellCritical'},WEAPON_SHARPENED={'physicalPenetration','spellPenetration'},WEAPON_DEFENDING={'physicalResistance','spellResistance'}}
function E.Build(s)
    local out,diagnostics={},{};local language=(s.meta or {}).language or 'en';local constants=s.constants or {}
    local function parse(source,text,kind)
        local clauses,tail=K.Descriptions.Parse(text,language,kind)
        K.Rules.Emit(out,source,clauses,'native '..kind..' description; complete unconditional stat clause')
        if tail~='' then source.description=text;diagnostics[#diagnostics+1]=K.Core.Diagnostic(source,'unrecognized or conditional description') end
    end
    for _,item in ipairs(s.equipment or {}) do if E.Active(item,s) then
        local root={key='item:'..item.slot,category='equipment',slot=item.slot,link=item.link,id=item.id,label=item.name or tostring(item.slot)}
        local function source(suffix,label) local r=K.Core.CopySerializable(root);r.key=r.key..':'..suffix;r.label=r.label..' — '..label;return r end
        if K.Core.Finite(item.armorRating) and item.armorRating>0 then
            K.Rules.Emit(out,source('armor',language=='ru' and 'броня' or 'armor'),{{stats={'physicalResistance','spellResistance'},amount=item.armorRating,operation='flat'}},'GetItemLinkArmorRating(link, true); includes condition and local armor traits')
        end
        if K.Core.Finite(item.weaponPower) and item.weaponPower>0 then
            if item.slot==constants.EQUIP_SLOT_MAIN_HAND or item.slot==constants.EQUIP_SLOT_BACKUP_MAIN then
                K.Rules.Emit(out,source('power',language=='ru' and 'сила' or 'power'),{{stats={'weaponDamage','spellDamage'},amount=item.weaponPower,operation='flat'}},'GetItemLinkWeaponPower; active main hand')
            elseif item.slot==constants.EQUIP_SLOT_OFF_HAND or item.slot==constants.EQUIP_SLOT_BACKUP_OFF then diagnostics[#diagnostics+1]=K.Core.Diagnostic(source('power','power'),'offhand weapon contribution scaling unverified') end
        end
        if item.enchant and item.enchant.description and item.enchant.description~='' then
            local origin=source('enchant',item.enchant.name or (language=='ru' and 'зачарование' or 'enchantment'))
            if item.enchant.hasCharges==false then parse(origin,item.enchant.description,'enchant')
            else origin.description=item.enchant.description;diagnostics[#diagnostics+1]=K.Core.Diagnostic(origin,'charged enchantment requires an active effect') end
        end
        if item.trait then
            local trait=item.trait;local origin=source('trait',trait.name or 'trait');local handled=false
            for name,stats in pairs(traits) do if constants['ITEM_TRAIT_TYPE_'..name]~=nil and trait.id==constants['ITEM_TRAIT_TYPE_'..name] then
                local _,values=K.Descriptions.Tokens(trait.description,language)
                if #values==1 then K.Rules.Emit(out,origin,{{stats=stats,amount=values[1],operation=name=='WEAPON_PRECISE' and 'criticalChance' or 'flat'}},'native trait ID and item-specific description');handled=true end
            end end
            if trait.id==constants.ITEM_TRAIT_TYPE_JEWELRY_TRIUNE and trait.id~=nil then parse(origin,trait.description,'trait');handled=true end
            for _,name in ipairs({'ARMOR_INFUSED','JEWELRY_INFUSED','WEAPON_INFUSED','ARMOR_REINFORCED','ARMOR_NIRNHONED','WEAPON_NIRNHONED','ARMOR_DIVINES'}) do if constants['ITEM_TRAIT_TYPE_'..name]~=nil and trait.id==constants['ITEM_TRAIT_TYPE_'..name] then handled=true end end
            if not handled and trait.description and trait.description~='' then diagnostics[#diagnostics+1]=K.Core.Diagnostic(origin,'trait has no verified character-stat rule') end
        end
    end end
    local ids={};for id in pairs(s.sets or {}) do ids[#ids+1]=id end;table.sort(ids)
    local seen={}
    for _,id in ipairs(ids) do local set=s.sets[id]
        for _,bonus in ipairs(set.bonuses or {}) do
            local count=bonus.perfected and set.perfected or ((set.normal or 0)+(set.perfected or 0))
            local family=set.familyId or id;local identity=family..':'..tostring(bonus.required)..':'..tostring(bonus.perfected or false)..':'..K.Descriptions.Clean(bonus.description)
            if count and bonus.required and count>=bonus.required and not seen[identity] then
                seen[identity]=true
                parse({key='set:'..identity,category='sets',id=id,familyId=family,label=(set.name or tostring(id))..' ('..bonus.required..')',required=bonus.required,perfected=bonus.perfected},bonus.description,'set')
            end
        end
    end
    return out,diagnostics
end
