-- Stateless projections of immutable Store snapshots. No API, clock or UI calls.
local Projector={}
KanaEffects.Projector=Projector
local function copy(value)
    if type(value) ~= "table" then return value end
    local result={}; for key,item in pairs(value) do result[key]=copy(item) end; return result
end
local function finite(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end
local function unitKey(unit) return unit.tag .. ":" .. unit.generation end
local function named(observation)
    local catalog=observation.catalog or {}
    return type(catalog.familyId) == "string" and catalog.familyId ~= ""
        and (catalog.level == "minor" or catalog.level == "major")
end
local function hidden(observation,profile)
    for _,selector in ipairs(profile.hidden or {}) do
        if KanaEffects.Selectors.Matches(selector,observation) then return true end
    end
    return false
end
local function live(observation,now)
    return observation.lifetime ~= "finite" or not finite(observation.endTime) or observation.endTime > now
end
local function indefinite(observation)
    -- Verified toggles have no natural expiry; removal still updates the Store.
    return observation.lifetime == "permanent" or observation.lifetime == "toggle"
end
local function timer(observations,category)
    if #observations == 0 then return {kind="missing"},false end
    local unknown,permanent,ending=false,false,nil
    for _,observation in ipairs(observations) do
        if indefinite(observation) then permanent=true
        elseif observation.lifetime == "finite" and finite(observation.endTime) then
            if ending == nil or (category and observation.endTime < ending)
                or (not category and observation.endTime > ending) then ending=observation.endTime end
        else unknown=true end
    end
    if category then
        if ending then return {kind="finite",endTime=ending},unknown end
        if not unknown then return {kind="permanent"},false end
    elseif permanent then return {kind="permanent"},unknown end
    if unknown then return {kind="unknown",knownUntil=ending},true end
    return {kind="finite",endTime=ending},false
end
local function matchesAny(ids,compiled,observation,cache)
    for _,id in ipairs(ids or {}) do if compiled:Matches(id,observation,cache) then return true end end
    return false
end
-- One admission decision shared by rendering and on-demand diagnostics. The
-- diagnostic detail allocation is opt-in; hot routing keeps its short circuit.
local function finish(detail,accepted,code)
    if detail then detail.admitted=accepted; detail.code=code; return detail end
    return accepted
end
function Projector.Decide(observation,widget,profile,compiled,explain,cache)
    local rules=widget.rules; local detail=explain and {admitted=false,includeSets={},excludeSets={}} or nil
    cache=cache or {}
    if (observation.unit or {}).tag~=widget.unitTag then return finish(detail,false,'wrong_source') end
    if widget.type=='table' then
        local found=false
        for row,columns in pairs(widget.slots or {}) do for column,selector in pairs(columns) do
            if row<=widget.layout.rows and column<=widget.layout.columns and KanaEffects.Selectors.Matches(selector,observation) then found=true end
        end end
        if detail then detail.globalHidden=hidden(observation,profile); detail.globalHideBypassed=found and detail.globalHidden end
        return finish(detail,found,found and 'explicit_slot' or 'no_slot')
    end
    if rules.expression~=nil then
        local accepted=compiled:MatchesWidget(widget.id,observation,cache)
        if detail then detail.expression=rules.expression; detail.expressionMatched=accepted; detail.globalHidden=hidden(observation,profile) end
        if not accepted then return finish(detail,false,'not_included') end
        if hidden(observation,profile) then return finish(detail,false,'global_hidden') end
        return finish(detail,true,'included')
    end
    local included,excluded=false,false
    if detail then
        for _,id in ipairs(rules.includeSets or {}) do local matched=compiled:Matches(id,observation,cache); detail.includeSets[#detail.includeSets+1]={id=id,matched=matched}; included=included or matched end
        for _,id in ipairs(rules.excludeSets or {}) do local matched=compiled:Matches(id,observation,cache); detail.excludeSets[#detail.excludeSets+1]={id=id,matched=matched}; excluded=excluded or matched end
        detail.globalHidden=hidden(observation,profile); detail.named=named(observation)
        detail.namedPolicy=rules.named; detail.namedAccepted=(rules.named~='only' or detail.named) and (rules.named~='exclude' or not detail.named)
    else
        included=matchesAny(rules.includeSets,compiled,observation,cache)
        if included then excluded=matchesAny(rules.excludeSets,compiled,observation,cache) end
    end
    if not included then return finish(detail,false,'not_included') end
    if excluded then return finish(detail,false,'excluded_set') end
    if (detail and detail.globalHidden) or (not detail and hidden(observation,profile)) then return finish(detail,false,'global_hidden') end
    local isNamed=named(observation)
    if (rules.named=='only' and not isNamed) or (rules.named=='exclude' and isNamed) then return finish(detail,false,'named_policy') end
    return finish(detail,true,'included')
end
local function buildEntry(widget,selector,unit,observations,profile,catalog,row,column)
    local metadata=catalog:Resolve(selector)
    local entry={selector=copy(selector),unit=copy(unit),active=#observations > 0,name=metadata.name,icon=metadata.icon,
        kind=metadata.kind,pair=selector.kind == "family" and selector.level == "pair",count=#observations,
        contributors=copy(observations),uncertain=false,row=row,column=column,hiddenInGrids=false}
    entry.key=widget.id .. ":" .. unitKey(unit) .. ":" .. KanaEffects.Selectors.Key(selector)
    if row then entry.key=entry.key .. ":" .. row .. ":" .. column end
    -- Prefer the real observation's contextual ability display over a generic
    -- nil-caster lookup. A family/category keeps its explicit aggregate name.
    local first=observations[1]
    if first then
        entry.kind=first.kind
        local described=first.catalog or {}
        if selector.kind == "ability" or selector.kind == "artificial" then
            if described.name and described.name ~= "" then entry.name=described.name end
            if described.icon and described.icon ~= "" then entry.icon=described.icon end
        elseif entry.icon == "" and described.icon then entry.icon=described.icon end
    end
    for _,observation in ipairs(observations) do
        if hidden(observation,profile) then entry.hiddenInGrids=true end
    end
    -- An absent explicitly hidden selector still carries its global-hide badge.
    for _,value in ipairs(profile.hidden or {}) do
        if KanaEffects.Selectors.Key(value) == KanaEffects.Selectors.Key(selector) then entry.hiddenInGrids=true end
    end
    if entry.pair then
        local components={minor={},major={}}
        for _,observation in ipairs(observations) do
            local level=(observation.catalog or {}).level
            if components[level] then components[level][#components[level]+1]=observation end
        end
        for _,level in ipairs({"minor","major"}) do
            -- Curated representative coverage does not invalidate a real native
            -- classification. nil means neither covered nor actually observed.
            if metadata.availableLevels[level] or #components[level] > 0 then
                local uncertain
                entry[level],uncertain=timer(components[level],false)
                entry.uncertain=entry.uncertain or uncertain
            end
        end
    else
        if selector.kind == "family" then entry.level=selector.level
        elseif selector.kind == "ability" then
            for _,observation in ipairs(observations) do
                local level=(observation.catalog or {}).level
                if level == "minor" or level == "major" then entry.level=level; break end
            end
            if not first then
                local level=catalog:Describe(selector.id).level
                if level == "minor" or level == "major" then entry.level=level end
            end
        end
        entry.single,entry.uncertain=timer(observations,selector.kind == "category")
        if selector.kind == "category" then
            local members={}; entry.count=0
            for _,observation in ipairs(observations) do
                local identity=KanaEffects.Selectors.Key(KanaEffects.Selectors.FromObservation(observation))
                if not members[identity] then members[identity]=true; entry.count=entry.count+1 end
            end
        end
    end
    return entry
end
local function order(group)
    local rank,firstSeen,id=nil,math.huge,math.huge
    for _,observation in ipairs(group.observations) do
        local value=(observation.catalog or {}).rank
        if finite(value) and (rank == nil or value < rank) then rank=value end
        value=observation.firstSeen or observation.observedAt
        if finite(value) and value < firstSeen then firstSeen=value end
        local observationId=observation.artificialEffectId or observation.abilityId
        if observationId < id then id=observationId end
    end
    return {rank=rank,firstSeen=firstSeen,id=id,key=group.key}
end
function Projector.BuildWidget(widget,profile,compiled,store,catalog,now)
    local snapshot=store:Snapshot(widget.unitTag,now)
    local unit=snapshot.unit or {tag=widget.unitTag,generation=0,name=""}
    local observations={}
    for _,observation in ipairs(snapshot.observations) do
        -- Defend the boundary even if a preview provider returns mixed units.
        if unitKey(observation.unit) == unitKey(unit) and live(observation,now) then
            observations[#observations+1]=observation
        end
    end
    local entries={}
    if widget.type == "table" then
        local slots={}
        for row,columns in pairs(widget.slots or {}) do
            for column,selector in pairs(columns) do slots[#slots+1]={row=row,column=column,selector=selector} end
        end
        table.sort(slots,function(a,b) if a.row == b.row then return a.column < b.column end; return a.row < b.row end)
        for _,slot in ipairs(slots) do
            local matching={}
            for _,observation in ipairs(observations) do
                if KanaEffects.Selectors.Matches(slot.selector,observation) then matching[#matching+1]=observation end
            end
            entries[#entries+1]=buildEntry(widget,slot.selector,unit,matching,profile,catalog,slot.row,slot.column)
        end
    else
        local groups,byKey={},{}
        for _,observation in ipairs(observations) do
            if Projector.Decide(observation,widget,profile,compiled) then
                local selector=KanaEffects.Selectors.FromObservation(observation)
                if widget.rules.mergePairs and named(observation) then
                    selector={kind="family",id=observation.catalog.familyId,level="pair"}
                end
                local key=KanaEffects.Selectors.Key(selector)
                local group=byKey[key]
                if not group then
                    group={selector=selector,key=key,observations={}}; byKey[key]=group; groups[#groups+1]=group
                end
                group.observations[#group.observations+1]=observation
            end
        end
        for _,group in ipairs(groups) do group.order=order(group) end
        table.sort(groups,function(a,b)
            local x,y=a.order,b.order
            if (x.rank ~= nil) ~= (y.rank ~= nil) then return x.rank ~= nil end
            if x.rank and x.rank ~= y.rank then return x.rank < y.rank end
            if not x.rank and x.firstSeen ~= y.firstSeen then return x.firstSeen < y.firstSeen end
            if x.id ~= y.id then return x.id < y.id end
            return x.key < y.key
        end)
        for _,group in ipairs(groups) do
            entries[#entries+1]=buildEntry(widget,group.selector,unit,group.observations,profile,catalog)
        end
    end
    return entries
end
local function changedSelector(selector,delta)
    local field=KanaEffects.Selectors.DeltaField(selector)
    return (delta[field] or {})[selector.id] == true
end
function Projector.AffectedWidgets(profile,compiled,delta)
    local affected,units={},{}
    for tag,present in pairs(delta.unitIdentityChanged or {}) do if present then units[tag]=true end end
    for key,present in pairs(delta.units or {}) do
        if present then
            local tag=string.match(key,"^(.*):%d+$")
            if tag then units[tag]=true end
        end
    end
    if next(units) == nil then return affected end
    local sets=compiled:AffectedSets(delta)
    local unitOnly=next(delta.abilities or {}) == nil and next(delta.artificialEffects or {}) == nil and next(delta.families or {}) == nil and next(delta.categories or {}) == nil
    for _,widget in ipairs(profile.widgets) do
        if units[widget.unitTag] then
            local dirty=unitOnly or (delta.unitIdentityChanged or {})[widget.unitTag] == true
            if widget.type == "table" then
                for _,columns in pairs(widget.slots or {}) do
                    for _,selector in pairs(columns) do dirty=dirty or changedSelector(selector,delta) end
                end
            elseif widget.rules.expression~=nil then
                dirty=true -- Expressions may inspect every changed observation field.
            else
                for _,field in ipairs({"includeSets","excludeSets"}) do
                    for _,id in ipairs(widget.rules[field]) do dirty=dirty or sets[id] == true end
                end
            end
            -- No membershipChanged gate: updated deadlines still require Render.
            if dirty then affected[widget.id]=true end
        end
    end
    return affected
end
