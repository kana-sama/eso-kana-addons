-- Relevant raw input from dump #7, API 101051. Two identical purple
-- CP160 Precise daggers and 160 Precision CP rating; no identity or outcomes.
local samples={
    {rating=0,chance=0},
    {rating=1,chance=0.0045637093},
    {rating=100,chance=0.4563709199},
    {rating=1000,chance=4.563709259},
    {rating=3699,chance=16.8811607361},
    {rating=4699,chance=21.4448699951},
}
local function dagger(slot)
    return {id=87874,slot=slot,weaponType=11,level=50,cp=160,quality=4,condition=100,weaponPower=1132,
        name='Смертоносный кинжал',icon='/esoui/art/icons/gear_ebonheart_dagger_a.dds',
        trait={id=3,name='Точность',description='Увеличивает рейтинг критического удара оружием и заклинаниями на |cffffff3,1%|r.'}}
end
return {
    consistent=true,meta={apiVersion=101051,language='ru'},
    context={level=50,championPoints=527,battleLeveled=false,championBattleLeveled=false,bar='front',hotbarCategory=0,weaponPair=1},
    constants={ITEM_TRAIT_TYPE_WEAPON_PRECISE=3,WEAPONTYPE_DAGGER=11,EQUIP_SLOT_MAIN_HAND=4,EQUIP_SLOT_OFF_HAND=5,EQUIP_SLOT_BACKUP_MAIN=20,EQUIP_SLOT_BACKUP_OFF=21},
    attributes={},equipment={dagger(4),dagger(5)},
    champion={{id=11,name='Точность',points=10,slottable=false,disciplineId=1,disciplineType=0,icon='EsoUI/Art/Champion/champion_points_magicka_icon.dds',
        currentBonus='Увеличение показателя крит. удара на |cffffff160|r',description='Показатель крит. удара увеличивается на |cffffff160|r за каждую стадию.'}},
    stats={weaponCritical={total=3699,withoutBonus=2181},spellCritical={total=3699,withoutBonus=2181}},
    criticalSamples={weaponCritical=samples,spellCritical=samples},
}
