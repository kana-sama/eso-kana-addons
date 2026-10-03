KanaInfoBar = KanaInfoBar or {}
local M = {}
KanaInfoBar.Model = M

M.anchors = {
    TOPLEFT={x=0,y=0}, TOP={x=.5,y=0}, TOPRIGHT={x=1,y=0},
    LEFT={x=0,y=.5}, RIGHT={x=1,y=.5},
    BOTTOMLEFT={x=0,y=1}, BOTTOM={x=.5,y=1}, BOTTOMRIGHT={x=1,y=1},
}
M.anchorOrder = {'TOPLEFT','TOP','TOPRIGHT','LEFT','RIGHT','BOTTOMLEFT','BOTTOM','BOTTOMRIGHT'}
M.anchorNames = {'Верхний левый','Середина верхней стороны','Верхний правый',
    'Середина левой стороны','Середина правой стороны','Нижний левый',
    'Середина нижней стороны','Нижний правый'}

function M.Copy(value)
    if type(value) ~= 'table' then return value end
    local copy = {}
    for k,v in pairs(value) do copy[k] = M.Copy(v) end
    return copy
end

function M.PingColor(ping)
    if ping > 200 then return 'red' end
    if ping > 150 then return 'orange' end
    return 'normal'
end

function M.BagColor(used, capacity)
    if capacity <= 0 then return 'normal' end
    if used * 100 >= capacity * 95 then return 'red' end
    if used * 100 >= capacity * 80 then return 'orange' end
    return 'normal'
end

function M.GearColor(minimum)
    if minimum==nil then return 'normal' end
    if minimum<=0 then return 'red' end
    if minimum<=20 then return 'orange' end
    return 'normal'
end

function M.GearStatus(items)
    local minimum,total,cost=100,0,0
    local count=#items
    if count==0 then return nil,nil,0,0 end
    for _,item in ipairs(items) do
        minimum=math.min(minimum,item.condition)
        total=total+item.condition
        cost=cost+item.cost
    end
    return minimum,math.floor(total/count+.5),cost,count
end

function M.TotalTreasure(items, treasureType)
    local count, value = 0, 0
    for _, item in ipairs(items) do
        if item.stolen and item.kind == treasureType then
            count = count + item.count
            value = value + item.count * item.price
        end
    end
    return count, value
end

function M.BestTreasureSale(items, remaining, treasureType)
    local candidates={}
    for _,item in ipairs(items) do
        if item.stolen and item.kind==treasureType and item.count>0 then
            candidates[#candidates+1]=item
        end
    end
    table.sort(candidates,function(a,b) return a.price>b.price end)
    local value,count=0,0
    remaining=math.max(0,remaining or 0)
    for _,item in ipairs(candidates) do
        if remaining==0 then break end
        local selected=math.min(item.count,remaining)
        value=value+selected*item.price
        count=count+selected
        remaining=remaining-selected
    end
    return value,count
end

function M.ReserveWidth(state, measured, minimum, now)
    local target = math.ceil((math.max(measured, minimum) + 8) / 16) * 16
    if not state.width or measured > state.width then
        state.width, state.since, state.target = target, nil, nil
    elseif target <= state.width - 32 then
        if state.target ~= target then state.target, state.since = target, now end
        if now - state.since >= 30 then
            state.width, state.since, state.target = target, nil, nil
        end
    else
        state.since, state.target = nil, nil
    end
    return state.width
end

function M.AnchorPosition(left, top, width, height, anchor)
    local a = M.anchors[anchor] or M.anchors.BOTTOMRIGHT
    return left + width * a.x, top + height * a.y
end

function M.Layout(rows, enabled, widths, visible, gap, rowGap, anchor, gridMode)
    local result = {width=0,height=0,slots={},rows={}}
    local maxColumns=0
    for index, row in ipairs(rows) do
        local ids, width = {}, 0
        for _, id in ipairs(row) do
            if enabled[id] and visible[id] then
                if #ids > 0 then width = width + gap end
                ids[#ids+1] = id
                width = width + widths[id]
            end
        end
        if #ids > 0 then
            result.rows[#result.rows+1] = {index=index,ids=ids,width=width}
            result.width = math.max(result.width,width)
            maxColumns=math.max(maxColumns,#ids)
        end
    end
    local a = M.anchors[anchor] or M.anchors.BOTTOMRIGHT
    if gridMode and maxColumns>0 then
        local columns,starts={},{}
        for _,row in ipairs(result.rows) do
            -- Whole-column offsets keep every visible widget on the same grid.
            row.firstColumn=1+math.floor((maxColumns-#row.ids)*a.x)
            for index,id in ipairs(row.ids) do
                local column=row.firstColumn+index-1
                columns[column]=math.max(columns[column] or 0,widths[id])
            end
        end
        local x=0
        for column=1,maxColumns do
            starts[column]=x
            x=x+columns[column]+(column<maxColumns and gap or 0)
        end
        result.width=x
        result.columns=columns
        for n,row in ipairs(result.rows) do
            local lastColumn=row.firstColumn+#row.ids-1
            row.x, row.y=starts[row.firstColumn],(n-1)*(32+rowGap)
            row.width=starts[lastColumn]+columns[lastColumn]-row.x
            for index,id in ipairs(row.ids) do
                local column=row.firstColumn+index-1
                result.slots[id]={x=starts[column],y=row.y,width=columns[column],row=row.index}
            end
        end
    else
        for n, row in ipairs(result.rows) do
            row.x, row.y = (result.width-row.width)*a.x, (n-1)*(32+rowGap)
            local x = row.x
            for _, id in ipairs(row.ids) do
                result.slots[id] = {x=x,y=row.y,width=widths[id],row=row.index}
                x = x + widths[id] + gap
            end
        end
    end
    if #result.rows > 0 then result.height = #result.rows*32 + (#result.rows-1)*rowGap end
    return result
end

function M.Normalize(config, ids)
    local known, seen, rows = {}, {}, {}
    for _, id in ipairs(ids) do known[id] = true end
    config.enabled = type(config.enabled)=='table' and config.enabled or {}
    for _, row in ipairs(type(config.rows)=='table' and config.rows or {}) do
        local clean = {}
        for _, id in ipairs(type(row)=='table' and row or {}) do
            if known[id] and not seen[id] then
                clean[#clean+1],seen[id] = id,true
            end
        end
        if #clean>0 then rows[#rows+1]=clean end
    end
    if #rows==0 then rows[1]={} end
    for _, id in ipairs(ids) do
        if not seen[id] then table.insert(rows[#rows],id) end
        if config.enabled[id]==nil then config.enabled[id]=true end
    end
    config.rows=rows
    if not M.anchors[config.anchor] then config.anchor='BOTTOMRIGHT' end
end

-- Target row/index refers to the original layout, before removing the source.
function M.Move(config, id, rowIndex, index, newRow)
    local sourceRow, sourceIndex
    for _, row in ipairs(config.rows) do
        for i, value in ipairs(row) do
            if value==id then sourceRow,sourceIndex=row,i end
        end
    end
    if not sourceRow then return false end
    local target = config.rows[rowIndex]
    if not newRow and not target then return false end
    if newRow then
        target={}
        table.insert(config.rows,math.min(#config.rows+1,math.max(1,rowIndex)),target)
    end
    if target==sourceRow and sourceIndex<index then index=index-1 end
    table.remove(sourceRow,sourceIndex)
    table.insert(target,math.min(#target+1,math.max(1,index)),id)
    for i=#config.rows,1,-1 do
        if #config.rows[i]==0 then table.remove(config.rows,i) end
    end
    config.enabled[id]=true
    return true
end
