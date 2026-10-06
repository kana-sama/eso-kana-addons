local K=KanaStatSources
local M={};K.Model=M
local priority={base=1,attributes=2,equipment=3,sets=4,food=5,mundus=6,skills=7,champion=8,effects=9,unknown=10}
local function contains(list,value) for _,v in ipairs(list or {}) do if v==value then return true end end;return false end
function M.Build(snapshot,contributions,diagnostics,policies)
    local out,seen={},{}
    for _,def in ipairs(K.Stats.Definitions) do
        local stat=def[1];local raw=snapshot.stats[stat] or {};local total=raw.total
        local b={rows={},total=total,available=K.Core.Finite(total),explained=0,unknown=0,diagnostics={},consistent=snapshot.consistent~=false,stat=stat}
        if not b.available then b.total=nil end
        if stat=='weaponCritical' or stat=='spellCritical' then b.critical=K.Critical.Calibrate((snapshot.criticalSamples or {})[stat],total) end
        out[stat]=b
    end
    for _,d in ipairs(diagnostics or {}) do
        if d.stat and out[d.stat] then table.insert(out[d.stat].diagnostics,d) end
    end
    local pending={}
    local function append(b,c,value,base)
        local r={key=c.key,label=c.label or c.key,category=c.category,source=c.source,evidence=c.evidence,rawValue=value,value=K.Core.Round(value),amount=c.amount,operation=c.operation,group=c.group,base=base}
        b.rows[#b.rows+1]=r
    end
    for _,c in ipairs(contributions or {}) do
        local b=out[c.stat];local identity=tostring(c.key)..':'..tostring(c.stat)
        if b and b.available and b.consistent and c.active~=false and not seen[identity] then
            seen[identity]=true
            local v=c.amount
            if not c.evidence or not K.Core.Finite(v) then b.diagnostics[#b.diagnostics+1]=K.Core.Diagnostic(c,'invalid or unverified amount')
            elseif c.operation=='percent' then pending[#pending+1]=c
            elseif c.operation=='criticalChance' then
                local rating,reason=K.Critical.RatingForChance(v,b.critical)
                if rating then append(b,c,rating) else b.diagnostics[#b.diagnostics+1]=K.Core.Diagnostic(c,reason) end
            elseif c.operation=='flat' or c.operation=='effectiveFlat' then append(b,c,v)
            else b.diagnostics[#b.diagnostics+1]=K.Core.Diagnostic(c,'unsupported operation') end
        end
    end
    local applied={}
    for stat,b in pairs(out) do
        local policy=(policies or {})[stat] or {}
        for _,group in ipairs(policy.groups or {}) do
            local base,hasBase=0,false
            for _,r in ipairs(b.rows) do
                if r.category=='base' then hasBase=true end
                if contains(group.scope,'subtotal') or (r.operation=='flat' and contains(group.scope,'flat')) or (r.operation~='effectiveFlat' and (contains(group.scope,r.category) or contains(group.scope,r.group))) then base=base+r.rawValue end
            end
            for _,c in ipairs(pending) do
                if c.stat==stat and c.group==group.id then
                    applied[c]=true
                    if group.requireBase and not hasBase then b.diagnostics[#b.diagnostics+1]=K.Core.Diagnostic(c,'percentage base unavailable')
                    else append(b,c,base*c.amount/100,base) end
                end
            end
        end
    end
    for _,c in ipairs(pending) do if not applied[c] then table.insert(out[c.stat].diagnostics,K.Core.Diagnostic(c,'percentage policy unavailable')) end end
    for stat,b in pairs(out) do
        table.sort(b.rows,function(a,c)
            local pa,pc=priority[a.category] or 9,priority[c.category] or 9
            if pa~=pc then return pa<pc end
            return tostring(a.key)<tostring(c.key)
        end)
        local rawSum=0
        for _,r in ipairs(b.rows) do b.explained=b.explained+r.value;rawSum=rawSum+r.rawValue end
        if b.available then
            b.unknown=b.total-b.explained;b.rawUnknown=b.total-rawSum
            if b.unknown~=0 then b.rows[#b.rows+1]={key='unknown',category='unknown',labelKey='unknown',value=b.unknown,rawValue=b.rawUnknown,operation='flat'} end
            local pendingPreview=(snapshot.preview or {})[stat]
            if K.Core.Finite(pendingPreview) and pendingPreview~=0 then b.preview={amount=pendingPreview,total=b.total+pendingPreview} end
        end
    end
    return out
end
