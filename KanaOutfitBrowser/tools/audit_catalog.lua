-- Run from eso-kana-addons with Lua 5.1; consumes actual client evidence, not invented items.
dofile('../../SavedVariables/KanaOutfitBrowser.lua')
dofile('KanaOutfitBrowser/Catalog.lua')
local audit
local function visit(value)
    if type(value) ~= 'table' then return end
    if value.audit and value.audit.version == 1 then audit = value.audit; return end
    for _, child in pairs(value) do visit(child) end
end
visit(KanaOutfitBrowserSavedVariables)
assert(audit, 'Full client snapshot is not saved yet; reload twice after installing collector')
local variants, _, snapshot = KanaOutfitBrowser.Catalog.Normalize(audit.records, audit.constants)
local families, recordsById = {}, {}
for _, record in ipairs(audit.records) do recordsById[record.collectibleId] = record end
for _, variant in ipairs(variants) do
    local family = families[variant.styleKey] or {name=variant.name, ids={}, slots={}}
    families[variant.styleKey] = family
    for slot, part in pairs(variant.slots) do
        family.ids[part.collectibleId] = true
        family.slots[slot] = true
    end
end
local function count(t) local n=0; for _ in pairs(t) do n=n+1 end; return n end
print(string.format('Records: %d; families: %d; variants: %d; omitted: %d',
    #audit.records, count(families), #variants, snapshot.omittedRecordCount))
local keys, represented = {}, {}
for key, family in pairs(families) do
    keys[#keys+1]=key
    for id in pairs(family.ids) do represented[id]=true end
end
table.sort(keys)
-- Sparse groups are candidates for investigation, not automatically errors:
-- some styles genuinely contain only a head/shoulders pair or one item.
for _, key in ipairs(keys) do
    local f=families[key]
    if key:find('collectible:',1,true)==1 or count(f.slots)<3 then
        print(string.format('\nREVIEW %s | %s | %d slots', key, f.name, count(f.slots)))
        local ids={}; for id in pairs(f.ids) do ids[#ids+1]=id end; table.sort(ids)
        for _,id in ipairs(ids) do
            local r=recordsById[id]
            print(string.format('  %d | %s | %s | armor=%s',id,r.collectibleName or '',r.icon or '',tostring(r.visualArmorType)))
        end
    end
end
for _, record in ipairs(audit.records) do
    if not represented[record.collectibleId] then
        print(string.format('UNREPRESENTED %d | %s | %s',record.collectibleId,record.collectibleName or '',record.icon or ''))
    end
end
