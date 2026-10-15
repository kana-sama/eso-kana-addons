local T=dofile('KanaArchiveAssist/tests/support.lua')
for _,n in ipairs({'Config','History','Features','ChoiceModel','ContextSupport'})do T.load(n)end
local K=KanaArchiveAssist;local catalog=dofile('KanaArchiveAssist/tests/fixtures/catalog.lua');local visions={}
for _,a in ipairs(catalog)do if a.kind==1 then visions[#visions+1]=a.id end end
local contextCount=tonumber(arg[1])or 9;assert(contextCount>=1 and contextCount<=#visions)
local history=K.History.New({id='p1'});local rng=73
local function pick()rng=rng*16807%2147483647;return visions[math.floor(rng/2147483647*#visions)+1]end
for i=1,2000 do
 local context,used={},{}
 while #context<contextCount do local id=pick();if not used[id]then used[id]=true;context[#context+1]={id,1+(i%3)}end end
 local options={pick(),pick(),pick()};while options[2]==options[1]do options[2]=pick()end;while options[3]==options[1]or options[3]==options[2]do options[3]=pick()end
 history:Append(T.observation(i,math.ceil(i/10),options[i%3+1],context,options))
end
local clock=function()return os.clock()*1000 end
local before=collectgarbage('count');local start=clock();local slices={}
local function drain(job)
 while true do local at=clock();local done,result,reason=job:Step(at+2);slices[#slices+1]=clock()-at;if done then assert(result,reason);return result end end
end
local snapshot=drain(K.ChoiceModel.NewFitJob(function(check)return history:BuildDataset(0,check)end,nil,73,clock));local fit=clock()-start
start=clock();drain(K.ContextSupport.NewJob(snapshot.dataset,snapshot,history.profile.history[2000],clock));local support=clock()-start
local after=collectgarbage('count');table.sort(slices)
print(string.format('2000 observations / 3 options / %d visions: fit=%.1fms support=%.1fms slices=%d p50=%.3fms p95=%.3fms max=%.3fms heap_delta=%.1fMiB',contextCount,fit,support,#slices,slices[math.ceil(#slices*.5)],slices[math.ceil(#slices*.95)],slices[#slices],(after-before)/1024))
