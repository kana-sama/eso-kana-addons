return function(T)
    local entry = loadfile('KanaPenetration/Model.lua')
    T.test('model exists', function() assert(entry, 'implement the penetration model') end)
    if not entry then return end
    KanaPenetration = {}; entry()
    local M = KanaPenetration.Model
    T.test('personal penetration stays in numerator', function()
        local r = M.Calculate(18200, 7000, 8922)
        T.eq(r.remaining, 9278); T.near(r.percent, 75.4472946756)
        T.eq(r.missing, 2278); T.eq(r.excess, 0); T.eq(r.penetration, 7000)
    end)
    T.test('overpenetration keeps percent while clamping fill', function()
        local r = M.Calculate(9100, 12000, 3100)
        T.eq(r.percent, 200); T.eq(r.fill, 1); T.eq(r.excess, 6000)
    end)
    T.test('fully stripped armor never divides by zero', function()
        local r = M.Calculate(9100, 0, 10000)
        T.eq(r.remaining, 0); T.eq(r.percent, nil); T.eq(r.stripped, true); T.eq(r.fill, 1)
    end)
    T.test('unknown armor remains unknown', function()
        local r = M.Calculate(nil, 9000, 5948)
        T.eq(r.percent, nil); T.eq(r.remaining, nil); T.eq(r.fill, 0)
    end)
    T.test('negative stats cannot produce negative bars', function()
        local r = M.Calculate(9100, -50, -10)
        T.eq(r.percent, 0); T.eq(r.remaining, 9100)
    end)
    T.test('invalid penetration does not pretend to be zero', function()
        for _, value in ipairs({'bad', math.huge, 0/0}) do
            local r = M.Calculate(9100, value, 0)
            T.eq(r.percent, nil); T.eq(r.fill, 0)
        end
    end)
    for _, case in ipairs({
        {'overland', {}, 9100}, {'quest interior', {instance='solo'}, 9100},
        {'delve', {instance='delve'}, 9100},
        {'public dungeon', {instance='public'}, 9100},
        {'actual dungeon wins over nearby public POI', {instance='public', dungeon=true}, 18200},
        {'normal dungeon', {dungeon=true}, 18200}, {'trial', {instance='raid',dungeon=true}, 18200},
        {'outside group entrance', {instance='group'}, 9100},
        {'outside raid entrance', {instance='raid'}, 9100},
        {'archive ordinary enemy', {archive=true, dungeon=true}, 9100},
        {'archive final boss', {archive=true, archiveBoss=true, dungeon=true}, 18200},
        {'Maelstrom', {zoneId=677, dungeon=true}, false},
        {'Vateshran', {zoneId=1227, dungeon=true}, false},
        {'house', {house=true}, false}, {'unknown zone', {unknown=true}, false},
    }) do
        T.test('profile: ' .. case[1], function()
            T.eq(M.Profile(case[2], {profile='auto'}), case[3] or nil)
        end)
    end
    T.test('explicit profile works in otherwise unknown context', function()
        T.eq(M.Profile({house=true}, {profile='custom', customResistance=13650}), 13650)
        T.eq(M.Profile({}, {profile='dungeon'}), 18200)
        T.eq(M.Profile({dungeon=true}, {profile='overland'}), 9100)
        T.eq(M.Profile({archive=true, archiveBoss=true}, {profile='custom', customResistance=13650}), 13650)
    end)
    T.test('corrupt manual armor stays unknown', function()
        T.eq(M.Profile({}, {profile='custom', customResistance=-1}), nil)
        T.eq(M.Profile({}, {profile='custom', customResistance=0/0}), nil)
    end)
    local names = {[61743]='Большой прорыв', [61742]='Малый прорыв'}
    local lookup = M.BuildLookup(function(id) return names[id] or '' end)
    local settings = {crusher=2108, alkosh=6000, tremorscale=2640}
    T.test('Breach variants and repeated casters do not stack', function()
        local r = M.Effects({{id=61743}, {id=999, name='Большой прорыв'}, {id=61742}, {id=61742}}, lookup, settings, false)
        T.eq(r.physical, 8922); T.eq(r.spell, 8922); T.eq(r.bonus, 0)
    end)
    T.test('empty names never classify unrelated effects', function()
        local r = M.Effects({{id=998, name=''}, {id=997}}, lookup, settings, false)
        T.eq(r.physical, 0); T.eq(r.spell, 0)
    end)
    T.test('variable debuffs use configured values once', function()
        local r = M.Effects({{id=17906}, {id=17906}, {id=75753}, {id=80866}}, lookup,
            {crusher=1622, alkosh=3000, tremorscale=2000}, false)
        T.eq(r.physical, 6622); T.eq(r.spell, 6622)
    end)
    T.test('localized real debuff aliases do not inherit dummy strength', function()
        local aliases=M.BuildLookup(function(id)
            if id==17906 or id==120007 then return 'Crusher' end
            return ''
        end)
        T.eq(M.Effects({{id=999,name='Crusher'}},aliases,{crusher=1622},false).physical,1622)
    end)
    T.test('physical poison does not reduce spell armor', function()
        local r = M.Effects({{id=79090}}, lookup, settings, false)
        T.eq(r.physical, 1320); T.eq(r.spell, 0)
    end)
    T.test('spell poison does not reduce physical armor', function()
        local r = M.Effects({{id=79087}}, lookup, settings, false)
        T.eq(r.physical, 0); T.eq(r.spell, 1320)
    end)
    T.test('other supported fixed reductions combine', function()
        local r = M.Effects({{id=159288}, {id=143808}, {id=187742}}, lookup, settings, false)
        T.eq(r.physical, 6741); T.eq(r.spell, 6741)
    end)
    T.test('Force of Nature adds personal penetration for unique statuses only', function()
        local r = M.Effects({{id=18084}, {id=18084}, {id=178123}, {id=999}}, lookup, settings, true)
        T.eq(r.bonus, 1320); T.eq(r.physical, 0); T.eq(r.spell, 0)
        T.eq(r.bonusMax, 5280)
    end)
    T.test('poison and burning are different statuses', function()
        T.eq(M.Effects({{id=18084}, {id=21929}}, lookup, settings, true).bonus, 1320)
    end)
    T.test('unequipped Force of Nature gives no bonus', function()
        T.eq(M.Effects({{id=18084}}, lookup, settings, false).bonus, 0)
    end)
end
