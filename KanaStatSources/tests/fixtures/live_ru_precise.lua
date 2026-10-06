-- Critical/item input fields from controlled dump #6, API 101051.
-- Only a CP160 purple Precise lightning staff; no character identity,
-- computed contributions or breakdowns. Naked dump #4 supplies the control.
local samples={
    {rating=0,chance=0},
    {rating=1,chance=0.0045637093},
    {rating=100,chance=0.4563709199},
    {rating=1000,chance=4.563709259},
    {rating=3539,chance=16.1509666443},
    {rating=4539,chance=20.7146759033},
}
return {
    consistent=true,
    meta={apiVersion=101051,language='ru'},
    context={level=50,championPoints=527,battleLeveled=false,championBattleLeveled=false,bar='front',hotbarCategory=0,weaponPair=1},
    constants={ITEM_TRAIT_TYPE_WEAPON_PRECISE=3,WEAPONTYPE_LIGHTNING_STAFF=15,EQUIP_SLOT_MAIN_HAND=4},
    attributes={},
    equipment={{
        id=87878,slot=4,weaponType=15,level=50,cp=160,quality=4,condition=100,weaponPower=1132,
        name='Смертоносный грозовой посох',icon='/esoui/art/icons/gear_ebonheart_staff_a.dds',
        trait={id=3,name='Точность',description='Увеличивает рейтинг критического удара оружием и заклинаниями на |cffffff6,2%|r.'},
    }},
    stats={weaponCritical={total=3539,withoutBonus=2181},spellCritical={total=3539,withoutBonus=2181}},
    criticalSamples={weaponCritical=samples,spellCritical=samples},
}
