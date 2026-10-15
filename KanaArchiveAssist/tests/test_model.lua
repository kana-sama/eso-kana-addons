local T=KAATest;T.load('Config');T.load('Profiles');local H=T.load('History');local F=T.load('Features');local M=T.load('ChoiceModel')
local function data(n)
 local h=H.New({id='p1'});for i=1,n do h:Append(T.observation(i,math.ceil(i/4),i%4==0 and 2 or 1))end;return h:BuildDataset(0)
end
T.test('stack features preserve thresholds and unseen query coordinates',function()
 local a=F.BuildRows({options={1,2},buffType=0,context={visions={{9,5}}}})
 T.eq(a[1]['b:1:9:1'],1);T.eq(a[1]['b:1:9:2'],1);T.near(a[1]['b:1:9:4'],math.log(3));T.eq(a[1]['c:1:2'],1)
end)
T.test('whole triple loss and finite difference gradient',function()
 local h=H.New({id='p1'});h:Append(T.observation(1,1,1,{}, {1,2,3}));local d=M.Compile(h:BuildDataset(0));local x={}
 for i=1,#d.keys do x[i]=0.1*i end
 local loss,g=M.LossGradient(x,d)
 for i=1,#x do local old=x[i];x[i]=old+1e-5;local a=M.LossGradient(x,d);x[i]=old-1e-5;local b=M.LossGradient(x,d);x[i]=old;T.near(g[i],(a-b)/2e-5,1e-5)end
 local zero={};for i=1,#d.keys do zero[i]=0 end;T.near(M.LossGradient(zero,d),math.log(3))
end)
T.test('stable softmax and deterministic fit agree with scalar optimum',function()
 local p=M.Softmax({1000,999,-1000});T.near(p[1]+p[2]+p[3],1);assert(p[1]>p[2])
 local d=data(60);local s,err=T.drain(M.NewFitJob(d,nil,17));assert(s,err)
 local u,prob=M.Predict(s,{options={1,2},buffType=0,context={visions={}}});assert(prob[1][1]>0.6)
 local again=T.drain(M.NewFitJob(d,s,17));local _,q=M.Predict(again,{options={1,2},buffType=0,context={visions={}}});T.near(q[1][1],prob[1][1],1e-5)
 T.eq(#u,1)
end)
T.test('regularized choice optimum matches independent dense Newton',function()
 for _,f in ipairs(dofile('KanaArchiveAssist/tests/fixtures/numerical.lua'))do
  local h=H.New({id='p1'});for i,o in ipairs(f.observations)do h:Append(T.observation(i,math.ceil(i/12),o.selected,o.visions,o.options))end
  local d=M.Compile(h:BuildDataset(0));local x,err=M.Fit(d,nil,nil,function()end);assert(x,err)
  T.near(M.LossGradient(x,d),f.loss,1e-7)
  local map={};for i,k in ipairs(d.keys)do map[k]=x[i]end
  local first=f.observations[1];local _,p=M.Predict({members={map}},{options=first.options,context={visions=first.visions}})
  for i=1,#p[1]do T.near(p[1][i],f.probabilities[i],1e-5)end
 end
end)
T.test('warm fits remain converged at floating point loss resolution',function()
 local sets={{101,102},{101,103},{101,104},{102,103},{102,104},{103,104},{101,102,103},{101,102,104},{101,103,104},{102,103,104}}
 local h=H.New({id='p1'});local snap;local rng=17;local truth={['a:101']=1.2,['a:102']=.4,['a:103']=-.4,['a:104']=-1.2}
 local function random()rng=rng*16807%2147483647;return rng/2147483647 end
 for run=1,42 do
  if run>1 then local why;snap,why=T.drain(M.NewFitJob(h:BuildDataset(0),snap,17));assert(snap,why)end
  for j=1,12 do local i=(run-1)*12+j;local ids=KanaArchiveAssist.Config.Copy(sets[(i-1)%10+1]);if random()<.5 then ids[1],ids[#ids]=ids[#ids],ids[1]end
   local o=T.observation(i,run,ids[1],{},ids);local _,p=M.Predict({members={truth}},o);local v=random();for k,prob in ipairs(p[1])do v=v-prob;if v<=0 then o.selectedId=ids[k];break end end;h:Append(o)
  end
 end
end)
T.test('small positive curvature is retained for a precise warm start',function()
 local h=H.New({id='p1'});local rng=17;local sets={{1,2},{1,3},{1,4},{2,3},{2,4},{3,4},{1,2,3},{1,2,4},{1,3,4},{2,3,4}}
 for i=1,1920 do
  local ids=KanaArchiveAssist.Config.Copy(sets[(i-1)%10+1]);rng=rng*16807%2147483647;if rng/2147483647<.5 then ids[1],ids[#ids]=ids[#ids],ids[1]end
  rng=rng*16807%2147483647;h:Append(T.observation(i,math.ceil(i/60),ids[math.min(#ids,math.floor(rng/2147483647*#ids)+1)],{},ids))
 end
 local config=KanaArchiveAssist.Config;local old={config.lambdaA,config.lambdaB,config.lambdaC};config.lambdaA,config.lambdaB,config.lambdaC=.25,2,1
 local d=h:BuildDataset(0);local snap,err=T.drain(M.NewFitJob(d,nil,17));assert(snap,err)
 local warm,why=T.drain(M.NewFitJob(d,snap,17));config.lambdaA,config.lambdaB,config.lambdaC=old[1],old[2],old[3];assert(warm,why)
end)
T.test('dataset preparation and training yield without publishing partial members',function()
 local h=H.New({id='p1'});for i=1,120 do h:Append(T.observation(i,math.ceil(i/12)))end
 local started=false;local now=0;local job=M.NewFitJob(function(check)started=true;return h:BuildDataset(0,check)end,nil,17,function()now=now+1;return now end)
 assert(not started);local done,result=job:Step(2);assert(started and not done and not result)
 local snapshot=T.drain(job);T.eq(#snapshot.members,1)
end)
