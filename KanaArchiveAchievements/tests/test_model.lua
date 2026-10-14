local unpack = unpack or table.unpack
local passed, failed = 0, 0
local function test(name, fn)
    local ok, error = pcall(fn)
    if ok then passed = passed + 1 else failed = failed + 1; print('FAIL: ' .. name .. ': ' .. tostring(error)) end
end
local file = io.open('KanaArchiveAchievements/Model.lua')
assert(file, 'Goal resolution and layout are not implemented')
file:close()
dofile('KanaArchiveAchievements/Model.lua')
local M = KanaArchiveAchievements.Model
local function fixture()
    local names = {[1]='Flame Aura', [2]='Swift Gale', [3]='Ferocious Strikes', [4]='Bestial Transformation', [5]='Orbiting Echoes'}
    local criteria = {
        [3781]={{'Acquire Flame Aura',0,1},{'Acquire Swift Gale',0,1}},
        [3784]={{'Acquire Ferocious Strikes',0,1}},
        [3796]={{'Acquire all Werewolf Behemoth Visions and the Verse',0,1}},
        [3799]={{'Acquire Offensive Verses or Visions',1,5}},
        [3800]={{'Acquire Offensive Verses or Visions',1,25}},
        [3801]={{'Acquire Offensive Verses or Visions',1,50}},
        [4153]={{'Acquire Orbiting Echoes',0,1}},
    }
    local c = {ABILITIES={
        [1]={ids={3781,3799,3800,3801},class=10},
        [2]={ids={3781,3799,3800,3801},class=10},
        [3]={ids={3784,3796},class=13},
        [4]={ids={3796},class=13},
        [5]={ids={4153,3799,3800,3801,4153},class=10},
    }, GENERAL={3799,3800,3801}, AVATAR={WOLF={id=3796,abilityIds={3,4}}}, EXCEPTIONS={[4]=99}, CLASSES={OFFENCE=10,DEFENCE=11,UTILITY=12,AVATAR=13}}
    local api = {
        GetAbilityName=function(id) return names[id] or '' end,
        GetString=function(id) assert(id==99); return 'Werewolf Behemoth' end,
        GetAchievementNumCriteria=function(id) return #(criteria[id] or {}) end,
        GetAchievementCriterion=function(id,i) return unpack(criteria[id][i]) end,
        zo_strformat=function(_,s) return s end,
        zo_strlower=function(s) return s:lower():gsub('О','о'):gsub('П','п'):gsub('С','с') end,
    }
    return M.New(api,c), criteria, names, c
end
local function equal(actual, expected)
    assert(table.concat(actual,',')==table.concat(expected,','), table.concat(actual,',') .. ' != ' .. table.concat(expected,','))
end
test('unique goal plus every unfinished counter', function()
    local m=fixture(); equal(m:GetGoals(1,0),{3781,3799,3800,3801})
end)
test('already acquired unique criterion is excluded', function()
    local m,c=fixture(); c[3781][1][2]=1; equal(m:GetGoals(1,0),{3799,3800,3801})
end)
test('completed counter tier is excluded', function()
    local m,c=fixture(); c[3799][1][2]=5; equal(m:GetGoals(1,0),{3781,3800,3801})
end)
test('vision uses real bucket to recover omitted counters and avatar goal', function()
    local m=fixture(); equal(m:GetGoals(3,0),{3784,3796,3799,3800,3801})
end)
test('wrong bucket does not gain offensive counters', function()
    local m=fixture(); equal(m:GetGoals(3,1),{3784,3796})
end)
test('completed avatar is excluded', function()
    local m,c=fixture(); c[3796][1][2]=1; equal(m:GetGoals(3,0),{3784,3799,3800,3801})
end)
test('Russian grammar and colour formatting are normalized', function()
    local m,c,n=fixture(); n[1]='|cffffffОгненная аура|r'; c[3781][1][1]='Получите огненная аура'; equal(m:GetGoals(1,0),{3781,3799,3800,3801})
end)
test('duplicate names make the unique match ambiguous', function()
    local m,c,n=fixture(); n[2]='Flame Aura'; equal(m:GetGoals(1,0),{3799,3800,3801})
end)
test('duplicates are removed', function()
    local m=fixture(); equal(m:GetGoals(5,0),{3799,3800,3801,4153})
end)
test('unmapped and empty abilities produce no goals', function()
    local m,c,n=fixture(); equal(m:GetGoals(99,0),{}); n[1]=''; equal(m:GetGoals(1,0),{})
end)
test('zero or unavailable criteria are not treated as missing', function()
    local m,c=fixture(); c[3781]={}; equal(m:GetGoals(1,0),{3799,3800,3801})
end)
test('layout centers complete and incomplete rows', function()
    local p,h=M.Layout(1200,{100,160,80})
    assert(p[1].x==29 and p[2].x==606 and p[3].x==317.5)
    assert(p[1].y==0 and p[2].y==0 and p[3].y==172 and h==252)
end)
test('narrow layout preserves every card in separate rows', function()
    local p,h=M.Layout(600,{100,160,80})
    assert(#p==3 and p[1].x==17.5 and p[3].y==284 and h==364)
end)
test('empty layout has no height', function()
    local p,h=M.Layout(1200,{}) assert(#p==0 and h==0)
end)
print(string.format('Model: %d passed, %d failed',passed,failed))
os.exit(failed==0 and 0 or 1)
