local K=KanaArchiveAssist;local C=K.Config
local H={};K.History=H
local function recordStats(byId,o,weight)
  for _,id in ipairs(o.options)do
   local p=byId[id]
   if not p then p={total=0,selected=0,runs=0,weighted=0,runIds={},visions={},pairs={}};byId[id]=p end
   p.total=p.total+1;p.weighted=p.weighted+weight
   if o.selectedId==id then p.selected=p.selected+1 end
   if not p.runIds[o.runId]then p.runIds[o.runId]=true;p.runs=p.runs+1 end
   for _,v in ipairs(o.context.visions)do p.visions[v[1]]=math.max(p.visions[v[1]]or 0,v[2]) end
   for _,other in ipairs(o.options)do if other~=id then
    local pair=p.pairs[other]or {total=0,chosen=0,otherChosen=0};p.pairs[other]=pair;pair.total=pair.total+1
    if o.selectedId==id then pair.chosen=pair.chosen+1 elseif o.selectedId==other then pair.otherChosen=pair.otherChosen+1 end
   end end
  end
end
function H.New(profile)
 profile.history=profile.history or {};profile.schemaVersion=profile.schemaVersion or 1
 local self=setmetatable({profile=profile,ids={},revisions={},runIndices={},runCounts={},lifetimeStats={},summary={total=0,runs=0,byType={},runTotals={}}}, {__index=H})
 if profile.schemaVersion~=1 then self.unavailable=true;return self end
 for _,o in ipairs(profile.history)do self:Index(o) end
 return self
end
function H:Valid(o)
 if not C.ValidOffer(o) or o.schemaVersion~=1 or o.profileId~=self.profile.id or type(o.observationId)~='string' or type(o.runId)~='string' or not C.Finite(o.timestamp) then return false end
 for _,id in ipairs(o.options)do if id==o.selectedId then return true end end;return false
end
function H:Index(o)
 if not self:Valid(o) or self.ids[o.observationId] then return false end
 self.ids[o.observationId]=true
 local t=o.buffType;self.runIndices[t]=self.runIndices[t] or {}
 if not self.runIndices[t][o.runId] then
  self.runCounts[t]=(self.runCounts[t] or 0)+1;self.runIndices[t][o.runId]=self.runCounts[t]
 end
 self.lifetimeStats[t]=self.lifetimeStats[t]or {};recordStats(self.lifetimeStats[t],o,0)
 local s=self.summary;s.total=s.total+1;s.byType[t]=(s.byType[t]or 0)+1
 if not s.runTotals[o.runId]then s.runs=s.runs+1 end
 s.runTotals[o.runId]=(s.runTotals[o.runId]or 0)+1;s.last=C.Copy(o)
 self.revisions[t]=(self.revisions[t] or 0)+1;return true
end
function H:Append(o)
 if self.unavailable or not self:Index(o) then return false end
 self.profile.history[#self.profile.history+1]=C.Copy(o);return true
end
function H:GetRevision(t) return self.revisions[t] or 0 end
function H:GetSummary(runId)
 local s=self.summary
 return {total=s.total,runs=s.runs,byType=C.Copy(s.byType),currentRun=s.runTotals[runId]or 0,last=C.Copy(s.last),unavailable=self.unavailable}
end
function H:BuildDataset(t,check)
 check=check or function()end
 local runCount=self.runCounts[t]or 0
 local d={profileId=self.profile.id,buffType=t,rows={},revision=self:GetRevision(t),statsIndex={},perkStats={},archiveStats={},unavailable=self.unavailable}
 if self.unavailable then return d end
 local kept,seen={},{}
 for i=#self.profile.history,1,-1 do
  local o=self.profile.history[i]
  if o.buffType==t and self:Valid(o) and not seen[o.observationId] then
   seen[o.observationId]=true;kept[#kept+1]=o;if #kept==C.window then break end
  end
  check()
 end
 for i=#kept,1,-1 do
  local o=C.Copy(kept[i]);local index=self.runIndices[t][o.runId]
  d.rows[#d.rows+1]={observation=o,weight=2^(-(runCount-index)/C.halfLife)}
  recordStats(d.perkStats,o,d.rows[#d.rows].weight)
  local key=C.OfferKey(o);local stats=d.statsIndex[key]
  if not stats then stats={total=0,runs=0,countsById={},runIds={}};d.statsIndex[key]=stats end
  stats.total=stats.total+1;stats.countsById[o.selectedId]=(stats.countsById[o.selectedId] or 0)+1
  if not stats.runIds[o.runId] then stats.runs=stats.runs+1;stats.runIds[o.runId]=true end
  check()
 end
 for id,p in pairs(self.lifetimeStats[t]or {})do
  if not d.perkStats[id]then d.archiveStats[id]=C.Copy(p);d.archiveStats[id].archiveOnly=true end
  check()
 end
 return d
end
function H.GetChoiceStats(dataset,offer)
 if not C.ValidOffer(offer) then return nil end
 local s=dataset.statsIndex[C.OfferKey(offer)];if not s then return nil end
 return {total=s.total,runs=s.runs,countsById=C.Copy(s.countsById)}
end

function H.GetPerkStats(dataset,offer)
 if not C.ValidOffer(offer)then return nil end
 local result={byId={},knownOptions=0,historyOptions=0,optionCount=#offer.options,exact=H.GetChoiceStats(dataset,offer)}
 for _,id in ipairs(offer.options)do
  local p=dataset.perkStats[id]or(dataset.archiveStats or {})[id]
  if p then
   local s={archiveOnly=p.archiveOnly,total=p.total,selected=p.selected,runs=p.runs,weighted=p.weighted,pairs={},knownVisions=0,knownStacks=0,currentVisions=#offer.context.visions}
   for _,v in ipairs(offer.context.visions)do if p.visions[v[1]]then s.knownVisions=s.knownVisions+1;if p.visions[v[1]]>=v[2]then s.knownStacks=s.knownStacks+1 end end end
   for _,other in ipairs(offer.options)do if p.pairs[other]then s.pairs[other]=C.Copy(p.pairs[other])end end
   result.byId[id]=s;result.historyOptions=result.historyOptions+1
   if not p.archiveOnly then result.knownOptions=result.knownOptions+1 end
  end
 end
 return result
end
