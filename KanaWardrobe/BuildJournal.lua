-- Durable facts only: native handles, bag indexes and live catalogues stay runtime.
local KW=KanaWardrobe
local J={};KW.BuildJournal=J
local components={equipment=true,abilities=true,attributes=true}
local states={confirming=true,applying=true,preparingEdit=true,editing=true,restoring=true,recovery=true}
local phases={skills=true,attributes=true,equipment=true,complete=true,locking=true,committing=true}
local stages={requesting=true,dispatching=true,waiting=true,confirmed=true,entry=true,sheathing=true,cooldown=true}
local function revision(value)return type(value)=='number' and value>=0 and value<math.huge and value==math.floor(value)end
local fields={'version','kind','operation','state','phase','page','component','presetId','revision','name','saveCommitted','committedRevision','paused','requestStage','maySent','fingerprint','dependencyKeys','budgets','confirmed','missing','problem','resolution','relinquished','ownerToken','verification'}
local function plain(v,seen,depth)
 if type(v)=='nil' or type(v)=='boolean' or type(v)=='string'then return v end
 if type(v)=='number'then if v==v and math.abs(v)<math.huge then return v end;error('invalid number')end
 if type(v)~='table' or getmetatable(v)~=nil then error('nonplain journal value')end
 seen=seen or {};depth=depth or 0;assert(not seen[v] and depth<20,'cyclic/deep journal');seen[v]=true
 local out={};for k,value in pairs(v)do assert(type(k)=='string' or type(k)=='number','invalid key');out[k]=plain(value,seen,depth+1)end
 seen[v]=nil;return out
end
local function canonical(value,component)
 if value==nil then return nil end
 local build,problem=KW.BuildModel.Normalize(value);assert(build,problem and problem.code or 'invalid build')
 if component then return {[component]=build[component]}end
 return {equipment=build.equipment,abilities=build.abilities,attributes=build.attributes}
end
local function aux(value)
 if value==nil then return end
 assert(type(value)=='table','invalid auxiliary facts')
 for category,slots in pairs(value)do
  assert(type(category)=='number' and category>=0 and category%1==0 and type(slots)=='table','invalid auxiliary category')
  for slot,ref in pairs(slots)do assert(type(slot)=='number' and slot>=0 and slot%1==0,'invalid native slot');assert(KW.BuildModel.Normalize({abilities={bars={front={[1]=ref}}}}),'invalid auxiliary ref')end
 end
end
local function pick(value,keys)
 if value==nil then return end
 assert(type(value)=='table','invalid journal record')
 local out={};for _,key in ipairs(keys)do if value[key]~=nil then out[key]=plain(value[key])end end
 return out
end
local function plan(value)
 if value==nil then return end
 local out=pick(value,{'requested','target','capabilities','extras','extraKey','fingerprint','dependencyKeys','verification','confirmed','equipmentPlan','skillRequest','attributeRequest'})
 for _,key in ipairs({'requested','target'})do out[key]=canonical(out[key])end
 aux(out.verification and out.verification.auxiliaryTarget)
 return out
end
local function selection(value,component)
 if value==nil then return end
 assert(type(value)=='table','invalid selection')
 local wanted=component=='equipment' and {'equipment'} or component=='abilities' and {'skills','bars'} or component=='attributes' and {'attributes'} or {'equipment','skills','bars','attributes'}
 local out=pick(value,wanted)
 if out.attributes~=nil then assert(type(out.attributes)=='boolean','invalid attributes selection')end
 for _,domain in ipairs({'equipment','skills'})do for key,enabled in pairs(out[domain] or {})do
  assert(type(enabled)=='boolean','invalid selected flag')
  if domain=='equipment'then assert(KW.Slots.IsSupported(key),'invalid selected equipment')
  else assert(KW.BuildModel.Normalize({abilities={skills={[key]={kind=type(key)=='string' and key:match(':(%a+):'),purchased=false,rank=0}}}}),'invalid selected skill')end
 end end
 for bar,slots in pairs(out.bars or {})do
  assert(bar=='front' or bar=='back' or bar=='werewolf','invalid selected bar')
  for slot,flag in pairs(slots)do assert(type(slot)=='number' and slot>=1 and slot<=6 and slot%1==0 and type(flag)=='boolean','invalid selected bar slot')end
 end
 return out
