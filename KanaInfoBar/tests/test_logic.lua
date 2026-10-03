-- Run from eso-kana-addons: lua KanaInfoBar/tests/test_logic.lua
dofile('KanaInfoBar/Logic.lua')
local M = KanaInfoBar.Model
local tests = 0
local function eq(actual, expected, why)
    assert(actual == expected, (why or '') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual))
    tests = tests + 1
end
-- Catches inclusive/exclusive boundary mistakes and rounded percentages.
for _, case in ipairs({{150,'normal'},{151,'orange'},{200,'orange'},{201,'red'}}) do
    eq(M.PingColor(case[1]), case[2], 'ping boundary')
end
for _, case in ipairs({{159,200,'normal'},{160,200,'orange'},{189,200,'orange'},
    {190,200,'red'},{200,200,'red'},{1,0,'normal'},{159,199,'normal'}}) do
    eq(M.BagColor(case[1],case[2]), case[3], 'bag boundary')
end
for _,case in ipairs({{21,'normal'},{20,'orange'},{1,'orange'},{0,'red'}}) do
    eq(M.GearColor(case[1]),case[2],'gear condition boundary')
end
eq(M.GearColor(nil),'normal','no repairable gear is neutral')
local min,average,repairCost,pieces=M.GearStatus({
    {condition=55,cost=100},{condition=20,cost=150},{condition=80,cost=50},
})
eq(min,20);eq(average,52);eq(repairCost,300);eq(pieces,3)
min,average,repairCost,pieces=M.GearStatus({})
eq(min,nil);eq(average,nil);eq(repairCost,0);eq(pieces,0)
-- Mixed inventory: junk treasures still count; non-treasures and clean items do not.
local count, value = M.TotalTreasure({
    {stolen=true, kind=7, count=3, price=110, junk=true},
    {stolen=true, kind=7, count=2, price=275},
    {stolen=true, kind=7, count=1, price=0},
    {stolen=true, kind=9, count=8, price=500},
    {stolen=false, kind=7, count=6, price=1000},
}, 7)
eq(count,6); eq(value,880)
eq(M.TotalTreasure({},7),0)
local treasures={
    {stolen=true,kind=7,count=3,price=110,junk=true},
    {stolen=true,kind=7,count=2,price=275},
    {stolen=true,kind=7,count=1,price=0},
    {stolen=false,kind=7,count=5,price=1000},
    {stolen=true,kind=9,count=4,price=500},
}
for _,case in ipairs({{0,0,0},{1,275,1},{2,550,2},{3,660,3},
    {4,770,4},{6,880,6},{50,880,6}}) do
    local sale,selected=M.BestTreasureSale(treasures,case[1],7)
    eq(sale,case[2],'best treasure sale value')
    eq(selected,case[3],'best treasure sale count')
end
eq(treasures[1].count,3,'calculation leaves source stacks untouched')
-- Growing text gets room immediately; brief spikes do not cause width oscillation.
local s = {}
eq(M.ReserveWidth(s,18,27,0),48)
eq(M.ReserveWidth(s,28,27,1),48)
eq(M.ReserveWidth(s,49,27,2),64)
eq(M.ReserveWidth(s,18,27,100),64, 'one-step shrink disallowed')
eq(M.ReserveWidth(s,90,27,101),112)
eq(M.ReserveWidth(s,20,27,102),112)
eq(M.ReserveWidth(s,20,27,131),112)
eq(M.ReserveWidth(s,20,27,132),48)
M.ReserveWidth(s,90,27,133)
M.ReserveWidth(s,20,27,134)
M.ReserveWidth(s,90,27,150)
eq(M.ReserveWidth(s,20,27,164),112,'new high value cancels old shrink timer')
eq(M.ReserveWidth(s,20,27,194),48)
-- All anchor mappings, both axes; no independent alignment state.
local cases = {{'TOPLEFT',0,0},{'TOP',.5,0},{'TOPRIGHT',1,0},
    {'LEFT',0,.5},{'RIGHT',1,.5},{'BOTTOMLEFT',0,1},{'BOTTOM',.5,1},{'BOTTOMRIGHT',1,1}}
