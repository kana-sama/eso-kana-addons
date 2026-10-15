local T=KAATest
for _,n in ipairs({'Config','History','ContextSupport'})do T.load(n)end
local K=KanaArchiveAssist
T.test('empty or unrelated history never fabricates evidence for unseen abilities',function()
 local h=K.History.New({id='p1'});local d=h:BuildDataset(0)
 local r=T.drain(K.ContextSupport.NewJob(d,{},T.observation(2,2)))
 assert(not r.supported);T.eq(next(r.byId),nil)
 h:Append(T.observation(1,1,4,{}, {4,5}));r=T.drain(K.ContextSupport.NewJob(h:BuildDataset(0),{},T.observation(2,2)))
 assert(not r.supported);T.eq(next(r.byId),nil)
end)
T.test('many encounters in one run cannot immediately give three chevrons',function()
 local h=K.History.New({id='p1'});for i=1,40 do h:Append(T.observation(i,1))end
 local r=T.drain(K.ContextSupport.NewJob(h:BuildDataset(0),{},T.observation(99,99)))
 assert(r.supported);T.eq(r.byId[1].maxLevel,1)
end)
T.test('evidence and per-ability tooltip facts own their copies',function()
 local h=K.History.New({id='p1'});h:Append(T.observation(1,1,1,{{9,1}}))
 local d=h:BuildDataset(0);local offer=T.observation(2,2,1,{{9,2},{10,1}})
 local r=T.drain(K.ContextSupport.NewJob(d,{},offer));T.eq(r.stats.byId[1].knownVisions,1)
 r.stats.byId[1].pairs[2].chosen=999
 T.eq(K.History.GetPerkStats(d,offer).byId[1].pairs[2].chosen,1)
end)
