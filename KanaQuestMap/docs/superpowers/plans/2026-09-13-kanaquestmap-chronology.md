# KanaQuestMap Chronology Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show The Questing Guide's chronology number and content name in KanaQuestMap pin tooltips without bundling a quest database.

**Architecture:** `KanaQuestMap` is an isolated renamed copy of QuestMap. A new `Chronology` module reads the loaded global `TQG` tables once, builds a session-only `questId -> metadata` index, and returns formatted tooltip text. QuestMap's existing pin tags carry `id`, so the tooltip callback asks the module for an optional second line.

**Tech Stack:** ESO Lua 5.1, LibMapPins, The Questing Guide runtime tables, standalone Lua test harness.

**Spec:** `/Users/kana/Documents/Elder Scrolls Online/live/AddOns/eso-kana-addons/KanaQuestMap/docs/superpowers/specs/2026-09-13-kanaquestmap-chronology-design.md`

## Global Constraints

- Do not modify `/Users/kana/Documents/Elder Scrolls Online/live/AddOns/QuestMap`.
- Do not include or save a `questId -> content` database in KanaQuestMap.
- The Questing Guide (`TheQuestingGuide`) is optional; its absence must preserve QuestMap's existing behavior.
- Read only `TQG.ObjectiveLevelClassic`, `TQG.ObjectiveLevelDLC`, `TQG.ObjectiveLevelGroup` and their matching `ZoneLevel*`/`TopLevel*` runtime tables.
- Rename manifest identity, runtime id, localization identifiers, and SavedVariables from `QuestMap` to `KanaQuestMap`.
- This addon directory is not a Git repository; record verification output instead of committing.

---

### Task 1: Rename the isolated add-on

**Files:**
- Rename: `QuestMap.addon` to `KanaQuestMap.addon`
- Modify: `KanaQuestMap.addon`
- Modify: `Init.lua`
- Modify: `PC/Main.lua`
- Modify: `console/Main.lua`
- Modify: `PC/Settings.lua`
- Modify: `lang/Strings-*.lua`

**Interfaces:**
- Produces: global `KanaQuestMap`, id name `KanaQuestMap`, and saved variables `KanaQuestMap_SavedVariables`.
- Consumes: unchanged `LibMapPins`, `LibGPS`, `LibQuestData`, and `LibMapData` dependencies.

- [ ] **Step 1: Add a static identity test**

Create `tests/test_identity.py` that asserts the manifest file is named
`KanaQuestMap.addon`, declares `## Title: KanaQuestMap`, and that all Lua and
localization source files contain no executable `QuestMap` identifier.

- [ ] **Step 2: Run the identity test to verify it fails**

Run: `python3 tests/test_identity.py`

Expected: failure because the copied manifest and source still use `QuestMap`.

- [ ] **Step 3: Apply the rename consistently**

Rename the manifest and replace only the addon's own identifiers: `QuestMap`
becomes `KanaQuestMap`, `QuestMap_SavedVariables` becomes
`KanaQuestMap_SavedVariables`, and `QUESTMAP_` localization constants become
`KANAQUESTMAP_`. Preserve dependency names and third-party API names.

- [ ] **Step 4: Run the identity test to verify it passes**

Run: `python3 tests/test_identity.py`

Expected: PASS.

### Task 2: Build a runtime chronology adapter for TQG

**Files:**
- Create: `Chronology.lua`
- Modify: `KanaQuestMap.addon`
- Test: `tests/test_chronology.lua`

**Interfaces:**
- Produces: `KanaQuestMap.Chronology:BuildIndex(tqg)`,
  `KanaQuestMap.Chronology:Get(questId)`, and
  `KanaQuestMap.Chronology:Format(questId)`.
- Consumes: TQG's `ObjectiveLevelClassic`, `ObjectiveLevelDLC`,
  `ObjectiveLevelGroup`, matching `ZoneLevel*`, matching `TopLevel*`, and
  ESO's `GetZoneNameById`.

- [ ] **Step 1: Write failing Lua tests**

Create a TQG fixture with a DLC entry:

```lua
ZoneLevelDLC = { [1] = { [1] = { name = 7.1, id = 1086 } } },
TopLevelDLC = { [1] = "7: Season of the Dragon" },
ObjectiveLevelDLC = { [1] = { [1] = { [1] = { internalId = 6359 } } } },
```

Assert `Format(6359)` is `"(7.10) Northern Elsweyr -- 7: Season of the Dragon"`.
Also assert `internalId = 0`, a missing TQG table, and an unknown quest return
`nil` without an error.

- [ ] **Step 2: Run the Lua test to verify it fails**

Run: `lua tests/test_chronology.lua`

Expected: failure because `Chronology.lua` is absent.

- [ ] **Step 3: Implement the smallest adapter**

Load `Chronology.lua` after `Init.lua`. Its module must walk each category's
numeric progression and zone indexes; accept only numeric nonzero
`internalId`s; derive a zone name with `GetZoneNameById(zone.id)`; normalize
the numeric order with `string.format("%.2f", zone.name)`; and include the
matching `TopLevel*` label when it exists. Never write the derived index to
SavedVariables.

- [ ] **Step 4: Run the Lua test to verify it passes**

Run: `lua tests/test_chronology.lua`

Expected: PASS.

### Task 3: Add chronology to both tooltip variants

**Files:**
- Modify: `PC/Main.lua`
- Modify: `console/Main.lua`
- Test: `tests/test_tooltip_integration.py`

**Interfaces:**
- Consumes: `pinTag.id` and `KanaQuestMap.Chronology:Format(questId)`.
- Produces: one optional chronology line after `pinTag.pinName` in keyboard and
  gamepad map-pin tooltips.

- [ ] **Step 1: Write a failing source-level integration test**

Create `tests/test_tooltip_integration.py` that reads both main files and
asserts each tooltip creator retrieves `pinTag.id`, calls
`KanaQuestMap.Chronology:Format`, and guards insertion with a nonempty check.

- [ ] **Step 2: Run the integration test to verify it fails**

Run: `python3 tests/test_tooltip_integration.py`

Expected: failure because tooltips currently render only `pinTag.pinName`.

- [ ] **Step 3: Add guarded output**

In gamepad mode, add the formatted line using
`LayoutIconStringLine(..., mapLocationTooltipContentName)`. In keyboard mode,
append `"\n" .. chronology` to the `SetTooltipText` value only when chronology
exists. Keep the original quest-name line unchanged.

- [ ] **Step 4: Run the integration test to verify it passes**

Run: `python3 tests/test_tooltip_integration.py`

Expected: PASS.

### Task 4: Verify the packaged fork

**Files:**
- Modify: `Readme.md`
- Create: `docs/validation/2026-09-13-chronology.md`

**Interfaces:**
- Documents: installation alongside, not over, QuestMap; optional TQG behavior;
  required in-game acceptance check.

- [ ] **Step 1: Add user-facing installation and fallback notes**

State that the folder is `KanaQuestMap`, original QuestMap must be disabled to
avoid duplicate pins, and The Questing Guide is optional but required for
chronology text.

- [ ] **Step 2: Run all automated checks**

Run: `python3 tests/test_identity.py && lua tests/test_chronology.lua && python3 tests/test_tooltip_integration.py`

Expected: all checks PASS.

- [ ] **Step 3: Record the verification boundary**

Create the validation note with exact command output and state that only an
in-game `/reloadui` plus a screenshot can verify ESO's rendered tooltip.
