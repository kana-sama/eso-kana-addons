#!/usr/bin/env python3
"""Run isolated Lua 5.1 tests; the ESO client is not simulated fully."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, '/private/tmp/kana-buff-panels-test-deps')
try:
    from lupa.lua51 import LuaRuntime
except ImportError:
    raise SystemExit('Install lupa with pip, or set PYTHONPATH to its installation.')

passed = failed = 0
if '--syntax' in sys.argv:
    lua = LuaRuntime(unpack_returned_tuples=True)
    parse = lua.eval('function(s,n) local f,e=loadstring(s,n); return f~=nil,e end')
    for path in sorted(ROOT.rglob('*.lua')):
        ok, error = parse(path.read_text(), '@' + str(path))
        if ok:
            passed += 1
        else:
            failed += 1
            print(f'FAIL {path.name}: {error}')
else:
    names = LuaRuntime(unpack_returned_tuples=True)
    names.globals().TEST_ROOT = str(ROOT)
    names.execute((ROOT / 'tests/integration.lua').read_text())
    for name in sorted(names.globals().Tests.keys()):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.globals().TEST_ROOT = str(ROOT)
        lua.execute((ROOT / 'tests/integration.lua').read_text())
        ok, error = lua.eval('function(f) local ok,e=pcall(f); return ok,e end')(lua.globals().Tests[name])
        if ok:
            passed += 1
        else:
            failed += 1
            print(f'FAIL {name}: {error}')
print(f'{"Syntax" if "--syntax" in sys.argv else "Tests"}: {passed} passed, {failed} failed (Lua 5.1)')
raise SystemExit(bool(failed))
