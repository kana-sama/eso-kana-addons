from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path('KanaStatSources')
for path in root.rglob('*.lua'):
    LuaRuntime().execute('assert(loadstring(...))', path.read_text())
for path in sorted((root / 'tests').glob('test_*.lua')):
    lua = LuaRuntime()
    group = path.stem.removeprefix('test_')
    lua.globals().arg = lua.table_from([group])
    lua.execute("dofile('KanaStatSources/tests/run.lua')")
print('Lua 5.1 syntax and behavior verified')
