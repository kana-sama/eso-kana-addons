# KanaArchiveAchievements Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan inline. Steps use checkbox syntax for tracking.

**Goal:** Show native achievement indicators and complete achievement tooltips for Infinite Archive choices.

**Architecture:** Read Archive Helper's ability catalogue, resolve relevant unfinished goals against live ESO criteria, and render independent native achievement containers in a centered scroll area below the selector. Post-hooks preserve both native selectors.

**Tech Stack:** Lua 5.1, ESO XML templates, ArchiveHelper 1.4.2+, native achievement pools and scroll controls.

**Spec:** `docs/superpowers/specs/2026-10-14-kana-archive-achievements-design.md`

## Global Constraints

- Native achievement indicators retain their original texture colours; no warning tint.
- Tooltips describe the highlighted option; indicators cover every visible option.
- Full criteria and rewards remain available through one vertical scroll area below the selector.
- Preserve choice, reroll, ability tooltips, existing layout and keyboard/gamepad navigation.
- Do not modify Archive Helper's files, saved settings or shared pools.
- Keep all initial addon work in one mutable jj change; do not push.

## Review Focus

- A unique criterion already earned must not look missing when other criteria remain unfinished.
- Older catalogue entries omit category counters for some visions; the actual choice bucket supplies the category.
- Native achievement pools reparent their controls; all created controls must remain inside the clipped addon container.
- UI scaling and short screens must preserve access to the last criterion and avoid the selector/keybinds.
- Rerolls reuse native choice controls; old indicators and highlighted-goal tooltips must be cleared.

### Task 1: Goal resolution and layout

**Files:** `KanaArchiveAchievements/Model.lua`, `KanaArchiveAchievements/tests/test_model.lua`.

**Interfaces:** `Model.New(api, catalogue):GetGoals(abilityId, bucketType)` returns deduplicated achievement IDs; `Model.Layout(width, heights)` returns centered card positions and total height.

- [x] Write failing tests for completed unique criteria, all quantitative tiers, avatar goals, Russian names/exceptions, ambiguous names, unknown abilities and wrapped centered rows.
- [x] Run `lua KanaArchiveAchievements/tests/test_model.lua`; expected missing-feature failure.
- [x] Implement normalization, criterion matching, category completion checks and deterministic row layout with 565-unit cards and 12-unit gaps.
- [x] Run the same command; expected all cases pass.

### Task 2: Native view and selector lifecycle

**Files:** `KanaArchiveAchievements/View.lua`, `KanaArchiveAchievements/Controller.lua`, `KanaArchiveAchievements/Templates.xml`, `KanaArchiveAchievements/tests/test_ui.lua`, `KanaArchiveAchievements/tests/support.lua`.

**Interfaces:** `View.New(api)` owns independent controls/pools; `Show(selector, ids, resetScroll)`, `Hide()`, `UpdateIndicators(selector, model)`, `Scroll(delta)` and `Layout()` manage the presentation. `Controller.Install(api, model, view)` returns selector/event handling state.

- [x] Write failing tests for independent complete tooltip instances, native texture colours, all-choice indicators, centered layout below the selector, short/scaled screens, preserving/clamping scroll, hover persistence, reroll invalidation, achievement updates and both selector modes.
- [x] Run `lua KanaArchiveAchievements/tests/test_ui.lua`; expected missing-feature failure.
- [x] Implement private pools and a template inheriting `ZO_AchievementBase`, then instantiate native `AchievementContainer` for every displayed goal.
- [x] Implement the common `ZO_ScrollContainer`, native wheel scrolling and gamepad scroll actions. Post-hook showing, selecting, refreshing, reroll state, choice commit and hiding without replacing native behavior.
- [x] Run both addon test files; expected all cases pass.

### Task 3: Bootstrap, documentation and completion

**Files:** `KanaArchiveAchievements/KanaArchiveAchievements.lua`, `KanaArchiveAchievements/KanaArchiveAchievements.addon`, `KanaArchiveAchievements/README.md`, root `README.md`, approved specification and this plan.

- [x] Add bootstrap cases to the lifecycle test: unrelated addon load, dependency data available, exactly one installation and native selector hooks retained.
- [x] Run tests and observe the bootstrap failure, then implement load order and ArchiveHelper dependency with API versions 101050/101051.
- [x] Document actual behavior, dependency, local verification command and one combined ESO client check.
- [x] Run all addon tests, Lua syntax checks and jj diff whitespace/scope checks in parallel; expected zero failures.
- [x] Obtain one fresh-context review of the complete addon and fix material findings with regression tests.
- [x] Record final verification and finish the single jj change with an empty working-copy child; do not push.

## Execution record

The user instructed implementation with “делай”; execution continues inline in the existing jj change. Repository instructions take precedence over intermediate per-task commits and Git-based skill scripts. A temporary ledger under `/tmp` records progress without introducing repository infrastructure.

The independent review found that native `AchievementContainer.Show` requires a top-level parent. Embedded cards now use native `Achievement.Show` and `Expand` directly, while only the enclosing top-level area calls `BringWindowToTop`. The regression preserves the original native Show contract, forbids that method on ordinary controls, and checks the complete expanded height.
