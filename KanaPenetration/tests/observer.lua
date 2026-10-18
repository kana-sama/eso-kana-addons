return function(T)
    local entry = loadfile('KanaPenetration/Observer.lua')
    T.test('observer exists', function() assert(entry, 'implement the ESO snapshot boundary') end)
    if not entry then return end
    KanaPenetration = {}; dofile('KanaPenetration/Model.lua'); entry()
    local function fixture()
        local state = {exists=true, attackable=true, zone=1, difficulty=0, instance=0,
            physical=7000, spell=7000, now=10, buffs={}, slots={}, points=50}
        local a = {STAT_PHYSICAL_PENETRATION=1, STAT_SPELL_PENETRATION=2,
            STAT_BONUS_OPTION_APPLY_BONUS=1, DUNGEON_DIFFICULTY_NONE=0,
            INSTANCE_TYPE_PUBLIC_DUNGEON=1, INSTANCE_TYPE_GROUP=2, INSTANCE_TYPE_RAID=3,
            INSTANCE_TYPE_SOLO=4, HOTBAR_CATEGORY_CHAMPION=4, SI_ABILITY_NAME=1, COMBAT_MECHANIC_FLAGS_HEALTH=32}
        a.DoesUnitExist=function() return state.exists end
        a.IsUnitAttackable=function() return state.attackable end
        a.IsUnitPlayer=function() return state.player end
        a.IsUnitDeadOrReincarnating=function() return state.dead end
        a.IsUnitJusticeGuard=function() return state.guard end
        a.IsPlayerInAvAWorld=function() return state.ava end
        a.IsActiveWorldBattleground=function() return state.battleground end
        a.GetUnitZoneIndex=function(tag) T.eq(tag, 'player'); return state.zone end
        a.GetZoneId=function(index) return index end
        a.GetCurrentMapZoneIndex=function() error('must not use viewed map') end
        a.GetCurrentZoneDungeonDifficulty=function() return state.difficulty end
        a.GetCurrentSubZonePOIIndices=function() return state.poiZone, state.poi end
        a.GetPOIInstanceType=function(z,p) T.eq(z,state.poiZone); T.eq(p,state.poi); return state.instance end
        a.IsInstanceEndlessDungeon=function() return state.archive end
        a.GetCurrentZoneHouseId=function() return state.house and 10 or 0 end
        a.GetPlayerStat=function(stat, option)
            T.eq(option, 1); return stat == 1 and state.physical or state.spell
        end
        a.GetUnitName=function() return state.name or 'Target' end
        a.GetItemLinkName=function(link)
            state.itemReads=(state.itemReads or 0)+1
            local id=tonumber(assert(link:match('item:(%d+):')))
            return 'Локализованная цель '..id..'^n'
        end
        a.GetUnitPower=function(tag,power)
            T.eq(tag,'reticleover');T.eq(power,32)
            return 1000,state.maxHealth or 40000,state.maxHealth or 40000
        end
        a.GetFrameTimeSeconds=function() return state.now end
        a.GetNumBuffs=function(tag) T.eq(tag, 'reticleover'); return #state.buffs end
        a.GetUnitBuffInfo=function(_, index)
            local b=state.buffs[index]
            return b.name or '', b.start or 0, b.finish or 0, index, 1, '', 0, 0, 0, 0, b.id, false, b.mine or false
        end
        a.GetAbilityName=function(id) return id == 61743 and 'Major Breach^n' or '' end
        a.zo_strformat=function(_, text) return text:gsub('%^%a','') end
        a.GetSlotBoundId=function(slot, category) T.eq(category,4); return state.slots[slot] or 0 end
        a.GetNumPointsSpentOnChampionSkill=function(id) T.eq(id,276); return state.points end
        return KanaPenetration.Observer.New(a), state, {profile='auto',crusher=2108,alkosh=6000,tremorscale=2640}
    end
    T.test('overland reads live personal stats', function()
        local observer,s,settings=fixture(); local r=observer:Capture(settings)
        T.eq(r.base,9100); T.eq(r.physical.penetration,7000); T.eq(r.source,'overland')
    end)
    T.test('public dungeon with no difficulty uses overland profile', function()
        local o,s,k=fixture(); s.poiZone=2; s.poi=3; s.instance=1
        T.eq(o:Capture(k).base,9100)
    end)
    T.test('current difficulty takes priority over unrelated compass POI', function()
        local o,s,k=fixture(); s.difficulty=1; s.poiZone=2; s.poi=3; s.instance=1
        T.eq(o:Capture(k).base,18200)
    end)
    T.test('standing outside group entrance remains overland', function()
        local o,s,k=fixture(); s.poiZone=2; s.poi=3; s.instance=2
        T.eq(o:Capture(k).base,9100)
    end)
    T.test('entering actual group dungeon selects group profile', function()
        local o,s,k=fixture(); s.poiZone=2; s.poi=3; s.instance=2; s.difficulty=1
        T.eq(o:Capture(k).base,18200)
    end)
    T.test('missing current zone does not guess overland', function()
        local o,s,k=fixture(); s.zone=0; T.eq(o:Capture(k).base,nil)
    end)
    T.test('dummy catalog is localized once and overrides zone profiles', function()
        local o,s,k=fixture();s.house=true;s.name='Локализованная цель 118553^n'
        local r=o:Capture(k);T.eq(r.base,18200);T.eq(r.source,'dummy')
        local reads=s.itemReads
        for i=1,20 do T.eq(o:Capture(k).base,18200) end
        T.eq(s.itemReads,reads)
        s.house=false;s.archive=true;T.eq(o:Capture(k).base,18200)
        s.name='Target';T.eq(o:Capture(k).base,9100)
    end)
    T.test('Archive assigns 18200 only to Tho’at Replicanum', function()
        local o,s,k=fixture();s.archive=true
        for _,name in ipairs({"Tho'at Replicanum", 'То’ат Копировальщица',
            "Replicanum de Tho'at", 'ソアト・レプリカヌム', '索特复影体'}) do
            s.name=name
            T.eq(o:Capture(k).base,18200,name)
        end
        for _,name in ipairs({"Tho'at Shard", 'Осколок То’ат', 'Другой босс'}) do
            s.name=name
            T.eq(o:Capture(k).base,9100,name)
        end
        s.archive=false;s.name="Tho'at Replicanum"
        T.eq(o:Capture(k).base,9100)
    end)
    T.test('Precursor has its own armor and manual override still wins', function()
        local o,s,k=fixture();s.house=true;s.name='Локализованная цель 132348'
        T.eq(o:Capture(k).base,9100)
        k.profile='custom';k.customResistance=12345;T.eq(o:Capture(k).base,12345)
    end)
    T.test('trial dummy supplies hidden armor debuffs without doubling visible ones', function()
        local o,s,k=fixture();s.house=true;s.name='Локализованная цель 147926'
        local r=o:Capture(k);T.eq(r.base,18200);T.eq(r.physical.remaining,1170)
        s.buffs={{id=61743},{id=61742},{id=120007},{id=120018},{id=17906},{id=75753}}
        T.eq(o:Capture(k).physical.remaining,1170)
        s.buffs[#s.buffs+1]={id=143808};T.eq(o:Capture(k).physical.remaining,170)
        s.name='Локализованная цель 118553';s.buffs={}
        T.eq(o:Capture(k).physical.remaining,18200)
    end)
    T.test('new housing dummy models never inherit an unknown house profile', function()
        local o,s,k=fixture();s.house=true;s.name='Новый манекен'
        T.eq(o:Capture(k).base,18200)
        s.maxHealth=21000000;T.eq(o:Capture(k).physical.remaining,1170)
        s.house=false;T.eq(o:Capture(k).physical.remaining,9100)
    end)
    T.test('all catalog variants have armor before their first hit', function()
        local o,s,k=fixture();s.archive=true
        for _,id in ipairs({118553,120426,120427,121314,121399,121400,
            126035,126036,126037,126038,130193,130194,130195,134823,141778,146069,
            151906,153563,156669,165569,166960,169117,178694,183856,190951,193794,
            199133,203270,211300,211499,219876,223732,147926,171875,187664,204408,132348}) do
            s.name='Локализованная цель '..id
            T.eq(o:Capture(k).base,id==132348 and 9100 or 18200)
        end
        for _,id in ipairs({147926,171875,187664,204408}) do
            s.name='Локализованная цель '..id
            T.eq(o:Capture(k).spell.remaining,1170)
        end
    end)
    T.test('third party Breach applies and expired/future effects do not', function()
        local o,s,k=fixture()
        s.buffs={{id=999,name='Major Breach^n',finish=20},{id=61742,finish=10},{id=79090,start=11,finish=15}}
        T.eq(o:Capture(k).physical.remaining,3152)
    end)
    T.test('same-name replacement target has no stale debuffs', function()
        local o,s,k=fixture(); s.buffs={{id=61743,finish=15}}
        T.eq(o:Capture(k).physical.remaining,3152)
        s.buffs={}; T.eq(o:Capture(k).physical.remaining,9100)
    end)
    T.test('weapon swaps use fresh stats', function()
        local o,s,k=fixture(); o:Capture(k); s.physical=3000
        local r=o:Capture(k); T.eq(r.physical.penetration,3000); T.eq(r.spell.penetration,7000)
    end)
    T.test('armor can be completely stripped', function()
        local o,s,k=fixture(); s.buffs={{id=61743},{id=61742},{id=17906}}
        T.eq(o:Capture(k).physical.stripped,true)
    end)
    T.test('equipped Force of Nature exposes bounds for invisible statuses', function()
        local o,s,k=fixture(); s.slots[5]=276; s.buffs={{id=18084},{id=18084}}
        local r=o:Capture(k); T.eq(r.physical.penetration,7660); T.eq(r.physical.upperPenetration,12280)
        T.eq(r.conditional,true); T.eq(r.spell.penetration,7660)
    end)
    T.test('unfunded Force of Nature is not counted', function()
        local o,s,k=fixture(); s.slots[5]=276; s.points=0
        T.eq(o:Capture(k).conditional,false)
    end)
    T.test('unavailable stats stay unknown', function()
        local o,s,k=fixture(); s.spell=0/0
        T.eq(o:Capture(k).spell.percent,nil)
    end)
    for _, key in ipairs({'player','dead','guard','ava','battleground'}) do
        T.test('hide unsuitable target: '..key,function()
            local o,s,k=fixture(); s[key]=true; T.eq(o:Capture(k),nil)
        end)
    end
    for _, key in ipairs({'exists','attackable'}) do
        T.test('hide missing eligibility: '..key,function()
            local o,s,k=fixture(); s[key]=false; T.eq(o:Capture(k),nil)
        end)
    end
end
