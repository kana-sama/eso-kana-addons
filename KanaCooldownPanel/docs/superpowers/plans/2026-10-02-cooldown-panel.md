# KanaCooldownPanel Implementation Plan

> Implement inline with superpowers:executing-plans.

**Goal:** Extract the native timer mirror from KanaAuras into an independent addon with per-skill context settings.

**Architecture:** Model.lua selects bars, identifies skills and determines states from native timers. KanaCooldownPanel.lua owns saved settings, scene controls and vertical dragging. Menu.lua extends the native action-slot menu.

**Tech Stack:** ESO API 101050/101051, Lua 5.1, native controls and menus; no library dependency.

**Spec:** The user's request in this conversation, including the confirmed one-row condition: werewolf OR Oakensoul equipped. Normally show two rows of five slots. Hidden skills keep their empty space. Missing important uptime is red and pulsing only in combat; remaining time below 2000 ms is orange. Unimportant uptime has neither warning. Text stays white. Use native effect timers without spell configurations.

## Review Focus

- Both ring slots and bar swaps must select the correct timers.
- Restricted werewolf slots must still expose preferences without enabling native slot removal.
- Skill preferences must survive slot moves, ranks and reloads, and remain character specific.
- Scene changes must not reveal expired cells outside combat or a panel over menus.
- Old position migration must not overwrite a new saved position; all old mirror entry points must be removed.

## Task 1: Standalone panel and native context menu

- [x] Add tests/panel.lua with a mocked ESO boundary covering all four states, exactly 2000 ms, both ring slots, werewolf, bar swaps, native menu preservation, restricted menus, skill keys, migration, drag and scenes.
- [x] Run the test and confirm failure because the addon is absent.
- [x] Create Model.lua, KanaCooldownPanel.lua, Menu.lua and KanaCooldownPanel.addon. Menu callbacks save flags by skill progression (crafted skills use crafted ID); two rows have inactive above active.
- [x] Run `PYTHONPATH=/tmp/kana-cooldown-test-deps python3 KanaCooldownPanel/tests/run.py` and require a passing Lua 5.1 result.

## Task 2: Remove the old mirror and document usage

- [x] Remove ActionBarMirror.lua and its test from KanaAuras; remove manifest/test-runner references; replace its README section with the new addon reference.
- [x] Add the new addon's README with settings, behavior, dragging and live verification steps.
- [x] Run both addons' Lua 5.1 suites and inspect the scoped changes. Obtain one independent code review, fix any material findings, and distinguish mock verification from untested in-game appearance.

No commit requested. Preserve all unrelated existing changes in KanaAuras.

## Execution record

- Task 1: Lua 5.1 test failed with missing Model.lua, then passed after implementation. The previous temporary Lupa folder was empty; installed the test runtime into /tmp/kana-cooldown-test-deps.
- Task 2: Old mirror removed, manifest and test runner detached, both READMEs updated. Both addons' Lua 5.1 suites passed; scoped diff has no whitespace errors. Added passing reload/character-isolation coverage.
- Final review: independent gpt-6-astra review found no actionable defects after checking native ESO menu/control sources, extraction and persistence. Live ESO rendering, dragging, werewolf menu and scene transitions remain unverified.
