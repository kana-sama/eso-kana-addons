KanaZoneGoals = {}
local f=loadfile('Core.lua'); if f then f() end
local K=KanaZoneGoals
assert(type(K.GroupGoals)=='function', 'missing progress model')
local goals={
 {key='a', category='fishing', name='Fish', current=1,total=2},
 {key='a', category='fishing', name='Fish duplicate', current=1,total=2},
 {key='b', category='sets', name='Set', current=5,total=5},
 {key='c', category='meetings', name='Unknown'},
}
local groups,done,total=K.GroupGoals(goals,{sets=false})
assert(done==0 and total==2,'disabled and duplicate goals must not count')
assert(#groups==2,'disabled categories must not be shown')
assert(groups[2].goals[1].complete==false,'unknown is not complete')
local _,d,t=K.GroupGoals(goals,{})
assert(d==1 and t==3,'summary counts goals, not unlike units')
local localCriteria={{index=1,current=1,total=1},{index=2,current=0,total=1}}
local c,r=K.SumCriteria(localCriteria,{[1]=true})
assert(c==1 and r==1,'local criterion must not include another zone')
c,r=K.SumCriteria(localCriteria,{[3]=true})
assert(c==nil and r==nil,'missing local criterion is unknown')
c,r=K.SumCriteria({{index=1,current=0,total=0}})
assert(c==nil,'zero requirement is not a completed goal')
for _,cat in ipairs(K.categories) do assert(cat.id~='books','Eidetic Memory excluded') end
print('PASS core: disabled/duplicate/unknown/local criteria/zero requirement/Eidetic exclusion')
