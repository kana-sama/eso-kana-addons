-- Read a learned library book by its localized title or by #bookId.
local function Say(text)
    d("|c88CCFFKanaReadBook|r: " .. text)
end

local function Normalize(text)
    text = zo_strformat("<<1>>", text or "")
    text = text:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
    return zo_strlower((text:gsub("^%s+", ""):gsub("%s+$", "")))
end

local function OpenBook(book)
    local body, medium, showTitle = ReadLoreBook(book.category, book.collection, book.index)
    if not body or body == "" or not medium or medium == BOOK_MEDIUM_NONE then
        Say("Не удалось получить текст книги: " .. book.title)
        return
    end
    LORE_READER:Show(book.title, body, medium, showTitle,
        GetLoreBookOverrideImageFromBookId(book.id))
end

SLASH_COMMANDS["/readbook"] = function(argument)
    local query = Normalize(argument)
    if query:sub(1, 1) == '"' and query:sub(-1) == '"' then
        query = Normalize(query:sub(2, -2))
    end
    if query == "" then
        Say("/readbook Название книги — поиск среди изученных книг. /readbook #ID — открыть по ID.")
        return
    end

    local requestedId = tonumber(query:match("^#(%d+)$"))
    if requestedId then
        -- Hidden collections can report zero books even when this lookup works.
        local category, collection, index = GetLoreBookIndicesFromBookId(requestedId)
        if category and collection and index then
            local title, _, known, id = GetLoreBookInfo(category, collection, index)
            if known and title and id == requestedId then
                OpenBook({title = zo_strformat("<<1>>", title), id = id,
                    category = category, collection = collection, index = index})
                return
            end
        end
        Say("Изученная книга с этим ID не найдена.")
        return
    end

    local exact, partial, seen = {}, {}, {}
    -- Search fresh so books learned this session are immediately available.
    for category = 1, GetNumLoreCategories() do
        local _, numCollections = GetLoreCategoryInfo(category)
        for collection = 1, numCollections do
            local _, _, _, numBooks = GetLoreCollectionInfo(category, collection)
            -- LoreBooks supplies collection metadata when ESO hides the count.
            -- Titles, learned status and text still come from the game itself.
            if (not numBooks or numBooks == 0) and LoreBooks_GetNewLoreCollectionInfo then
                numBooks = select(4, LoreBooks_GetNewLoreCollectionInfo(category, collection))
            end
            for index = 1, numBooks or 0 do
                local title, _, known, id = GetLoreBookInfo(category, collection, index)
                if known and title and id and not seen[id] then
                    seen[id] = true
                    local normalizedTitle = Normalize(title)
                    local isExact = normalizedTitle == query
                    if isExact or normalizedTitle:find(query, 1, true) then
                        local book = {title = zo_strformat("<<1>>", title), id = id,
                            category = category, collection = collection, index = index}
                        local matches = isExact and exact or partial
                        matches[#matches + 1] = book
                    end
                end
            end
        end
    end

    local matches = #exact > 0 and exact or partial
    if #matches == 0 then
        Say("Изученная книга не найдена. Укажи название на языке игры или проверь ID.")
    elseif #matches == 1 then
        OpenBook(matches[1])
    else
        Say(string.format("Найдено книг: %d. Уточни название или используй /readbook #ID:", #matches))
        for i = 1, math.min(#matches, 20) do
            Say(string.format("%s — /readbook #%d", matches[i].title, matches[i].id))
        end
        if #matches > 20 then
            Say("Показаны первые 20 совпадений. Уточни запрос.")
        end
    end
end
