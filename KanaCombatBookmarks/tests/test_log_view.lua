local T = dofile('KanaCombatBookmarks/tests/support.lua')
T.load('Names'); T.load('Model')
local constants = {'DAMAGE_OUT', 'DAMAGE_IN', 'DAMAGE_SELF', 'HEAL_OUT', 'HEAL_IN', 'HEAL_SELF',
    'EFFECTS_IN', 'EFFECTS_OUT', 'GROUPEFFECTS_IN', 'GROUPEFFECTS_OUT', 'PLAYERSTATS', 'RESOURCES',
    'MESSAGES', 'DEATH', 'PLAYERSTATS_ADVANCED', 'SKILL_TIMINGS', 'BOSSHP', 'PERFORMANCE'}
for i, name in ipairs(constants) do _G['LIBCOMBAT_EVENT_' .. name] = i + 3 end
POWERTYPE_HEALTH = -2
LibCombat = {GetFormattedAbilityName = function(id) return 'ability' .. id end}
T.test('log view implementation', function() T.load('LogView') end)
if T.failed > 0 then T.finish() end
local V = KanaCombatBookmarks.LogView
local function selections() return {unit = {}, ability = {}, buff = {}, resource = {}} end
local function fight()
    return {combatstart = 1000, log = {
        {4, 1000, 1, 10, 20, 30}, {5, 1100, 1, 20, 10, 31},
        {10, 1200, 10, 32}, {16, 1300, 1}, {15, 1400, 33, 10, 0}},
        kanaCombatBookmarks = {version = 1, entries = {
            {id = 1, offsetMs = 100, name = 'Армагеддон'}, {id = 2, offsetMs = 100, name = 'Кракен'}}}}