for _, c in ipairs(cases) do
    local a = M.anchors[c[1]]
    eq(a.x,c[2]); eq(a.y,c[3])
    local l = M.Layout({{'a','b'},{'c'}},{a=true,b=true,c=true},{a=40,b=60,c=50},
        {a=true,b=true,c=true},10,4,c[1])
    eq(l.width,110); eq(l.height,68)
    eq(l.slots.c.x,60*c[2]); eq(l.slots.c.y,36)
    local x,y = M.AnchorPosition(100,200,110,68,c[1])
    eq(x,100+110*c[2]); eq(y,200+68*c[3])
end
local l=M.Layout({{'a'},{'b'}},{a=true,b=true},{a=100,b=30},{a=false,b=true},12,4,'RIGHT')
eq(l.height,32); eq(l.slots.b.y,0); eq(l.slots.a,nil)
eq(#l.rows,1); eq(l.rows[1].index,2,'hidden row identity retained')
-- Grid mode shares column boundaries across rows; the anchor chooses columns
-- for shorter rows while hidden widgets still collapse.
local gridRows={{'a','b','c'},{'d','e'}}
local gridEnabled={a=true,b=true,c=true,d=true,e=true}
local gridWidths={a=40,b=30,c=50,d=70,e=90}
local gridVisible={a=true,b=true,c=true,d=true,e=true}
l=M.Layout(gridRows,gridEnabled,gridWidths,gridVisible,10,4,'LEFT',true)
eq(l.width,230);eq(l.slots.a.x,0);eq(l.slots.d.x,0)
eq(l.slots.b.x,80);eq(l.slots.e.x,80)
eq(l.slots.a.width,70);eq(l.slots.e.width,90)
eq(l.rows[2].x,0);eq(l.rows[2].width,170)
l=M.Layout(gridRows,gridEnabled,gridWidths,gridVisible,10,4,'RIGHT',true)
eq(l.width,220);eq(l.slots.d.x,50);eq(l.slots.b.x,50)
eq(l.slots.e.x,130);eq(l.slots.c.x,130)
eq(l.rows[2].x,50);eq(l.rows[2].width,170)
l=M.Layout({{'a','b','c'},{'d'}},gridEnabled,
    {a=40,b=60,c=80,d=100},gridVisible,10,4,'TOP',true)
eq(l.width,240);eq(l.slots.d.x,l.slots.b.x)
eq(l.rows[2].x,50);eq(l.rows[2].width,100)
l=M.Layout({{'a','b'},{'c'}},gridEnabled,
    {a=40,b=60,c=50},{a=false,b=true,c=true},10,4,'LEFT',true)
eq(l.width,60);eq(l.slots.a,nil);eq(l.slots.b.x,0);eq(l.slots.c.x,0)
-- Normalization never duplicates a module or loses a disabled module position.
local c={rows={{'a','a','bad'},{'b'},{}},enabled={a=true,b=false}}
M.Normalize(c,{'a','b','c'})
eq(table.concat(c.rows[1],','),'a'); eq(table.concat(c.rows[2],','),'b,c')
eq(c.enabled.b,false); eq(c.enabled.c,true)
-- Moves address positions in the pre-drop row and collapse emptied source rows.
local function config() return {rows={{'a','b','c'},{'d'}},enabled={a=true,b=true,c=true,d=true}} end
c=config(); M.Move(c,'a',1,4,false); eq(table.concat(c.rows[1],','),'b,c,a')
c=config(); M.Move(c,'d',1,2,false); eq(#c.rows,1); eq(table.concat(c.rows[1],','),'a,d,b,c')
c=config(); M.Move(c,'d',1,1,true); eq(table.concat(c.rows[1],','),'d'); eq(#c.rows,2)
c=config(); M.Move(c,'a',3,1,true); eq(table.concat(c.rows[3],','),'a')
eq(M.Move(c,'missing',1,1,false),false)
local copy=M.Copy(c); copy.rows[1][1]='changed'; eq(c.rows[1][1],'b','editor snapshot isolation')
print('PASS: '..tests..' logic assertions')
