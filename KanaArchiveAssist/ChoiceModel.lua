local K=KanaArchiveAssist;local C,F=K.Config,K.Features
local M={};K.ChoiceModel=M
function M.Softmax(u)
 local max=-math.huge;for _,v in ipairs(u)do max=math.max(max,v)end
 local p,sum={},0;for i,v in ipairs(u)do p[i]=math.exp(v-max);sum=sum+p[i]end
 for i=1,#p do p[i]=p[i]/sum end;return p,max+math.log(sum)
end
function M.Compile(dataset,check)
 check=check or function()end
 local keys,raw,byKey={}, {}, {}
 for _,r in ipairs(dataset.rows)do
  local o=C.Copy(r.observation);table.sort(o.options)
  local key=C.OfferKey(o);local g=byKey[key]
  if not g then
   g={raw=F.BuildRows(o),observations={},options=o.options};byKey[key]=g;raw[#raw+1]=g
   for _,row in ipairs(g.raw)do for k in pairs(row)do keys[k]=true end end
  end
  local winner;for i,id in ipairs(o.options)do if id==o.selectedId then winner=i end end
  g.observations[#g.observations+1]={winner=winner,weight=r.weight,run=o.runId};check()
 end
 local list={};for k in pairs(keys)do list[#list+1]=k end;table.sort(list)
 local index=F.Index(list)
 for _,g in ipairs(raw)do
  g.rows={};for _,r in ipairs(g.raw)do g.rows[#g.rows+1]=F.Encode(r,index)end;g.raw=nil;check()
 end
 return {keys=list,index=index,groups=raw,dataset=dataset}
end
local function targets(compiled,check)
 check=check or function()end
 local result={}
 for gi,g in ipairs(compiled.groups)do
  local t={total=0};for i=1,#g.rows do t[i]=0 end
  for _,o in ipairs(g.observations)do
   t[o.winner]=t[o.winner]+o.weight;t.total=t.total+o.weight;check()
  end
  result[gi]=t
 end
 return result
end
function M.LossGradient(theta,compiled,weights,check)
 check=check or function()end;weights=weights or targets(compiled)
 local loss,grad=0,{}
 for i,key in ipairs(compiled.keys)do local x=theta[i]or 0;local l=F.Lambda(key);grad[i]=l*x;loss=loss+0.5*l*x*x;if i%64==0 then check()end end
 for gi,g in ipairs(compiled.groups)do
  local u={};for i,row in ipairs(g.rows)do u[i]=F.Dot(theta,row)end
  local p,lse=M.Softmax(u);local t=weights[gi]
  for i,row in ipairs(g.rows)do loss=loss+t[i]*(lse-u[i]);F.Add(grad,row,t.total*p[i]-t[i])end;check()
 end
 return loss,grad
end
local function vecDot(a,b,check)local n=0;for i=1,#a do n=n+a[i]*b[i];if check and i%128==0 then check()end end;return n end
local function norm(a,check)local n=0;for i,v in ipairs(a)do n=math.max(n,math.abs(v));if check and i%128==0 then check()end end;return n end
local function fit(compiled,weights,start,check)
 local function dot(a,b)return vecDot(a,b,check)end
 weights=weights or targets(compiled,check)
 local x={};for i=1,#compiled.keys do x[i]=start and start[i]or 0;if i%128==0 then check()end end
 local loss,g=M.LossGradient(x,compiled,weights,check);local tolerance=C.fitTolerance*math.max(1,norm(g,check));local memory={}
 for iteration=0,C.maxFit do
  if not C.Finite(loss) then return nil,'numerical_failure' end
  if norm(g,check)<=tolerance then return x end
  if iteration==C.maxFit then return nil,'not_converged' end
  local q={};for i,v in ipairs(g)do q[i]=v;if i%128==0 then check()end end
  local alpha={}
  for j=#memory,1,-1 do local m=memory[j];alpha[j]=m.rho*dot(m.s,q);for i=1,#q do q[i]=q[i]-alpha[j]*m.y[i];if i%128==0 then check()end end;check()end
  local scale=1;local last=memory[#memory];if last then scale=dot(last.s,last.y)/dot(last.y,last.y)end
  for i=1,#q do q[i]=q[i]*scale;if i%128==0 then check()end end
  for j,m in ipairs(memory)do local b=m.rho*dot(m.y,q);for i=1,#q do q[i]=q[i]+m.s[i]*(alpha[j]-b);if i%128==0 then check()end end;check()end
  for i=1,#q do q[i]=-q[i];if i%128==0 then check()end end
  local slope=dot(g,q)
  if slope>=0 then memory={};for i=1,#q do q[i]=-g[i]end;slope=-dot(g,g)end
  local step,newLoss,newG,newX=1
  for _=1,24 do
   newX={};for i=1,#x do newX[i]=x[i]+step*q[i];if i%128==0 then check()end end
   newLoss,newG=M.LossGradient(newX,compiled,weights,check)
   if C.Finite(newLoss) and newLoss<=loss+1e-4*step*slope+1e-14*math.max(1,math.abs(loss)) then break end
   step=step/2;newX=nil
  end
  if not newX then return nil,'not_converged' end
  local s,y={},{};for i=1,#x do s[i]=newX[i]-x[i];y[i]=newG[i]-g[i];if i%128==0 then check()end end
  local sy=dot(s,y)
  if sy>0 then memory[#memory+1]={s=s,y=y,rho=1/sy};if #memory>8 then table.remove(memory,1)end else memory={}end
  x,loss,g=newX,newLoss,newG;check()
 end
end
local function baseCompiled(compiled,check)
 local keys={};for _,k in ipairs(compiled.keys)do if k:sub(1,1)=='a'then keys[#keys+1]=k end end
 local index=F.Index(keys);local result={keys=keys,index=index,groups={}}
 for _,g in ipairs(compiled.groups)do
  local group={rows={},observations=g.observations}
  for _,row in ipairs(g.rows)do
   local raw={};for i=1,#row,2 do local k=compiled.keys[row[i]];if index[k]then raw[k]=row[i+1]end end
   group.rows[#group.rows+1]=F.Encode(raw,index)
  end
  result.groups[#result.groups+1]=group;check()
 end
 return result
end
local function fitMap(compiled,old,check)
 local start={};for i,key in ipairs(compiled.keys)do start[i]=old and old[key]or 0;if i%128==0 then check()end end
 local x,reason=fit(compiled,nil,start,check);if not x then return nil,reason end
 local map={};for i,key in ipairs(compiled.keys)do map[key]=x[i];if i%128==0 then check()end end;return map
end
local function predictMap(theta,offer)
 local raw=F.BuildRows(offer);local u={}
 for i,row in ipairs(raw)do local n=0;for key,v in pairs(row)do n=n+(theta[key]or 0)*v end;u[i]=n end
 return u,M.Softmax(u)
end
local function calibrate(dataset,check)
 local runs,seen={},{}
 for _,r in ipairs(dataset.rows)do local id=r.observation.runId;if not seen[id]then seen[id]=true;runs[#runs+1]=id end;check()end
 if #runs<4 then return {uniform=0,base=1,context=0,validationRuns=0,validationChoices=0}end
 local validationRuns=math.ceil(#runs/4);local held={}
 for i=#runs-validationRuns+1,#runs do held[runs[i]]=true end
 local training={rows={}};local validation={};local cutoff
 for i,r in ipairs(dataset.rows)do if held[r.observation.runId]then cutoff=i;break end end
 for i,r in ipairs(dataset.rows)do
  if held[r.observation.runId]then validation[#validation+1]=r
  elseif i<cutoff then training.rows[#training.rows+1]=r end
  check()
 end
 local compiled=M.Compile(training,check)
 local base,reason=fitMap(baseCompiled(compiled,check),nil,check);if not base then return nil,reason end
 local context;context,reason=fitMap(compiled,nil,check);if not context then return nil,reason end
 -- These scores come from later *whole runs* excluded from both validation fits.
 -- They select predictive mixtures, not posterior confidence in a perk's rank.
 local losses={-math.log(.4),-math.log(.4),-math.log(.2)}
 for _,r in ipairs(validation)do
  local o=r.observation;local _,bp=predictMap(base,o);local _,cp=predictMap(context,o)
  for i,id in ipairs(o.options)do if id==o.selectedId then
   losses[1]=losses[1]+r.weight*math.log(#o.options)
   losses[2]=losses[2]-r.weight*math.log(math.max(1e-15,bp[i]))
   losses[3]=losses[3]-r.weight*math.log(math.max(1e-15,cp[i]))
  end end;check()
 end
 local w=M.Softmax({-losses[1],-losses[2],-losses[3]})
 return {uniform=.02+.94*w[1],base=.02+.94*w[2],context=.02+.94*w[3],validationRuns=validationRuns,validationChoices=#validation}
end
function M.NewFitJob(dataset,previous,seed,clock)
 return C.Job(function(check)
  if type(dataset)=='function'then dataset=dataset(check)end
  if dataset.unavailable or #dataset.rows==0 then return nil,'insufficient_history' end
  local mixture,reason=calibrate(dataset,check);if not mixture then return nil,reason end
  local compiled=M.Compile(dataset,check)
  local old=previous and previous.configVersion==C.version and previous
  local base;base,reason=fitMap(baseCompiled(compiled,check),old and old.base,check);if not base then return nil,reason end
  local context;context,reason=fitMap(compiled,old and old.members[1],check);if not context then return nil,reason end
  return {version=(previous and previous.version or 0)+1,profileId=dataset.profileId,buffType=dataset.buffType,historyRevision=dataset.revision,configVersion=C.version,members={context},base=base,mixture=mixture,compiled=compiled,dataset=dataset}
 end,clock)
end
function M.Predict(snapshot,offer)
 local contextU,p=predictMap(snapshot.members[1],offer);local u={}
 for i,v in ipairs(contextU)do u[i]=v end
 if snapshot.mixture then
  local baseU,bp=predictMap(snapshot.base,offer);local w=snapshot.mixture
  for i=1,#p do p[i]=w.uniform/#p+w.base*bp[i]+w.context*p[i];u[i]=math.log(p[i]*#p)end
  -- Full probabilities model the actual offer, but glyphs compare only known
  -- abilities. Normalize each expert on that subset *before* mixing it.
  local known={}
  if snapshot.dataset then for i,id in ipairs(offer.options)do if snapshot.dataset.perkStats[id]then known[#known+1]=i end end end
  if #known>=2 and #known<#offer.options then
   local bu,cu={},{};for j,i in ipairs(known)do bu[j]=baseU[i];cu[j]=contextU[i]end
   local bq,cq=M.Softmax(bu),M.Softmax(cu)
   for j,i in ipairs(known)do u[i]=math.log((w.uniform/#known+w.base*bq[j]+w.context*cq[j])*#known)end
  elseif #known==1 then
   local i=known[1];local bq,cq=M.Softmax({baseU[i],0}),M.Softmax({contextU[i],0})
   local q=w.uniform*.5+w.base*bq[1]+w.context*cq[1];u[i]=math.log(q/math.max(1e-15,1-q))
  end
 end
 return {u},{p}
end
M.Fit=fit
