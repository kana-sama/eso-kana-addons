-- Sequential full-catalog experiment. The teacher never calls the model's feature builder.
-- Run from repository root: lua KanaArchiveAssist/tests/benchmark.lua [scenario] [seed] [two|three|mixed]
local T=dofile('KanaArchiveAssist/tests/support.lua')
for _,n in ipairs({'Config','History','Features','ChoiceModel','ContextSupport','Grades'})do T.load(n)end
local K=KanaArchiveAssist;local M=K.ChoiceModel
local evaluate=dofile('KanaArchiveAssist/tests/metrics.lua')
local catalog=dofile('KanaArchiveAssist/tests/fixtures/catalog.lua')
local columns={'offers','slots','shown','directions','opposite','spurious','picks','hits','randomHits','regret','randomRegret','n','nll','baseNll','affected','affectedNll','affectedBaseNll'}
local function empty()local m={};for _,k in ipairs(columns)do m[k]=0 end;return m end
local function experiment(kind,seed,mode)
 local rng=seed
 local function random()rng=rng*16807%2147483647;return rng/2147483647 end
 local function pick(xs)return xs[math.min(#xs,math.floor(random()*#xs)+1)]end
 local pools={[0]={{},{},{}},[1]={{},{},{}}};local base={};local triggers={}
 for _,a in ipairs(catalog)do pools[a.kind][a.bucket][#pools[a.kind][a.bucket]+1]=a;base[a.id]=(random()*2-1)*2 end
 for i=1,3 do triggers[i]=pools[1][i][1].id end
 local function truth(o,run,stacks)
  local u,affected={},false
  for i,id in ipairs(o.options)do
   local v=kind=='equal'and 0 or base[id]*(kind=='drift'and run>30 and -1 or 1)
   if kind=='context'or kind=='stacks'then
    local n=stacks[triggers[id%3+1]]or 0
    if n>0 then v=v+(id%2==0 and 2.5 or -2.5);affected=true end
    if kind=='stacks'and (stacks[id]or 0)>=2 then v=v-3;affected=true end
    if(stacks[triggers[1]]or 0)>0 and(stacks[triggers[2]]or 0)>0 then v=v+(id%5==0 and 1.5 or 0)end
   end
   if kind=='cycle'then
    local clan=id%3
    for _,other in ipairs(o.options)do if other~=id then
     local otherClan=other%3;if(clan-otherClan)%3==1 then v=v+1.5 elseif(clan-otherClan)%3==2 then v=v-1.5 end
    end end
   end
   u[i]=v
  end
  return u,affected
 end
 local function teacherChoice(options,u)
  -- 90% noisy preference choice, 10% uniform experimentation.
  if random()<.1 then return pick(options)end
  local peak=-math.huge;for _,v in ipairs(u)do peak=math.max(peak,v)end
  local weights,total={},0;for i,v in ipairs(u)do weights[i]=math.exp(v-peak);total=total+weights[i]end
  local r=random()*total
  for i,w in ipairs(weights)do r=r-w;if r<=0 then return options[i]end end
  return options[#options]
 end
 local histories={[0]=K.History.New({id='p1'}),[1]=K.History.New({id='p1'})};local snaps,bases={},{};local serial=0
 local function train(t)
  local d=histories[t]:BuildDataset(t);if #d.rows==0 then return end
  local reason;snaps[t],reason=T.drain(M.NewFitJob(d,snaps[t],seed));assert(snaps[t],reason);bases[t]={members={snaps[t].base}}
 end
 for run=1,60 do
  for t=0,1 do train(t)end
  local stacks={};local metrics={[0]=empty(),[1]=empty()}
  for cycle=1,10 do for stage=1,3 do
   local t=stage==3 and 1 or 0;local ids={};local buckets={1,2,3}
   if mode=='two'or(mode~='three'and random()<.3)then table.remove(buckets,math.floor(random()*3)+1)end
   for _,b in ipairs(buckets)do
    local eligible={}
    for _,a in ipairs(pools[t][b])do
     local unlocked=true;if a.requires then for _,id in ipairs(a.requires)do if(stacks[id]or 0)==0 then unlocked=false end end end
     if unlocked then eligible[#eligible+1]=a end
    end
    local a=pick(eligible)
    -- Skew scenario tests rare offers without claiming knowledge of server weights.
    if kind=='skew'then while a.id%11==0 and random()<.85 do a=pick(eligible)end end
    ids[#ids+1]=a.id
   end
   if random()<.5 then ids[1],ids[#ids]=ids[#ids],ids[1]end
   local visions={};for id,n in pairs(stacks)do visions[#visions+1]={id,n}end;table.sort(visions,function(a,b)return a[1]<b[1]end)
   serial=serial+1;local o=T.observation(serial,run,ids[1],visions,ids);o.buffType=t
   local utility,affected=truth(o,run,stacks);o.selectedId=teacherChoice(ids,utility)
   local metric=metrics[t];local snapshot=snaps[t];metric.offers=metric.offers+1;metric.slots=metric.slots+#ids
   if snapshot then
    local estimates,prob=M.Predict(snapshot,o);local _,bp=M.Predict(bases[t],o)
    local support=T.drain(K.ContextSupport.NewJob(snapshot.dataset,snapshot,o))
    local result=K.Grades.Rate(ids,estimates[1],support)
    local oracle=K.Grades.FromUtilities(ids,utility)
    local grades={}
    for i,id in ipairs(ids)do
     local grade=result.byId[id].grade;grades[id]=grade
     if grade~=nil then
      metric.shown=metric.shown+1
      if grade~=0 then
       metric.directions=metric.directions+1
       if grade*oracle[id]<0 then metric.opposite=metric.opposite+1 elseif oracle[id]==0 then metric.spurious=metric.spurious+1 end
      end
     end
     if o.selectedId==id then
      local nll=-math.log(math.max(1e-15,prob[1][i]));local bnll=-math.log(math.max(1e-15,bp[1][i]))
      metric.nll=metric.nll+nll;metric.baseNll=metric.baseNll+bnll
      if affected then metric.affected=metric.affected+1;metric.affectedNll=metric.affectedNll+nll;metric.affectedBaseNll=metric.affectedBaseNll+bnll end
     end
    end
    local visible=evaluate(ids,grades,utility)
    if visible then
     metric.picks=metric.picks+1;metric.regret=metric.regret+visible.regret;metric.randomRegret=metric.randomRegret+visible.randomRegret
     metric.hits=metric.hits+visible.hit;metric.randomHits=metric.randomHits+visible.randomHit
    end
    metric.n=metric.n+1
   end
   assert(histories[t]:Append(o))
   if t==1 then stacks[o.selectedId]=(stacks[o.selectedId]or 0)+1 end
   -- Reproduce live cold start within a run; subsequent fits between runs are
   -- conservative and keep the experiment inexpensive. Nothing sees the future.
   if run<=2 then train(t)end
  end end
  for t=0,1 do
   local fields={kind,tostring(seed),mode,tostring(run),tostring(t),'2'}
   for _,key in ipairs(columns)do fields[#fields+1]=string.format('%.9g',metrics[t][key])end
   print(table.concat(fields,','))
  end
  io.stdout:flush()
 end
end
print('scenario,seed,mode,run,type,protocol,'..table.concat(columns,','))
if arg[1]then experiment(arg[1],tonumber(arg[2])or 73,arg[3]or 'mixed')
else for _,kind in ipairs({'stable','context','stacks','cycle','equal','drift','skew'})do for _,seed in ipairs({73,271,2027,8191})do experiment(kind,seed,'mixed')end end end
