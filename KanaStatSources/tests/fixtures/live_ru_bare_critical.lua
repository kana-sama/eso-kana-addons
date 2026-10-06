-- Critical fields from dump #4, API 101051, addon 1.0.5.
-- No equipment, critical CP, or critical Mundus; no character identity.
local samples={
    {rating=0,chance=0},
    {rating=1,chance=0.0045637093},
    {rating=100,chance=0.4563709199},
    {rating=1000,chance=4.563709259},
    {rating=2181,chance=9.9534492493},
    {rating=3181,chance=14.5171585083},
}
return {
    consistent=true,
    meta={apiVersion=101051,language='ru'},
    context={level=50,championPoints=527,battleLeveled=false,championBattleLeveled=false},
    attributes={},
    stats={
        weaponCritical={total=2181,withoutBonus=2181},
        spellCritical={total=2181,withoutBonus=2181},
    },
    criticalSamples={weaponCritical=samples,spellCritical=samples},
}
