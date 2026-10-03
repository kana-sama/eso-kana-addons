"""Regression against the complete client snapshot; run from AddOns with lupa.lua51."""
import json
from pathlib import Path
from lupa.lua51 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().zo_strlower = lambda value: value.lower()
lua.execute('dofile("KanaOutfitBrowser/Catalog.lua")')
catalog = lua.globals().KanaOutfitBrowser.Catalog
fixture = json.loads(Path('KanaOutfitBrowser/tests/fixtures/catalog-client.json').read_text())
records = fixture['records']
variants, _, snapshot = catalog.Normalize(lua.table_from(records, recursive=True), lua.table_from(fixture['constants'], recursive=True))
by_id = {r['collectibleId']: r for r in records}
represented, families, membership = set(), {}, {}
keys = set()
for v in variants.values():
    assert v['key'] not in keys
    keys.add(v['key'])
    ids = families.setdefault(v['styleKey'], set())
    known = 0
    for slot, part in v['slots'].items():
        ident = part['collectibleId']
        assert slot in by_id[ident]['eligibleSlots'], (ident, slot)
        represented.add(ident)
        ids.add(ident)
        membership.setdefault(ident, set()).add(v['styleKey'])
        known += bool(part['unlocked'])
    assert known == v['knownCount']
assert represented == set(by_id), sorted(set(by_id) - represented)
assert snapshot['omittedRecordCount'] == 0

def one_family(ids):
    groups = {key for ident in ids for key in membership[ident]}
    assert len(groups) == 1, groups
    return next(iter(groups))

bone = one_family(range(10898, 10905))
assert len(families[bone]) == 7
moon_ids = [r['collectibleId'] for r in records if 'жрецов Новой Луны' in r['collectibleName']]
assert len(moon_ids) == 22
moon = one_family(moon_ids)
assert len(families[moon]) == 22
for a,b in [(11338,11328),(13138,13118),(4516,4510),(6144,6141),(9541,9539),(12181,12430),(4550,4551),(12144,12148)]:
    one_family([a,b])
# The same art base with a bg qualifier is a different style, not an armor weight.
fang = [r['collectibleId'] for r in records if 'клыкастого червя' in r['collectibleName'].lower()]
lair = [r['collectibleId'] for r in records if 'Логова Клыка' in r['collectibleName']]
assert len(fang) == 22 and len(lair) == 22
assert one_family(fang) != one_family(lair)
# Shared engine category 67 must not collapse distinct bosses or opal recolors.
assert one_family([5452,5453]) != one_family([5454,5455])
assert one_family([5452,5453]) != one_family([6910,6911])

prefs = lua.table_from({'favorites':{'collectible:10898:visual:6':True},
    'hidden':{'collectible:10898:visual:6':True},
    'styleOrder':['collectible:10898:visual:6','collectible:10899:visual:6']}, recursive=True)
catalog.MigratePreferences(prefs, snapshot)
assert prefs['favorites'][bone] is True
assert not prefs['hidden'][bone], 'one hidden part must not hide the whole merged set'
assert list(prefs['styleOrder'].values()) == [bone]
reversed_variants, _, _ = catalog.Normalize(lua.table_from(list(reversed(records)), recursive=True), lua.table_from(fixture['constants'], recursive=True))
def fingerprint(source):
    return {v['key']: (v['name'], tuple(sorted((slot, p['collectibleId']) for slot,p in v['slots'].items()))) for v in source.values()}
assert fingerprint(variants) == fingerprint(reversed_variants), 'enumeration order changes grouping or labels'
print(f'Client regression: {len(records)} / {len(represented)} items retained; '
      f'{len(families)} families; {len(variants)} variants; bone/new moon/aliases/bosses/migration PASS')
