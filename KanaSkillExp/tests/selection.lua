local loader = loadfile('KanaSkillExp/Selection.lua')
if loader then loader() end
local selection = KanaSkillExpSelection or {}
assert(type(selection.Add) == 'function', 'manual selection is not implemented')

local entries = {}
local first = { kind = 'ability', id = 17, name = 'Z' }
local line = { kind = 'line', id = 17, name = 'A' }
selection.Add(entries, first)
selection.Add(entries, line)
selection.Add(entries, { kind = 'ability', id = 23, name = 'B' })
assert(#entries == 3 and entries[1].id == 17 and entries[2].kind == 'line'
    and entries[3].id == 23, 'mixed selection must retain insertion order')
selection.Add(entries, { kind = 'ability', id = 17, name = 'New morph' })
assert(#entries == 3, 'another morph of the same progression must not duplicate a skill')
assert(selection.Find(entries, line) == 2, 'line and ability IDs occupy separate namespaces')
selection.Remove(entries, line)
assert(#entries == 2 and entries[1].id == 17 and entries[2].id == 23,
    'removal must preserve the order of surviving entries')
selection.Add(entries, line)
assert(entries[3].kind == 'line', 're-adding an entry must append it')
selection.Remove(entries, {kind = 'line', id = 999})
assert(#entries == 3, 'removing an absent entry must not remove another entry')
first.name = 'Changed outside saved data'
assert(entries[1].name == 'Z', 'saved selection must not retain a mutable menu descriptor')
local reloaded = {}
for i, entry in ipairs(entries) do
    reloaded[i] = {kind = entry.kind, id = entry.id, name = entry.name}
end
assert(selection.Find(reloaded, {kind = 'ability', id = 23}) == 2,
    'saved identifiers must work after reloading without object identity')
print('PASS: persistent selection order, deduplication, removal and identity')
