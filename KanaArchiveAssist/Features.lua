local K=KanaArchiveAssist;local C=K.Config
local F={};K.Features=F
function F.BuildRows(offer)
 local rows={}
 for _,id in ipairs(offer.options)do
  local row={['a:'..id]=1}
  for _,v in ipairs(offer.context.visions)do
   for k=1,3 do if v[2]>=k then row['b:'..id..':'..v[1]..':'..k]=1 end end
   if v[2]>3 then row['b:'..id..':'..v[1]..':4']=math.log(v[2]-2)end
  end
  for _,other in ipairs(offer.options)do if id~=other then row['c:'..id..':'..other]=1 end end
  rows[#rows+1]=row
 end
 return rows
end
function F.Encode(row,index)
 local entries={};for k,v in pairs(row)do entries[#entries+1]={index[k],v}end
 table.sort(entries,function(a,b)return a[1]<b[1]end)
 local out={};for _,x in ipairs(entries)do out[#out+1]=x[1];out[#out+1]=x[2]end;return out
end
function F.Dot(theta,row)
 local n=0;for k=1,#row,2 do n=n+(theta[row[k]]or 0)*row[k+1]end;return n
end
function F.Add(out,row,scale)
 for k=1,#row,2 do local i=row[k];out[i]=(out[i]or 0)+scale*row[k+1]end
end
function F.Lambda(key) return key:sub(1,1)=='a' and C.lambdaA or key:sub(1,1)=='b' and C.lambdaB or C.lambdaC end
function F.Index(keys)
 local out={};for i,k in ipairs(keys)do out[k]=i end;return out
end
