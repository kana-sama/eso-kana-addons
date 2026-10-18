local Layout = {}
KanaBuffPanels.Layout = Layout

local function CellBounds(m, timed)
    local cell = {left=-m.width/2, right=m.width/2, top=-m.height/2, bottom=m.height/2}
    if timed then
        local position = m.timerPosition or 1
        if position == 1 then
            cell.bottom = cell.bottom + m.labelHeight
        elseif position == 2 or position == 3 then
            local side = (m.labelWidth or m.width) + m.gap
            if position == 2 then cell.left = cell.left - side else cell.right = cell.right + side end
            cell.top = math.min(cell.top, -m.labelHeight/2)
            cell.bottom = math.max(cell.bottom, m.labelHeight/2)
        end
    end
    return cell
end

function Layout.Place(count, orientation, growth, m)
    local vertical = orientation == 2
    -- Empty editor outlines show the axis without placeholder icons or timers.
    local layoutCount = count == 0 and 3 or count
    local centers, previous, previousCell = {}, nil, nil
    local minX, minY, maxX, maxY
    for i = 1, layoutCount do
        local timed = i <= count and (m.hasDuration == nil or m.hasDuration[i])
        local cell = CellBounds(m, timed)
        local x, y = 0, 0
        if previous then
            if vertical then
                y = growth == 2 and (previous.y + previousCell.top - m.gap - cell.bottom)
                    or (previous.y + previousCell.bottom + m.gap - cell.top)
            else
                x = growth == 2 and (previous.x + previousCell.left - m.gap - cell.right)
                    or (previous.x + previousCell.right + m.gap - cell.left)
            end
        end
        local center = {x=x,y=y}
        if i <= count then centers[i] = center end
        local left, top, right, bottom = x+cell.left, y+cell.top, x+cell.right, y+cell.bottom
        minX = minX and math.min(minX, left) or left
        minY = minY and math.min(minY, top) or top
        maxX = maxX and math.max(maxX, right) or right
        maxY = maxY and math.max(maxY, bottom) or bottom
        previous, previousCell = center, cell
    end
    local width, height = maxX-minX, maxY-minY
    if growth == 3 then
        -- Timers can expand the outline, but never move the icon row or column sideways.
        local dx = vertical and 0 or -(minX+maxX)/2
        local dy = vertical and -(minY+maxY)/2 or 0
        for _, center in ipairs(centers) do center.x=center.x+dx;center.y=center.y+dy end
        minX, minY = minX+dx, minY+dy
    end
    return {centers=centers,bounds={x=minX,y=minY,width=width,height=height}}
end
