dofile('Core.lua')
local K=KanaZoneGoals
local f=loadfile('Providers.lua');if f then f() end
assert(type(K.AchievementGoal)=='function','missing ESO providers')
GetAchievementInfo=function(id)return 'Achievement '..id,'Description',10,'icon' end
GetAchievementNumCriteria=function()return 2 end
GetAchievementCriterion=function(_,i)return 'Criterion '..i,i==1 and 1 or 0,1 end
IsAchievementComplete=function()return true end -- whole-account completion must not override a local criterion
local g=K.AchievementGoal(872,'meetings',{[2]=true})
assert(g.current==0 and g.total==1,'local incomplete criterion must remain incomplete')
assert(#g.criteria==1 and g.criteria[1].index==2,'tooltip must show local criteria only')
GetAchievementNumCriteria=function()return 0 end
IsAchievementComplete=function()return false end
g=K.AchievementGoal(123,'special')
assert(g.current==0 and g.total==1,'zero-criteria achievements use completion flag')
GetAchievementInfo=function()return '' end
assert(K.AchievementGoal(0,'special')==nil,'invalid achievement must not be displayed')
assert(K.MapBasename('EsoUI/Art/Maps/foo/auridon_base_0.dds')=='auridon_base')
local mappings={{'a',872,1,'meetings',false},{'b',872,2,'meetings',false},{'a',872,1,'meetings',false}}
local resolved=K.ResolveMapGoals(mappings,{a={zoneId=3},b={zoneId=19}})
assert(resolved[3][872].criteria[1] and not resolved[3][872].criteria[2],'criteria leaked across zones')
local r=K.ResolveMapGoals({{'unknown',872,1,'meetings',false}}, {})
assert(next(r)==nil,'unknown map must not be guessed')
print('PASS providers: local criteria/account flag/zero criteria/invalid ID/map resolution')
