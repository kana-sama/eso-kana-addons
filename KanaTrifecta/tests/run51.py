"""Run behavior suites and syntax checks in the same Lua version as ESO."""
from pathlib import Path
import os
import sys
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[2]
os.chdir(root)
addon = root / "KanaTrifecta"
suite = sys.argv[1] if len(sys.argv) > 1 else "all"
files = sorted((addon / "tests").glob("test_*.lua")) if suite == "all" else [addon / "tests" / f"test_{suite}.lua"]
assert files, "No test suites"
lua = LuaRuntime()
assert lua.eval("_VERSION") == "Lua 5.1"
for path in addon.rglob("*.lua"):
    lua.execute("assert(loadstring(...))", path.read_text())
passed = failed = 0
for path in files:
    lua = LuaRuntime(unpack_returned_tuples=True)
    tests = lua.execute(path.read_text())
    for name in sorted(tests):
        try:
            tests[name]()
            passed += 1
        except Exception as exc:
            failed += 1
            print(f"FAIL {path.stem}.{name}: {exc}")
print(f"{passed} passed; {failed} failed (Lua 5.1)")
sys.exit(1 if failed else 0)
