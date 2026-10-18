"""Run the Dragonknight HUD tests with Python and Lua 5.1 (lupa)."""
from pathlib import Path
import os
from lupa.lua51 import LuaRuntime

os.chdir(Path(__file__).resolve().parent.parent)
lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().zo_strlower = lambda value: value.lower()
lua.execute("dofile('tests/stacks.lua')")
LuaRuntime(unpack_returned_tuples=True).execute("dofile('tests/heat.lua')")
for path in ("SeethingFury.lua", "HeatShock.lua"):
    lua.execute("assert(loadfile(...))", path)
print("PASS: Lua 5.1 syntax")
