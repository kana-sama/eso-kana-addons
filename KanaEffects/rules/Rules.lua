-- Pure observation predicates and reusable set DAGs. No clock or UI ownership.
local Rules = {}
local Compiled = {}
Compiled.__index = Compiled
KanaEffects.Rules = Rules

local function finite(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end
local function nonempty(value) return type(value) == "string" and value ~= "" end
local enums = {
    kind={buff=true,debuff=true,unknown=true}, lifetime={short=true,long=true,permanent=true,toggle=true,unknown=true},
    origin={skill=true,set=true,enchant=true,unknown=true}, castBy={self=true,other=true,unknown=true},
}
local function lifetime(observation, threshold)
    if observation.lifetime == "finite" then
        if not finite(observation.fullDuration) or observation.fullDuration < 0 then return "unknown" end
        return observation.fullDuration < threshold and "short" or "long"
    end
    if observation.lifetime == "permanent" or observation.lifetime == "toggle" then return observation.lifetime end
    return "unknown"
end
local function facetValue(field, observation, threshold)
    local catalog=observation.catalog or {}
    if field == "lifetime" then return lifetime(observation,threshold) end
    if field == "named" then
        return nonempty(catalog.familyId) and (catalog.level == "minor" or catalog.level == "major")
    end
    if field == "origin" then return catalog.origin or "unknown" end
    return observation[field] or "unknown"
end

-- A small expression language, never Lua evaluation. Compiled functions close
-- over validated literals only; no environment, globals or executable source.
local CATEGORY={Food='food',Drink='drink',exp='xp',system='service',Event='event',
    Membership='membership',Cooldown='cooldown',Justice='justice',SkillExperience='skillExperience'}
Rules.ExpressionLimits={length=16384,depth=48,nodes=1024}
local expressionCache,expressionOrder={},{}
local function duration(o)
    if o.lifetime=='permanent' or o.lifetime=='toggle' then return math.huge end
    if o.lifetime=='finite' and finite(o.fullDuration) and o.fullDuration>=0 then return o.fullDuration end
end
local functions={
    element_of={type='boolean',args='set',run=function(o,t,args,resolve) return resolve and resolve(args[1],args[2]) or false end},
    is_buff={type='boolean',run=function(o) return o.kind=='buff' end},
    is_debuff={type='boolean',run=function(o) return o.kind=='debuff' end},
    is_named={type='boolean',run=function(o,t) return facetValue('named',o,t) end},
    is_permanent={type='boolean',run=function(o) return o.lifetime=='permanent' end},
    is_toggle={type='boolean',run=function(o) return o.lifetime=='toggle' end},
    is_unknown_duration={type='boolean',run=function(o) return duration(o)==nil end},
    total_duration={type='number',run=duration},
    kind={type='string',run=function(o,t) return facetValue('kind',o,t) end},
    lifetime={type='string',run=function(o,t) return facetValue('lifetime',o,t) end},
    origin={type='string',run=function(o,t) return facetValue('origin',o,t) end},
    cast_by={type='string',run=function(o,t) return facetValue('castBy',o,t) end},
    from_category={type='boolean',args='category',run=function(o,_,args)
        local categories=(o.catalog or {}).categories or {}
        for _,id in ipairs(args) do if categories[id]==true then return true end end
        return false
    end},
}
for _,kind in ipairs({'ability','artificial','family','category'}) do
    local selectorKind=kind
    functions[kind]={type='boolean',args=kind=='category' and 'category' or kind,run=function(o,_,args)
        if selectorKind=='category' then return functions.from_category.run(o,nil,args) end
        return KanaEffects.Selectors.Matches({kind=selectorKind,id=args[1],level=args[2]},o)
    end}
end
function Rules.ParseExpression(source)
    if type(source)~='string' or #source>Rules.ExpressionLimits.length then return nil,'Правило: максимум 16384 байта.' end
    if expressionCache[source] then return expressionCache[source] end
    local position,tokens,references=1,{},{}
    local function bad(message,at) error('Позиция '..tostring(at or position)..': '..message,0) end
    local function parse()
        while position<=#source do
            local char=source:sub(position,position); local start=position
            if char:match('%s') then position=position+1
            else
                local token={pos=start}; local tail=source:sub(position)
                if char=='"' or char=="'" then
                    local parts={}; position=position+1
                    while position<=#source and source:sub(position,position)~=char do
                        local c=source:sub(position,position)
                        if c=='\\' then
                            position=position+1; c=source:sub(position,position)
                            local escaped={n='\n',r='\r',t='\t',['\\']='\\',['"']='"',["'"]="'"}
                            if not escaped[c] then bad('Недопустимая escape-последовательность.') end
                            c=escaped[c]
                        end
                        parts[#parts+1]=c; position=position+1
                    end
                    if position>#source then bad('Не закрыта строка.',start) end
                    position=position+1; token.kind='literal'; token.type='string'; token.value=table.concat(parts)
                elseif char:match('[%d%-]') then
                    local value=tail:match('^%-?%d+%.?%d*')
                    if not value or not finite(tonumber(value)) then bad('Ожидается конечное число.') end
                    token.kind='literal'; token.type='number'; token.value=tonumber(value); position=position+#value
                elseif char:match('[%a_]') then
                    local value=tail:match('^[%a_][%w_]*'); position=position+#value
                    token.kind=value; token.value=value
                    if value=='true' or value=='false' then token.kind='literal'; token.type='boolean'; token.value=value=='true' end
                else
                    local pair=source:sub(position,position+1)
                    if pair=='==' or pair=='~=' or pair=='>=' or pair=='<=' then token.kind=pair; position=position+2
                    elseif char:match('[(),.<>]') then token.kind=char; position=position+1
                    else bad('Недопустимый символ «'..char..'».') end
                end
                token.finish=position-1; tokens[#tokens+1]=token
                if #tokens>Rules.ExpressionLimits.nodes then bad('Слишком сложное правило.',start) end
            end
        end
        tokens[#tokens+1]={kind='end',pos=#source+1}
        local cursor,depth=1,0
        local function peek() return tokens[cursor] end
        local function take(kind)
            local token=peek(); if token.kind~=kind then bad('Ожидается «'..kind..'».',token.pos) end
            cursor=cursor+1; return token
        end
        local function literal(token)
            local value=token.value; return {type=token.type,literal=true,value=value,run=function() return value end}
        end
        local expression,unary
        local function atom()
            local token=peek()
            if token.kind=='(' then
                take('('); depth=depth+1; if depth>Rules.ExpressionLimits.depth then bad('Слишком глубокое вложение.',token.pos) end
                local node=expression(); take(')'); depth=depth-1; return node
            elseif token.kind=='literal' then take('literal'); return literal(token)
            elseif token.kind=='Category' then
                take('Category'); take('.'); local key=peek(); cursor=cursor+1
                if not CATEGORY[key.kind] then bad('Неизвестная категория «'..tostring(key.kind)..'».',key.pos) end
                return literal({type='string',value=CATEGORY[key.kind]})
            end
            local spec=functions[token.kind]
            if not spec then bad('Неизвестная функция «'..tostring(token.kind)..'».',token.pos) end
            cursor=cursor+1; take('('); local args={}; local reference
            if peek().kind~=')' then
                repeat
                    -- Arguments are literals or Category constants, not calls.
                    if peek().kind~='literal' and peek().kind~='Category' then bad('Аргумент должен быть литералом или Category.*.',peek().pos) end
                    local argument=peek(); local arg=atom(); args[#args+1]=arg.value
                    if spec.args=='set' then
                        if argument.kind~='literal' or argument.type~='string' then bad('element_of требует строковое имя набора.',argument.pos) end
                        if #args==1 then reference={name=arg.value,start=argument.pos,finish=argument.finish}
                        elseif #args==2 then reference.id=arg.value end
                    end
                    if peek().kind~=',' then break end; take(',')
                until false
            end
            take(')')
            local valid=#args==0 and not spec.args
            if spec.args=='set' then valid=(#args==1 or #args==2) and nonempty(args[1]) and (#args==1 or nonempty(args[2]))
            elseif spec.args=='category' then
                valid=#args>0; for _,arg in ipairs(args) do valid=valid and nonempty(arg) end
            elseif spec.args=='ability' or spec.args=='artificial' then
                valid=#args==1 and finite(args[1]) and args[1]%1==0 and args[1]>=(spec.args=='ability' and 1 or 0)
            elseif spec.args=='family' then
                valid=#args==2 and nonempty(args[1]) and (args[2]=='pair' or args[2]=='minor' or args[2]=='major')
            end
            if not valid then bad('Неверные типы или число аргументов '..token.kind..'().',token.pos) end
            if reference then references[#references+1]=reference end
            return {type=spec.type,run=function(o,t,resolve) return spec.run(o,t,args,resolve) end}
        end
        unary=function()
            if peek().kind=='not' then
                local token=take('not'); depth=depth+1; if depth>Rules.ExpressionLimits.depth then bad('Слишком глубокое вложение.',token.pos) end
                local child=unary(); depth=depth-1
                if child.type~='boolean' then bad('not требует boolean.',token.pos) end
                return {type='boolean',run=function(o,t,resolve) return not child.run(o,t,resolve) end}
            end
            return atom()
        end
        local comparisons={['==']=true,['~=']=true,['>']=true,['<']=true,['>=']=true,['<=']=true}
        local function compare()
            local left=unary(); local token=peek()
            if not comparisons[token.kind] then return left end
            cursor=cursor+1; local right=unary(); local op=token.kind
            if left.type~=right.type or ((op~='==' and op~='~=') and left.type~='number') then bad('Несовместимые типы сравнения.',token.pos) end
            return {type='boolean',run=function(o,t,resolve)
                local a,b=left.run(o,t,resolve),right.run(o,t,resolve)
                -- Unknown duration is missing data. Every comparison, including
                -- ~=, is false; use is_unknown_duration() to test it explicitly.
                if a==nil or b==nil then return false end
                if op=='==' then return a==b elseif op=='~=' then return a~=b elseif op=='>' then return a>b
                elseif op=='<' then return a<b elseif op=='>=' then return a>=b else return a<=b end
            end}
        end
        local function booleanChain(child,operator)
            local nodes={child()}
            while peek().kind==operator do
                local token=take(operator); nodes[#nodes+1]=child()
                if nodes[#nodes].type~='boolean' or nodes[1].type~='boolean' then bad(operator..' требует boolean.',token.pos) end
            end
            if #nodes==1 then return nodes[1] end
            return {type='boolean',run=function(o,t,resolve)
                for _,node in ipairs(nodes) do
                    local value=node.run(o,t,resolve)
                    if operator=='and' and not value then return false elseif operator=='or' and value then return true end
                end
                return operator=='and'
            end}
        end
        local function conjunction() return booleanChain(compare,'and') end
        expression=function() return booleanChain(conjunction,'or') end
        local result=expression()
        if cursor~=#tokens then bad('Лишний текст после выражения.',peek().pos) end
        take('end')
        if result.type~='boolean' then bad('Результат правила должен быть boolean.',1) end
        result.references=references
        return result
    end
    local ok,result=pcall(parse)
    if not ok then return nil,result end
    expressionCache[source]=result; expressionOrder[#expressionOrder+1]=source
    if #expressionOrder>128 then expressionCache[table.remove(expressionOrder,1)]=nil end
    return result
end
local function quote(value)
    if type(value)~='string' then return tostring(value) end
    return '"'..value:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n'):gsub('\r','\\r'):gsub('\t','\\t')..'"'
end
-- Conversion is lazy and lossless: old saved ASTs remain valid until edited.
-- Include/exclude set edges retain their independent union/subtraction rules.
function Rules.PredicateExpression(node)
    if not node then return 'false' end
    if node.op=='expression' then return node.source end
    if node.op=='not' then return 'not ('..Rules.PredicateExpression(node.arg)..')' end
    if node.op=='and' or node.op=='or' then
        if #node.args==0 then return node.op=='and' and 'true' or 'false' end
        local parts={}; for _,child in ipairs(node.args) do parts[#parts+1]='('..Rules.PredicateExpression(child)..')' end
        return table.concat(parts,' '..node.op..' ')
    end
    if node.op=='selector' then
        local s=node.selector; return s.kind..'('..quote(s.id)..(s.level and ', '..quote(s.level) or '')..')'
    end
    if node.op=='facet' then
        if #node.values==0 then return 'false' end
        local parts={}; local getter=node.field=='named' and 'is_named' or node.field=='castBy' and 'cast_by' or node.field
        for _,v in ipairs(node.values) do parts[#parts+1]=node.field=='category' and 'from_category('..quote(v)..')' or getter..'() == '..quote(v) end
        return '('..table.concat(parts,' or ')..')'
    end
    error('Unknown legacy predicate operator: '..tostring(node.op))
end
-- Name calls remain readable. Duplicate legacy names retain a stable ID;
-- never inline a referenced DAG, whose expansion could be exponential.
local function legacyExpression(owner,sets,predicate)
    local byId,counts={},{}
    for _,set in ipairs(sets or {}) do byId[set.id]=set; counts[set.name]=(counts[set.name] or 0)+1 end
    local function reference(id)
        local set=assert(byId[id],'Unknown legacy set '..tostring(id))
        if counts[set.name]==1 then return 'element_of('..quote(set.name)..')' end
        return 'element_of('..quote(set.name)..', '..quote(id)..')'
    end
    local function build(value,base)
        local included={}; if base then included[#included+1]='('..base..')' end
        for _,id in ipairs(value.includeSets or {}) do included[#included+1]=reference(id) end
        local source=#included>0 and table.concat(included,' or ') or 'false'
        local excluded={}; for _,id in ipairs(value.excludeSets or {}) do excluded[#excluded+1]=reference(id) end
        if #excluded>0 then source='('..source..') and not ('..table.concat(excluded,' or ')..')' end
        return source
    end
    return build(owner,predicate)
end
function Rules.SetExpression(set,sets)
    if #(set.includeSets or {})==0 and #(set.excludeSets or {})==0 then return Rules.PredicateExpression(set.predicate) end
    return legacyExpression(set,sets,set.predicate and Rules.PredicateExpression(set.predicate) or nil)
end
function Rules.WidgetExpression(widget,sets)
    local rules=widget.rules
    if rules.expression~=nil then return rules.expression end
    local source=legacyExpression(rules,sets)
    if rules.named=='only' then source='('..source..') and is_named()'
    elseif rules.named=='exclude' then source='('..source..') and not is_named()' end
    return source
end
function Rules.RewriteReferences(source,oldName,newName,setId)
    local parsed=Rules.ParseExpression(source); if not parsed then return source end
    for i=#parsed.references,1,-1 do local ref=parsed.references[i]
        if ref.name==oldName and (ref.id==nil or ref.id==setId) then source=source:sub(1,ref.start-1)..quote(newName)..source:sub(ref.finish+1) end
    end
    return source
end
-- Visit sources in legacy ASTs too: mixed old/new profiles are supported.
local function visitSources(profile,callback)
    local function predicate(node,owner)
        if type(node)~='table' then return end
        if node.op=='expression' then node.source=callback(node.source,owner)
        elseif node.op=='not' then predicate(node.arg,owner)
        elseif (node.op=='and' or node.op=='or') and type(node.args)=='table' then for _,child in ipairs(node.args) do predicate(child,owner) end end
    end
    for _,set in ipairs(profile.sets) do predicate(set.predicate,set) end
    for _,widget in ipairs(profile.widgets) do if widget.rules.expression~=nil then widget.rules.expression=callback(widget.rules.expression,widget) end end
end
function Rules.RenameReferences(profile,oldName,newName,setId)
    visitSources(profile,function(source) return Rules.RewriteReferences(source,oldName,newName,setId) end)
end
function Rules.ReferenceOwners(profile,setId)
    local target,owners,seen=nil,{},{}
    for _,set in ipairs(profile.sets) do if set.id==setId then target=set end end
    if not target then return owners end
    local function add(owner) if owner~=target and not seen[owner] then seen[owner]=true; owners[#owners+1]=owner.name..' ('..owner.id..')' end end
    for _,list in ipairs({profile.sets,profile.widgets}) do for _,owner in ipairs(list) do
        local rules=owner.rules or owner
        if not owner.rules or rules.expression==nil then
            for _,field in ipairs({'includeSets','excludeSets'}) do for _,id in ipairs(rules[field]) do if id==setId then add(owner) end end end
        end
    end end
    visitSources(profile,function(source,owner)
        local parsed=Rules.ParseExpression(source)
        for _,ref in ipairs(parsed and parsed.references or {}) do
            if ref.id==setId or (ref.id==nil and ref.name==target.name) then add(owner) end
        end
        return source
    end)
    return owners
end
local function reason(matched, code, label, path, children, setId)
    return {matched=matched,code=code,label=label,path=path,children=children or {},setId=setId}
end
local function listLabel(values)
    local labels={}; for i,value in ipairs(values) do labels[i]=tostring(value) end
    return table.concat(labels,", ")
end

function Rules.Compile(setDefs, longThreshold, widgets)
    local diagnostics={}
    local function fail(code,path,message)
        diagnostics[#diagnostics+1]={code=code,path=path,message=message}
    end
    if not finite(longThreshold) or longThreshold <= 0 then
        fail("invalid_threshold","longThreshold","Duration threshold must be a positive finite number")
    end
    if type(setDefs) ~= "table" then
        fail("invalid_sets","sets","Expected set definitions"); return nil,diagnostics
    end
    local result=setmetatable({sets={},order={},reverse={},index={abilities={},artificialEffects={},families={},categories={}},generic={},
        threshold=longThreshold,names={},widgetExpressions={}},Compiled)
    local function list(value,path)
        if type(value) ~= "table" then fail("invalid_list",path,"Expected a dense list"); return false end
        local count,maximum=0,0
        for key in pairs(value) do
            count=count+1
            if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
                fail("invalid_list",path,"Expected a dense list"); return false
            end
            if key > maximum then maximum=key end
        end
        -- # is undefined for tables with holes. Validated positive integer keys
        -- are dense exactly when their count equals their largest index.
        if count ~= maximum then fail("invalid_list",path,"Expected a dense list"); return false end
        return true
    end
    local function index(kind,key,id)
        local bucket=result.index[kind][key]
        if not bucket then bucket={}; result.index[kind][key]=bucket end
        bucket[id]=true
    end
    local activePredicates={}
    local pendingExpressions={}
    local buildPredicate
    buildPredicate=function(value,path,id)
        if type(value) ~= "table" then fail("invalid_predicate",path,"Expected a predicate"); return end
        if activePredicates[value] then fail("invalid_predicate",path,"Cyclic predicate AST"); return end
        activePredicates[value]=true
        local node={op=value.op,path=path}
        if value.op == "expression" then
            local parsed,message=Rules.ParseExpression(value.source)
            if not parsed then fail('invalid_expression',path..'.source',message)
            else node.expression=parsed; node.source=value.source; result.generic[id]=true
                pendingExpressions[#pendingExpressions+1]={parsed=parsed,id=id,path=path} end
        elseif value.op == "and" or value.op == "or" then
            node.args={}
            if list(value.args,path .. ".args") then
                for i,child in ipairs(value.args) do node.args[i]=buildPredicate(child,path .. ".args[" .. i .. "]",id) end
                if value.op == "and" and #value.args == 0 then result.generic[id]=true end
            end
        elseif value.op == "not" then
            -- NOT may admit every changed nonmatching observation, so an exact
            -- positive selector index alone would miss its display refreshes.
            result.generic[id]=true
            node.arg=buildPredicate(value.arg,path .. ".arg",id)
        elseif value.op == "selector" then
            local selector=value.selector
            local valid=type(selector) == "table"
            if valid and (selector.kind == "ability" or selector.kind == "artificial") then
                valid=finite(selector.id) and selector.id >= (selector.kind=="artificial" and 0 or 1)
                    and selector.id % 1 == 0 and selector.level == nil
            elseif valid and selector.kind == "family" then
                valid=nonempty(selector.id) and (selector.level == "pair" or selector.level == "minor" or selector.level == "major")
            elseif valid and selector.kind == "category" then
                valid=nonempty(selector.id) and selector.level == nil
            else valid=false end
            if not valid then fail("invalid_selector",path .. ".selector","Invalid selector")
            else
                node.selector={kind=selector.kind,id=selector.id,level=selector.level}
                local kind=KanaEffects.Selectors.DeltaField(selector)
                index(kind,selector.id,id)
            end
        elseif value.op == "facet" then
            node.field=value.field; node.values={}; node.valueSet={}
            local validField=enums[value.field] or value.field == "named" or value.field == "category"
            if not validField then fail("invalid_predicate",path .. ".field","Unknown facet") end
            if list(value.values,path .. ".values") then
                for i,item in ipairs(value.values) do
                    local valid=validField and (value.field == "named" and type(item) == "boolean"
                        or value.field == "category" and nonempty(item)
                        or enums[value.field] and enums[value.field][item] == true)
                    if not valid then fail("invalid_predicate",path .. ".values[" .. i .. "]","Invalid facet value")
                    else
                        node.values[i]=item; node.valueSet[item]=true
                        if value.field == "category" then index("categories",item,id) end
                    end
                end
            end
            -- Delta has no kind/lifetime/name/origin/castBy field detail.
            if value.field ~= "category" then result.generic[id]=true end
        else fail("invalid_predicate",path .. ".op","Unknown predicate operator") end
        activePredicates[value]=nil
        return node
    end
    if not list(setDefs,"sets") then return nil,diagnostics end
    for i,definition in ipairs(setDefs) do
        local path="sets[" .. i .. "]"
        if type(definition) ~= "table" or not nonempty(definition.id) then
            fail("invalid_id",path .. ".id","Expected a stable nonempty set ID")
        elseif result.sets[definition.id] then fail("duplicate_id",path .. ".id","Duplicate set ID " .. definition.id)
        else
            local node={id=definition.id,name=type(definition.name) == "string" and definition.name or definition.id,
                path=path,includeSets={},excludeSets={},expressionSets={}}
            result.sets[node.id]=node; result.order[#result.order+1]=node.id
            if result.names[node.name]==nil then result.names[node.name]=node.id else result.names[node.name]=false end
            if definition.predicate ~= nil then node.predicate=buildPredicate(definition.predicate,path .. ".predicate",node.id) end
            for _,field in ipairs({"includeSets","excludeSets"}) do
                if list(definition[field],path .. "." .. field) then
                    for j,ref in ipairs(definition[field]) do
                        if not nonempty(ref) then fail("invalid_reference",path .. "." .. field .. "[" .. j .. "]","Expected set ID")
                        else node[field][j]=ref end
                    end
                end
            end
        end
    end
    for i,widget in ipairs(widgets or {}) do
        if widget.rules.expression~=nil then
            local path='widgets['..i..'].rules.expression'
            local parsed,message=Rules.ParseExpression(widget.rules.expression)
            if not parsed then fail('invalid_expression',path,message)
            else result.widgetExpressions[widget.id]=parsed; pendingExpressions[#pendingExpressions+1]={parsed=parsed,path=path} end
        else
            for _,field in ipairs({'includeSets','excludeSets'}) do for _,ref in ipairs(widget.rules[field]) do
                if not result.sets[ref] then fail('unknown_set','widgets['..i..'].rules.'..field,'Unknown set '..ref..' in '..widget.name) end
            end end
        end
    end
    for _,pending in ipairs(pendingExpressions) do
        for _,ref in ipairs(pending.parsed.references) do
            local id=ref.id or result.names[ref.name]
            if id==nil or (ref.id and not result.sets[id]) then fail('unknown_set',pending.path,'Неизвестный набор «'..ref.name..'».')
            elseif id==false then fail('ambiguous_set',pending.path,'Несколько наборов с именем «'..ref.name..'». Укажите уникальное имя.')
            elseif ref.id and result.sets[id].name~=ref.name then fail('set_name_mismatch',pending.path,'Имя набора «'..ref.name..'» не соответствует ID «'..ref.id..'».')
            elseif pending.id then result.sets[pending.id].expressionSets[#result.sets[pending.id].expressionSets+1]=id end
        end
    end
    if #diagnostics > 0 then return nil,diagnostics end
    for _,id in ipairs(result.order) do
        local node=result.sets[id]
        for _,field in ipairs({"includeSets","excludeSets","expressionSets"}) do
            for i,ref in ipairs(node[field]) do
                local path=node.path .. "." .. field .. "[" .. i .. "]"
                if not result.sets[ref] then fail("unknown_set",path,node.name .. " references unknown set " .. ref)
                else
                    if not result.reverse[ref] then result.reverse[ref]={} end
                    result.reverse[ref][id]=true
                end
            end
        end
    end
    if #diagnostics > 0 then return nil,diagnostics end
    local state,stack,positions={},{},{}
    local function visit(id)
        state[id]=1; stack[#stack+1]=id; positions[id]=#stack
        local node=result.sets[id]
        for _,field in ipairs({"includeSets","excludeSets","expressionSets"}) do
            for i,ref in ipairs(node[field]) do
                if state[ref] == 1 then
                    local names={}
                    for j=positions[ref],#stack do
                        local cyclic=result.sets[stack[j]]; names[#names+1]=cyclic.name .. " (" .. cyclic.id .. ")"
                    end
                    names[#names+1]=result.sets[ref].name .. " (" .. ref .. ")"
                    fail("set_cycle",node.path .. "." .. field .. "[" .. i .. "]","Set cycle: " .. table.concat(names," -> "))
                elseif not state[ref] then visit(ref) end
            end
        end
        state[id]=2; positions[id]=nil; stack[#stack]=nil
    end
    for _,id in ipairs(result.order) do if not state[id] then visit(id) end end
    if #diagnostics > 0 then return nil,diagnostics end
    return result,diagnostics
end

local function evaluatePredicate(node, observation, threshold, explain, resolve)
    local matched,children,label=false,explain and {} or nil,nil
    local actual
    if node.op == 'expression' then
        matched=node.expression.run(observation,threshold,resolve); label=node.source
    elseif node.op == "and" or node.op == "or" then
        matched=node.op == "and"
        for _,child in ipairs(node.args) do
            local value,detail=evaluatePredicate(child,observation,threshold,explain,resolve)
            if explain then children[#children+1]=detail end
            if node.op == "and" and not value then matched=false; if not explain then break end end
            if node.op == "or" and value then matched=true; if not explain then break end end
        end
        label=node.op == "and" and "All predicates must match" or "At least one predicate must match"
    elseif node.op == "not" then
        local value,detail=evaluatePredicate(node.arg,observation,threshold,explain,resolve)
        matched=not value; if explain then children[1]=detail end; label="Predicate must not match"
    elseif node.op == "selector" then
        matched=KanaEffects.Selectors.Matches(node.selector,observation)
        if explain then label="Selector " .. KanaEffects.Selectors.Key(node.selector) end
    elseif node.op == "facet" then
        if node.field == "category" then
            local categories=(observation.catalog or {}).categories or {}
            local matchingCategory
            for _,value in ipairs(node.values) do
                if categories[value] == true then matched=true; matchingCategory=value; break end
            end
            if explain then
                actual=matchingCategory
                label="Matching category=" .. tostring(matchingCategory) .. "; expected any of: " .. listLabel(node.values)
            end
        else
            local value=facetValue(node.field,observation,threshold)
            matched=node.valueSet[value] == true
            if explain then
                actual=value
                label=node.field .. " = " .. tostring(value) .. "; expected any of: " .. listLabel(node.values)
                if node.field == "lifetime" then
                    label=label .. "; fullDuration=" .. tostring(observation.fullDuration) .. "; threshold=" .. tostring(threshold)
                end
            end
        end
    end
    if explain then
        local detail=reason(matched,node.op,label,node.path,children)
        if node.op == "facet" then
            detail.field=node.field; detail.values={}; for i,v in ipairs(node.values) do detail.values[i]=v end
            detail.actual=actual
            if node.field == "lifetime" then detail.fullDuration=observation.fullDuration; detail.threshold=threshold end
        elseif node.op == "selector" then
            detail.selector={kind=node.selector.kind,id=node.selector.id,level=node.selector.level}
        end
        return matched,detail
    end
    return matched
end
function Compiled:_Evaluate(setId, observation, explain, cache)
    local cached=cache[setId]
    if cached then return cached.matched,cached.reason end
    local node=self.sets[setId]
    if not node then
        if explain then return false,reason(false,"unknown_set","Unknown set " .. tostring(setId),"sets",{},setId) end
        return false
    end
    local base,excluded,children=false,false,explain and {} or nil
    if node.predicate then
        local value,detail=evaluatePredicate(node.predicate,observation,self.threshold,explain,function(name,id) return self:_Evaluate(id or self.names[name],observation,explain,cache) end)
        base=value; if explain then children[#children+1]=detail end
    end
    for _,field in ipairs({"includeSets","excludeSets"}) do
        for i,ref in ipairs(node[field]) do
            local value,detail=self:_Evaluate(ref,observation,explain,cache)
            if field == "includeSets" then base=base or value else excluded=excluded or value end
            if explain then
                local code=field == "includeSets" and "include_set" or "exclude_set"
                local label=(field == "includeSets" and "Included through " or "Excluded through ") .. self.sets[ref].name .. " (" .. ref .. ")"
                local child=reason(value,code,label,node.path .. "." .. field .. "[" .. i .. "]",{detail},ref)
                child.setName=self.sets[ref].name; children[#children+1]=child
            end
        end
    end
    local matched=base and not excluded
    local detail
    if explain then
        local code=base and (excluded and "excluded" or "included") or "not_included"
        local label=node.name .. " (" .. setId .. "): " .. code
        detail=reason(matched,code,label,node.path,children,setId); detail.setName=node.name
    end
    cache[setId]={matched=matched,reason=detail}
    return matched,detail
end
function Compiled:MatchesWidget(widgetId, observation)
    local parsed=self.widgetExpressions[widgetId]
    if not parsed then return false end
    local cache={}
    return parsed.run(observation,self.threshold,function(name,id) return self:_Evaluate(id or self.names[name],observation,false,cache) end)
end
function Compiled:Matches(setId, observation)
    local matched=self:_Evaluate(setId,observation,false,{})
    return matched
end
function Compiled:Explain(setId, observation)
    local _,detail=self:_Evaluate(setId,observation,true,{})
    return detail
end
function Compiled:AffectedSets(delta)
    local affected,queue={},{}
    local changed=false
    for _,field in ipairs({"units","abilities","artificialEffects","families","categories"}) do
        if next(delta[field] or {}) ~= nil then changed=true; break end
    end
    if not changed then return affected end
    local function mark(id)
        if not affected[id] then affected[id]=true; queue[#queue+1]=id end
    end
    for id in pairs(self.generic) do mark(id) end
    for _,field in ipairs({"abilities","artificialEffects","families","categories"}) do
        for key,present in pairs(delta[field] or {}) do
            if present then for id in pairs(self.index[field][key] or {}) do mark(id) end end
        end
    end
    local cursor=1
    while cursor <= #queue do
        for id in pairs(self.reverse[queue[cursor]] or {}) do mark(id) end
        cursor=cursor+1
    end
    return affected
end
