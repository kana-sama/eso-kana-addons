# Regression tests

Run from the KanaEffects directory:

```sh
python3 tests/run.py
python3 tests/run.py --syntax
```

Requires Lua 5.1 via the pinned `lupa` package in `requirements.txt`. The runner
uses `/tmp/kana-effects-test-deps` by default, or `KANA_EFFECTS_TEST_DEPS`.

These suites retain the existing production runtime/render/editor harnesses and
add panel-reference admission, warning lifecycle and confirmed rename cases.
They run against this directory's Lua files; they do not touch ESO or SavedVariables.
Native appearance and mouse interaction still require client verification.
