-- Extract factual associations only; never execute an addon's application code.
-- Usage: lua tools/import_mappins.lua /path/to/AddOns /output/Data.lua
local root, output = assert(arg[1]), assert(arg[2])
local function read(path) local f=assert(io.open(path));local s=f:read('*a');f:close();return s end
local function tableFrom(source, pattern)
    local literal=assert(source:match(pattern), 'table not found: '..pattern)
    return assert(load('return '..literal, 'data literal', 't', {}))()
end
local src=read(root..'/MapPins/MapPins.lua')
local achievements=tableFrom(src,'local Achievements=(%b{})')
local bosses=tableFrom(src,'local Bosses=(%b{})')
local zoneCriteria=tableFrom(src,'local ZoneAchievement=(%b{})')
local museums={[1250]=true,[1712]=true,[2099]=true,[1958]=true,[2320]=true,[2463]=true,[2534]=true,[2669]=true,[2759]=true}
local meetings={[872]=true,[873]=true,[871]=true,[869]=true,[716]=true,[1247]=true,[1316]=true,[2171]=true,[2330]=true,[2358]=true,[2964]=true,[3082]=true,[3299]=true,[4040]=true,[4432]=true,[4455]=true,[4456]=true,[4457]=true}
local global={[704]=true,[1082]=true,[1383]=true,[1379]=true,[1380]=true,[1381]=true,[1438]=true}
local rows, seen={},{}
local function add(map,id,index,category,boss)
    if not id or id<=100 then return end
    local key=map..':'..id..':'..tostring(index)..':'..category
    if seen[key] then return end;seen[key]=true
    rows[#rows+1]=string.format('    {%q,%d,%d,%q,%s},',map,id,index or 0,category,tostring(boss or false))
end
for map, data in pairs(achievements) do
    for id, pins in pairs(data) do
        if type(id)=='number' and id>100 and id~=1824 then
            for _,p in ipairs(pins) do
                if id==873 then
                    local index=zoneCriteria[map:gsub('_base$','')]
                    if index then for _,a in ipairs({869,871,873}) do add(map,a,index,'meetings') end end
                elseif id==1383 then add(map,p[3],p[4],'global')
                else add(map,id,p[3],museums[id] and 'museums' or meetings[id] and 'meetings' or global[id] and 'global' or 'special') end
            end
        end
    end
end
for map,pins in pairs(bosses) do
    for _,p in ipairs(pins) do add(map,p[3],p[4],'dungeons',true) end
end
table.sort(rows)
local f=assert(io.open(output,'w'))
f:write('-- Generated from Map Pins 1.100.22; see SOURCES.md and tools/import_mappins.lua.\n')
f:write('-- map texture basename, achievement ID, criterion (0 = entire), category, public-dungeon-only.\nKanaZoneGoals.mapGoals = {\n',table.concat(rows,'\n'),'\n}\n')
f:close();print('Imported '..#rows..' map/achievement/criterion associations')
-- Other factual datasets downloaded separately for development (not runtime dependencies).
local research=arg[3]
if research then
    local uspf=read(research..'/1863/USPF/USPF.lua')
    local pd=tableFrom(uspf,'\n\tPD = (%b{}),\n}')
    local zones=tableFrom(uspf,'ZN = (%b{})')
    local zdat=read(research..'/4077/ZoneDailiesAchievementTracker/Data/Achievements.lua')
    local daily=tableFrom(zdat,'ZDAT%.Data%.Achievements%.DB = (%b{})')
    local out=assert(io.open(output,'a'))
    out:write('\n-- Urich\'s Skill Point Finder 7.5.0: public dungeon group events.\nKanaZoneGoals.publicDungeons = {\n')
    for _,v in ipairs(pd) do out:write(string.format('    {%d,%d,%d},\n',assert(zones[v.zone]),v.achievement,v.id)) end
    out:write('}\n\n-- Zone Dailies Achievement Tracker 1.0.5: final achievement tier and quest-giver wayshrine.\nKanaZoneGoals.dailyGoals = {\n')
    for _,zone in ipairs(daily) do
        for _,v in ipairs(zone.ACHIEVEMENTS) do out:write(string.format('    {%d,%d},\n',v.WAYSHRINE_ID,v.ACHIEVEMENT_IDS[#v.ACHIEVEMENT_IDS])) end
    end
    out:write('}\n');out:close()
end
