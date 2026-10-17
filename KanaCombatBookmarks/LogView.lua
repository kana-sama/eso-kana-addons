local addon = KanaCombatBookmarks
local View = {}
addon.LogView = View
local PAGE_SIZE = 1000

-- Match Combat Metrics' log filters, including its combined self-event categories.
local function predicate(selection, filters)
    local units, abilities = selection.unit or {}, selection.ability or {}
    local buffs, resources = (selection.buff or {}).buff, (selection.resource or {}).resource
    local allUnits, hasUnits = {}, false
    for _, category in ipairs({'healingIn', 'healingOut', 'damageIn', 'damageOut'}) do
        for id, enabled in pairs(units[category] or {}) do allUnits[id] = enabled; hasUnits = true end
    end
    local categories = {
        [LIBCOMBAT_EVENT_DAMAGE_IN] = 'damageIn', [LIBCOMBAT_EVENT_DAMAGE_OUT] = 'damageOut',
        [LIBCOMBAT_EVENT_HEAL_IN] = 'healingIn', [LIBCOMBAT_EVENT_HEAL_OUT] = 'healingOut',
    }
    return function(line)
        local kind = line[1]
        local enabled = filters[kind]
            or (kind == LIBCOMBAT_EVENT_DAMAGE_SELF and (filters[LIBCOMBAT_EVENT_DAMAGE_IN] or filters[LIBCOMBAT_EVENT_DAMAGE_OUT]))
            or (kind == LIBCOMBAT_EVENT_HEAL_SELF and (filters[LIBCOMBAT_EVENT_HEAL_IN] or filters[LIBCOMBAT_EVENT_HEAL_OUT]))
            or ((kind == LIBCOMBAT_EVENT_BOSSHP or kind == LIBCOMBAT_EVENT_DEATH) and filters[LIBCOMBAT_EVENT_MESSAGES])
        if enabled ~= true then return false end
        local category = categories[kind]
        if category then
            local outgoing = kind == LIBCOMBAT_EVENT_DAMAGE_OUT or kind == LIBCOMBAT_EVENT_HEAL_OUT
            local unitId = outgoing and line[5] or line[4]
            return (units[category] == nil or units[category][unitId] ~= nil)
                and (abilities[category] == nil or abilities[category][line[6]] ~= nil)
        elseif kind == LIBCOMBAT_EVENT_HEAL_SELF then
            return ((units.healingIn == nil and filters[LIBCOMBAT_EVENT_HEAL_IN])
                or (units.healingIn ~= nil and units.healingIn[line[4]] ~= nil)
                or (units.healingOut == nil and filters[LIBCOMBAT_EVENT_HEAL_OUT])
                or (units.healingOut ~= nil and units.healingOut[line[5]] ~= nil))
                and ((abilities.healingIn == nil and filters[LIBCOMBAT_EVENT_HEAL_IN])
                or (abilities.healingIn ~= nil and abilities.healingIn[line[6]] ~= nil)
                or (abilities.healingOut == nil and filters[LIBCOMBAT_EVENT_HEAL_OUT])
                or (abilities.healingOut ~= nil and abilities.healingOut[line[6]] ~= nil))
        elseif kind == LIBCOMBAT_EVENT_EFFECTS_IN or kind == LIBCOMBAT_EVENT_EFFECTS_OUT
            or kind == LIBCOMBAT_EVENT_GROUPEFFECTS_IN or kind == LIBCOMBAT_EVENT_GROUPEFFECTS_OUT then
            local name = LibCombat.GetFormattedAbilityName(line[4])
            return (buffs == nil or buffs[name] ~= nil) and (not hasUnits or allUnits[line[3]] ~= nil)
        elseif kind == LIBCOMBAT_EVENT_RESOURCES then
            return line[5] ~= POWERTYPE_HEALTH and (resources == nil or resources[line[3] or 0] ~= nil)
        end
        return kind == LIBCOMBAT_EVENT_PLAYERSTATS or kind == LIBCOMBAT_EVENT_MESSAGES
            or kind == LIBCOMBAT_EVENT_SKILL_TIMINGS or kind == LIBCOMBAT_EVENT_BOSSHP
            or kind == LIBCOMBAT_EVENT_DEATH or kind == LIBCOMBAT_EVENT_PERFORMANCE
    end
