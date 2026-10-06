# Stat tooltip correctness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan inline. The user explicitly authorized planning followed immediately by implementation.

**Goal:** Correct all eight tooltip, source attribution and rounding issues reported by the user.
**Architecture:** Render in a private native ZO_BaseTooltip, preserving native animation lifecycle. Compute minimum-fitting geometry from source cells. Round the complete contribution sum once and distribute fractional units deterministically among its rows.
**Tech Stack:** ESO API 101051, Lua 5.1; native keyboard controls; Lua 5.4 and Lupa Lua 5.1 test runners.
**Spec:** KanaStatSources/docs/2026-10-06-tooltip-fixes.md

## Global Constraints

- Work in the existing live addon checkout. Preserve unrelated addons and SavedVariables.
- Two columns, bold native stat styling, short names and source icons.
- No shared InformationTooltip mutations, private API calls, universal critical-rating divisor, polling or expensive work on hover.
- Raw values/calibration and meaningful unknown residuals remain available in dumps.
- No approval gate or push. Review the completed diff and report live-client verification limits.

## Review Focus

Native tooltip ownership/fade events; shared map tooltip invariance; width and UI-scale units; rounding math without hiding missing sources; base critical calibration and zero rows.

---

### Task 1: Isolate the tooltip and correct its lifecycle

**Files:** KanaStatSources/Tooltip.lua, tests/fixtures/controls.lua, tests/test_tooltip.lua, tests/test_presentation.lua
**Interfaces:** Consumes Table.New(api, tooltip), view.Clear()/Render()/Scroll(); produces Bridge.tooltip (owned native tooltip), Bridge.Clear() (immediate disposal), Bridge.Hide() (fade preserving contents), unchanged Show/Refresh interface.

- [x] Write regression tests with native-like InitializeTooltip/ClearTooltip/ClearTooltipImmediately and deferred fade completion. Assert InformationTooltip dimensions, constraints, handlers and content remain unchanged.
- [x] Run tooltip tests and observe failures on the old shared implementation.
- [x] Create the private ZO_BaseTooltip via WINDOW_MANAGER:CreateControlFromVirtual. Prehook known stat exits to fade the owned tooltip; clear on its OnHide/OnCleared. Hidden stat controls and player deactivation hide immediately.
- [x] Run tooltip/presentation tests and commit scoped lifecycle fixes.

### Task 2: Fit two-column geometry and simplify the critical footer

**Files:** KanaStatSources/Table.lua, tests/test_table.lua, tests/test_presentation.lua, tests/test_text_layout.lua
**Interfaces:** Consumes breakdown rows, native calibrated critical.chance, and owned tooltip default constraints/padding; produces measured source-only width floored at native default, percentage-only footer, no formula control.

- [x] Write failures for native minimum width, exact long-source width, descriptions/titles not inflating width, percentage-only footer and stable refresh geometry.
- [x] Remove rating/formula UI. Measure source/footer cells only, default width from untouched native constraints, title/description wrapping inside the same width.
- [x] Keep existing scroll and attribute preview behavior; avoid cached visible-text measurements and shared tooltip restoration.
- [x] Run all layout groups, check UI scale fixtures, commit scoped rendering fixes.

### Task 3: Correct source attribution and rounding

**Files:** KanaStatSources/sources/Base.lua, Model.lua, tests/test_base.lua, tests/test_model.lua, tests/test_live_ru.lua
**Interfaces:** Base.Build(snapshot) produces base/attribute icon metadata and criticalChance contribution amount=10 for calibrated stats; Model.Build preserves rawValue/rawUnknown and produces zero-free rows with integer values summing to the rounded known subtotal plus genuine unknown.

- [x] Write failures for base critical 10%, native Wardrobe attribute icons, zero passives, two fractional percentage rows and preserved genuine missing/overcounted sources.
- [x] Add verified base critical chance rule, existing native icons, and deterministic largest-remainder rounding over the complete known subtotal (not each row independently).
- [x] Preserve raw contributions in dumps and diagnostics when critical calibration is unavailable.
- [x] Run model/base/live regression tests and full suite, commit scoped source fixes.

### Task 4: Verify and document the completed change

**Files:** KanaStatSources/Core.lua, KanaStatSources.addon, README.md, docs/validation.md, docs/client-validation.md, docs/tooltip-layout.md, docs/research.md
**Interfaces:** Consumes passing production/test changes; produces v1.0.4 release metadata and updated validation evidence.

- [x] Run full Lua 5.4 and Lua 5.1 behavior/syntax suites and git diff --check.
- [x] Review the complete change with one fresh reviewer; resolve substantive findings with failing regression tests.
- [x] Update documentation to match the final percent-only UI, dedicated tooltip, rounding and remaining client validation.
- [x] Commit scoped verified changes; report succinctly with /reloadui and honest rendering limits.
