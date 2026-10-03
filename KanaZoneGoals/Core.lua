KanaZoneGoals = KanaZoneGoals or {}
local K = KanaZoneGoals
K.name = 'KanaZoneGoals'
K.version = '1.0.0'
K.categories = {
    {id='sets', name='Сеты местности'},
    {id='fishing', name='Рыбалка'},
    {id='meetings', name='Встречи и персонажи'},
    {id='museums', name='Музейные коллекции'},
    {id='collectibles', name='Коллекционные награды'},
    {id='antiquities', name='Древности'},
    {id='dynamic', name='Динамические события'},
    {id='special', name='Особые достижения местности'},
    {id='dungeons', name='Публичные подземелья'},
    {id='quests', name='Побочные задания'},
    {id='dailies', name='Достижения ежедневных заданий'},
    {id='styles', name='Мотивы и стили'},
    {id='global', name='Местные части общих достижений'},
}
K.categoryById = {}
for _, category in ipairs(K.categories) do K.categoryById[category.id] = category end

function K.SumCriteria(criteria, selected)
    local current, total, found = 0, 0, {}
    for _, criterion in ipairs(criteria) do
        if not selected or selected[criterion.index] then
            if type(criterion.current) ~= 'number' or type(criterion.total) ~= 'number' or criterion.total <= 0 then
                return nil, nil
            end
            current = current + math.min(math.max(criterion.current, 0), criterion.total)
            total = total + criterion.total
            found[criterion.index] = true
        end
    end
    if selected then
        for index in pairs(selected) do if not found[index] then return nil, nil end end
    end
    if total == 0 then return nil, nil end
    return current, total
end

function K.GroupGoals(goals, enabled)
    local groups, byCategory, seen = {}, {}, {}
    local completed, count = 0, 0
    for _, category in ipairs(K.categories) do
        if enabled[category.id] ~= false then
            byCategory[category.id] = {id=category.id, name=category.name, goals={}, completed=0, total=0,unavailableCount=0}
        end
    end
    for _, goal in ipairs(goals) do
        local group = byCategory[goal.category]
        if group and not seen[goal.key] then
            seen[goal.key] = true
            goal.complete = not goal.unavailable and type(goal.current)=='number' and type(goal.total)=='number' and goal.total>0 and goal.current>=goal.total or false
            group.goals[#group.goals+1] = goal
            if goal.unavailable then
                group.unavailableCount=group.unavailableCount+1
            else
                group.total = group.total + 1
                count = count + 1
                if goal.complete then group.completed=group.completed+1; completed=completed+1 end
            end
        end
    end
    for _, category in ipairs(K.categories) do
        local group = byCategory[category.id]
        if group and #group.goals>0 then
            table.sort(group.goals, function(a,b)
                if a.complete~=b.complete then return not a.complete end
                if a.name==b.name then return a.key<b.key end
                return a.name<b.name
            end)
            groups[#groups+1] = group
        end
    end
    return groups, completed, count
end

-- ESO strings include grammatical suffixes (for example ^M); never display those raw.
function K.CleanName(name)
    local text=name or ''
    if zo_strformat then text=zo_strformat('<<1>>',text) end
    return text:gsub('%^[%a]+','')
end

function K.ItemLink(id)
    return string.format('|H1:item:%d:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h',id)
end

function K.TextQuality(text)
    local link=(text or ''):match('(|H[^|]*:item:[^|]+|h.-|h)')
    if link then return GetItemLinkQuality(link) end
end
