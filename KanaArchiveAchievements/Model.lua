KanaArchiveAchievements = KanaArchiveAchievements or {}
local M = {}
KanaArchiveAchievements.Model = M
M.CARD_WIDTH, M.GAP = 565, 12

function M.New(api, catalogue)
    local self = {api = api, catalogue = catalogue, names = {}, general = {}, byClass = {}, avatars = {}}
    for _, id in ipairs(catalogue.GENERAL or {}) do self.general[id] = true end
    for _, info in pairs(catalogue.ABILITIES) do
        local group = self.byClass[info.class] or {}
        self.byClass[info.class] = group
        for _, id in ipairs(info.ids) do
            if self.general[id] then group[id] = true end
        end
    end
    for _, avatar in pairs(catalogue.AVATAR or {}) do
        local abilities = {}
        for _, id in ipairs(avatar.abilityIds) do abilities[id] = true end
        self.avatars[avatar.id] = abilities
    end
    return setmetatable(self, {__index = M})
end

function M:Normalize(text)
    text = self.api.zo_strformat('<<1>>', text or '')
    text = text:gsub('|c%x%x%x%x%x%x', ''):gsub('|r', '')
    return self.api.zo_strlower(text:gsub('^%s+', ''):gsub('%s+$', ''))
end

function M:AbilityName(id)
    local exception = (self.catalogue.EXCEPTIONS or {})[id]
    return self:Normalize(exception and self.api.GetString(exception) or self.api.GetAbilityName(id))
end

function M:NamesForAchievement(id)
    if not self.names[id] then
        local names = {}
        for abilityId, info in pairs(self.catalogue.ABILITIES) do
            for _, goal in ipairs(info.ids) do
                if goal == id then
                    local name = self:AbilityName(abilityId)
                    if name ~= '' then names[abilityId] = name end
                    break
                end
            end
        end
        self.names[id] = names
    end
    return self.names[id]
end

function M:Criteria(id)
    local count = self.api.GetAchievementNumCriteria(id)
    if not count or count <= 0 then return end
    local criteria, complete = {}, true
    for i = 1, count do
        local text, current, required = self.api.GetAchievementCriterion(id, i)
        if type(text) ~= 'string' or type(current) ~= 'number' or type(required) ~= 'number' or required <= 0 then return end
        criteria[i] = {text = text, current = current, required = required}
        if current < required then complete = false end
    end
    return criteria, complete
end

function M:GetGoals(abilityId, bucketType)
    local record = self.catalogue.ABILITIES[abilityId]
    if not record or self:AbilityName(abilityId) == '' then return {} end
    local candidates = {}
    for _, id in ipairs(record.ids) do
        if not self.general[id] then candidates[id] = true end
    end
    local classes = self.catalogue.CLASSES or {}
    local class = ({[0] = classes.OFFENCE, [1] = classes.DEFENCE, [2] = classes.UTILITY})[bucketType] or record.class
    for id in pairs(self.byClass[class] or {}) do candidates[id] = true end

    local result = {}
    for id in pairs(candidates) do
        local criteria, complete = self:Criteria(id)
        if criteria and not complete then
            local needed = self.general[id] or (self.avatars[id] and self.avatars[id][abilityId])
            if not needed then
                local names = self:NamesForAchievement(id)
                for _, criterion in ipairs(criteria) do
                    if criterion.current < criterion.required then
                        local text, matched, ambiguous = self:Normalize(criterion.text), nil, false
                        for candidate, name in pairs(names) do
                            if text:find(name, 1, true) then
                                if matched then ambiguous = true end
                                matched = candidate
                            end
                        end
                        if matched == abilityId and not ambiguous then needed = true; break end
                    end
                end
            end
            if needed then result[#result + 1] = id end
        end
    end
    table.sort(result)
    return result
end

function M.Layout(width, heights)
    local positions, y = {}, 0
    local columns = math.max(1, math.floor((width + M.GAP) / (M.CARD_WIDTH + M.GAP)))
    for first = 1, #heights, columns do
        local count = math.min(columns, #heights - first + 1)
        local x = (width - count * M.CARD_WIDTH - (count - 1) * M.GAP) / 2
        local rowHeight = 0
        for offset = 0, count - 1 do
            local i = first + offset
            positions[i] = {x = x + offset * (M.CARD_WIDTH + M.GAP), y = y}
            rowHeight = math.max(rowHeight, heights[i])
        end
        y = y + rowHeight + M.GAP
    end
    return positions, math.max(0, y - M.GAP)
end
