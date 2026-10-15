local T=KAATest
for _,n in ipairs({'Config','History','Features','ChoiceModel','ContextSupport','Grades'})do T.load(n)end
local K=KanaArchiveAssist
local function train(observations)
 local h=K.History.New({id='p1'});for _,o in ipairs(observations)do assert(h:Append(o))end
 local s,why=T.drain(K.ChoiceModel.NewFitJob(h:BuildDataset(0),nil,17));assert(s,why);return s
end
local function predict(s,o)
 local evidence=T.drain(K.ContextSupport.NewJob(s.dataset,s,o));local u=K.ChoiceModel.Predict(s,o)
 return K.Grades.Rate(o.options,u[1],evidence)
end
T.test('one real choice already gives limited markers and factual statistics',function()
 local s=train({T.observation(1,1)})
 local o=T.observation(2,1);local r=predict(s,o)
 T.eq(r.byId[1].grade,1);T.eq(r.byId[2].grade,-1)
 local stats=K.History.GetPerkStats(s.dataset,o)
 T.eq(stats.byId[1].total,1);T.eq(stats.byId[1].selected,1);T.eq(stats.byId[2].selected,0)
 T.eq(stats.byId[1].runs,1);T.eq(stats.byId[1].pairs[2].chosen,1)
end)
T.test('new visions and unseen opponent combinations retain learned information',function()
 local rows={};for i=1,24 do rows[i]=T.observation(i,math.ceil(i/6),i%2==0 and 1 or 2,{},i%2==0 and {1,2}or{2,3})end
 local s=train(rows);local r=predict(s,T.observation(99,9,1,{{999,2}},{1,3}))
 assert(r.byId[1].grade~=nil and r.byId[3].grade~=nil)
 assert(r.byId[1].grade>0 and r.byId[3].grade<0)
end)
T.test('hide only unseen abilities and compare the known subset',function()
 local s=train({T.observation(1,1)})
 local r=predict(s,T.observation(2,1,1,{}, {1,2,3}))
 T.eq(r.byId[1].grade,1);T.eq(r.byId[2].grade,-1);T.eq(r.byId[3].grade,nil)
 local lone=predict(s,T.observation(3,1,1,{}, {1,4}));assert(lone.byId[1].grade~=nil);T.eq(lone.byId[4].grade,nil)
 local unknown=predict(s,T.observation(4,1,4,{}, {4,5}));T.eq(unknown.byId[4].grade,nil);T.eq(unknown.byId[5].grade,nil)
end)
T.test('strength grows only when preference and accumulated evidence both permit it',function()
 local rows={};for i=1,120 do rows[i]=T.observation(i,math.ceil(i/10))end
 local s=train(rows);local r=predict(s,T.observation(121,13));T.eq(r.byId[1].grade,3);T.eq(r.byId[2].grade,-3)
end)
T.test('repeated contextual reversals and nontransitive cycles remain learnable',function()
 local rows={};for i=1,240 do local active=i%2==0;rows[i]=T.observation(i,math.ceil(i/20),active and 2 or 1,active and {{9,1}}or {})end
 local s=train(rows);local plain=predict(s,T.observation(241,13));local contextual=predict(s,T.observation(242,13,1,{{9,1}}))
 assert(plain.byId[1].grade>0 and contextual.byId[1].grade<0)
 local sets={{1,2},{2,3},{3,1}};rows={}
 for i=1,360 do local pair=sets[(i-1)%3+1];rows[i]=T.observation(i,math.ceil(i/30),pair[1],{},pair)end
 s=train(rows);for _,pair in ipairs(sets)do local r=predict(s,T.observation(999,99,pair[1],{},pair));assert(r.byId[pair[1]].grade>0 and r.byId[pair[2]].grade<0)end
end)
T.test('old saved history rebuilds evidence without a destructive migration',function()
 local profile={id='p1',schemaVersion=1,history={T.observation(1,1,1,{{9,2}})}};local before=profile.history[1]
 local h=K.History.New(profile);local d=h:BuildDataset(0);local s=K.History.GetPerkStats(d,T.observation(2,2,1,{{9,3},{10,1}}))
 T.eq(profile.history[1],before);T.eq(s.byId[1].total,1);T.eq(s.byId[1].knownVisions,1);T.eq(s.byId[1].currentVisions,2)
 T.eq(s.exact,nil)
end)
T.test('unseen stacks or a new direct opponent limit strength but keep information',function()
 local rows={};for i=1,120 do rows[i]=T.observation(i,math.ceil(i/10),1,{{9,1}})end
 local s=train(rows)
 local known=predict(s,T.observation(121,13,1,{{9,1}}));T.eq(known.byId[1].grade,3)
 local stacked=predict(s,T.observation(122,13,1,{{9,2}}));T.eq(stacked.byId[1].grade,1)
 for i=121,240 do rows[i]=T.observation(i,math.ceil(i/10),3,{{9,1}},{3,4})end
 s=train(rows);local other=predict(s,T.observation(999,99,1,{{9,1}},{1,4}));T.eq(other.byId[1].grade,1);T.eq(other.byId[4].grade,-1)
end)
T.test('out of sample calibration can prefer indifference over fitting random choices',function()
 local rows={};local rng=193
 local function random(n)rng=rng*16807%2147483647;return math.floor(rng/2147483647*n)+1 end
 for i=1,500 do
  local a,b,c=random(12),random(12),random(12);while b==a do b=random(12)end;while c==a or c==b do c=random(12)end
  local ids={a,b,c};rows[i]=T.observation(i,math.ceil(i/10),ids[random(3)],{},ids)
 end
 local s=train(rows);assert(s.mixture and s.mixture.uniform>s.mixture.context)
 local dirs=0
 for a=1,11 do for b=a+1,12 do local r=predict(s,T.observation(999,99,a,{}, {a,b}));if r.byId[a].grade~=0 then dirs=dirs+1 end end end
 assert(dirs<12,'noise produces too many directional pairs: '..dirs)
end)
T.test('calibrated probabilities keep a meaningful baseline for a lone known perk',function()
 local rows={};for i=1,120 do rows[i]=T.observation(i,math.ceil(i/10))end
 local s=train(rows)
 local liked=predict(s,T.observation(999,99,1,{}, {1,9}));assert(liked.byId[1].grade>0)
 local disliked=predict(s,T.observation(999,99,2,{}, {2,9}));assert(disliked.byId[2].grade<0)
end)
T.test('unknown third option cannot break a tie between known mixture estimates',function()
 local s={members={{['a:1']=-2,['a:2']=0}},base={['a:1']=4,['a:2']=2},mixture={uniform=.02,base=.49,context=.49},dataset={perkStats={[1]={},[2]={}}}}
 local pair=K.ChoiceModel.Predict(s,T.observation(1,1,1,{}, {1,2}))
 local triple=K.ChoiceModel.Predict(s,T.observation(2,1,1,{}, {1,2,3}))
 T.near(pair[1][1]-pair[1][2],0);T.near(triple[1][1]-triple[1][2],0)
end)
T.test('resumed old runs do not leak later choices into chronological calibration',function()
 local rows={};for i=1,40 do rows[i]=T.observation(i,math.ceil(i/10),i%3==0 and 2 or 1)end
 local a=train(rows)
 for i=41,70 do rows[i]=T.observation(i,1,2)end
 local b=train(rows)
 T.near(a.mixture.base,b.mixture.base,1e-10);T.near(a.mixture.context,b.mixture.context,1e-10)
end)
T.test('a perk outside the training window still shows archived facts instead of disappearing',function()
 local h=K.History.New({id='p1'});h:Append(T.observation(1,1))
 for i=2,2001 do h:Append(T.observation(i,math.ceil(i/10),3,{}, {3,4}))end
 local s,why=T.drain(K.ChoiceModel.NewFitJob(h:BuildDataset(0),nil,17));assert(s,why)
 local o=T.observation(2002,202);local r=predict(s,o)
 T.eq(r.byId[1].grade,0);T.eq(r.byId[2].grade,0)
 local stats=K.History.GetPerkStats(s.dataset,o);T.eq(stats.byId[1].total,1);T.eq(stats.byId[1].selected,1);assert(stats.byId[1].archiveOnly)
 local partial=predict(s,T.observation(2004,202,3,{}, {3,4,1}));T.eq(partial.byId[3].grade,3);T.eq(partial.byId[4].grade,-3);T.eq(partial.byId[1].grade,0)
 local unrelated=predict(s,T.observation(2003,202,5,{}, {5,6}));T.eq(unrelated.byId[5].grade,nil)
end)