end
local function pending(value,phase)
 if value==nil then return end
 local out=pick(value,{'phase','token','sent','sentAt','result','original','target','auxiliaryOriginal','auxiliaryTarget','problem','resolved','relinquished','cancelledGeneration','entryContext','kind','equipSlot','uid','before','expected','source','batch','outgoing'})
 assert(out.sent==nil or type(out.sent)=='boolean','invalid sent flag')
 assert(out.token==nil or type(out.token)=='number' and out.token>=1 and out.token%1==0,'invalid token')
 assert(out.result==nil or type(out.result)=='number' and out.result%1==0,'invalid native result')
 local original=out.original
 local domain=original and (original.skills or original.bars) and 'abilities' or original and original.health~=nil and 'attributes' or nil
 if domain then
  assert(type(out.target)=='table','missing pending target')
  for _,key in ipairs({'original','target'})do local normalized=canonical({[domain]=out[key]});out[key]=normalized[domain]end
  assert(not out.sent or out.token,'missing sent token')
 elseif out.kind then
  assert((out.kind=='equip' or out.kind=='unequip') and KW.Slots.IsSupported(out.equipSlot) and type(out.uid)=='string','invalid equipment pending')
 elseif phase=='skills' or phase=='attributes' then error('invalid component pending')end
 aux(out.auxiliaryOriginal);aux(out.auxiliaryTarget)
 return out
end
local function legacy(raw)
 assert(states[raw.state] and type(raw.original)=='table' and type(raw.selected)=='table' and type(raw.missing)=='table','invalid legacy journal')
 assert(raw.kind=='apply' or raw.kind=='edit' or raw.kind=='new','invalid legacy kind')
 local original=canonical({equipment=raw.original}).equipment
 for _,slot in ipairs(KW.Slots.Order)do assert(original[slot],'incomplete original gear')end
 assert(type(raw.name)=='string' and type(raw.presetId)=='string' and type(raw.revision)=='number' and raw.revision>=0 and raw.revision%1==0,'invalid legacy identity')
 if raw.originalPreset then assert(KW.BuildModel.Normalize(raw.originalPreset),'invalid legacy preset')end
 local out=plain(raw);pending(out.pending)
 return out
