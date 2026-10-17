local Model = {}
KanaCombatBookmarks.Model = Model

function Model.Add(entries, offsetMs, name)
    local previous = entries[#entries]
    local entry = {id = previous and previous.id + 1 or 1, offsetMs = offsetMs, name = name}
    entries[#entries + 1] = entry
    return entry
end

function Model.Time(milliseconds)
    local sign = milliseconds < 0 and '-' or ''
    local value = math.floor(math.abs(milliseconds))
    return string.format('%s%02d:%02d.%03d', sign, math.floor(value / 60000), math.floor(value / 1000) % 60, value % 1000)
end

function Model.Entries(fight)
    local data = fight and fight.kanaCombatBookmarks
    if type(data) == 'table' and data.version == 1 and type(data.entries) == 'table' then return data.entries end
    return {}
end
