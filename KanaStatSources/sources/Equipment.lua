local K=KanaStatSources
local E={};K.Sources.Equipment=E
function E.Active(item,s)
    local c=s.constants or {};local bar=(s.context or {}).bar
    if item.slot==c.EQUIP_SLOT_BACKUP_MAIN or item.slot==c.EQUIP_SLOT_BACKUP_OFF then return bar=='back' end
    if item.slot==c.EQUIP_SLOT_MAIN_HAND or item.slot==c.EQUIP_SLOT_OFF_HAND then return bar=='front' end
    return true
end
local function activeDualWieldOffhand(s)
    local c=s.constants or {};local context=s.context or {};local mainSlot,offSlot,category,pair
    if context.bar=='front' then mainSlot,offSlot,category,pair=c.EQUIP_SLOT_MAIN_HAND,c.EQUIP_SLOT_OFF_HAND,c.HOTBAR_CATEGORY_PRIMARY,1
    elseif context.bar=='back' then mainSlot,offSlot,category,pair=c.EQUIP_SLOT_BACKUP_MAIN,c.EQUIP_SLOT_BACKUP_OFF,c.HOTBAR_CATEGORY_BACKUP,2
    else return nil end
    if not K.Core.Finite(category) or context.hotbarCategory~=category or context.weaponPair~=pair then return nil end
    if not K.Core.Finite(mainSlot) or not K.Core.Finite(offSlot) then return nil end
    local main,off
    for _,item in ipairs(s.equipment or {})do
        if item.slot==mainSlot then main=item end
        if item.slot==offSlot then off=item end
    end
    local function oneHand(item)
        if not item then return false end
        for _,name in ipairs({'WEAPONTYPE_AXE','WEAPONTYPE_HAMMER','WEAPONTYPE_SWORD','WEAPONTYPE_DAGGER'})do
            if K.Core.Finite(c[name]) and item.weaponType==c[name] then return true end
        end
        return false
    end
    if oneHand(main) and oneHand(off) and K.Core.Finite(main.weaponPower) and main.weaponPower>0 then return off end
