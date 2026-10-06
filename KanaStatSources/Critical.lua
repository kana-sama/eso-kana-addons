local K=KanaStatSources
local C={};K.Critical=C
function C.Calibrate(samples,rating)
    local out={verified=false,rating=rating,samples=samples or {}}
    local offset,slope
    for _,s in ipairs(samples or {}) do
        if K.Core.Finite(s.rating) and K.Core.Finite(s.chance) then
            if s.rating==0 then offset=s.chance end
            if s.rating==rating then out.chance=s.chance end
        end
    end
    if not offset then return out end
    for _,s in ipairs(samples or {}) do if s.rating==1 and K.Core.Finite(s.chance) then slope=s.chance-offset end end
    if not K.Core.Finite(slope) or slope<=0 then return out end
    local cap
    for _,s in ipairs(samples or {}) do
        if not K.Core.Finite(s.rating) or not K.Core.Finite(s.chance) then return out end
        local p=offset+s.rating*slope
        if math.abs(p-s.chance)>1e-6 then
            if math.abs(s.chance-100)<1e-6 and p>=100 then cap=100 else return out end
        end
    end
    if not K.Core.Finite(out.chance) then return out end
    out.offset=offset;out.slope=slope;out.pointsPerPercent=1/slope;out.cap=cap;out.verified=true
    out.calculated=offset+rating*slope
    if cap then out.calculated=math.min(cap,out.calculated) end
    return out
end
function C.RatingForChance(deltaPercent,calibration)
    if not calibration or not calibration.verified or not K.Core.Finite(deltaPercent) then return nil,'critical conversion unavailable' end
    return deltaPercent*calibration.pointsPerPercent
end
function C.Formula(c,language)
    if not c or not K.Core.Finite(c.chance) then return K.Stats.Text(language,'unavailable') end
    local result=K.Stats.Number(c.chance,language,1)..'%'
    if not c.verified then return 'P('..K.Stats.Number(c.rating,language)..') = '..result..' · '..K.Stats.Text(language,'formulaUnknown') end
    local digits=2
    while digits<10 do
        local k=tonumber(string.format('%.'..digits..'f',c.pointsPerPercent))
        local p=c.offset+c.rating/k;if c.cap then p=math.min(c.cap,p) end
        if string.format('%.1f',p)==string.format('%.1f',c.chance) then break end
        digits=digits+1
    end
    local text=K.Stats.Number(c.rating,language)..' / '..K.Stats.Number(c.pointsPerPercent,language,digits)
    if c.offset~=0 then text=K.Stats.Number(c.offset,language,4)..' + '..text end
    if c.cap then text='min('..c.cap..', '..text..')' end
    return text..' = '..result
end
