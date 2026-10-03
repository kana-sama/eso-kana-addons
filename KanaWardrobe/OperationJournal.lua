local KW=KanaWardrobe
local J={};KW.OperationJournal=J
function J.Plain(value,seen,depth)
 local t=type(value)
 if t=='nil' or t=='boolean' or t=='string'then return value end
 if t=='number'then assert(value==value and math.abs(value)<math.huge,'nonfinite journal number');return value end
 assert(t=='table' and not getmetatable(value),'runtime value in operation journal')
 seen=seen or {};depth=depth or 0
 assert(not seen[value] and depth<48,'cyclic/deep operation journal');seen[value]=true
 local result={}
 for k,v in pairs(value)do assert(type(k)=='string' or type(k)=='number','invalid journal key');result[k]=J.Plain(v,seen,depth+1)end
 seen[value]=nil;return result
end
function J.Archive(saved,operation)
 saved.operationHistory=saved.operationHistory or {}
 saved.operationHistory[#saved.operationHistory+1]=J.Plain(operation)
end
local function validOperation(op)
 if type(op)~='table' or op.version~=1 or type(op.intent)~='table' or type(op.steps)~='table'
  or type(op.index)~='number' or op.index%1~=0 or op.index<1 or not op.steps[op.index]then return false end
 for _,step in ipairs(op.steps)do
  if type(step)~='table' or type(step.kind)~='string' or step.attempts~=nil and type(step.attempts)~='table'then return false end
 end
 return op.index<=#op.steps
end
function J.Load(saved)
 if not saved.operation then return end
 local ok,op=pcall(J.Plain,saved.operation)
 if not ok or not validOperation(op)then
  saved.invalidOperation=saved.operation
  op={version=1,intent={kind='invalid'},index=1,steps={{id='diff',kind='diff',status='failed',attempts={},problem=KW.Problem('invalidOperation')}},status='failed',visible=true,hadFailure=true}
 else
  op.status='paused';op.pauseRequested=false;op.visible=false
  for _,step in ipairs(op.steps)do if step.status=='running'then step.status='unconfirmed' end end
 end
 saved.operation=J.Plain(op);return op
end
-- xpcall keeps the originating stack before unwinding native callbacks.
function J.ErrorDetails(err)
 local message=tostring(err)
 return {error=message,traceback=debug and debug.traceback and debug.traceback(message,2) or message}
end
function J.Report(saved)
 local out={'KanaWardrobe operation report','addon='..tostring(KW.version or '0.1.0')}
 local bytes,lines=0,0
 local limit=23500 -- leave room for the header and truncation notice
 local truncated=false
 local function append(line)
  if bytes+#line+1>limit or lines>=220 then truncated=true;return false end
  out[#out+1]=line;bytes=bytes+#line+1;lines=lines+1;return true
 end
 local seen={}
 local function dump(value,prefix,depth)
  if truncated then return end
  depth=depth or 0
  if type(value)~='table'then
   local scalar=tostring(value)
   if #scalar>2048 then
    local last=2048
    while scalar:byte(last+1)>=128 and scalar:byte(last+1)<192 do last=last-1 end
    scalar=scalar:sub(1,last)..' [value shortened; full value in SavedVariables]'
   end
   append(prefix..'='..scalar);return
  end
  if seen[value] then append(prefix..'=[cycle]');return end
  if depth>=16 then append(prefix..'=[depth limit; full value in SavedVariables]');return end
  seen[value]=true
  local keys={};for key in pairs(value)do keys[#keys+1]=key end
  table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
  for _,key in ipairs(keys)do
   dump(value[key],prefix..'.'..tostring(key),depth+1)
   if truncated then break end
  end
  seen[value]=nil
 end
 local op=saved.operation or saved.operationHistory and saved.operationHistory[#saved.operationHistory] or {}
 dump(op.id,'operation.id');dump(op.status,'operation.status');dump(op.index,'operation.index')
 dump(op.intent and op.intent.kind or op.kind,'operation.kind')
 dump(op.intent and op.intent.name or op.name,'operation.name')
 local step=op.steps and op.steps[op.index or 1] or {}
 local problem=step.problem or {};local details=problem.details or {}
 dump(step.kind,'step.kind');dump(problem.code,'failure.code')
 -- Put the error ahead of potentially huge actual/expected snapshots.
 for _,key in ipairs({'error','traceback','domain','result','phase','reason'})do
  if details[key]~=nil then dump(details[key],'failure.'..key)end
 end
 -- Put actionable differences before the full captured catalogue.
 for index,row in ipairs(details.differences or {})do
  if KW.Dialogs and KW.Dialogs.Difference then append('difference.'..index..'='..KW.Dialogs.Difference(row))end
 end
 dump(details.differences,'failure.differences')
 dump(saved.operationReportError,'reportDisplayError')
 dump(saved.operationObserverError,'observerError')
 for i,s in ipairs(op.steps or {})do
  append('steps.'..i..'='..tostring(s.kind)..' / '..tostring(s.status))
 end
 dump(problem,'step.problem');dump(step.details,'step.details');dump(step.pending,'step.pending')
 local attempts=step.attempts or {};dump(attempts[#attempts],'step.lastAttempt')
 dump(op,'operation')
 out[#out+1]=truncated and '[Report shortened. Full journal: SavedVariables/KanaWardrobe.lua]' or 'Full journal: SavedVariables/KanaWardrobe.lua'
 return table.concat(out,'\n')
end
function J.ShowReport(saved)
 -- Store UI failures independently; the original operation and error stay intact.
 local function onError(err)saved.operationReportError=tostring(err)end
 local ok,err=xpcall(function()
  KW.ProbeReport.Show(J.Report(saved),onError)
 end,J.ErrorDetails)
 if not ok then onError(err.traceback)end
end
