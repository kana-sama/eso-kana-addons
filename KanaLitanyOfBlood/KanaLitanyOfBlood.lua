local ADDON_NAME = "KanaLitanyOfBlood"
local ACHIEVEMENT_ID = 1410
local TARGET_COUNT = 15
local strokes = {{}, {}}
local measure

local function NormalizeTitle(text)
    text = zo_strformat("<<1>>", text or "")
    text = text:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
    return zo_strlower((text:gsub("^%s+", ""):gsub("%s+$", "")))
end

local function CompletedRanges(body)
    if GetAchievementNumCriteria(ACHIEVEMENT_ID) ~= TARGET_COUNT + 1 then return {} end

    -- The refrain ends the introduction and each of the 15 targets. Find it
    -- in the game's localized text rather than supplying a translated book.
    local sentences = {}
    for start, text, after in body:gmatch("()([^%.!?]+[%.!?])()") do
        local sentence = text:match("^%s*(.-)%s*$")
        local endings = sentences[sentence]
        if not endings then endings = {}; sentences[sentence] = endings end
        endings[#endings + 1] = after - 1
    end
    local endings
    for _, candidate in pairs(sentences) do
        if #candidate == TARGET_COUNT + 1 then
            if endings then return {} end -- An ambiguous edition stays intact.
            endings = candidate
        end
    end
    if not endings then return {} end

    local ranges = {}
    for index = 1, TARGET_COUNT do
        local _, completed, required = GetAchievementCriterion(ACHIEVEMENT_ID, index)
        if completed and required and required > 0 and completed >= required then
            -- Keep the leading star separator outside the target's crossout.
            local first = body:find("[^%s%*]", endings[index] + 1)
            ranges[#ranges + 1] = {first = first, last = endings[index + 1]}
        end
    end
    return ranges
end

local function Segments(label, body, ranges)
    local segments, cursor = {}, 1
    for index = 1, label:GetNumLines() do
        local text = label:GetTextForLines(index, index):gsub("^[\r\n]+", ""):gsub("[\r\n]+$", "")
        if text:find("%S") then
            local first, last = body:find(text, cursor, true)
            if not first then return {} end -- Never guess at rendered positions.
            cursor = last + 1
            for _, range in ipairs(ranges) do
                local from, to = math.max(first, range.first), math.min(last, range.last)
                if from <= to then
                    segments[#segments + 1] = {
                        line = index,
                        prefix = text:sub(1, from - first),
                        text = text:sub(from - first + 1, to - first + 1),
                        lineText = text,
                    }
                end
            end
        end
    end
    return segments
end

local function TextWidth(text)
    measure:SetText(text)
    return (measure:GetTextDimensions())
end

local function HideStrokes()
    for _, page in ipairs(strokes) do
        for _, stroke in ipairs(page) do stroke:SetHidden(true) end
    end
end

local function Refresh(reader)
    HideStrokes()
    local title = NormalizeTitle(GetAchievementName(ACHIEVEMENT_ID))
    if title == "" or NormalizeTitle(reader.titleText) ~= title or reader.useOverrideImage then return end
    local body = reader.bodyText
    if type(body) ~= "string" then return end
    local ranges = CompletedRanges(body)
    if #ranges == 0 then return end

    if not measure then
        measure = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "Measure", reader.control, CT_LABEL)
        measure:SetHidden(true)
        measure:SetMouseEnabled(false)
    end
    for pageIndex, page in ipairs({reader.firstPage, reader.secondPage}) do
        if pageIndex == 1 or reader.numPagesPerGrouping > 1 then
            local label = page.body
            -- Label getters return the current face and an already formatted
            -- style string; ZO_CreateFontString instead expects a style enum.
            local font = string.format("%s|%u", label:GetFont(), label:GetFontSize())
            local style = label:GetFontStyle()
            if style ~= "" then font = font .. "|" .. style end
            measure:SetFont(font)
            local fontHeight = label:GetFontHeight()
            -- Each segment fits one native line; measure it without wrapping.
            measure:SetDimensions(label:GetWidth() * 2, fontHeight * 2)
            local alignment = label:GetHorizontalAlignment()
            for index, segment in ipairs(Segments(label, body, ranges)) do
                local x = TextWidth(segment.prefix)
                if alignment == TEXT_ALIGN_CENTER then
                    x = x + (label:GetWidth() - TextWidth(segment.lineText)) / 2
                elseif alignment == TEXT_ALIGN_RIGHT then
                    x = x + label:GetWidth() - TextWidth(segment.lineText)
                end
                local stroke = strokes[pageIndex][index]
                if not stroke then
                    -- Children of the native body inherit its page clipping,
                    -- scrolling and UI scale without changing text or layout.
                    stroke = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "Stroke" .. pageIndex .. "_" .. index, label, CT_TEXTURE)
                    stroke:SetMouseEnabled(false)
                    stroke:SetDrawLayer(DL_OVERLAY)
                    strokes[pageIndex][index] = stroke
                end
                stroke:ClearAnchors()
                stroke:SetAnchor(TOPLEFT, label, TOPLEFT, x, (segment.line - 0.5) * fontHeight)
                stroke:SetDimensions(TextWidth(segment.text), math.max(1, fontHeight / 20))
                stroke:SetColor(label:GetColor())
                stroke:SetHidden(false)
            end
        end
    end
end

local function OnLoaded(_, addonName)
    if addonName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    local reader = LORE_READER
    reader.firstPage.body:SetStoreLineEndingCharacterIndices(true)
    reader.secondPage.body:SetStoreLineEndingCharacterIndices(true)
    SecurePostHook(reader, "LayoutText", Refresh)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ACHIEVEMENT_UPDATED, function(_, id)
        if id == ACHIEVEMENT_ID and not reader.control:IsHidden() then Refresh(reader) end
    end)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, function()
        if not reader.control:IsHidden() then Refresh(reader) end
    end)
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnLoaded)
