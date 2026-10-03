# Stepwise Preset Operations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Replace opaque apply/recovery chains with a persisted, retryable sequence visible before calculation starts.

**Architecture:** OperationExecutor is the sole dispatcher. OperationPlan builds a full preflight diff; OperationSteps sends and verifies one action through existing adapters. OperationSession connects segmented editing and preset actions; OperationWindow renders saved state without game scans.

**Tech Stack:** ESO API 101051, Lua 5.1, native controls, existing Lua fixture suite.

**Spec:** `docs/superpowers/specs/2026-10-02-stepwise-operations-design.md`

## Global Constraints

- Equipment requests remain individually verified; independent sends are not an atomic batch.
- All preflight checks precede character mutations; omitted components are not read or changed.
- Order: required gear changes, attributes, talents, front bar, back bar, verification.
- Pause drains the already submitted action; close only hides; reload never dispatches automatically.
- Equipment editing equips only equipment; skills/attributes editing mounts local drafts only.
- Save restores equipment or closes the local draft; Save and Apply applies only the edited component.
- Retain failed attempts and native facts, including after restart/success; never edit live SavedVariables externally.
- Keep current shared panels and display caches. Work in the existing feature checkout containing accepted, uncommitted fixes.

## Review Focus

- Late callbacks after retry/restart must not finish another attempt (task 1).
- Reload between repository write and completion must not save a duplicate preset (task 4).
- Skill respec implicitly updates slotted morphs and werewolf slots (tasks 2–3).
- Hidden window and native page transitions must not cancel submitted requests or restart work (tasks 4–5).
- A failed old journal must not replace the list with recovery-only controls (tasks 4–5).

### Task 1: Durable executor

**Files:** create `OperationJournal.lua`, `OperationExecutor.lua`, `tests/test_operations.lua`.

**Interfaces:** `OperationExecutor.New(saved, clock, handlers, onChanged, onComplete)`; `Start(intent)`, `Continue()`, `Restart()`, `Pause()`, `SetVisible(bool)`, `GetView()`, `IsBusy()`. `handlers:Run(step, operation, report, done)` completes with `(result, problem)`; result may contain calculated `steps` and `target`. All persisted data is plain Lua data. `report` saves intermediate native request facts.

- [x] Write failure/continue, pause during pending action, generation isolation, reload, restart and success cleanup tests against controllable asynchronous handlers.
- [x] Run `lua tests/run.lua operations`; confirm missing executor failure.
- [x] Implement serialized attempts, diff as first step, callback guards, no automatic rollback/retry, archive and paused reload.
- [x] Run the same group; require all pass.

### Task 2: Diff and step contracts

**Files:** create `OperationPlan.lua`, `tests/test_operation_plan.lua`; reuse `EquipmentPlan.lua` and adapter Prepare methods.

**Interfaces:** `OperationPlan.Build(snapshot, requested, services, capabilities)` returns `{steps,target,extras,extraKey}` or problem. Gear step stores source UID, expected destination and displaced UID; attributes and skills store desired component; bar steps store one desired bar. `verify` stores only affected target domains.

- [x] Test no-op, missing gear/budget preflight, direct replacement, relocation/mythic dependency order, separate talents/bars and gear-only no catalogue access.
- [x] Run `lua tests/run.lua operation_plan` and observe RED.
- [x] Build minimal changes from existing validated diff; strip runtime data and global snapshot fingerprint guards. Verify only planned changes/required implicit changes.
- [x] Run the group and existing planner/mastery groups.

### Task 3: Native step execution

**Files:** create `OperationSteps.lua`, `tests/test_operation_steps.lua`; extend adapters only where a retry needs owned-request cleanup.

**Interfaces:** `OperationSteps.New(inventory, skills, attributes, events, clock, services)`; `Run(step, operation, report, done)`; delegated local steps through services. Native request state is persisted before send and on response. Each invocation checks actual target first; then fresh dependencies, sends once, and verifies results.

- [x] Test one gear request, already satisfied retry, timeout facts, native refusal, delayed result, mastery release before purchase, morph resolution before bar dispatch and no duplicate cast on retry.
- [x] Run `lua tests/run.lua operation_steps` and observe RED.
- [x] Implement bounded event/poll waits; stop at refusal/timeout, retain descriptor, reconcile only owned state. No automatic sheathing or whole-build fallback.
- [x] Run targeted steps and adapter tests.

### Task 4: Session and all entry points

**Files:** create `OperationSession.lua`, `tests/test_operation_session.lua`; modify `Session.lua`, `Core.lua`, manifest.

**Interfaces:** `OperationSession.Attach(session)` opts runtime into the new path, preserving selection/editor helpers. Apply, BeginEdit/New, Save/Cancel/SaveAndApply and QuickLoad submit serialized intents. Diff prepares editor or commit state; `save`, `mountDraft`, `closeDraft`, `openEditor`, `finishEditor` are idempotent local steps.

- [x] Test apply preflight window before capture, editor component isolation, save/retry checkpoint, cancel restoration, save-and-apply without restoration, reload migration and failure with usable list.
- [x] Run `lua tests/run.lua operation_session` and observe RED.
- [x] Route runtime actions through the executor; keep saved editor separate from active operation. Migrate old journal into an archived, paused intent when unambiguous; otherwise show diagnosis with new selections available.
- [x] Preserve display capture cache; no Catalogue or recovery inspection on GetView/page open.
- [x] Run session/editor/integration groups; update tests that explicitly demanded obsolete recovery behavior only for the new runtime path.

### Task 5: Window and panel affordance

**Files:** create `OperationWindow.lua`, `tests/test_operation_window.lua`; modify `UI.lua`, `Core.lua`, manifest, `lang/en.lua`, `lang/ru.lua`.

**Interfaces:** `OperationWindow.New(executor, api)`; `Refresh(view)`; nonmodal top-level scroll window, close, pause, continue, restart, report. Panel icon calls `executor:SetVisible(true)`. UI model reads executor summary only.

- [x] Test button commands, hide versus pause, success clear, error details, bounded scroll content and no native reads during render.
- [x] Run `lua tests/run.lua operation_window` and observe RED.
- [x] Implement pooled step rows, errors under rows, explicit additional-change consent, statuses with symbols and color, copy report through ProbeReport.
- [x] Show operation progress without replacing preset list; editor controls available only while editing, not during prepare/save/restore.
- [x] Run UI/geometry and new window groups.

### Task 6: Integration verification

**Files:** update `docs/client-validation.md`; all changed implementation/test files.

- [x] Run `lua tests/run.lua all`, Lua syntax checks and `git diff --check`; fix regressions with reproducing tests.
- [x] Review actual runtime wiring for all actions, late events, migration, unselected components and skill/bar verification after equipment changes.
- [x] Conduct a fresh code review of the final change; address important findings.
- [x] Record what local tests prove and what needs live ESO validation. Do not claim live rendering or server success without observing them.

Execution authorization: user explicitly requested implementation after reviewing the spec and atomicity limitation. Execute inline in this session; do not insert another approval cycle for the already authorized implementation.

Completion note: implementation and independent review are complete. Two Important review findings (editor baseline on restart; save before diff across reload) were reproduced and fixed. Live ESO acceptance remains pending; see docs/client-validation.md. Existing local branch/install is preserved.
