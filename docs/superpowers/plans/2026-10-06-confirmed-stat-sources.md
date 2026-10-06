# Confirmed stat sources implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan inline, then one fresh whole-change review.

**Goal:** Remove only evidence-backed residuals from the latest character dump.

**Architecture:** Extend the existing source providers, preserve authoritative native totals and signed residuals. Add a sanitized replay fixture for the latest dump; keep the tooltip renderer unchanged.

**Tech Stack:** ESO API 101051, Lua 5.1, Lua 5.4 tests, offline SavedVariables replay.

**Spec:** `KanaStatSources/docs/2026-10-06-confirmed-sources.md`.

## Global Constraints

- Restrict numeric bases to API 101051, level 50 CP160+, both battle-leveling flags false.
- Emit only a verified active weapon passive; read its amount from RU/EN native text.
- Preserve unproven critical-rating discrepancies and genuine signed residuals.
- Do not change tooltip layout or SavedVariables; exclude character/account identity from fixtures.

## Review Focus

- Other levels, CP<160, unavailable flags or a future API retain an unknown base.
- Unknown native totals must never be converted to base contributions.
- Native effectiveFlat Mundus values remain excluded from a second multiplier.
- A shield on the inactive bar, dual wield, absent weapon metadata or transformed bar cannot activate Sword and Board.
- Conditional learned/proc descriptions cannot become permanent sources; an injected unexplained stat delta remains visible.

### Task 1: Verified bases and raw attribute percentage scope

**Files:** `Sources/Base.lua`, `Rules.lua`, `tests/test_base.lua`, `tests/fixtures/live_ru_tank.lua`, `tests/test_live_ru_tank.lua` under `KanaStatSources`.

**Interfaces:** `K.Sources.Base.Build(snapshot)` emits flat bases/attributes and diagnostics; `K.App:Explain(snapshot)` retains native totals and calculates residuals.

- [x] Write failing tests for level-50 recovery 309/514/514, critical resistance 1320, no inference outside verified context, and percentage scope including attributes.
- [x] Run base/replay tests and confirm failures are missing sources/scope.
- [x] Add gated bases and change attributes to flat, preserving effectiveFlat Mundus.
- [x] Add ID 185239 Erudition rule for its complete RU/EN unconditional description; test foreign IDs, inactive/unpurchased skills and conditional tails. This rule is necessary to reproduce the recovery formulas in the fixture.
- [x] Run base/replay tests; expect recovery/HP/critical-resistance residuals zero, crit -10 preserved. Run full suite.
- [x] Commit the verified foundation rules with their tests.

### Task 2: Active Sword and Board

**Files:** `Rules.lua`, `tests/test_skills.lua`, `tests/test_live_ru_tank.lua` under `KanaStatSources`.

**Interfaces:** Registry rule `skill:29397` validates active main/offhand weapon types, then emits parsed percent clauses for weapon/spell damage.

- [ ] Write failing tests for front/back activation, no shield/dual wield/two-handed/transformed/missing metadata, inactive or unpurchased line, and RU/EN current amount.
- [ ] Run skills/replay tests; verify missing Sword and Board attribution fails.
- [ ] Implement the explicit condition; leave all other weapon passives conservative.
- [ ] Run full suite: tank damage totals 3008, residual zero, unknown injected bonuses preserved, crit residual unchanged.
- [ ] Commit the active weapon rule with tests.

### Task 3: Validation and release

**Files:** `Core.lua`, `KanaStatSources.addon`, `README.md`, `docs/research.md`, `docs/validation.md` under `KanaStatSources`.

- [ ] Update evidence, limits, latest dump results and release version to 1.0.5.
- [ ] Run `lua KanaStatSources/tests/run.lua` and `PYTHONPATH=/tmp/kana-cooldown-test-deps python3 KanaStatSources/tests/run51.py`; require all checks pass.
- [ ] Obtain one fresh-context whole-change review, address material findings with failing regressions and rerun suite.
- [ ] Commit scoped release/docs; report remaining crit discrepancy and client verification limit.
