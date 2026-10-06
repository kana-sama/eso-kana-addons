KanaStatSources = {name='KanaStatSources', version='1.0.0', schemaVersion=1, Sources={}}
local K=KanaStatSources
K.Core={}
function K.Core.Finite(v) return type(v)=='number' and v==v and v~=math.huge and v~=-math.huge end
function K.Core.Round(v) return v<0 and -math.floor(-v+0.5) or math.floor(v+0.5) end
function K.Core.CopySerializable(value)
    local diagnostics,seen={},{}
    local function copy(v,path)
        local t=type(v)
        if t=='nil' or t=='string' or t=='boolean' then return v end
        if t=='number' and K.Core.Finite(v) then return v end
        if t=='table' and not seen[v] then
            seen[v]=true;local out={}
            for key,child in pairs(v) do
                if type(key)=='string' or (type(key)=='number' and K.Core.Finite(key)) then out[key]=copy(child,path..'.'..tostring(key)) end
            end
            seen[v]=nil;return out
        end
        diagnostics[#diagnostics+1]={reason='not serializable',path=path,type=t}
        return nil
    end
    return copy(value,'root'),diagnostics
end
function K.Core.Diagnostic(source,reason)
    return {sourceKey=source.sourceKey or source.key,category=source.category,stat=source.stat,reason=reason,source=source.source or source,ruleId=source.ruleId}
end
function K.Core.Reader(api,errors)
    local reported={}
    return function(name,...)
        local fn=api[name]
        local values
        if type(fn)=='function' then values={pcall(fn,...)} else values={false,'API unavailable'} end
        if not values[1] then
            if not reported[name] then errors[#errors+1]={api=name,reason=tostring(values[2])};reported[name]=true end
            return nil
        end
        return (unpack or table.unpack)(values,2,table.maxn and table.maxn(values) or 32)
    end
end
function K.Core.Signature(value)
    if type(value)~='table' then return tostring(value) end
    local keys={};for key in pairs(value) do keys[#keys+1]=key end
    table.sort(keys,function(a,b)return tostring(a)<tostring(b) end)
    local out={};for _,key in ipairs(keys) do out[#out+1]=tostring(key)..'='..K.Core.Signature(value[key]) end
    return table.concat(out,';')
end
