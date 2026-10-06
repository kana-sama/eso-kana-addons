local T=dofile('KanaStatSources/tests/support.lua')
local K=T.load()
local function samples(fn,r)
    local out={};for _,v in ipairs({0,1,100,1000,r,r+1000}) do out[#out+1]={rating=v,chance=fn(v)} end;return out
end
return {
    live_coefficient=function()
        local c=K.Critical.Calibrate(samples(function(r)return r/200 end,1000),1000)
        T.eq(c.verified,true);T.near(c.pointsPerPercent,200);T.eq(c.chance,5)
        T.eq(K.Critical.RatingForChance(5,c),1000)
    end,
    offset_is_not_added_to_delta=function()
        local c=K.Critical.Calibrate(samples(function(r)return 5+r/200 end,1000),1000)
        T.eq(c.offset,5);T.near(K.Critical.RatingForChance(5,c),1000)
    end,
    cap_preserves_raw_rating=function()
        local c=K.Critical.Calibrate(samples(function(r)return math.min(100,r/200) end,30000),30000)
        T.eq(c.verified,true);T.eq(c.cap,100);T.eq(c.rating,30000);T.eq(c.chance,100)
    end,
    nonlinear_is_not_falsely_explained=function()
        local c=K.Critical.Calibrate(samples(function(r)return r*r/200000 end,1000),1000)
        T.eq(c.verified,false);T.eq(c.chance,5);T.eq(K.Critical.RatingForChance(5,c),nil)
    end,
    zero_rating=function()
        local c=K.Critical.Calibrate(samples(function(r)return r/219.1234 end,0),0)
        T.eq(c.verified,true);T.eq(c.chance,0)
    end,
    critical_chance_contribution_is_rating=function()
        local s=T.snapshot({weaponCritical=3000});s.criticalSamples.weaponCritical=samples(function(r)return r/200 end,3000)
        local c=T.flat('buff','weaponCritical',5,'effects');c.operation='criticalChance'
        local b=K.Model.Build(s,{T.flat('base','weaponCritical',2000),c},{},{}).weaponCritical
        T.eq(b.explained,3000);T.eq(b.critical.chance,15)
    end,
}
