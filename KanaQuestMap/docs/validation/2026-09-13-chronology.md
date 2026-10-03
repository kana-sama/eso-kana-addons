# KanaQuestMap chronology validation

## Automated checks

Run from `/Users/kana/Documents/Elder Scrolls Online/live/AddOns/KanaQuestMap`:

```text
$ python3 tests/test_identity.py
PASS: fork identity
$ /opt/homebrew/opt/lua@5.4/bin/lua tests/test_chronology.lua .
PASS: chronology adapter
$ python3 tests/test_tooltip_integration.py
PASS: tooltip integration
$ /opt/homebrew/opt/lua@5.4/bin/luac -p Init.lua Chronology.lua PC/Main.lua console/Main.lua PC/Settings.lua
```

The Lua runtime is Homebrew Lua 5.4. The code and tests use Lua 5.1-compatible
syntax; ESO rendering itself is not emulated.

## In-game acceptance check

1. Disable `QuestMap`; enable `KanaQuestMap`, `TheQuestingGuide`, and
   `LibUespQuestData`.
2. Run `/reloadui`.
3. Hover a known story pin, for example a Northern Elsweyr quest. The tooltip
   should retain the quest name and add a chronology line such as
   `DLC #3: Thieves Guild -- Hew's Bane`.
4. Hover a pin not classified by TQG or disable TQG. The tooltip must retain
   its original QuestMap content and show no empty extra line.

For a side quest in a TQG zone that is not listed by quest ID, the tooltip
must still show that zone's chronology through `GetQuestZoneId`.

A screenshot after these checks is required to verify the final ESO layout.