end
function J.Key(value)
 if type(value)=='string'then return 's'..#value..':'..value end
 if type(value)=='number'then return 'n'..string.format('%.17g',value)end
 if type(value)~='table'then return type(value)..':'..tostring(value)end
 local keys={};for key in pairs(value)do keys[#keys+1]=key end;table.sort(keys,function(a,b)return type(a)..tostring(a)<type(b)..tostring(b)end)
 local out={};for _,key in ipairs(keys)do out[#out+1]=J.Key(key)..'='..J.Key(value[key])end;return '{'..table.concat(out,';')..'}'
end
function J.Read(raw,repo)
 local ok,result=pcall(function()
  assert(type(raw)=='table','invalid journal')
  if raw.version==1 then return legacy(raw)end
  assert(raw.version==2 and (raw.kind=='new' or raw.kind=='edit' or raw.kind=='apply'),'invalid journal kind')
  local operation=raw.kind=='apply' and 'apply' or 'editor';assert(raw.operation==nil or raw.operation==operation,'invalid operation')
  local component=operation=='editor' and KW.BuildDraft.Component(raw.page) or nil
  assert(operation=='apply' or component and raw.component==component,'invalid editor component')
  assert(states[raw.state] and (states[raw.phase] or phases[raw.phase]) and type(raw.original)=='table','invalid journal state')
  assert(raw.requestStage==nil or stages[raw.requestStage],'invalid request stage')
  local out={};for _,key in ipairs(fields)do if raw[key]~=nil then out[key]=plain(raw[key])end end
  if operation=='apply'then assert(raw.page==nil and raw.component==nil,'invalid apply scope')end
  assert(raw.presetId==nil or type(raw.presetId)=='string' and raw.presetId~='','invalid preset identity')
  assert(raw.revision==nil or revision(raw.revision),'invalid preset revision')
  assert((raw.presetId==nil)==(raw.revision==nil),'incomplete preset identity')
  assert(raw.name==nil or type(raw.name)=='string','invalid journal name')
  assert(raw.saveCommitted==nil or type(raw.saveCommitted)=='boolean','invalid save checkpoint')
  if operation=='editor'then
   assert(type(raw.name)=='string','missing editor name')
   if raw.kind=='edit' or raw.saveCommitted then assert(raw.presetId and raw.revision,'missing editor identity')end
  end
  if raw.committedRevision~=nil then assert(revision(raw.committedRevision),'invalid committed revision')end
  if raw.phase=='committing' or raw.phase=='locking'then
   assert(operation=='editor' and type(raw.saveCommitted)=='boolean' and type(raw.commitCandidate)=='table','invalid commit checkpoint')
   local candidate=canonical(raw.commitCandidate);assert(KW.BuildModel.HasParts(candidate),'empty commit candidate')
   local name=KW.Presets.NormalizeName(raw.name);assert(name and name==raw.name,'invalid committing name')
   if raw.saveCommitted then assert(revision(raw.committedRevision) and raw.committedRevision==raw.revision,'invalid committed identity')end
  end

  if out.ownerToken then assert(type(out.ownerToken)=='number' and out.ownerToken>=1 and out.ownerToken%1==0,'invalid owner token')end
  for domain,flag in pairs(out.confirmed or {})do assert((components[domain] or domain=='skills') and type(flag)=='boolean','invalid confirmed domain')end
  if out.resolution then
   local r=out.resolution
   assert(type(r)=='table' and r.released==true and (r.resolution=='actualTarget' or r.resolution=='acceptCurrent' or r.resolution=='confirmActualTarget' or r.resolution=='relinquished'),'invalid local resolution')
   assert(r.nativeOutcome=='unknown' or r.nativeOutcome=='unsent' or type(r.nativeOutcome)=='number' and r.nativeOutcome%1==0,'invalid native outcome')
  end
  out.operation=operation;out.original=canonical(raw.original,component)
  for _,key in ipairs({'target','experiment','draft','actual'})do out[key]=canonical(raw[key],component)end
  for _,key in ipairs({'originalPreset','commitCandidate'})do out[key]=canonical(raw[key])end
  assert(not component or out.original[component],'missing original component')
  out.selection=selection(raw.selection,component)
  out.clearedGroups=pick(raw.clearedGroups,{'equipment','skills','bars','attributes'})
  for _,flag in pairs(out.clearedGroups or {})do assert(type(flag)=='boolean','invalid cleared group')end
  out.editorPlan=plan(raw.editorPlan)
  if raw.confirmation then
   out.confirmation=pick(raw.confirmation,{'action','presetName'});out.confirmation.plan=plan(raw.confirmation.plan)
  end
  out.pending=pending(raw.pending,raw.phase)
  aux(out.verification and out.verification.auxiliaryTarget)
  out.maySent=raw.maySent==true or raw.requestStage=='dispatching' or raw.requestStage=='requesting' and out.pending and out.pending.original and out.pending.original.health~=nil or out.pending and out.pending.sent==true or false
  return out
 end)
 if not ok then return nil,KW.Problem('invalidJournal',{reason=tostring(result)})end
 return result
end
function J.Write(saved,journal)
 if journal==nil then saved.journal=nil;return true end
 local validated,problem=J.Read(journal);if not validated then return nil,problem end
 saved.journal=validated;return true
end
function J.Reconcile(journal,actual)
 local confirmed,remaining={},{};local target=journal.target or journal.experiment or {};local unresolved=false
 for component in pairs(components)do if target[component]then
  local matches=KW.BuildModel.Matches(actual,{[component]=target[component]})
  if matches then confirmed[component]=true else remaining[component]=KW.Copy(target[component])end
 end end
 if journal.pending and journal.maySent and not journal.resolution then unresolved=true end
 return {confirmed=confirmed,remaining=remaining,unresolved=unresolved}
end
