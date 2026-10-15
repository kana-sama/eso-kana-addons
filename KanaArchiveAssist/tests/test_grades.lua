local T=KAATest;T.load('Config');local G=T.load('Grades');T.load('History')
T.test('pairs and all triple roles',function()
 for _,x in ipairs({{.55,0},{.6,1},{.7,2},{.8,3}})do local u=math.log(x[1]/(1-x[1]));local g=G.FromUtilities({1,2},{u,0});T.eq(g[1],x[2]);T.eq(g[2],-x[2])end
 for _,x in ipairs({{{1,0,-1},{2,0,-2}},{{1,1,0},{2,2,-2}},{{1,0,0},{2,-2,-2}},{{0,0,0},{0,0,0}},{{.4,.2,0},{1,0,-1}}})do
  local g=G.FromUtilities({1,2,3},x[1]);for i=1,3 do T.eq(g[i],x[2][i])end
  local flipped=G.FromUtilities({3,1,2},{x[1][3],x[1][1],x[1][2]});for i=1,3 do T.eq(flipped[i],g[i])end
 end
end)
T.test('evidence caps magnitude without changing direction or hiding a known tie',function()
 local evidence={byId={[1]={maxLevel=1},[2]={maxLevel=2},[3]={maxLevel=3}}}
 local result=G.Rate({1,2,3},{5,0,-5},evidence)
 T.eq(result.byId[1].grade,1);T.eq(result.byId[2].grade,0);T.eq(result.byId[3].grade,-3)
end)
T.test('exact stats use same alternatives and all vision stacks',function()
 local h=KanaArchiveAssist.History.New({id='p1'});for i=1,12 do h:Append(T.observation(i,math.ceil(i/3),i<=7 and 1 or i<=11 and 2 or 3,{{9,2}},{1,2,3}))end
 local d=h:BuildDataset(0);local o=T.observation(99,99,1,{{9,2}},{3,1,2});local s=KanaArchiveAssist.History.GetChoiceStats(d,o)
 T.eq(s.total,12);T.eq(s.runs,4);T.eq(s.countsById[1],7);o.context.visions[1][2]=1;assert(not KanaArchiveAssist.History.GetChoiceStats(d,o))
end)
