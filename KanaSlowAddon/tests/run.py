from pathlib import Path
import sys
from lupa.lua51 import LuaRuntime
root = Path(sys.argv[1] if len(sys.argv)>1 else Path(__file__).resolve().parent.parent)
source = root / ('KanaSlowAddon.lua' if (root/'KanaSlowAddon.lua').exists() else 'SlowDialogs.lua')
for case in ['toggle', 'action', 'service', 'close', 'natural']:
    lua=LuaRuntime(unpack_returned_tuples=True)
    lua.globals().SOURCE=str(source)
    lua.globals().CASE=case
    lua.execute((root/'tests/test.lua').read_text())
    print('PASS',case)

for path in root.glob("*.lua"):
    LuaRuntime().execute("assert(loadfile(...))",str(path))
print("PASS Lua 5.1 syntax")
