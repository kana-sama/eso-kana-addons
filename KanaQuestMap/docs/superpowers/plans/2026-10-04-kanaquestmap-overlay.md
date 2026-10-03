# KanaQuestMap Overlay Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert KanaQuestMap from a QuestMap fork into an update-safe QuestMap overlay.

**Architecture:** The addon manifest loads a compact Kana-owned runtime after QuestMap. The runtime decorates QuestMap/LibMapPins behavior, owns only Kana settings, and retains old fork settings through a non-destructive one-time migration.

**Tech Stack:** ESO Lua API, QuestMap, LibMapPins, LibQuestData, LibAddonMenu-2.0, The Questing Guide.

**Spec:** `docs/superpowers/specs/2026-10-04-kanaquestmap-overlay-design.md`

## Global Constraints

- Never modify files under `../QuestMap`.
- `KanaQuestMap` depends on QuestMap and loads after it.
- TQG is optional; all non-chronology features work without it.
- The old `KanaQuestMap_SavedVariables` data is preserved.
- Non-QuestMap pins are never intercepted.

## Review Focus

- An existing QuestMap setting must win over a fork-era setting during migration.
- A non-QuestMap LibMapPins pin must pass through unchanged.
- Quest 4493 is suppressed only on the two false Stonefalls map textures.
- A missing TQG table must leave the original tooltip functional.
- An old LibAddonMenu that skips `custom.createFunc` must still render blacklist controls.

### Task 1: Declare the overlay and migrate settings

**Files:**
- Modify: `KanaQuestMap/KanaQuestMap.addon`
- Create: `KanaQuestMap/Overlay.lua`
- Test: `KanaQuestMap/tests/test_overlay_manifest.py`

- [ ] Write a failing test requiring QuestMap dependency, no copied QuestMap runtime entries, and loading `Overlay.lua`.
- [ ] Run the test and observe failure.
- [ ] Implement manifest and `KanaQuestMap:Initialize()` with non-destructive SavedVariables migration.
- [ ] Run the test and observe pass.

### Task 2: Restore map and journal behavior through hooks

**Files:**
- Create: `KanaQuestMap/PC/Overlay.lua`
- Create: `KanaQuestMap/console/Overlay.lua`
- Test: `KanaQuestMap/tests/test_overlay_hooks.py`

- [ ] Write failing tests for blacklist filtering, QuestMap-only pin rerouting, LibQuestData location filtering, chronology decoration, and journal hook registration.
- [ ] Run the test and observe failure.
- [ ] Implement narrow PC/console hooks and pass-through failure behavior.
- [ ] Run the test and observe pass.

### Task 3: Recreate Kana-only settings UI

**Files:**
- Create: `KanaQuestMap/PC/OverlaySettings.lua`
- Test: `KanaQuestMap/tests/test_overlay_settings.py`

- [ ] Write a failing test requiring an independent Kana panel and old-LAM-safe input initialization.
- [ ] Run the test and observe failure.
- [ ] Implement blacklist input/list/delete controls backed by Kana saved variables.
- [ ] Run the test and observe pass.

### Task 4: Full verification

**Files:**
- Modify: `KanaQuestMap/README-Kana.md`

- [ ] Update installation instructions to require both addons.
- [ ] Run all Python and Lua tests, then `luac -p` over loaded Lua files.
- [ ] Inspect QuestMap for an empty diff and report live `/reloadui` checks.
