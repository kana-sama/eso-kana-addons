-- Pure geometry, shared by live HUD and editor. Coordinates are GuiRoot UI units.
local Layout = {}
KanaEffects.Layout = Layout
local CONTENT_GAP = 4
local function copy(value)
    local result = {}; for key, item in pairs(value) do result[key] = item end; return result
end

-- fontMetrics:MeasureText(text, fontSize, role) returns measured width,height in
-- UI units. Native adapter caches descriptor/role/scale; never infer font pixels.
-- The formatter emits tenths under 3s, integer seconds under 60s, integer m/h,
-- and caps durations beyond 999h at the honest string 999h+.
function Layout.Measure(style, fontMetrics)
    local timerWidth, timerHeight = 0, 0
    local function timer(text)
        local width, height = fontMetrics:MeasureText(text, style.timerFontSize, 'timer')
        timerWidth = math.max(timerWidth, width); timerHeight = math.max(timerHeight, height)
    end
    for _, text in ipairs({'∞', '?', '—', '9.9', '999h+'}) do timer(text) end
    for value = 0, 29 do timer(string.format('%d.%d', math.floor(value / 10), value % 10)) end
    for value = 0, 59 do timer(tostring(value)) end
    -- 60m is reserved too, so a formatter rounding upward at the hour boundary
    -- cannot clip. Exhaustive measured candidates also handle non-tabular digits.
    for value = 1, 60 do timer(tostring(value) .. 'm') end
    for value = 1, 999 do timer(tostring(value) .. 'h') end
    local icon = style.iconSize
    local _,snapshotHeight = fontMetrics:MeasureText('Снимок', style.nameFontSize, 'name')
    local nameWidth, nameHeight, width, height, rightInset = 0, 0, nil, nil, 0
    if style.mode == 'over' then
        -- Overlay text can extend beyond the icon; it never resizes its panel.
        width, height = icon, icon
    elseif style.mode == 'under' then
        width, height = math.max(icon,timerWidth), icon + CONTENT_GAP + timerHeight
    elseif style.mode == 'right' or style.mode == 'list' then
        rightInset = CONTENT_GAP
        width, height = icon + CONTENT_GAP + timerWidth + rightInset, math.max(icon, timerHeight)
        if style.mode == 'list' then
            local minimumName
            minimumName, nameHeight = fontMetrics:MeasureText('…', style.nameFontSize, 'name')
            width = math.max(style.rowWidth, width + CONTENT_GAP + minimumName)
            nameWidth = width - icon - 2 * CONTENT_GAP - timerWidth - rightInset
            height = math.max(height, nameHeight)
        end
    else error('unsupported style: ' .. tostring(style.mode), 2) end
    return {cellWidth=width, cellHeight=height, iconWidth=icon,
        timerColumnWidth=timerWidth, timerLineHeight=timerHeight,
        contentGap=CONTENT_GAP, rightInset=rightInset, nameColumnWidth=nameWidth, nameLineHeight=nameHeight, snapshotLineHeight=math.max(1,snapshotHeight)}
end

-- Absolute GuiRoot icon rectangle, shared by renderer and gesture hit zones.
-- Inputs are immutable; timer/list cell height can exceed the square icon.
function Layout.IconRect(style, cellRect, measurement)
    local icon=measurement.iconWidth
    local x,y=cellRect.x,cellRect.y+(cellRect.height-icon)/2
    if style.mode=='over' then x=cellRect.x+(cellRect.width-icon)/2
    elseif style.mode=='under' then x,y=cellRect.x+(cellRect.width-icon)/2,cellRect.y end
    return {x=x,y=y,width=icon,height=icon}
end

local function extent(count, size, gap)
    if count == 0 then return 0 end
    return count * size + (count - 1) * gap
end
local function origin(anchor, width, height, reference)
    return reference.x + anchor.relativePointX * reference.width + anchor.x - anchor.pointX * width,
        reference.y + anchor.relativePointY * reference.height + anchor.y - anchor.pointY * height
end
local function intersects(rect, viewport)
    return viewport.width > 0 and viewport.height > 0
        and rect.x < viewport.x + viewport.width and rect.x + rect.width > viewport.x
        and rect.y < viewport.y + viewport.height and rect.y + rect.height > viewport.y
end
-- Exact intersecting cell range: edge contact and inter-cell gaps are excluded.
local function visibleRange(start, size, gap, count, viewStart, viewSize)
    if count == 0 or viewSize <= 0 then return 1, 0 end
    local step = size + gap
    return math.max(1, math.floor((viewStart - start - size) / step) + 2),
        math.min(count, math.ceil((viewStart + viewSize - start) / step))
end
local function reverseRange(first, last, count, reverse)
    if reverse then return count - last + 1, count - first + 1 end
    return first, last
end
function Layout.GridAlignment(widget)
    if widget.layout.align~=nil then return widget.layout.align end
    -- A missing optional field reproduces the old partial-line placement.
    local point=widget.layout.fixedAxis=='rows' and widget.anchor.pointY or widget.anchor.pointX
    return point==1 and 'end' or 'start'
