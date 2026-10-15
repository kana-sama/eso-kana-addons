KanaArchiveAssist=KanaArchiveAssist or {}
local K=KanaArchiveAssist
local C={version=3,window=2000,halfLife=30,fitTolerance=1e-6,maxFit=500,frameMs=2,lambdaA=2,lambdaB=16,lambdaC=2,secondLevelEvidence=8,thirdLevelEvidence=24,debugCapture=false}
K.Config=C
function C.Copy(t)
 if type(t)~='table' then return t end
 local r={};for k,v in pairs(t) do r[k]=C.Copy(v) end;return r
end
function C.Finite(x) return type(x)=='number' and x==x and math.abs(x)<math.huge end
function C.Visions(visions)
 if type(visions)~='table' then return nil end
 local out,seen={},{}
 for _,v in ipairs(visions or {}) do
  if type(v)~='table' or not C.Finite(v[1]) or v[1]<=0 or v[1]%1~=0 or not C.Finite(v[2]) or v[2]<1 or v[2]%1~=0 or seen[v[1]] then return nil end
  seen[v[1]]=true;out[#out+1]={v[1],v[2]}
 end
 table.sort(out,function(a,b)return a[1]<b[1] end);return out
end
function C.OfferKey(o)
 local ids={};for _,id in ipairs(o.options) do ids[#ids+1]=id end;table.sort(ids)
 local v=C.Visions(o.context and o.context.visions);if not v then return nil end
 local parts={tostring(o.buffType),table.concat(ids,',')}
 for _,x in ipairs(v) do parts[#parts+1]=x[1]..':'..x[2] end
 return table.concat(parts,';')
end
function C.ValidOffer(o)
 if type(o)~='table' or type(o.context)~='table' or type(o.context.visions)~='table' or type(o.options)~='table' or (#o.options~=2 and #o.options~=3) or not C.Finite(o.buffType) then return false end
 local seen={};for _,id in ipairs(o.options) do
  if not C.Finite(id) or id<=0 or id%1~=0 or seen[id] then return false end;seen[id]=true
 end
 return C.Visions(o.context and o.context.visions)~=nil
end
-- All numerical work can yield inside scans, rather than only between iterations.
function C.Job(fn,clock)
 local job={clock=clock or function()return 0 end}
 function job:Check() if self.clock()>=self.deadline then coroutine.yield() end end
 job.thread=coroutine.create(function()return fn(function()job:Check()end)end)
 function job:Step(deadline)
  if self.done then return true,self.result,self.reason end
  self.deadline=deadline
  local ok,result,reason=coroutine.resume(self.thread)
  if not ok then self.done=true;self.reason='numerical_failure';self.error=result
  elseif coroutine.status(self.thread)=='dead' then self.done=true;self.result=result;self.reason=reason end
  return self.done,self.result,self.reason
 end
 return job
end