end
T.test('markers follow same-time events, preserve ordering and bypass event filters', function()
    local f = fight(); local rows = V.BuildRows(f, selections(), {[4] = true, [5] = true})
    T.eq(#rows, 4); T.eq(rows[1].event, f.log[1]); T.eq(rows[2].event, f.log[2])
    T.eq(rows[3].bookmark.name, 'Армагеддон'); T.eq(rows[4].bookmark.name, 'Кракен')
    T.eq(#f.log, 5); T.eq(f.log[2][2], 1100)
    rows = V.BuildRows(f, selections(), {}); T.eq(#rows, 2)
end)
T.test('selected targets, abilities, effects and resources retain CMX semantics', function()
    local s = selections(); s.unit.damageOut = {[99] = true}
    T.eq(#V.BuildRows(fight(), s, {[4] = true}), 2)
    s.unit.damageOut = {[20] = true}; s.ability.damageOut = {[30] = true}
    T.eq(#V.BuildRows(fight(), s, {[4] = true}), 3)
    s.ability.damageOut = {[31] = true}; T.eq(#V.BuildRows(fight(), s, {[4] = true}), 2)
    s = selections(); s.buff.buff = {ability32 = true}
    T.eq(#V.BuildRows(fight(), s, {[10] = true}), 3)
    s.unit.damageIn = {[99] = true}; T.eq(#V.BuildRows(fight(), s, {[10] = true}), 2)
    s = selections(); s.resource.resource = {[33] = true}
    T.eq(#V.BuildRows(fight(), s, {[15] = true}), 3)
    local f = fight(); f.log[5][5] = -2
    T.eq(#V.BuildRows(f, s, {[15] = true}), 2)
end)
T.test('self damage/healing and message-derived events follow category switches', function()
    local f = {combatstart = 0, log = {{6,1},{9,2,1,10,10,30},{17,3},{20,4},{19,5},{21,6}}}
    local rows = V.BuildRows(f, selections(), {[4]=true,[7]=true,[16]=true,[19]=true,[21]=true})
    -- Current CMX omits DAMAGE_SELF in its second filtering stage.
    T.eq(#rows, 5)
    local s = selections(); s.ability.healingOut = {[31] = true}
    T.eq(#V.BuildRows(f, s, {[7]=true}), 0)
end)
T.test('jump window crosses a native page boundary and centers variable-height lines', function()
    for _, index in ipairs({999,1000,1001}) do
        local first, last = V.Window(2500, index, 1)
        assert(first < index - 20 and last > index + 20 and last - first + 1 <= 1000)
    end
    T.eq(V.CenterScroll(80,20,30,33), 38.5)
    T.eq(V.CenterScroll(80,5,30,33), 46)
    T.eq(V.CenterScroll(10,20,0,1), 0)
    local first,last = V.Window(2500,nil,3); T.eq(first,2001); T.eq(last,2500)
end)
T.test('marker display and copying retain name without markup', function()
    local text = V.BookmarkText({name='Армагеддон',offsetMs=74350}, 40)
    assert(text:find('Армагеддон',1,true))
    local plain = V.PlainText(text)
    assert(plain:find('Армагеддон',1,true)); assert(plain:find('01:14.350',1,true))
    assert(not plain:find('|c',1,true) and not plain:find('|t',1,true))
end)
T.test('event selection agrees with the installed CMX renderer', function()
    local f = assert(io.open((os.getenv('ESO_ADDONS_ROOT') or '..') .. '/CombatMetrics/CombatMetricsUI.lua'))
    local source = f:read('*a'):gsub('\r\n','\n'); f:close()
    local code = assert(source:match('(local function updateCombatLog%(panel%).-\nend)\n\nlocal CMX_PLOT'))
    local captures, buffer = {}, {}
    function buffer:GetNumHistoryLines() return #captures end
    function buffer:GetScrollPosition() return 0 end
    function buffer:GetNumVisibleLines() return 20 end
    function buffer:IsHidden() return false end
    function buffer:Clear() captures = {} end
    function buffer:SetMaxHistoryLines() end
    function buffer:SetFont() end
    function buffer:SetScrollPosition() end
    local slider = {GetValue = function() return 0 end, SetValue = function() end}
    local window = {GetNamedChild = function(_,name) return name=='Buffer' and buffer or slider end,
        AddColoredText = function() end}
    local panel = {IsHidden = function() return false end, GetNamedChild = function() return window end}
    local env = setmetatable({CMX={Log=function()end,GetCombatLogString=function(_,line) captures[#captures+1]=line; return 'event',{1,1,1} end},
        zo_ceil=math.ceil,zo_floor=math.floor,zo_min=math.min,zo_max=math.max,
        GetControl=function()return{Update=function()end}end,GetString=function()return '14'end,
        GetFormattedAbilityName=LibCombat.GetFormattedAbilityName}, {__index=_G})
    local wrapper = 'return function(fightData,selections,db) local currentCLPage=1; local fontsize=14; local logtypeCategories={}\n' .. code .. '\nupdateCombatLog(...) end'
    -- Pass the panel as an explicit argument; captures are populated by native formatting.
    wrapper = wrapper:gsub('function%(fightData,selections,db%)','function(fightData,selections,db,panel)'):gsub('updateCombatLog%(%.%.%.%)','updateCombatLog(panel)')
    local chunk
    if setfenv then chunk=assert(loadstring(wrapper)); setfenv(chunk,env) else chunk=assert(load(wrapper,'native-filter','t',env)) end
    local native = chunk()
    -- Native category mapping is required for the target/ability filters.
    wrapper=wrapper:gsub('local logtypeCategories={}', "local logtypeCategories={[4]='damageOut',[5]='damageIn',[7]='healingOut',[8]='healingIn'}")
    if setfenv then chunk=assert(loadstring(wrapper)); setfenv(chunk,env) else chunk=assert(load(wrapper,'native-filter','t',env)) end
    native=chunk()
    for scenario=1,8 do
        local filters={}; for i=4,21 do filters[i]=scenario%2==0 or i%2==0 end
        local s=selections()
        if scenario>=3 then s.unit.damageOut={[20]=true} end
        if scenario>=5 then s.ability.damageOut={[30]=true}; s.buff.buff={ability32=true} end
        if scenario>=7 then s.resource.resource={[33]=true} end
        local data=fight()
        for _,line in ipairs({{6,1500},{9,1501,1,10,10,30},{17,1502},{20,1503},{19,1504},{21,1505}}) do data.log[#data.log+1]=line end
        native(data,s,{FightReport={CLSelection=filters,scale=1}},panel)
        local actual={}; for _,row in ipairs(V.BuildRows(data,s,filters)) do if row.event then actual[#actual+1]=row.event end end
        T.eq(#actual,#captures); for i,line in ipairs(captures) do T.eq(actual[i],line) end
    end
end)
T.test('bookmark progress uses combat duration, clamps grace marks and handles missing duration', function()
    local fight={combatstart=100000,combatend=120000,combattime=999}
    T.eq(V.BookmarkProgress({offsetMs=5000},fight),0.25)
    T.eq(V.BookmarkProgress({offsetMs=20000},fight),1)
    T.eq(V.BookmarkProgress({offsetMs=25000},fight),1)
    T.eq(V.BookmarkProgress({offsetMs=-5},fight),0)
    T.eq(V.BookmarkProgress({offsetMs=5000},{combattime=20}),0.25)
    T.eq(V.BookmarkProgress({offsetMs=5000},{combatstart=0,combatend=0}),0)
    T.eq(V.BookmarkProgress({offsetMs=5000},{}),0)
end)
T.finish()
