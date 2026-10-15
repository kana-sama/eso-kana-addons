local K=KanaArchiveAssist
local G={};K.Grades=G
local threshold=math.log(1.15/.85)
local function level(d)
 local e=math.exp(-math.abs(d));local q=(1-e)/(1+e)
 if q+1e-12>=.55 then return 3 elseif q+1e-12>=.35 then return 2 elseif q+1e-12>=.15 then return 1 else return 0 end
end
function G.FromUtilities(options,u)
 local order={};for i,id in ipairs(options)do order[#order+1]={id=id,u=u[i]}end
 table.sort(order,function(a,b)if a.u==b.u then return a.id<b.id else return a.u>b.u end end)
 local out={}
 if #order==2 then local l=level(order[1].u-order[2].u);out[order[1].id]=l;out[order[2].id]=-l;return out end
 local a,b,c=order[1],order[2],order[3];local d1,d2=a.u-b.u,b.u-c.u;local range=d1+d2;local x,y,z
 if range<threshold-1e-12 then x,y,z=0,0,0
 elseif d1<threshold-1e-12 and d2>=threshold-1e-12 then x,y,z=level(range),level(d2),-level(d2)
 elseif d1>=threshold-1e-12 and d2<threshold-1e-12 then x,y,z=level(d1),-level(d1),-level(range)
 elseif d1>=threshold-1e-12 and d2>=threshold-1e-12 then x,y,z=level(d1),0,-level(d2)
 else x,y,z=level(range),0,-level(range)end
 out[a.id],out[b.id],out[c.id]=x,y,z;return out
end
function G.Rate(options,utilities,evidence)
 local known,u={},{}
 for i,id in ipairs(options)do if evidence.byId[id]and not evidence.byId[id].archiveOnly then known[#known+1]=id;u[#u+1]=utilities[i]end end
 local grades={}
 if #known>=2 then grades=G.FromUtilities(known,u)
 elseif #known==1 then
  -- Utilities are centered by the common regularized prior; this is an overall
  -- tendency, not a claimed comparison against never-seen opponents.
  grades[known[1]]=G.FromUtilities({known[1],0},{u[1],0})[known[1]]
 end
 local result={byId={},support=evidence,reason=evidence.reason}
 for _,id in ipairs(options)do
  local g=grades[id];local p=evidence.byId[id]
  if p and p.archiveOnly then g=0 end
  if g and p then g=math.max(-p.maxLevel,math.min(p.maxLevel,g))end
  result.byId[id]={grade=g}
 end
 return result
end