end
function Layout.Place(widget, entries, referenceRect, viewportRect, measurement)
    local config, anchor = widget.layout, widget.anchor
    local count, rows, columns = #entries
    if widget.type == 'table' then
        rows, columns = config.rows, config.columns; count = rows * columns
    elseif count == 0 then rows, columns = 0, 0
    elseif config.fixedAxis == 'rows' then
        rows = config.count; columns = math.ceil(count / rows)
    else columns = config.count; rows = math.ceil(count / columns) end
    local width = extent(columns, measurement.cellWidth, config.gap)
    local height = extent(rows, measurement.cellHeight, config.gap)
    local x, y = origin(anchor, width, height, referenceRect)
    local rect = {x=x, y=y, width=width, height=height}
    local result = {rect=rect, viewport=copy(viewportRect), measurement=measurement, placements={}, logicalCount=count,
        overflow={left=x<viewportRect.x, right=x+width>viewportRect.x+viewportRect.width,
            top=y<viewportRect.y, bottom=y+height>viewportRect.y+viewportRect.height}}
    local function add(entry, row, column, offsetX, offsetY)
        local cell = {x=x+(column-1)*(measurement.cellWidth+config.gap)+(offsetX or 0),
            y=y+(row-1)*(measurement.cellHeight+config.gap)+(offsetY or 0), width=measurement.cellWidth, height=measurement.cellHeight}
        if intersects(cell, viewportRect) then
            result.placements[#result.placements+1] = {key=entry and entry.key or widget.id..':empty-slot:'..row..':'..column,
                rect=cell, row=row, column=column,
                visible=entry ~= nil and (entry.active == true or config.absent == 'ghost')}
        end
    end
    if widget.type == 'table' then
        -- Index only supplied entries; never expand the logical table. Emit
        -- intersecting empty slots for editor hit testing without inventing Entry
        -- records or active content. Tables never mirror their assignments.
        local occupied = {}
        for _, entry in ipairs(entries) do
            if entry.row and entry.column and entry.row >= 1 and entry.row <= rows
                and entry.column >= 1 and entry.column <= columns then
                occupied[entry.row] = occupied[entry.row] or {}
                occupied[entry.row][entry.column] = entry
            end
        end
        local c1,c2 = visibleRange(x,measurement.cellWidth,config.gap,columns,viewportRect.x,viewportRect.width)
        local r1,r2 = visibleRange(y,measurement.cellHeight,config.gap,rows,viewportRect.y,viewportRect.height)
        for row=r1,r2 do for column=c1,c2 do
            add(occupied[row] and occupied[row][column], row, column)
        end end
    elseif count > 0 then
        local reverseX,reverseY = anchor.pointX == 1,anchor.pointY == 1
        local alignment=Layout.GridAlignment(widget); local fraction=alignment=='center' and 0.5 or alignment=='end' and 1 or 0
        -- Placement addresses stay integer: whole alignment slots belong to
        -- row/column, while a remaining half-slot center shift belongs only
        -- to rect. Legacy and start/end addresses retain their old values.
        -- Bound the outer line range first, then clip each occupied line using
        -- its aligned origin. Even a billion-cell capacity visits only viewport
        -- intersections, with results still emitted in original Entry order.
        if config.fixedAxis == 'rows' then
            local c1,c2=visibleRange(x,measurement.cellWidth,config.gap,columns,viewportRect.x,viewportRect.width)
            c1,c2=reverseRange(c1,c2,columns,reverseX)
            for column=c1,c2 do
                local length=math.min(rows,count-(column-1)*rows); local offset=(rows-length)*fraction
                local slots=math.floor(offset); local pixels=(offset-slots)*(measurement.cellHeight+config.gap)
                local r1,r2=visibleRange(y+offset*(measurement.cellHeight+config.gap),measurement.cellHeight,config.gap,length,viewportRect.y,viewportRect.height)
                r1,r2=reverseRange(r1,r2,length,reverseY)
                for row=r1,r2 do add(entries[(column-1)*rows+row],(reverseY and length-row+1 or row)+slots,reverseX and columns-column+1 or column,0,pixels) end
            end
        else
            local r1,r2=visibleRange(y,measurement.cellHeight,config.gap,rows,viewportRect.y,viewportRect.height)
            r1,r2=reverseRange(r1,r2,rows,reverseY)
            for row=r1,r2 do
                local length=math.min(columns,count-(row-1)*columns); local offset=(columns-length)*fraction
                local slots=math.floor(offset); local pixels=(offset-slots)*(measurement.cellWidth+config.gap)
                local c1,c2=visibleRange(x+offset*(measurement.cellWidth+config.gap),measurement.cellWidth,config.gap,length,viewportRect.x,viewportRect.width)
                c1,c2=reverseRange(c1,c2,length,reverseX)
                for column=c1,c2 do add(entries[(row-1)*columns+column],reverseY and rows-row+1 or row,(reverseX and length-column+1 or column)+slots,pixels,0) end
            end
        end
    end
    return result
end
function Layout.Reanchor(anchor, oldRect, newPointX, newPointY, referenceRect)
    local result = copy(anchor)
    result.pointX, result.pointY = newPointX, newPointY
    result.x = oldRect.x + newPointX * oldRect.width - referenceRect.x - anchor.relativePointX * referenceRect.width
    result.y = oldRect.y + newPointY * oldRect.height - referenceRect.y - anchor.relativePointY * referenceRect.height
    return result
end
function Layout.Center(anchor, rect, referenceRect, axis)
    local result = copy(anchor)
    if axis == 'horizontal' then
        result.x = referenceRect.width/2 - anchor.relativePointX*referenceRect.width + (anchor.pointX-0.5)*rect.width
    elseif axis == 'vertical' then
        result.y = referenceRect.height/2 - anchor.relativePointY*referenceRect.height + (anchor.pointY-0.5)*rect.height
    else error('unsupported center axis: ' .. tostring(axis), 2) end
    return result
end

-- Changing the reference or its point preserves the current Runtime rectangle.
function Layout.Rereference(anchor, oldRect, referenceId, relativeX, relativeY, referenceRect)
    local result=copy(anchor)
    result.relativeTo=referenceId; result.relativePointX=relativeX; result.relativePointY=relativeY
    return Layout.Reanchor(result,oldRect,result.pointX,result.pointY,referenceRect)
end
