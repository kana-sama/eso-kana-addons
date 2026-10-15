local K=KanaArchiveAssist;local C=K.Config
local S={};K.ContextSupport=S
-- Evidence limits strength, never withholds a known ability because a context is new.
function S.NewJob(dataset,snapshot,offer,clock)
 return C.Job(function(check)
  if dataset.unavailable or not C.ValidOffer(offer)then return {supported=false,reason='insufficient_history',byId={}}end
  local stats=K.History.GetPerkStats(dataset,offer)
  local result={supported=stats.historyOptions>0,byId={},stats=stats}
  if not result.supported then result.reason='insufficient_history'end
  for _,id in ipairs(offer.options)do
   local p=stats.byId[id]
   if p then
    local cap=1
    if p.weighted>=C.thirdLevelEvidence and p.runs>=3 then cap=3
    elseif p.weighted>=C.secondLevelEvidence and p.runs>=2 then cap=2 end
    -- New stack features and entirely unobserved matchups inherit the general
    -- estimate, but not the strongest visual emphasis.
    local newPair=false
    for _,other in ipairs(offer.options)do if other~=id and stats.byId[other]and not stats.byId[other].archiveOnly and not p.pairs[other]then newPair=true end end
    if p.knownStacks<p.currentVisions or newPair or stats.knownOptions==1 then cap=1 end
    p.preliminary=cap==1
    result.byId[id]={maxLevel=cap,archiveOnly=p.archiveOnly}
   end
   check()
  end
  return result
 end,clock)
end
