#!/usr/bin/env python3
"""Isolated Lua 5.1 tests; no client, SavedVariables or system-Lua fallback."""
import argparse
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, '/private/tmp/kana-buff-panels-test-deps')
try:
    from lupa.lua51 import LuaRuntime
except ImportError:
    raise SystemExit('Install: python3 -m pip install --target /private/tmp/kana-buff-panels-test-deps -r KanaBuffPanels/tests/requirements.txt')

parser = argparse.ArgumentParser()
parser.add_argument('--suite', action='append')
parser.add_argument('--all', action='store_true')
parser.add_argument('--syntax', action='store_true')
args = parser.parse_args()
if args.all and args.suite:
    parser.error('--all and --suite are mutually exclusive')

def runtime():
    lua = LuaRuntime(unpack_returned_tuples=True)
    assert lua.eval('_VERSION') == 'Lua 5.1'
    lua.globals().TEST_ROOT = str(ROOT)
    lua.execute('KanaBuffPanels = {}; Tests = {}; function eq(a,b) assert(a == b, tostring(a).." ~= "..tostring(b)) end; function near(a,b) assert(math.abs(a-b)<0.00001, tostring(a).." ~= "..tostring(b)) end; function loadModule(name) assert(loadfile(TEST_ROOT.."/"..name..".lua"))() end')
    return lua

passed = failed = 0
if args.syntax:
    lua = runtime()
    parse = lua.eval('function(text, name) local f,e=loadstring(text,name); return f~=nil,e end')
    for path in sorted(ROOT.rglob('*.lua')):
        ok, error = parse(path.read_text(), '@' + str(path))
        if ok:
            passed += 1
        else:
            failed += 1
            print(f'FAIL syntax {path.name}: {error}')
else:
    suites = [ROOT / 'tests' / (s + '.lua') for s in args.suite] if args.suite else sorted((ROOT / 'tests').glob('*.lua'))
    if not suites:
        raise SystemExit('No test suites found')
    for path in suites:
        lua = runtime()
        try:
            lua.execute(path.read_text(), name='@' + str(path))
        except Exception as error:
            failed += 1
            print(f'FAIL load {path.name}: {error}')
            continue
        invoke = lua.eval('function(f) local ok,e=pcall(f); return ok,e end')
        for name in sorted(lua.globals().Tests.keys()):
            ok, error = invoke(lua.globals().Tests[name])
            if ok:
                passed += 1
            else:
                failed += 1
                print(f'FAIL {path.stem}/{name}: {error}')
print(f'{"Syntax" if args.syntax else "Tests"}: {passed} passed, {failed} failed (Lua 5.1)')
raise SystemExit(bool(failed))
