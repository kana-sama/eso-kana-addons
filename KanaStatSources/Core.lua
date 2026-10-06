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
