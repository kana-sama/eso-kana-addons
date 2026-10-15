local T=KAATest
T.test('simulation uses visible strength and averages indistinguishable green choices',function()
 local evaluate=dofile('KanaArchiveAssist/tests/metrics.lua')
 local x=evaluate({1,2,3},{[1]=1,[2]=1,[3]=-1},{2,0,1})
 T.near(x.hit,.5);T.near(x.regret,1);T.near(x.randomHit,1/3);T.near(x.randomRegret,1)
 local y=evaluate({1,2,3},{[1]=1,[2]=2,[3]=-1},{2,0,1})
 T.near(y.hit,0);T.near(y.regret,2)
 assert(not evaluate({1,2,3},{[1]=0,[2]=0,[3]=-1},{2,0,1}))
end)
