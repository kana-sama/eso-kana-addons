local T=dofile('KanaStatSources/tests/support.lua');local K=T.load({'Core','Stats','Rules','Descriptions','sources/Equipment'})
local function snapshot() return {meta={language='en'},context={bar='front'},equipment={},sets={},constants={EQUIP_SLOT_MAIN_HAND=4,EQUIP_SLOT_OFF_HAND=5,EQUIP_SLOT_BACKUP_MAIN=20,EQUIP_SLOT_BACKUP_OFF=21,ITEM_TRAIT_TYPE_ARMOR_INFUSED=16,ITEM_TRAIT_TYPE_WEAPON_PRECISE=4}} end
return {
 triune_and_impenetrable=function()
    local s=snapshot();s.meta.language='ru';s.constants.ITEM_TRAIT_TYPE_JEWELRY_TRIUNE=32;s.constants.ITEM_TRAIT_TYPE_ARMOR_IMPENETRABLE=2
    s.equipment={{slot=1,name='Ring',trait={id=32,description='Увеличивает максимальную магию на 439, максимальное здоровье на 482 и максимальный запас сил на 439.'}},{slot=2,name='Armor',trait={id=2,description='Увеличивает сопротивляемость критическому урону на 127. Уменьшает потерю прочности на 50%.'}}}
    local c=K.Sources.Equipment.Build(s);local sums={};for _,v in ipairs(c)do sums[v.stat]=(sums[v.stat] or 0)+v.amount end
    T.eq(sums.maxHealth,482);T.eq(sums.maxMagicka,439);T.eq(sums.maxStamina,439);T.eq(sums.criticalResistance,127)
 end,
 trait_locale_not_guessed=function()
    local s=snapshot();s.meta.language='fr';s.equipment={{slot=4,name='Weapon',trait={id=4,description='Augmente le critique de 7,5%.'}}}
    local c,d=K.Sources.Equipment.Build(s);T.eq(#c,0);T.eq(#d>0,true)
 end,
 same_named_slots_visible=function()
    local s=snapshot();s.equipment={{slot=1,name='Ring',enchant={description='Adds 1000 Maximum Magicka.',hasCharges=false}},{slot=2,name='Ring',enchant={description='Adds 1000 Maximum Magicka.',hasCharges=false}}};s.constants.EQUIP_SLOT_RING1=1;s.constants.EQUIP_SLOT_RING2=2;s.slotNames={[1]='Ring 1',[2]='Ring 2'}
    local c=K.Sources.Equipment.Build(s);T.eq(c[1].label~=c[2].label,true)
    T.eq(c[1].label:find('Ring 1',1,true)~=nil,true)
 end,
 pieces=function() local s=snapshot();for i=1,2 do s.equipment[i]={slot=i,name='Same',armorRating=1200,enchant={description='Adds 868 Maximum Magicka.',hasCharges=false},trait={id=16,description='Increases enchantment by 25%.'}} end;local c=K.Sources.Equipment.Build(s);T.eq(#c,6);T.eq(c[1].amount,1200);T.eq(c[3].amount,868);T.eq(c[3].key~=c[6].key,true) end,
 active_bar=function() local s=snapshot();s.constants.ITEM_TRAIT_TYPE_WEAPON_SHARPENED=7;s.equipment={{slot=20,weaponPower=1800,trait={id=7,description='Increases Physical and Spell Penetration by 1500.'}},{slot=4,weaponPower=1800,trait={id=7,description='Increases Physical and Spell Penetration by 1500.'}},{slot=5,armorRating=1700}};local c=K.Sources.Equipment.Build(s);T.eq(#c,6);for _,r in ipairs(c) do T.eq(r.source.slot~=20,true) end end,
 dual_wield_without_type_or_context_stays_unknown=function() local s=snapshot();s.equipment={{slot=4,weaponPower=1500},{slot=5,weaponPower=1500}};local c,d=K.Sources.Equipment.Build(s);T.eq(#c,2);T.eq(#d>0,true) end,
 sets=function() local s=snapshot();s.sets={[1]={id=1,familyId=1,name='Set',normal=3,perfected=2,bonuses={{index=1,required=2,description='Adds 1096 Maximum Magicka.'},{index=2,required=5,description='Adds 129 Weapon and Spell Damage.'}}},[2]={id=2,familyId=1,name='Perfected Set',normal=3,perfected=2,bonuses={{index=1,required=2,description='Adds 1096 Maximum Magicka.'},{index=2,required=5,description='Adds 129 Weapon and Spell Damage.'},{index=3,required=5,perfected=true,description='Adds 657 Critical Chance.'}}}};local c=K.Sources.Equipment.Build(s);T.eq(#c,3) end,
 charged_glyph=function() local s=snapshot();s.equipment={{slot=4,name='Sword',enchant={hasCharges=true,description='Adds 452 Weapon and Spell Damage for 5 seconds.'}}};local c,d=K.Sources.Equipment.Build(s);T.eq(#c,0);T.eq(#d,1) end,
}
