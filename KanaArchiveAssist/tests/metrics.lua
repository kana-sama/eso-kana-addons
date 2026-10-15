-- Evaluate only information visible in the glyphs, without a hidden score tie-break.
return function(options,grades,truth)
 local best,top=-math.huge,0
 for i,id in ipairs(options)do best=math.max(best,truth[i]);top=math.max(top,grades[id]or 0)end
 if top==0 then return nil end
 local result={hit=0,regret=0,randomHit=0,randomRegret=0};local ties=0
 for i,id in ipairs(options)do
  local regret=best-truth[i];local hit=regret<=.3 and 1 or 0
  result.randomHit=result.randomHit+hit/#options;result.randomRegret=result.randomRegret+regret/#options
  if grades[id]==top then result.hit=result.hit+hit;result.regret=result.regret+regret;ties=ties+1 end
 end
 result.hit=result.hit/ties;result.regret=result.regret/ties;return result
end
