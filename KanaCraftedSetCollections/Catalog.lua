KanaCraftedSetCollections = KanaCraftedSetCollections or {}
local addon = KanaCraftedSetCollections

local function Lower(value)
    if zo_strlower then return zo_strlower(value) end
    return string.lower(value)
end

local function SortRows(rows)
    table.sort(rows, function(left, right)
        local leftName, rightName = Lower(left.name), Lower(right.name)
        if leftName == rightName then return left.setId < right.setId end
        return leftName < rightName
    end)
end

local function NativeCategoryIds()
    local manager = ITEM_SET_COLLECTIONS_DATA_MANAGER
    if not manager or not manager.TopLevelItemSetCollectionCategoryIterator then return nil end
    local ids = {}
    local function Visit(category)
        ids[category:GetId()] = true
        for _, child in category:SubcategoryIterator() do Visit(child) end
    end
    for _, category in manager:TopLevelItemSetCollectionCategoryIterator() do Visit(category) end
    return ids
end

function addon.FilterRows(rows, query)
    rows = rows or {}
    query = Lower((query or ""):match("^%s*(.-)%s*$"))
    if query == "" then return rows end

    local words = {}
    for word in query:gmatch("%S+") do words[#words + 1] = word end
    local filtered = {}
    for _, row in ipairs(rows) do
        local name = Lower(row.name)
        local matches = true
        for _, word in ipairs(words) do
            if not name:find(word, 1, true) then
                matches = false
                break
            end
        end
        if matches then filtered[#filtered + 1] = row end
    end
    return filtered
end

function addon.BuildCatalog(lib)
    local source = lib.GetSetTypeSetsData(LIBSETS_SETTYPE_CRAFTED)
    if type(source) ~= "table" then return nil, "LibSets crafted set data is unavailable" end

    local nativeCategoryIds = NativeCategoryIds()
    local categoriesByZone = {}
    for _, mapping in ipairs(lib.GetItemSetCollectionToZoneIds() or {}) do
        if mapping.category and (not nativeCategoryIds or nativeCategoryIds[mapping.category])
            and not mapping.isDungeon and not mapping.isTrial and not mapping.isArena then
            for _, zoneId in ipairs(mapping.zoneIds or {}) do
                if type(zoneId) == "number" and zoneId > 0 then
                    local categories = categoriesByZone[zoneId] or {}
                    categories[mapping.category] = true
                    categoriesByZone[zoneId] = categories
                end
            end
        end
    end

    local catalog = { byCategory = {}, fallback = {}, all = {} }
    for setId in pairs(source) do
        local zones, seenZones = {}, {}
        for _, zoneId in ipairs(lib.GetZoneIds(setId) or {}) do
            if type(zoneId) == "number" and zoneId > 0 and not seenZones[zoneId] then
                zones[#zones + 1] = zoneId
                seenZones[zoneId] = true
            end
        end

        local itemId = lib.GetSetItemId(setId)
        local itemLink = itemId and lib.buildItemLink(itemId) or nil
        if itemLink and itemLink ~= "" then
            local row = {
                setId = setId,
                name = lib.GetSetName(setId) or tostring(setId),
                itemLink = itemLink,
                icon = GetItemLinkIcon(itemLink),
                traitsNeeded = lib.GetTraitsNeeded(setId),
                zoneIds = zones,
                zoneByCategory = {},
            }
            catalog.all[#catalog.all + 1] = row

            for _, zoneId in ipairs(zones) do
                for categoryId in pairs(categoriesByZone[zoneId] or {}) do
                    if not row.zoneByCategory[categoryId] then
                        row.zoneByCategory[categoryId] = zoneId
                        local rows = catalog.byCategory[categoryId] or {}
                        rows[#rows + 1] = row
                        catalog.byCategory[categoryId] = rows
                    end
                end
            end
            if not next(row.zoneByCategory) then catalog.fallback[#catalog.fallback + 1] = row end
        end
    end

    for _, rows in pairs(catalog.byCategory) do SortRows(rows) end
    SortRows(catalog.fallback)
    SortRows(catalog.all)
    return catalog
end
