local T = {}
function T.eq(a,b) assert(a==b, 'expected '..tostring(b)..', got '..tostring(a)) end
function T.near(a,b,e) assert(math.abs(a-b)<=(e or 1e-8), 'expected '..b..', got '..tostring(a)) end
function T.snapshot(totals)
    local s={schemaVersion=1,stats={},consistent=true,criticalSamples={},preview={},context={}}
    for k,v in pairs(totals or {}) do s.stats[k]={total=v} end
    return s
end
function T.flat(key,stat,amount,category)
    return {key=key,sourceKey=key,stat=stat,amount=amount,operation='flat',category=category or 'base',label=key,evidence='test arithmetic',active=true}
end
function T.percent(key,stat,amount,group,scope)
    local v=T.flat(key,stat,amount,'effects');v.operation='percent';v.group=group;v.scope=scope;return v
end
function T.sumRows(b) local n=0;for _,r in ipairs(b.rows) do n=n+r.value end;return n end
function T.load(files)
    KanaStatSources=nil
    for _,f in ipairs(files or {'Core','Stats','Rules','Critical','Model'}) do dofile('KanaStatSources/'..f..'.lua') end
    return KanaStatSources
end
return T
