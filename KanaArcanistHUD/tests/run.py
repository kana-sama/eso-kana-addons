"""Run the Arcanist HUD tests with Python and Lua 5.1 (lupa)."""
from pathlib import Path
import os
from lupa.lua51 import LuaRuntime

os.chdir(Path(__file__).resolve().parent.parent)
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("dofile('tests/crux.lua')")
lua.execute("assert(loadfile('Crux.lua'))")
print("PASS: Lua 5.1 syntax")
