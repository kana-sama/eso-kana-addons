"""Run with Python + lupa (Lua 5.1); no ESO client required."""
from pathlib import Path
import os
from lupa.lua51 import LuaRuntime

os.chdir(Path(__file__).resolve().parent.parent)
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("dofile('tests/blood.lua')")
LuaRuntime(unpack_returned_tuples=True).execute("dofile('tests/werewolf.lua')")
for path in ("BloodHunger.lua", "WerewolfForm.lua"):
    lua.execute("assert(loadfile(...))", path)
print("PASS: Lua 5.1 syntax")
