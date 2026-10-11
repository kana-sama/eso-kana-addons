-- Run from eso-kana-addons: lua KanaLitanyOfBlood/tests/test.lua
local passed, failed = 0, 0
local function test(name, run)
    local ok, err = pcall(run)
    if ok then passed = passed + 1 else failed = failed + 1; io.stderr:write(name .. ": " .. tostring(err) .. "\n") end
end

local function width(text)
    local _, continuationBytes = text:gsub("[\128-\191]", "")
    return (#text - continuationBytes) * 8
end

local function wrappedLines(text, maxWidth)
    local lines = {}
    for sourceLine in (text .. "\n"):gmatch("(.-)\n") do
        sourceLine = sourceLine:gsub("\r$", "")
        local line = ""
        for chunk in sourceLine:gmatch("%S+%s*") do
            local nextLine = line .. chunk
            if width((nextLine:gsub("%s+$", ""))) > maxWidth and line ~= "" then
                lines[#lines + 1] = line:gsub("%s+$", "")
                line = chunk
            else
                line = nextLine
            end
        end
        lines[#lines + 1] = line:gsub("%s+$", "")
    end
    return lines
end

local function book(russian, joined, separator)
    separator = separator or "* * *"
    local ending = russian and "Узнай их по знаку." or "Know them by the sign."
    local opening = russian and "Приношу тебе эти души." or "I offer you these souls."
    local parts = { (russian and "Вступление." or "Introduction.") .. "\n" .. ending }
    for i = 1, 15 do
        parts[#parts + 1] = separator .. "\n\n" .. opening .. "\n"
            .. (russian and "Описание цели " or "Description of target ") .. i .. ".\n" .. ending
    end
    local text = table.concat(parts, "\n\n")
    if joined then text = text:gsub("\n", " ") end
    return text
end

local function setup(options)
    options = options or {}
    local events, controls = {}, {}
    local Control = {}; Control.__index = Control
    local function control(parent, kind)
        local value = setmetatable({parent = parent, kind = kind, hidden = false,
            text = "", font = "EsoUI/Common/Fonts/Univers57.slug", fontSize = 14,
            fontStyle = "", fontHeight = 14,
            width = options.width or 240, height = 0, color = {0.2, 0.1, 0.05, 1}}, Control)
        controls[#controls + 1] = value
        return value
    end
    function Control:SetText(value)
        self.text = value
        self.lines = wrappedLines(value, self.width / (self.fontSize / 20))
    end
    function Control:GetText() return self.text end
    function Control:GetNumLines() return #self.lines end
    function Control:GetTextForLines(first, last)
        assert(self.storeLines, "native label requires stored line-ending indices")
        return table.concat(self.lines, "\n", first, last)
    end
    function Control:SetStoreLineEndingCharacterIndices(value) self.storeLines = value end
    function Control:SetHidden(value) self.hidden = value end
    function Control:IsHidden() return self.hidden end
    function Control:SetMouseEnabled(value) self.mouseEnabled = value end
    function Control:SetFont(value)
        -- The client returns a bare face from GetFont, but SetFont takes a
        -- face|size|style descriptor. Invalid input leaves its default font.
        local face, size, style = value:match("^([^|]+)|([^|]+)|?(.*)$")
        if face and tonumber(size) then
            self.font, self.fontSize, self.fontStyle = face, tonumber(size), style
            self.fontHeight = self.fontSize
        end
    end
    function Control:GetFont() return self.font end
    function Control:GetFontSize() return self.fontSize end
    function Control:GetFontStyle() return self.fontStyle end
    function Control:GetFontHeight() return self.fontHeight end
    function Control:GetWidth() return self.width end
    function Control:SetDimensions(w, h) self.width, self.height = w, h end
    function Control:GetTextDimensions()
        local maxWidth = 0
        for _, line in ipairs(self.lines) do maxWidth = math.max(maxWidth, width(line) * self.fontSize / 20) end
        return maxWidth, #self.lines * self.fontHeight
    end
    function Control:GetStringWidth() error("scaled pixel widths must not be used as UI dimensions") end
    function Control:GetHorizontalAlignment() return TEXT_ALIGN_LEFT end
    function Control:GetColor() return table.unpack(self.color) end
    function Control:SetColor(...) self.color = {...} end
    function Control:SetDrawLayer(value) self.drawLayer = value end
    function Control:ClearAnchors() self.anchor = nil end
    function Control:SetAnchor(...) self.anchor = {...} end
    function Control:SetVerticalScroll(value) self.scroll = value end
    CT_LABEL, CT_TEXTURE, TOPLEFT, DL_OVERLAY = 1, 2, 3, 4
    TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, TEXT_ALIGN_RIGHT = 0, 1, 2
    EVENT_ADD_ON_LOADED, EVENT_ACHIEVEMENT_UPDATED, EVENT_PLAYER_ACTIVATED = 1, 2, 3
    EVENT_MANAGER = {
        RegisterForEvent = function(_, _, event, callback) events[event] = callback end,
        UnregisterForEvent = function(_, _, event) events[event] = nil end,
    }
    WINDOW_MANAGER = {CreateControl = function(_, _, parent, kind) return control(parent, kind) end}
    function SecurePostHook(object, method, callback)
        local original = object[method]
        object[method] = function(...) original(...); callback(...) end
    end
    function zo_strformat(_, value) return value end
    function zo_strlower(value) return value:lower() end
    function GetFontStyleString(style)
        assert(type(style) == "number", "Checking type on argument fontStyle failed in GetFontStyleString_lua")
        return style == 0 and "" or "soft-shadow"
    end
    -- Native globalapi.lua: this helper accepts a FontStyle enum, whereas a
    -- LabelControl's GetFontStyle returns an already formatted style string.
    function ZO_CreateFontString(face, size, style)
        local styleString = GetFontStyleString(style)
        if styleString == "" then
            return string.format("%s|%u", face, size)
        else
            return string.format("%s|%u|%s", face, size, styleString)
        end
    end
    local title = options.russian and "Литания крови" or "Litany of Blood"
    function GetAchievementName(id) assert(id == 1410); return title end
    function GetAchievementNumCriteria(id) assert(id == 1410); return options.criteriaCount or 16 end
    local complete = options.complete or {[1] = true}
    function GetAchievementCriterion(id, index)
        assert(id == 1410)
        if options.missingProgress then return "", nil, nil end
        return "Criterion " .. index, complete[index] and 1 or 0, 1
    end
    LORE_READER = {control = control(), firstPage = control(), secondPage = control(),
        numPagesPerGrouping = options.pages or 2, renderablePageHeight = options.height or 180}
    local reader = LORE_READER
    reader.firstPage.body, reader.secondPage.body = control(reader.firstPage, CT_LABEL), control(reader.secondPage, CT_LABEL)
    for _, page in ipairs({reader.firstPage, reader.secondPage}) do
        page.body.font = "EsoUI/Common/Fonts/ProseAntiquePSMT.slug"
        page.body.fontSize, page.body.fontHeight = options.fontHeight or 20, options.fontHeight or 20
        page.body.fontStyle = "soft-shadow"
    end
    reader.firstPage.body.storeLines = true -- Native XML only enables this on the first page.
    function reader:LayoutText()
        self.firstPage.body:SetText(self.bodyText)
        self.secondPage.body:SetText(self.bodyText)
        self.pageHeight = math.floor(self.renderablePageHeight / self.firstPage.body:GetFontHeight()) * self.firstPage.body:GetFontHeight()
        self.maxPageGroupings = math.ceil((#self.firstPage.body.lines * self.firstPage.body:GetFontHeight() + 40) / self.pageHeight / self.numPagesPerGrouping)
        self.secondPageAdditionalOffset = self.pageHeight - 40
        self.firstPage:SetVerticalScroll(0)
        self.secondPage:SetVerticalScroll(self.secondPageAdditionalOffset)
        self.secondPage:SetHidden(self.numPagesPerGrouping == 1)
    end
    function reader:Show(name, text)
        self.titleText, self.bodyText, self.pageGrouping = name, text, 1
        self:LayoutText()
    end
    function reader:ChangePageGrouping(offset)
        self.pageGrouping = math.max(1, math.min(self.maxPageGroupings, self.pageGrouping + offset))
        local scroll = (self.pageGrouping - 1) * self.pageHeight * self.numPagesPerGrouping
        self.firstPage:SetVerticalScroll(scroll)
        self.secondPage:SetVerticalScroll(scroll + self.secondPageAdditionalOffset)
    end
    local file = io.open("KanaLitanyOfBlood/KanaLitanyOfBlood.lua")
    if file then
        file:close()
        dofile("KanaLitanyOfBlood/KanaLitanyOfBlood.lua")
        events[EVENT_ADD_ON_LOADED](EVENT_ADD_ON_LOADED, "KanaLitanyOfBlood")
    end
    local context = {reader = reader, title = title, complete = complete, events = events, controls = controls}
    function context:strokes(page)
        local result = {}
        for _, item in ipairs(controls) do
            if item.kind == CT_TEXTURE and not item.hidden and (not page or item.parent == page.body) then
                result[#result + 1] = item
            end
        end
        return result
    end
    function context:markedTexts(page)
        local result = {}
        local label = (page or reader.firstPage).body
        for _, item in ipairs(self:strokes(page or reader.firstPage)) do
            local line = math.floor(item.anchor[5] / label:GetFontHeight()) + 1
            local x, text = 0, ""
            for char in label.lines[line]:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
                if x >= item.anchor[4] and x < item.anchor[4] + item.width then text = text .. char end
                x = x + 8 * label.fontSize / 20
            end
            result[#result + 1] = text
        end
        return table.concat(result, "\n")
    end
    return context
end

test("crossouts measure the complete text with the native font descriptor", function()
    local c = setup({width = 1000})
    c.reader:Show(c.title, book())
    for _, page in ipairs({c.reader.firstPage, c.reader.secondPage}) do
        local marked = c:markedTexts(page)
        assert(marked:find("I offer you these souls.", 1, true), "the complete offering must be crossed out")
        assert(marked:find("Description of target 1.", 1, true), "the crossout must reach the end of the target description")
        assert(marked:find("Know them by the sign.", 1, true), "the complete closing sentence must be crossed out")
    end
end)

test("past kills strike only the matching stanza on both native pages", function()
    local c = setup({complete = {[2] = true, [15] = true}})
    local text = book()
    c.reader:Show(c.title, text)
    local marked = c:markedTexts()
    assert(marked:find("target 2.", 1, true), "completed second target must be crossed out")
    assert(marked:find("target 15.", 1, true), "last completed target must remain reachable")
    assert(not marked:find("target 1.", 1, true), "incomplete target must remain unmarked")
    assert(not marked:find("Introduction.", 1, true), "introduction must remain unmarked")
    assert(#c:strokes(c.reader.firstPage) == #c:strokes(c.reader.secondPage))
    assert(c.reader.bodyText == text and c.reader.firstPage.body:GetText() == text and c.reader.secondPage.body:GetText() == text)
end)

test("star separators remain visible without crossouts on both pages", function()
    for _, separator in ipairs({"***", "* * *", " \t* * * \t"}) do
        local c = setup({width = 1000, complete = {[1] = true, [15] = true}})
        local text = book(false, false, separator)
        c.reader:Show(c.title, text)
        for _, page in ipairs({c.reader.firstPage, c.reader.secondPage}) do
            local marked = c:markedTexts(page)
            assert(not marked:find("*", 1, true), "separators must not be crossed out")
            assert(marked:find("Description of target 1.", 1, true))
            assert(marked:find("Description of target 15.", 1, true))
            assert(page.body:GetText() == text, "the original separators and layout must remain intact")
        end
    end
end)

test("Russian text and CRLF preserve byte positions", function()
    local c = setup({russian = true, width = 1000, complete = {[3] = true}})
    c.reader:Show(c.title, book(true):gsub("\n", "\r\n"))
    assert(c:markedTexts():find("Описание цели 3.", 1, true))
    assert(not c:markedTexts():find("Описание цели 2.", 1, true))
end)

test("the same repeated sentence works without source line breaks", function()
    local c = setup({width = 1000, complete = {[1] = true}})
    c.reader:Show(c.title, book(false, true))
    assert(#c:strokes() > 0, "paragraph formatting must not hide completed targets")
    assert(not c:markedTexts():find("Introduction", 1, true))
    assert(not c:markedTexts():find("target 2", 1, true), "a shared visual line must not cross out its incomplete target")
end)

test("other books clear pooled strokes", function()
    local c = setup()
    c.reader:Show(c.title, book())
    assert(#c:strokes() > 0)
    c.reader:Show("Another book", book())
    assert(#c:strokes() == 0, "crossouts must not leak into other books")
end)

test("the fulfilled book is not treated as the target list", function()
    local c = setup()
    c.reader:Show("Litany of Blood Fulfilled", book())
    assert(#c:strokes() == 0)
end)

test("the reward criterion does not cross out any target", function()
    local c = setup({complete = {[16] = true}})
    c.reader:Show(c.title, book())
    assert(#c:strokes() == 0)
end)

test("unavailable progress leaves the original book intact", function()
    local c = setup({missingProgress = true})
    c.reader:Show(c.title, book())
    assert(#c:strokes() == 0)
end)

test("unexpected book structure is left unmarked", function()
    local c = setup()
    c.reader:Show(c.title, "Different edition.\nKnow them by the sign.")
    assert(#c:strokes() == 0)
end)

test("unexpected criteria cannot be mapped to targets", function()
    local c = setup({criteriaCount = 15})
    c.reader:Show(c.title, book())
    assert(#c:strokes() == 0)
end)

test("achievement updates refresh without resetting the current pages", function()
    local c = setup({complete = {}})
    c.reader:Show(c.title, book())
    c.reader:ChangePageGrouping(1)
    local firstScroll, secondScroll = c.reader.firstPage.scroll, c.reader.secondPage.scroll
    c.complete[4] = true
    assert(c.events[EVENT_ACHIEVEMENT_UPDATED], "achievement refresh must be registered")
    c.events[EVENT_ACHIEVEMENT_UPDATED](EVENT_ACHIEVEMENT_UPDATED, 999)
    assert(#c:strokes() == 0)
    c.events[EVENT_ACHIEVEMENT_UPDATED](EVENT_ACHIEVEMENT_UPDATED, 1410)
    assert(c:markedTexts():find("target 4.", 1, true))
    assert(c.reader.pageGrouping == 2 and c.reader.firstPage.scroll == firstScroll and c.reader.secondPage.scroll == secondScroll)
end)

test("font and width changes rebuild strokes in logical UI units", function()
    local c = setup({width = 240, complete = {[1] = true}})
    c.reader:Show(c.title, book())
    local original = #c:strokes(c.reader.firstPage)
    for _, page in ipairs({c.reader.firstPage, c.reader.secondPage}) do
        page.body.width, page.body.fontHeight, page.body.font = 144, 30, "CustomBookFont"
        page.body.fontSize = 30
    end
    c.reader:LayoutText()
    assert(#c:strokes(c.reader.firstPage) > original, "narrow pages must include every wrapped target line")
    for _, stroke in ipairs(c:strokes()) do
        assert(stroke.width <= 144 and stroke.height > 0)
        assert(stroke.anchor[2] == stroke.parent, "strokes must follow native body scrolling")
        assert(stroke.mouseEnabled == false, "strokes must not intercept page clicks")
    end
end)

test("measurement follows player fonts and string styles including an empty style", function()
    local c = setup({width = 1000})
    local left, right = c.reader.firstPage.body, c.reader.secondPage.body
    left.font, left.fontSize, left.fontHeight, left.fontStyle = "PlayerFonts/Left.slug", 22, 22, "outline"
    right.font, right.fontSize, right.fontHeight, right.fontStyle = "PlayerFonts/Right.slug", 28, 28, ""
    c.reader:Show(c.title, book())
    for _, page in ipairs({c.reader.firstPage, c.reader.secondPage}) do
        assert(c:markedTexts(page):find("Description of target 1.", 1, true), "each page must use its actual font metrics")
    end
    local probe
    for _, item in ipairs(c.controls) do
        if item.kind == CT_LABEL and item.hidden then probe = item end
    end
    assert(probe and probe:GetFont() == "PlayerFonts/Right.slug", "the measurement font must follow the player selection")
    assert(probe:GetFontSize() == 28 and probe:GetFontStyle() == "", "size and empty style must be preserved")
end)

test("a small single-page reader still reaches the last target", function()
    local c = setup({height = 90, pages = 1, complete = {[15] = true}})
    c.reader:Show(c.title, book())
    assert(c:markedTexts():find("target 15.", 1, true))
    assert(#c:strokes(c.reader.secondPage) == 0)
    c.reader:ChangePageGrouping(c.reader.maxPageGroupings)
    assert(c.reader.pageGrouping == c.reader.maxPageGroupings and c.reader.firstPage.scroll > 0)
end)

test("opening and reflowing reuse the existing stroke controls", function()
    local c = setup()
    c.reader:Show(c.title, book())
    local count = #c.controls
    c.reader:LayoutText()
    c.reader:Show("Another book", "Text.")
    c.reader:Show(c.title, book())
    assert(#c.controls == count, "reopening must not grow the control pool")
end)

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
