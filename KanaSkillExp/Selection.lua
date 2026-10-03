KanaSkillExpSelection = {}
local selection = KanaSkillExpSelection

function selection.Find(entries, target)
    for i, entry in ipairs(entries) do
        if entry.kind == target.kind and entry.id == target.id then return i end
    end
end

function selection.Add(entries, target)
    if selection.Find(entries, target) then return end
    local entry = {}
    for key, value in pairs(target) do entry[key] = value end
    entries[#entries + 1] = entry
end

function selection.Remove(entries, target)
    local index = selection.Find(entries, target)
    if index then table.remove(entries, index) end
end
