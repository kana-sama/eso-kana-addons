-- Native calls are injected through EsoApi. No globals, range scans or name inference.
local Catalog = {}
Catalog.__index = Catalog
KanaEffects.Catalog = Catalog
local levels = {"minor", "major"}
local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}; for key, item in pairs(value) do result[key] = copy(item) end
    return result
end
local function positiveInteger(value)
    return type(value) == "number" and value > 0 and value < math.huge and value == math.floor(value)
end
local function artificialId(value)
    return type(value)=="number" and value>=0 and value<math.huge and value==math.floor(value)
end
local function nonempty(value) return type(value) == "string" and value ~= "" end
local function append(list, values)
    for _, value in ipairs(values or {}) do list[#list+1] = value end
end
local function sortedKeys(values)
    local result = {}; for key in pairs(values) do result[#result+1] = key end
    table.sort(result); return result
end
function Catalog.New(api, versionedData, diagnostics)
    assert(type(api.NormalizeName) == "function", "Catalog requires injected ESO name normalization")
    local data = versionedData or {families=KanaEffects.CatalogData.Families, categories=KanaEffects.CatalogData.Categories}
    assert(data.families.apiVersion == data.categories.apiVersion, "Catalog data versions must agree")
    local self = setmetatable({api=api, data=copy(data), families={}, categories={}, seeds={}, entries={},
        metadata={}, observedMetadata={}, observedRepresentativeIcons={}, observedLevels={}, unitTags={}, buffTypes={},
        diagnostics=diagnostics, cacheIds={}, cacheRing={}, cacheHead=1, cacheSize=0, contextOrders={}, tagOrders={}, familyIcons={},
        artificialEntries={},artificialOrder={}}, Catalog)
    self.dataVersion = data.families.apiVersion
    self.apiVersion = api.GetAPIVersion and api.GetAPIVersion() or 0
    self.versionMatches = self.apiVersion == self.dataVersion
    local language = api.language or (api.GetCVar and api.GetCVar("language.2")) or "en"
    self.locale = (KanaEffects.Localization or {})[language] or (KanaEffects.Localization or {}).en
    assert(self.locale, "Catalog localization must be loaded first")
    for _, family in ipairs(self.data.families.rows) do
        self.families[family.id] = family
        for _, level in ipairs(levels) do
            local definition = family.levels[level]
            local constant = definition.nativeConstant and (api.constants or {})[definition.nativeConstant]
            if constant ~= nil then self.buffTypes[constant] = {familyId=family.id, level=level} end
            if definition.representativeId then
                self.seeds[definition.representativeId] = {familyId=family.id, level=level, categories={},
                    aliases={}, origin="unknown", provenance=definition.provenance}
            end
        end
    end
    for _, category in ipairs(self.data.categories.rows) do self.categories[category.id] = category end
    for id, seed in pairs(self.data.categories.abilities) do self.seeds[id] = copy(seed) end
    for id, seed in pairs(self.data.families.overrides or {}) do
        self.seeds[id] = copy(seed); self.seeds[id].categories = {}; self.seeds[id].aliases = {}
    end
    return self
end
-- Coordinated FIFO: insertion order, hits do not promote. Eviction touches caches only.
function Catalog:_CacheId(id)
    if self.cacheIds[id] then return end
    local slot
    if self.cacheSize<1024 then self.cacheSize=self.cacheSize+1; slot=self.cacheSize
    else
        slot=self.cacheHead; local evicted=self.cacheRing[slot]
        for _,field in ipairs({'cacheIds','entries','unitTags','metadata','observedMetadata','observedRepresentativeIcons','contextOrders','tagOrders'}) do self[field][evicted]=nil end
        self.cacheHead=slot%1024+1
    end
    self.cacheRing[slot]=id; self.cacheIds[id]=true
end
function Catalog:_Context(id,key)
    local order=self.contextOrders[id] or {}; self.contextOrders[id]=order
    for _,known in ipairs(order) do if known==key then return end end
    if #order==8 then
        local old=table.remove(order,1)
        if self.metadata[id] then self.metadata[id][old]=nil end
        if self.observedMetadata[id] then self.observedMetadata[id][old]=nil end
    end
    order[#order+1]=key
end
function Catalog:_Recipient(id,tag)
    local order=self.tagOrders[id] or {}; self.tagOrders[id]=order
    local tags=self.unitTags[id] or {}; self.unitTags[id]=tags
    if tags[tag] then return end
    if #order==8 then tags[table.remove(order,1)]=nil end
    order[#order+1]=tag; tags[tag]=true
end
function Catalog:GetCacheStats()
    local contexts,tags,levels=0,0,0
    for _,values in pairs(self.contextOrders) do contexts=contexts+#values end
    for _,values in pairs(self.tagOrders) do tags=tags+#values end
    for _,values in pairs(self.observedLevels) do for _ in pairs(values) do levels=levels+1 end end
    return {abilityIds=self.cacheSize,contexts=contexts,unitTags=tags,discoveredLevels=levels,capacity=1024,contextsPerId=8,unitTagsPerId=8,policy='FIFO'}
end
function Catalog:_Label(kind, id)
    local labels = self.locale[kind] or {}
    return labels[id] or id
end
function Catalog:_Diagnostic(code)
    return {code=code, path="selector", message=self.locale.reasons[code] or code}
end
function Catalog:Describe(abilityId, casterContext)
    local context = type(casterContext) == "table" and casterContext or {}
    local caster = type(casterContext) == "string" and casterContext or context.casterUnitTag
    if not nonempty(caster) then caster = nil end
    local validId = positiveInteger(abilityId)
    local exists = validId and self.api.DoesAbilityExist and self.api.DoesAbilityExist(abilityId) == true or false
    -- Native names may be contextual too. Keep their cache keyed by caster;
    -- classification is recalculated every call, never taken from an earlier one.
    local metadataKey = caster or false
    if validId then self:_CacheId(abilityId); self:_Context(abilityId,metadataKey) end
    if self.diagnostics then self.diagnostics:Count("catalog_describes") end
    local nativeMetadata = validId and self.metadata[abilityId] and self.metadata[abilityId][metadataKey] or nil
    if exists and not nativeMetadata then
        nativeMetadata = {name=self.api.GetAbilityName and self.api.GetAbilityName(abilityId, caster) or "",
            icon=self.api.GetAbilityIcon and self.api.GetAbilityIcon(abilityId) or ""}
        if nonempty(nativeMetadata.name) and nonempty(nativeMetadata.icon) then
            self.metadata[abilityId] = self.metadata[abilityId] or {}
            self.metadata[abilityId][metadataKey] = nativeMetadata
        end
    end
    nativeMetadata = nativeMetadata or {}
    local observed = validId and self.observedMetadata[abilityId] and self.observedMetadata[abilityId][metadataKey] or nil
    if validId and (nonempty(context.name) or nonempty(context.icon)) then
        observed = observed or {}
        if nonempty(context.name) then observed.name = context.name end
        if nonempty(context.icon) then
            observed.icon = context.icon
            -- Generic family display can reuse the actual representative icon,
            -- but its contextual name must never escape this caster cache key.
            self.observedRepresentativeIcons[abilityId] = context.icon
        end
        self.observedMetadata[abilityId] = self.observedMetadata[abilityId] or {}
        self.observedMetadata[abilityId][metadataKey] = observed
    end
    local name = observed and observed.name or nativeMetadata.name
    local icon = observed and observed.icon or nativeMetadata.icon
    if not nonempty(name) then name = "" end
    if not nonempty(icon) then icon = "" end
    local seed = self.versionMatches and self.seeds[abilityId] or nil
    local entry = {abilityId=abilityId, name=name, icon=icon, aliases=copy(seed and seed.aliases or {}),
        familyId=seed and seed.familyId or nil, level=seed and seed.level or nil,
        categories=copy(seed and seed.categories or {}), origin=seed and seed.origin or "unknown",
        apiVersion=self.apiVersion, provenance=seed and seed.provenance or (exists and "native-api:" .. self.apiVersion or "unknown"),
        verified=exists and nonempty(nativeMetadata.name) and nonempty(nativeMetadata.icon)}
    if self.versionMatches and not entry.familyId and exists and caster and self.api.GetAbilityBuffType then
        local classification = self.buffTypes[self.api.GetAbilityBuffType(abilityId, caster)]
        if classification then
            entry.familyId, entry.level = classification.familyId, classification.level
            entry.provenance = entry.provenance .. ";native-BuffType:" .. self.apiVersion
            -- Bounded session-local evidence: one representative per declared
            -- family/level, only with current API, trusted caster and complete
            -- native existence/name/icon verification. Never promote enum-only
            -- or recipient/unknown-caster observations into selector support.
            if entry.verified then
                local familyLevels = self.observedLevels[entry.familyId]
                if not familyLevels then familyLevels = {}; self.observedLevels[entry.familyId] = familyLevels end
                if not familyLevels[entry.level] then
                    familyLevels[entry.level] = {representativeId=abilityId, provenance=entry.provenance}
                end
            end
        end
    end
    if observed then entry.provenance = entry.provenance .. ";observation" end
    local family = self.families[entry.familyId]
    if family and entry.level and nonempty(context.icon) then
        local definition=self:_Level(entry.familyId,entry.level)
        if definition and definition.representativeId==abilityId then
            self.familyIcons[entry.familyId]=self.familyIcons[entry.familyId] or {}
            self.familyIcons[entry.familyId][entry.level]=context.icon
        end
    end
    if family then entry.rank = family.rank
    else
        for id in pairs(entry.categories) do
            local rank = self.categories[id] and self.categories[id].rank
            if rank and (not entry.rank or rank < entry.rank) then entry.rank = rank end
        end
    end
    if validId and (nonempty(entry.name) or nonempty(entry.icon)) then
        self.entries[abilityId] = copy(entry)
        if nonempty(context.unitTag) then
            self:_Recipient(abilityId,context.unitTag)
        end
    end
    return entry
end
function Catalog:_Level(familyId, level)
    local definition = self.families[familyId].levels[level]
    if definition.catalogSupported then return definition end
    local evidence = self.observedLevels[familyId] and self.observedLevels[familyId][level]
    if self.versionMatches and evidence then return evidence end
end
function Catalog:DescribeArtificial(id)
    local name,icon,effectType
    if artificialId(id) and self.api.GetArtificialEffectInfo then name,icon,effectType=self.api.GetArtificialEffectInfo(id) end
    local known=self.artificialEntries[id]
    if not nonempty(name) then name=known and known.name or "" end
    if not nonempty(icon) then icon=known and known.icon or "" end
    local entry={artificialEffectId=id,name=name,icon=icon,aliases={},categories={},origin="unknown",
        apiVersion=self.apiVersion,provenance="native-artificial-effect:" .. self.apiVersion,
        verified=artificialId(id) and nonempty(name) and nonempty(icon),kind="unknown"}
    local constants=self.api.constants or {}
    if effectType~=nil and effectType==constants.BUFF_EFFECT_TYPE_BUFF then entry.kind="buff"
    elseif effectType~=nil and effectType==constants.BUFF_EFFECT_TYPE_DEBUFF then entry.kind="debuff"
    elseif known then entry.kind=known.kind end
    if entry.verified then
        if not known then
            if #self.artificialOrder==128 then self.artificialEntries[table.remove(self.artificialOrder,1)]=nil end
            self.artificialOrder[#self.artificialOrder+1]=id
        end
        self.artificialEntries[id]=copy(entry)
    end
    return entry
end
function Catalog:ValidateSelector(selector)
    if type(selector) ~= "table" then return false, self:_Diagnostic("invalid_selector") end
    local fields = {kind=true,id=true}; if selector.kind == "family" then fields.level = true end
    for key in pairs(selector) do if not fields[key] then return false, self:_Diagnostic("invalid_selector") end end
    if selector.kind == "ability" or selector.kind == "artificial" then
        if not (selector.kind=="artificial" and artificialId(selector.id) or selector.kind=="ability" and positiveInteger(selector.id)) then
            return false, self:_Diagnostic("invalid_selector")
        end
        local entry = selector.kind=="artificial" and self:DescribeArtificial(selector.id) or self:Describe(selector.id)
        if not entry.verified and not (nonempty(entry.name) and nonempty(entry.icon)) then return false, self:_Diagnostic("unknown_ability") end
        return true
    end
    if selector.kind == "category" then
        if not self.categories[selector.id] then return false, self:_Diagnostic("unknown_category") end
    elseif selector.kind == "family" then
        local family = self.families[selector.id]
        if not family then return false, self:_Diagnostic("unknown_family") end
        if selector.level ~= "pair" and selector.level ~= "minor" and selector.level ~= "major" then
            return false, self:_Diagnostic("invalid_selector")
        end
        if selector.level ~= "pair" and not self:_Level(selector.id, selector.level) then
            return false, self:_Diagnostic("unsupported_level")
        end
        if selector.level == "pair" and not self:_Level(selector.id, "minor") and not self:_Level(selector.id, "major") then
            return false, self:_Diagnostic("unsupported_level")
        end
    else return false, self:_Diagnostic("invalid_selector") end
    if not self.versionMatches then return false, self:_Diagnostic("catalog_version_mismatch") end
    return true
end
function Catalog:Resolve(selector)
    local metadata = {name="", icon="", kind="unknown", pair=false, availableLevels={}}
    if type(selector) ~= "table" then return metadata end
    if selector.kind == "ability" or selector.kind == "artificial" then
        local entry = selector.kind=="artificial" and self:DescribeArtificial(selector.id) or self:Describe(selector.id)
        metadata.name, metadata.icon = entry.name, entry.icon
        if entry.kind then metadata.kind=entry.kind end
        local family = self.families[entry.familyId]
        if family then metadata.kind = family.kind end
        return metadata
    end
    if selector.kind == "category" and self.categories[selector.id] then
        metadata.name = self:_Label("categories", selector.id)
        -- Categories have no verified stock texture; retain missing icon explicitly.
    elseif selector.kind == "family" and self.families[selector.id] then
        local family = self.families[selector.id]
        metadata.name, metadata.kind, metadata.pair = self:_Label("families", selector.id), family.kind, selector.level == "pair"
        if selector.level == "minor" or selector.level == "major" then
            metadata.name = metadata.name .. " (" .. self.locale.levels[selector.level] .. ")"
        end
        for _, level in ipairs(levels) do
            local definition = self:_Level(selector.id, level)
            if self.versionMatches and definition then
                metadata.availableLevels[level] = true
                if selector.level == "pair" or selector.level == level then
                    local entry = self:Describe(definition.representativeId)
                    local icon = (self.familyIcons[selector.id] or {})[level] or self.observedRepresentativeIcons[definition.representativeId] or entry.icon
                    if metadata.icon == "" and nonempty(icon) then metadata.icon = icon end
                    if selector.level == level and nonempty(entry.name) then metadata.name = entry.name end
                end
            end
        end
    end
    return metadata
end
function Catalog:_Aliases(kind, id, level, extra)
    local aliases = {}; append(aliases, extra)
    for _, locale in pairs(KanaEffects.Localization) do
        append(aliases, {locale[kind][id]})
        if kind == "families" and locale.levels[level] then aliases[#aliases+1] = locale.levels[level] .. " " .. locale[kind][id] end
        append(aliases, (locale[kind == "families" and "familyAliases" or "categoryAliases"] or {})[id])
    end
    return aliases
end
function Catalog:Search(query, filter, offset, limit)
    if self.diagnostics then self.diagnostics:Count("catalog_scans") end
    query = self.api.NormalizeName(query or ""); filter = filter or {}
    offset, limit = math.max(0, math.floor(offset or 0)), math.max(0, math.floor(limit or 50))
    local results = {}
    local function matches(item, aliases, tags)
        if filter.kind and filter.kind ~= item.selector.kind then return false end
        if filter.group and filter.group ~= item.group then return false end
        if filter.level and item.selector.level ~= filter.level then return false end
        if filter.category and not (tags or {})[filter.category] then return false end
        if filter.unitTag then
            local found = false; for _, tag in ipairs(item.unitTags) do if tag == filter.unitTag then found = true end end
            if not found then return false end
        end
        if query == "" then return true end
        if string.find(self.api.NormalizeName(item.name), query, 1, true) then return true end
        for _, alias in ipairs(aliases or {}) do
            if string.find(self.api.NormalizeName(alias), query, 1, true) then return true end
        end
        return false
    end
    local function add(selector, aliases, tags, rank)
        local metadata = self:Resolve(selector)
        local ok, diagnostic = self:ValidateSelector(selector)
        local ids = {}
        if selector.kind == "ability" then ids[1] = selector.id
        elseif selector.kind == "family" then
            for _, level in ipairs(levels) do
                local definition = self:_Level(selector.id, level)
                if metadata.availableLevels[level] and (selector.level == "pair" or selector.level == level) then ids[#ids+1] = definition.representativeId end
            end
        end
        local item = {selector=copy(selector), name=metadata.name, icon=metadata.icon, selectable=ok,
            reason=diagnostic and diagnostic.message or nil, abilityIds=ids,
            unitTags=selector.kind == "ability" and sortedKeys(self.unitTags[selector.id] or {})
                or selector.kind=="artificial" and {"player"} or {}}
        if selector.kind == "family" then item.group = self.families[selector.id].uiGroup or "common" end
        if matches(item, aliases, tags) then results[#results+1] = {item=item,rank=rank,key=KanaEffects.Selectors.Key(selector)} end
    end
    -- Numeric queries are exact addressable requests, never substring/range scans.
    if string.match(query, "^%d+$") then
        local id = tonumber(query)
        if positiveInteger(id) then
            local entry = self:Describe(id)
            if nonempty(entry.name) and nonempty(entry.icon) then
                local original = query; query = ""
                add({kind="ability",id=id}, entry.aliases, entry.categories, 1000)
                query = original
            end
        end
        if artificialId(id) then
            local entry=self:DescribeArtificial(id)
            if entry.verified then
                local original=query; query=""; add({kind="artificial",id=id},{},{},1001); query=original
            end
        end
    else
        for _, family in ipairs(self.data.families.rows) do
            for index, level in ipairs({"pair","minor","major"}) do
                add({kind="family",id=family.id,level=level}, self:_Aliases("families",family.id,level),nil,family.rank*10+index)
            end
        end
        for _, category in ipairs(self.data.categories.rows) do
            add({kind="category",id=category.id},self:_Aliases("categories",category.id),{[category.id]=true},category.rank*10)
        end
        local known = {}; if self.versionMatches then for id in pairs(self.seeds) do known[id] = true end end
        for id in pairs(self.entries) do known[id] = true end
        for _, id in ipairs(sortedKeys(known)) do
            local entry = self:Describe(id)
            if nonempty(entry.name) and nonempty(entry.icon) then add({kind="ability",id=id},entry.aliases,entry.categories,2000+id) end
        end
        for _,id in ipairs(sortedKeys(self.artificialEntries)) do add({kind="artificial",id=id},{},{},3000+id) end
    end
    table.sort(results,function(a,b) if a.rank == b.rank then return a.key < b.key end; return a.rank < b.rank end)
    local page = {}; for index=offset+1,math.min(offset+limit,#results) do page[#page+1] = results[index].item end
    return page, #results
end