end

function View.BuildRows(fight, selections, filters)
    local accept = predicate(selections or {}, filters or {})
    local rows, marks = {}, {}
    for _, entry in ipairs(addon.Model.Entries(fight)) do marks[#marks + 1] = entry end
    table.sort(marks, function(a, b)
        if a.offsetMs == b.offsetMs then return a.id < b.id end
        return a.offsetMs < b.offsetMs
    end)
    local nextMark = 1
    local function emitBefore(time)
        while marks[nextMark] and fight.combatstart + marks[nextMark].offsetMs < time do
            rows[#rows + 1] = {bookmark = marks[nextMark]}
            nextMark = nextMark + 1
        end
    end
    for _, line in ipairs(fight.log or {}) do
        emitBefore(line[2])
        if accept(line) then rows[#rows + 1] = {event = line} end
    end
    emitBefore(math.huge)
    return rows
end

function View.Window(count, target, page)
    local first = target and math.max(1, math.min(target - math.floor(PAGE_SIZE / 2), count - PAGE_SIZE + 1))
        or ((page or 1) - 1) * PAGE_SIZE + 1
    return first, math.min(count, first + PAGE_SIZE - 1)
end

-- Positions use explicit line-height slots, including measured wrapped events.
function View.CenterScroll(total, visible, before, after)
    return math.max(0, math.min(total - visible, total - (before + after + visible) / 2))
end

function View.BookmarkText(entry)
    -- Copying retains the exact time; on-screen labels show only the name.
    return '── ' .. entry.name .. ' · ' .. addon.Model.Time(entry.offsetMs) .. ' ──'
end

function View.BookmarkProgress(entry, fight)
    local duration = (fight.combatend or 0) - (fight.combatstart or 0)
    if duration <= 0 then duration = (fight.combattime or 0) * 1000 end
    if duration <= 0 then return 0 end
    return math.max(0, math.min(1, entry.offsetMs / duration))
end

function View.PlainText(text)
    return (text:gsub('|c%x%x%x%x%x%x', ''):gsub('|r', ''):gsub('|t.-|t', ''))
end

function View.New(api, adapter)
    return setmetatable({api = api, adapter = adapter, page = 1, buttons = {}, markerControls = {}, eventControls = {}}, {__index = View})
end

local function anchors(control)
    local result = {}
    for i = 0, 1 do
        local valid, point, relative, to, x, y = control:GetAnchor(i)
        if valid then result[#result + 1] = {point, relative, to, x, y} end
    end
    return result
end

local function paintButton(button, selected)
    local bright = selected or button.hovered
    -- Match CMX's flat buff rows: a translucent bar and a white selection wash.
    button.background:SetCenterColor(1, 1, 1, bright and 0.2 or 0)
    button.background:SetEdgeColor(0, 0, 0, 0)
    button.fill:SetColor(0.75, 0.5, 0, button.pressed and 0.4 or 0.6)
end

local function singleLineLabel(a, parent)
    local label = a.WINDOW_MANAGER:CreateControl(nil, parent, a.CT_LABEL)
    label:SetMouseEnabled(false)
    label:SetMaxLineCount(1)
    label:SetWrapMode(a.TEXT_WRAP_MODE_ELLIPSIS)
    label:SetHorizontalAlignment(a.TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(a.TEXT_ALIGN_CENTER)
    label:SetColor(1, 1, 1, 1)
    return label
end

function View:CreateBookmarkButton()
    local a, wm = self.api, self.api.WINDOW_MANAGER
    local button = wm:CreateControl(nil, self.child, a.CT_BUTTON)
    button:SetMouseEnabled(true)
    button.background = wm:CreateControl(nil, button, a.CT_BACKDROP)
    button.background:SetAnchorFill(button)
    button.background:SetMouseEnabled(false)
    button.background:SetDrawLayer(a.DL_OVERLAY)
    button.fill = wm:CreateControl(nil, button, a.CT_TEXTURE)
    button.fill:SetAnchor(a.TOPLEFT, button, a.TOPLEFT, 0, 0)
    button.fill:SetMouseEnabled(false)
    button.fill:SetDrawLayer(a.DL_CONTROLS)
    button.label = singleLineLabel(a, button)
    button.label:SetHorizontalAlignment(a.TEXT_ALIGN_LEFT)
    button:SetHandler('OnClicked', function(control) self:JumpTo(control.bookmarkId) end)
    button:SetHandler('OnMouseEnter', function(control)
        control.hovered = true; paintButton(control, control.bookmarkId == self.jumpId)
    end)
    button:SetHandler('OnMouseExit', function(control)
        control.hovered, control.pressed = false, false; paintButton(control, control.bookmarkId == self.jumpId)
    end)
    button:SetHandler('OnMouseDown', function(control)
        control.pressed = true; paintButton(control, control.bookmarkId == self.jumpId)
    end)
    button:SetHandler('OnMouseUp', function(control)
        control.pressed = false; paintButton(control, control.bookmarkId == self.jumpId)
    end)
    button:SetHandler('OnMouseWheel', function(_, delta) a.ZO_Scroll_OnMouseWheel(self.scroll, delta) end)
    return button
end

function View:Layout(enabled)
    local a = self.api
    local scale = a.CMX.db.FightReport.scale or 1
    local entries = addon.Model.Entries(self.fight)
    local rowHeight, gap = 20 * scale, scale
    local rowFont = self.font .. 'soft-shadow-thin'
    self.title:SetFont(rowFont)
    self.title:SetText('Закладки')
    -- GetStringWidth returns native pixels; control dimensions need UI units.
    -- Keep this label unconstrained, separate from the wrapped log measurer.
    self.nameMeasure:SetFont(rowFont)
    self.nameMeasure:SetText('Закладки')
    local contentWidth = self.nameMeasure:GetTextWidth()
    for _, entry in ipairs(entries) do
        self.nameMeasure:SetText(entry.name)
        contentWidth = math.max(contentWidth, self.nameMeasure:GetTextWidth())
    end
    contentWidth = math.ceil(contentWidth + 4 * scale)
    local contentHeight = math.max(0, #entries * (rowHeight + gap) - gap)
    local scrollHeight = math.max(1, self.window:GetHeight() - rowHeight - gap)
    local gutter = contentHeight > scrollHeight and (a.ZO_SCROLL_BAR_WIDTH or 16) or 0
    local width = contentWidth + gutter
    local panelWidth, panelHeight = self.panel:GetWidth(), self.panel:GetHeight()
    local changed = self.layoutEnabled ~= enabled or self.layoutWidth ~= panelWidth
        or self.layoutHeight ~= panelHeight or self.layoutScale ~= scale or self.sidebarWidth ~= width
    if changed then
        for control, saved in pairs(self.originalAnchors) do
            control:ClearAnchors()
            for _, anchor in ipairs(saved) do
                local x, y = anchor[4] * scale / self.initialScale, anchor[5] * scale / self.initialScale
                if enabled and anchor[1] == a.BOTTOMRIGHT then x = x - width end
                control:SetAnchor(anchor[1], anchor[2], anchor[3], x, y)
            end
        end
        self.layoutEnabled, self.layoutWidth, self.layoutHeight, self.layoutScale = enabled, panelWidth, panelHeight, scale
        self.sidebarWidth = width
        self.layoutPending = enabled
    end
    -- The buffer supplies native scrolling only. Its nonempty sentinel messages
    -- must not be painted over the separately measured event/marker controls.
    -- TextBuffer lines otherwise ignore SetAlpha. Restore CMX's default when
    -- returning to a fight without bookmarks.
    self.buffer:SetLinesInheritAlpha(enabled)
    self.buffer:SetAlpha(enabled and 0 or self.originalBufferAlpha)
    self.sidebar:SetHidden(not enabled)
    if not enabled then return end
    -- The native log window already reserves space after its scrollbar.
    self.sidebar:SetAnchor(a.TOPLEFT, self.window, a.TOPRIGHT, 0, 0)
    self.sidebar:SetDimensions(width, self.window:GetHeight())
    self.title:SetAnchor(a.TOPLEFT, self.sidebar, a.TOPLEFT, 2 * scale, 0)
    self.title:SetWidth(contentWidth - 4 * scale)
    self.scroll:SetAnchor(a.TOPLEFT, self.sidebar, a.TOPLEFT, 0, rowHeight + gap)
    self.scroll:SetDimensions(width, scrollHeight)
    local viewport = self.scroll:GetNamedChild('Scroll')
    viewport:ClearAnchors()
    viewport:SetAnchor(a.TOPLEFT, self.scroll, a.TOPLEFT)
    viewport:SetAnchor(a.BOTTOMRIGHT, self.scroll, a.BOTTOMRIGHT, -gutter, 0)
    local y = 0
    for i, entry in ipairs(entries) do
        local button = self.buttons[i]
        if not button then
            button = self:CreateBookmarkButton()
            self.buttons[i] = button
        end
        button.bookmarkId = entry.id
        button.label:SetFont(rowFont)
        button.label:SetText(entry.name)
        button.label:SetAnchor(a.TOPLEFT, button, a.TOPLEFT, 2 * scale, 0)
        button.label:SetAnchor(a.BOTTOMRIGHT, button, a.BOTTOMRIGHT, -2 * scale, 0)
        button:SetDimensions(contentWidth, rowHeight)
        button.progress = View.BookmarkProgress(entry, self.fight)
        button.fill:SetDimensions(contentWidth * button.progress, rowHeight)
        button.fill:SetHidden(button.progress == 0)
        paintButton(button, button.bookmarkId == self.jumpId)
        button:ClearAnchors()
        button:SetAnchor(a.TOPLEFT, self.child, a.TOPLEFT, 0, y)
        button:SetHidden(false)
        y = y + rowHeight + gap
    end
    for i = #entries + 1, #self.buttons do self.buttons[i]:SetHidden(true) end
    self.child:SetDimensions(contentWidth, contentHeight)
    a.ZO_Scroll_UpdateScrollBar(self.scroll)
end

function View:UpdateMarkers(force)
    if not self.active or not self.renderedMarkers then return end
    local a, b = self.api, self.buffer
    local total, position = b:GetNumHistoryLines(), b:GetScrollPosition()
    local width, height = b:GetWidth(), b:GetHeight()
    local lineHeight = self.slotHeight
    if not force and (self.renderWidth ~= width or self.renderHeight ~= height) then
        self:Render(self.jumpId and self.indices[self.jumpId])
        return
    end
    if not force and self.markerTotal == total and self.markerPosition == position
        and self.markerWidth == width and self.markerHeight == height and self.markerLineHeight == lineHeight then return end
    self.markerTotal, self.markerPosition = total, position
    self.markerWidth, self.markerHeight, self.markerLineHeight = width, height, lineHeight
    for i, marker in ipairs(self.renderedMarkers) do
        local band = self.markerControls[i]
        if not band then
            band = a.WINDOW_MANAGER:CreateControl(nil, self.markerLayer, a.CT_BACKDROP)
            band:SetMouseEnabled(false)
            band:SetDrawLayer(a.DL_OVERLAY)
            band:SetDrawLevel(1)
            band:SetCenterColor(0.58, 0.38, 0.065, 1)
            band:SetEdgeTexture('', 1, 1, 1)
            band:SetEdgeColor(1, 0.78, 0.28, 1)
            band.label = singleLineLabel(a, band)
            band.label:SetAnchorFill(band)
            band.label:SetDrawLayer(a.DL_OVERLAY)
            band.label:SetDrawLevel(2)
            self.markerControls[i] = band
        end
        -- Every buffer message is one invisible slot. Visible text is drawn in
        -- measured labels, so native wrapping cannot shift a band onto an event.
        local y = height - (total - position - marker.span.before) * lineHeight
        band:ClearAnchors()
        band:SetAnchor(a.TOPLEFT, self.markerLayer, a.TOPLEFT, 0, y)
        local bandHeight = (marker.span.after - marker.span.before) * lineHeight
        band:SetDimensions(width, bandHeight)
        band.label:SetFont(self.font)
        band.label:SetText(marker.entry.name)
        band:SetHidden(y >= height or y + bandHeight <= 0)
    end
    for i = #self.renderedMarkers + 1, #self.markerControls do self.markerControls[i]:SetHidden(true) end
    local used = 0
    for _, event in ipairs(self.renderedEvents) do
        local y = height - (total - position - event.span.before) * lineHeight
        local eventHeight = (event.span.after - event.span.before) * lineHeight
        if y < height and y + eventHeight > 0 then
            used = used + 1
            local label = self.eventControls[used]
            if not label then
                label = a.WINDOW_MANAGER:CreateControl(nil, self.markerLayer, a.CT_LABEL)
                label:SetMouseEnabled(false)
                self.eventControls[used] = label
            end
            label:ClearAnchors()
            label:SetAnchor(a.TOPLEFT, self.markerLayer, a.TOPLEFT, 0, y)
            label:SetDimensions(width, eventHeight)
            label:SetFont(self.font)
            label:SetColor(event.color[1], event.color[2], event.color[3], 1)
            label:SetText(event.span.text)
            label:SetHidden(false)
        end
    end
    for i = used + 1, #self.eventControls do self.eventControls[i]:SetHidden(true) end
end

function View:CopyVisible()
    local b = self.buffer
    local bottom = b:GetNumHistoryLines() - b:GetScrollPosition()
    local top, lines = bottom - self.visibleSlots, {}
    for _, span in ipairs(self.spans or {}) do
        if span.after > top and span.before < bottom then lines[#lines + 1] = View.PlainText(span.text) end
    end
    self.copy:SetFont(self.font)
    self.copy:SetText(table.concat(lines, '\n'))
    self.copy:SelectAll()
    self.copy:TakeFocus()
end

function View:Render(target, settled)
    local a, b = self.api, self.buffer
    self.renderGeneration = (self.renderGeneration or 0) + 1
    if self.layoutPending and not settled then
        local generation = self.renderGeneration
        a.zo_callLater(function()
            if self.renderGeneration ~= generation or not self.active or self.panel:IsHidden() then return end
            -- Anchor-derived dimensions resolve on the next frame in ESO.
            self:Layout(true)
            self.layoutPending = false
            self:Render(target, true)
            if a.CMX.db.FightReport.CLSelection.CopyPaste then self:CopyVisible() end
        end, 1)
    end
    local first, last = View.Window(#self.rows, target, self.page)
    self.spans, self.markerSpans, self.renderedMarkers, self.renderedEvents = {}, {}, {}, {}
    b:Clear()
    -- Leave room for wrapped events and blank context at both endpoints.
    b:SetMaxHistoryLines(16000)
    b:SetFont(self.font)
    self.renderWidth, self.renderHeight = b:GetWidth(), b:GetHeight()
    self.measure:SetWidth(self.renderWidth)
    -- Read capacity from geometry, never from a just-cleared TextBuffer.
    local visible = math.max(1, math.floor(self.renderHeight / self.measure:GetFontHeight()))
    self.visibleSlots = visible
    -- Sentinels supply CMX's native scroll positions, not the text layout.
    local lineHeight = math.max(1, self.renderHeight) / visible
    self.slotHeight = lineHeight
    local padding = math.ceil(visible / 2)
    -- Whitespace-only messages may be discarded, collapsing every row to zero
    -- height. A real glyph is retained; Layout hides only the native buffer.
    local function blanks(count) for _ = 1, count do b:AddMessage('.', 1, 1, 1) end end
    if first == 1 then blanks(padding) end
    for index = first, last do
        local row, text, color = self.rows[index]
        if row.bookmark then
            text = View.BookmarkText(row.bookmark)
            color = {1, 1, 1}
        else
            text, color = a.CMX.GetCombatLogString(self.fight, row.event, self.fontSize)
        end
        if text and color then
            local before = b:GetNumHistoryLines()
            self.measure:SetText(row.bookmark and ' ' or text)
            local textHeight = row.bookmark and self.measure:GetFontHeight() or self.measure:GetTextHeight()
            local lines = math.max(1, math.ceil(textHeight / lineHeight))
            blanks(lines)
            local span = {before = before, after = b:GetNumHistoryLines(), text = text}
            self.spans[#self.spans + 1] = span
            if row.bookmark then
                self.markerSpans[row.bookmark.id] = span
                self.renderedMarkers[#self.renderedMarkers + 1] = {span = span, entry = row.bookmark}
            else
                self.renderedEvents[#self.renderedEvents + 1] = {span = span, color = color}
            end
        end
    end
    if last == #self.rows then blanks(padding) end
    local total = b:GetNumHistoryLines()
    local span = target and self.markerSpans[self.rows[target].bookmark.id]
    local position = span and View.CenterScroll(total, visible, span.before, span.after)
        or math.max(0, total - visible)
    position = math.floor(position + 0.5) -- TextBuffer accepts integer line offsets.
    b:SetScrollPosition(position)
    self.slider:SetMinMax(math.min(visible, total), total)
    self.slider:SetValue(total - position)
    self.slider:SetHidden(total <= visible)
    if total > visible then self.slider:SetThumbTextureHeight(math.max(20, math.floor(visible / total * self.slider:GetHeight()))) end
    self.pages:Update(self.page, math.max(1, math.ceil(#self.rows / PAGE_SIZE)))
    self.markerLayer:SetHidden(false)
    self:UpdateMarkers(true)
    for _, button in ipairs(self.buttons) do paintButton(button, button.bookmarkId == self.jumpId) end
end

function View:Refresh()
    if self.panel:IsHidden() then return self.active end
    local fight = self.adapter:GetViewedFight()
    if not fight or #addon.Model.Entries(fight) == 0 then
        if self.active then self:Layout(false) end
        self.markerLayer:SetHidden(true)
        self.renderGeneration = (self.renderGeneration or 0) + 1
        self.active, self.fight, self.jumpId, self.page = false, nil, nil, 1
        return false
    end
    local changed = self.fight ~= fight
    if changed then self.page, self.jumpId = 1, nil end
    self.fight, self.active = fight, true
    local db = self.api.CMX.db.FightReport
    self.fontSize = tonumber(self.api.GetString(self.api.SI_COMBAT_METRICS_FONT_SIZE)) * db.scale
    self.font = string.format('%s|%s|', self.api.GetString(self.api.SI_COMBAT_METRICS_STD_FONT), self.fontSize)
    self.measure:SetFont(self.font)
    self:Layout(true)
    if changed then self.api.ZO_Scroll_ScrollAbsoluteInstantly(self.scroll, 0) end
    -- Entering native copy mode must use the current viewport, without recentering.
    if db.CLSelection.CopyPaste and not changed and self.spans then self:CopyVisible(); return true end
    self.rows = View.BuildRows(fight, self.adapter.selections, db.CLSelection)
    self.indices = {}
    for i, row in ipairs(self.rows) do if row.bookmark then self.indices[row.bookmark.id] = i end end
    self.page = math.min(self.page, math.max(1, math.ceil(#self.rows / PAGE_SIZE)))
    self:Render(self.jumpId and self.indices[self.jumpId])
    if db.CLSelection.CopyPaste then self:CopyVisible() end
    return true
end

function View:JumpTo(id)
    if not self.active or not self.indices[id] then return false end
    if not self.fight.log or #self.fight.log == 0 then
        self.api.ZO_AlertNoSuppression(self.api.UI_ALERT_CATEGORY_ALERT, nil, 'У этого боя нет подробного лога. Сохранены только закладки.')
        return false
    end
    if self.api.CMX.db.FightReport.CLSelection.CopyPaste then
        -- Use CMX's own toggle to keep its button overlay and visibility in sync.
        self.copyButton:GetHandler('OnMouseUp')(self.copyButton)
    end
    self.jumpId = id
    self.page = math.ceil(self.indices[id] / PAGE_SIZE)
    self:Render(self.indices[id])
    return true
end

function View:Install()
    if self.installed then return true end
    local a = self.api
    local report, panel = a.CombatMetrics_Report, a.CombatMetrics_Report_MainPanelCombatLog
    if not report or type(report.Update) ~= 'function' or not panel or type(panel.Update) ~= 'function' then return false end
    local window, copy = panel:GetNamedChild('Window'), panel:GetNamedChild('CopyPasteBox')
    local pages = panel:GetNamedChild('HeaderPageButtonRow')
    local copyButton = panel:GetNamedChild('HeaderFilterButtonRowCopyPaste')
    local buffer, slider = window and window:GetNamedChild('Buffer'), window and window:GetNamedChild('Slider')
    if not buffer or not slider or not copy or not pages or type(pages.Update) ~= 'function'
        or not copyButton or not copyButton:GetHandler('OnMouseUp') or type(a.CMX.GenerateSelectionStats) ~= 'function' then return false end
    for _, key in ipairs({'PageLeft','Page1','Page2','Page3','Page4','Page5','PageRight'}) do
        if not pages:GetNamedChild(key) then return false end
    end
    self.report, self.panel, self.window, self.copy = report, panel, window, copy
    self.buffer, self.slider, self.pages, self.copyButton = buffer, slider, pages, copyButton
    self.originalBufferAlpha = buffer:GetAlpha()
    self.initialScale = a.CMX.db.FightReport.scale or 1
    self.originalAnchors = {[window] = anchors(window), [copy] = anchors(copy)}
    local wm = a.WINDOW_MANAGER
    self.sidebar = wm:CreateControl('KanaCombatBookmarksSidebar', panel, a.CT_CONTROL)
    self.sidebar:SetHidden(true)
    self.title = wm:CreateControl(nil, self.sidebar, a.CT_LABEL)
    self.title:SetAnchor(a.TOPLEFT, self.sidebar, a.TOPLEFT)
    self.title:SetColor(1, 0.84, 0.31, 1)
    self.scroll = wm:CreateControlFromVirtual('KanaCombatBookmarksScroll', self.sidebar, 'ZO_ScrollContainer')
    self.child = self.scroll:GetNamedChild('Scroll'):GetNamedChild('Child')
    self.child:SetResizeToFitDescendents(false)
    self.child:SetMouseEnabled(true)
    self.child:SetHandler('OnMouseWheel', function(_, delta) a.ZO_Scroll_OnMouseWheel(self.scroll, delta) end)
    self.measure = wm:CreateControl(nil, self.sidebar, a.CT_LABEL)
    self.measure:SetHidden(true)
    self.nameMeasure = wm:CreateControl(nil, self.sidebar, a.CT_LABEL)
    self.nameMeasure:SetHidden(true)
    self.markerLayer = wm:CreateControl('KanaCombatBookmarksMarkerLayer', window, a.CT_SCROLL)
    self.markerLayer:SetAnchorFill(buffer)
    self.markerLayer:SetMouseEnabled(false)
    self.markerLayer:SetHidden(true)
    self.markerLayer:SetHandler('OnUpdate', function() self:UpdateMarkers() end)
    local nativeUpdate = panel.Update
    panel.Update = function(control, ...)
        if not self:Refresh() then return nativeUpdate(control, ...) end
    end
    local generate = a.CMX.GenerateSelectionStats
    a.CMX.GenerateSelectionStats = function(fight, category, selections, ...)
        if self.captureSelection then self.adapter.selections = selections; self.captureSelection = false end
        return generate(fight, category, selections, ...)
    end
    local updateReport = report.Update
    report.Update = function(control, ...)
        self.captureSelection = true
        local result = updateReport(control, ...)
        self.captureSelection = false
        return result
    end
    for _, key in ipairs({'PageLeft','Page1','Page2','Page3','Page4','Page5','PageRight'}) do
        local button = pages:GetNamedChild(key)
        local native = button:GetHandler('OnMouseUp')
        button:SetHandler('OnMouseUp', function(control, ...)
            if not self.active then if native then return native(control, ...) end; return end
            self.page = math.max(1, math.min(tonumber(control.value or (self.page + control.func)), math.max(1, math.ceil(#self.rows / PAGE_SIZE))))
            self.jumpId = nil
            self:Render()
            if a.CMX.db.FightReport.CLSelection.CopyPaste then self:CopyVisible() end
        end)
    end
    self.installed = true
    return true
end
