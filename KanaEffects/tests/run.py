#!/usr/bin/env python3
"""Run isolated Lua 5.1 suites; never fall back to the system Lua binary."""
import argparse
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
DEPS = Path(os.environ.get('KANA_EFFECTS_TEST_DEPS', '/tmp/kana-effects-test-deps'))
if DEPS.is_dir():
    sys.path.insert(0, str(DEPS))
try:
    from lupa.lua51 import LuaRuntime
except ImportError:
    raise SystemExit('Lua 5.1 unavailable: pip install --target /tmp/kana-effects-test-deps -r tests/requirements.txt')

parser = argparse.ArgumentParser()
parser.add_argument('--suite', action='append', help='suite basename; default all tests/*.lua')
parser.add_argument('--all', action='store_true', help='explicit alias for the default full suite')
parser.add_argument('--syntax', action='store_true', help='parse every Lua file without executing')
args = parser.parse_args()
if args.all and args.suite:
    parser.error('--all cannot be combined with --suite')
lua = LuaRuntime(unpack_returned_tuples=True)
version = lua.eval('_VERSION')
if version != 'Lua 5.1':
    raise SystemExit('Refusing non-5.1 runtime: ' + version)
print('Runtime: ' + version, flush=True)
if args.syntax:
    parse = lua.eval('function(text, name) local f, err = loadstring(text, name); return f ~= nil, err end')
    failures = []
    files = sorted(ROOT.rglob('*.lua'))
    for path in files:
        valid, error = parse(path.read_text(), '@' + str(path))
        if not valid:
            failures.append((path, error))
    for path, error in failures:
        print('FAIL syntax: ' + str(path) + ': ' + error)
    print(f'Syntax: {len(files)} files, {len(failures)} failures')
    raise SystemExit(bool(failures))

suites = [ROOT / 'tests' / (name + '.lua') for name in args.suite] if args.suite else sorted((ROOT / 'tests').glob('*.lua'))
if not suites:
    raise SystemExit('No suites found')
failed = passed = 0
for suite in suites:
    runtime = LuaRuntime(unpack_returned_tuples=True)
    runtime.globals().TEST_ROOT = str(ROOT)
    runtime.execute('KanaEffects = {}; TestSupport = {}; Tests = {}')
    for path in sorted((ROOT / 'tests/support').glob('*.lua')):
        runtime.execute(path.read_text(), name='@' + str(path))
    try:
        runtime.execute(suite.read_text(), name='@' + str(suite))
    except Exception as error:
        failed += 1
        print(f'FAIL load {suite.name}: {error}')
        continue
    tests = runtime.globals().Tests
    invoke = runtime.eval('function(f) return pcall(f) end')
    for name in sorted(tests.keys()):
        result = invoke(tests[name])
        ok, detail = result if isinstance(result, tuple) else (result, None)
        if ok:
            passed += 1
            print('PASS ' + name)
        else:
            failed += 1
            print(f'FAIL {name}: {detail}')
print(f'Tests: {passed} passed, {failed} failed')
raise SystemExit(bool(failed))