end
local traits={JEWELRY_HEALTHY={'maxHealth'},JEWELRY_ARCANE={'maxMagicka'},JEWELRY_ROBUST={'maxStamina'},JEWELRY_PROTECTIVE={'physicalResistance','spellResistance'},ARMOR_PROSPEROUS={'healthRecovery','magickaRecovery','staminaRecovery'},ARMOR_IMPENETRABLE={'criticalResistance'},WEAPON_PRECISE={'weaponCritical','spellCritical'},WEAPON_SHARPENED={'physicalPenetration','spellPenetration'},WEAPON_DEFENDING={'physicalResistance','spellResistance'}}
local function triune(description,language)
    local template,values=K.Descriptions.Tokens(description,language)
    if #values~=3 then return nil end
    local clauses={}
    for _,resource in ipairs({{'maxHealth',{'health','здоровье','здоровья'}},{'maxMagicka',{'magicka','магии','магия','магию'}},{'maxStamina',{'stamina','запас сил','запаса сил'}}})do
        local index
        for _,name in ipairs(resource[2])do index=template:match(name..' by @([0-9]+)@') or template:match(name..' на @([0-9]+)@');if index then break end end
        if not index then return nil end
        clauses[#clauses+1]={stats={resource[1]},amount=values[tonumber(index)],operation='flat'}
    end
    return clauses
end
local function damageClause(clause)
    if clause.operation~='flat' or not K.Core.Finite(clause.amount) or clause.amount<0 then return false end
    for _,stat in ipairs(clause.stats)do if stat~='weaponDamage' and stat~='spellDamage' then return false end end
    return #clause.stats>0
end
local function setItemWeight(item,s)
    local c=s.constants or {};local context=s.context or {}
    local weapon=item.slot==c.EQUIP_SLOT_MAIN_HAND or item.slot==c.EQUIP_SLOT_OFF_HAND or item.slot==c.EQUIP_SLOT_BACKUP_MAIN or item.slot==c.EQUIP_SLOT_BACKUP_OFF
    if not weapon then return 1 end
    local category=context.bar=='front' and c.HOTBAR_CATEGORY_PRIMARY or context.bar=='back' and c.HOTBAR_CATEGORY_BACKUP
    local pair=context.bar=='front' and 1 or context.bar=='back' and 2
    if not K.Core.Finite(category) or context.hotbarCategory~=category or context.weaponPair~=pair then return nil end
    for _,name in ipairs({'WEAPONTYPE_TWO_HANDED_AXE','WEAPONTYPE_TWO_HANDED_HAMMER','WEAPONTYPE_TWO_HANDED_SWORD','WEAPONTYPE_BOW','WEAPONTYPE_FIRE_STAFF','WEAPONTYPE_FROST_STAFF','WEAPONTYPE_LIGHTNING_STAFF','WEAPONTYPE_HEALING_STAFF'})do
        if K.Core.Finite(c[name]) and item.weaponType==c[name]then return 2 end
    end
    for _,name in ipairs({'WEAPONTYPE_AXE','WEAPONTYPE_HAMMER','WEAPONTYPE_SWORD','WEAPONTYPE_DAGGER','WEAPONTYPE_SHIELD'})do
        if K.Core.Finite(c[name]) and item.weaponType==c[name]then return 1 end
    end
end
local function averageSetDamage(s,set,bonus,clause,language)
    -- Working hypothesis explicitly accepted by the user: average individual
    -- damage values by active set pieces, then floor before percent modifiers.
    -- This rule is limited to flat weapon/spell damage; resource bonuses use
    -- their equipped descriptions, which already reconcile the native totals.
    local family=set.familyId or set.id
    local template=K.Descriptions.Tokens(bonus.description,language)
    local audit={rule='weightedFloor',equippedAmount=clause.amount,numerator=0,denominator=0,samples={}}
    for _,item in ipairs(s.equipment or {})do
        if E.Active(item,s) and (item.familyId or item.setId)==family and (not bonus.perfected or item.setId~=family)then
            local weight=setItemWeight(item,s)
            if not weight then return nil,nil,'active weapon weight unavailable' end
            local amount,matched
            for _,own in ipairs(item.setBonuses or {})do
                if own.required==bonus.required and (own.perfected==true)==(bonus.perfected==true) and K.Descriptions.Tokens(own.description,language)==template then
                    local clauses=K.Descriptions.Parse(own.description,language,'set')
                    for _,candidate in ipairs(clauses)do
                        if damageClause(candidate) and K.Core.Signature(candidate.stats)==K.Core.Signature(clause.stats)then
                            if amount~=nil then return nil,nil,'item bonus description is ambiguous' end
                            amount=candidate.amount;matched=own
                        end
                    end
                end
            end
            if amount==nil then return nil,nil,'item-specific set damage unavailable' end
            audit.numerator=audit.numerator+amount*weight;audit.denominator=audit.denominator+weight
            audit.samples[#audit.samples+1]={slot=item.slot,link=item.link,setId=item.setId,amount=amount,weight=weight,index=matched.index,description=matched.description}
        end
    end
    if audit.denominator==0 then return nil,nil,'active set items unavailable' end
    local count=bonus.perfected and set.perfected or ((set.normal or 0)+(set.perfected or 0))
    if audit.denominator~=count then return nil,nil,'active item weights disagree with native set count' end
    audit.mean=audit.numerator/audit.denominator;audit.amount=math.floor(audit.mean)
    return audit.amount,audit
end
function E.Build(s)
    local out,diagnostics={},{};local language=(s.meta or {}).language or 'en';local constants=s.constants or {}
    local dualWieldOffhand=activeDualWieldOffhand(s)
    local function parse(source,text,kind,set,bonus)
        local clauses,tail=K.Descriptions.Parse(text,language,kind)
        if set and bonus then
            clauses=K.Core.CopySerializable(clauses)
            for _,clause in ipairs(clauses)do if damageClause(clause)then
                local amount,audit,reason=averageSetDamage(s,set,bonus,clause,language)
                if amount~=nil then
                    clause.amount=amount;source.damageAverages=source.damageAverages or {}
                    for _,stat in ipairs(clause.stats)do source.damageAverages[stat]=audit end
                else diagnostics[#diagnostics+1]=K.Core.Diagnostic(source,'set damage averaging: '..reason)end
            end end
        end
        local start=#out
        K.Rules.Emit(out,source,clauses,'native '..kind..' description; complete unconditional stat clause')
        for i=start+1,#out do
            if source.damageAverages and source.damageAverages[out[i].stat]then
                out[i].ruleId='setDamage:weightedFloor'
                out[i].evidence='user-accepted working rule; floor(weighted mean of individual native set damage values); active two-handed weapons count twice; other items once'
            end
        end
        if tail~='' then source.description=text;local d=K.Core.Diagnostic(source,'unrecognized or conditional description');d.unparsed=tail;diagnostics[#diagnostics+1]=d end
    end
    for _,item in ipairs(s.equipment or {}) do if E.Active(item,s) then
        local slotName=item.slotName or (s.slotNames or {})[item.slot] or ('#'..item.slot)
        local root={key='item:'..item.slot,category='equipment',slot=item.slot,link=item.link,id=item.id,name=item.name or tostring(item.slot),icon=item.icon,label=(item.name or tostring(item.slot))..' ['..slotName..']'}
        local function source(suffix,label) local r=K.Core.CopySerializable(root);r.key=r.key..':'..suffix;r.label=r.label..' — '..label;return r end
        if K.Core.Finite(item.armorRating) and item.armorRating>0 then
            K.Rules.Emit(out,source('armor',language=='ru' and 'броня' or 'armor'),{{stats={'physicalResistance','spellResistance'},amount=item.armorRating,operation='flat'}},'GetItemLinkArmorRating(link, true); includes condition and local armor traits')
        end
        if K.Core.Finite(item.weaponPower) and item.weaponPower>0 then
            if item.slot==constants.EQUIP_SLOT_MAIN_HAND or item.slot==constants.EQUIP_SLOT_BACKUP_MAIN then
                K.Rules.Emit(out,source('power',language=='ru' and 'сила' or 'power'),{{stats={'weaponDamage','spellDamage'},amount=item.weaponPower,operation='flat'}},'GetItemLinkWeaponPower; active main hand')
            elseif item==dualWieldOffhand then
                -- The item's full native power already includes local traits.
                -- Quantize the offhand's base contribution before the shared
                -- additive damage percentages. UESP uses this coefficient for
                -- all offhand weapons; dumps #7-#10 independently reconcile it.
                local origin=source('power',language=='ru' and 'сила' or 'power')
                origin.weaponPower=item.weaponPower;origin.offhandFactor=0.178
                K.Rules.Emit(out,origin,{{stats={'weaponDamage','spellDamage'},amount=math.floor(item.weaponPower*178/1000),operation='flat'}},'GetItemLinkWeaponPower; active normal dual-wield bar; floor(native offhand power * 0.178); UESP item formula and controlled API 101051 dumps #9/#10')
            elseif item.slot==constants.EQUIP_SLOT_OFF_HAND or item.slot==constants.EQUIP_SLOT_BACKUP_OFF then diagnostics[#diagnostics+1]=K.Core.Diagnostic(source('power','power'),'offhand weapon type or active normal dual-wield context unavailable') end
        end
        if item.enchant and item.enchant.description and item.enchant.description~='' then
            local origin=source('enchant',item.enchant.name or (language=='ru' and 'зачарование' or 'enchantment'))
            if item.enchant.hasCharges==false then parse(origin,item.enchant.description,'enchant')
            else origin.description=item.enchant.description;diagnostics[#diagnostics+1]=K.Core.Diagnostic(origin,'charged enchantment requires an active effect') end
        end
        if item.trait then
            local trait=item.trait;local origin=source('trait',trait.name or 'trait');local handled=false
            for name,stats in pairs(traits) do if (language=='ru' or language=='en') and constants['ITEM_TRAIT_TYPE_'..name]~=nil and trait.id==constants['ITEM_TRAIT_TYPE_'..name] then
                local _,values=K.Descriptions.Tokens(trait.description,language)
                if #values==1 then
                    local amount,operation,evidence=values[1],'flat','native trait ID and item-specific description'
                    if name=='WEAPON_PRECISE' then
                        -- The native description already includes weapon size
                        -- and quality. Convert its percentage through the live
                        -- API curve and quantize each item's rating separately.
                        -- No item identity, weapon type or CP160 lookup applies.
                        operation='criticalChanceInteger';origin.description=trait.description
                        evidence='native Precise ID and item-specific percentage; calibrated critical conversion with per-item floor; controlled dumps #6/#7 validate integer trait rating'
                    end
                    K.Rules.Emit(out,origin,{{stats=stats,amount=amount,operation=operation}},evidence)
                    handled=true
                end
                if name=='ARMOR_IMPENETRABLE' and #values>1 then
                    local clauses=K.Descriptions.Parse(trait.description,language,'trait')
                    for _,clause in ipairs(clauses)do if clause.operation=='flat' and clause.stats[1]=='criticalResistance' then K.Rules.Emit(out,origin,{clause},'native Impenetrable trait ID; resistance clause excludes durability modifier');handled=true end end
                end
            end end
            if (language=='ru' or language=='en') and trait.id==constants.ITEM_TRAIT_TYPE_JEWELRY_TRIUNE and trait.id~=nil then
                local clauses=triune(trait.description,language)
                if clauses then K.Rules.Emit(out,origin,clauses,'native Triune trait ID; resource-specific amounts in native item description');handled=true end
            end
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
                parse({key='set:'..identity,category='sets',id=id,familyId=family,name=set.name or tostring(id),icon=set.icon,label=(set.name or tostring(id))..' ('..bonus.required..')',required=bonus.required,perfected=bonus.perfected},bonus.description,'set',set,bonus)
            end
        end
    end
    return out,diagnostics
end
