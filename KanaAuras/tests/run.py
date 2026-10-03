"""Run with Python + lupa (Lua 5.1); no ESO client required."""
from pathlib import Path
import os
from lupa.lua51 import LuaRuntime

os.chdir(Path(__file__).resolve().parent.parent)
lua = LuaRuntime(unpack_returned_tuples=True)
# ESO provides Unicode lowercasing; Python supplies that boundary in tests.
lua.globals().zo_strlower = lambda value: value.lower()
lua.execute("dofile('tests/stacks.lua')")
LuaRuntime(unpack_returned_tuples=True).execute("dofile('tests/heat.lua')")
LuaRuntime(unpack_returned_tuples=True).execute("dofile('tests/crux.lua')")
LuaRuntime(unpack_returned_tuples=True).execute("dofile('tests/blood.lua')")
LuaRuntime(unpack_returned_tuples=True).execute("dofile('tests/werewolf.lua')")
for path in ("KanaAuras.lua", "HeatShock.lua", "Crux.lua", "BloodHunger.lua", "WerewolfForm.lua"):
    lua.execute("assert(loadfile(...))", path)
print("PASS: Lua 5.1 syntax")
