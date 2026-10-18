from pathlib import Path
import os
from lupa.lua51 import LuaRuntime
root = Path(__file__).resolve().parent.parent
os.chdir(root)
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("dofile('tests/test.lua')")
for path in root.glob('*.lua'):
    lua.execute('assert(loadfile(...))', str(path))
print('PASS Lua 5.1 syntax')
