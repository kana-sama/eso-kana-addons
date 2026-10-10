"""Run with Python + lupa (Lua 5.1), without an ESO client."""
from pathlib import Path
import os
import runpy
from lupa.lua51 import LuaRuntime

os.chdir(Path(__file__).resolve().parent.parent)
runpy.run_path('tests/active_row.py')
LuaRuntime(unpack_returned_tuples=True).execute("dofile('tests/panel.lua')")
lua = LuaRuntime(unpack_returned_tuples=True)
for path in ("Model.lua", "Settings.lua", "ActiveBar.lua", "KanaCooldownPanel.lua", "Menu.lua"):
    lua.execute("assert(loadfile(...))", path)
print("PASS: Lua 5.1 syntax")
