# Panel exclusion references

Request: `not_on_panel("Panel name")` checks that an effect is not admitted by the
named panel. A missing name returns false and shows an error beside the calling
panel. Renaming a referenced panel requires confirmation before rewriting all
filter code references. Cancel must leave both the name and code unchanged.

Decisions: admission uses the same observation/source and normal projection rules,
including fixed slots, family pair selectors and global hiding, independent of
render order, clipping or stale rendered data. Missing/ambiguous names and cycles
are nonfatal call errors. Surface warnings on consuming panels even through named
sets, including empty panels. No polling or arbitrary Lua execution.

- [x] Engine: parsed string references, dependency validation, safe evaluation,
  memoization and rename helpers (final_review).
- [x] Editor: confirmation and atomic rename, draft buffers, documentation
  (final_fixes).
- [x] Runtime/render: per-panel warnings, native warning icon, hover description
  and click to edit; visible for an empty panel (root).
- [x] Regression: missing/ambiguous refs, tables/pairs/sources/hidden, cycles,
  rename accept/cancel/stale callback/outer cancel and warning lifecycle.
- [x] Independent review and affected/full tests; record native verification gap.

Canonical source is now AddOns/eso-kana-addons/KanaEffects. Old temporary worktree
Git metadata is invalid after repository consolidation; do not install from it.
Tests are staged via /private/tmp/ke-panel-test.py against the current canonical
source. No external SavedVariables or upstream-addon changes.

## Review checkpoint

Independent read-only audit found no functional blocker. Root fixed an auxiliary
window covering the filter after warning click, and a repeated Notice call that
would hide the rename explanation. Final confirmation uses scroll content rows
and human panel/set names. Existing tests were run against canonical relocated
source; profiler fixtures were adjusted for `eso-kana-addons/`, and the standalone
rule-editor double now implements the production editor open/generation contract.

Focused regression suites and their native-control harness are preserved under
`KanaEffects/tests/` (excluded from the addon manifest). No installation copy from
the obsolete temporary checkout, no upstream addon changes, no game inputs.
Native icon/dialog rendering and interaction remain unverified until reload.

Final validation: full staged Lua5.1 suite **555 passed / 0 failed**
(`/tmp/ke-panel-final-full2.log`); canonical retained suites **155 / 0**
(`/tmp/ke-panel-repository-final.log`); syntax **52 / 0**; manifest **40** existing
product files, XML parsed, tests excluded; `git diff --check` clean. Source changes
are in the active monorepo working tree, uncommitted. Reload ESO to activate.

## User correction: positive membership

The requested meaning is “present on panel”, so the public predicate is now
`on_panel(name)` and returns the actual admission result. Missing/ambiguous/cyclic
calls still return false. Exclusion is written explicitly as `not on_panel(name)`.
The old spelling is migration-only: Storage validates structure, copies the
profile, normalizes complete old call tokens, then validates expressions. No `not`
is inserted; other string literals, panel names and comments are untouched. Loading
leaves raw SavedVariables unchanged; normal Save persists the normalized code.
Independent review found no blockers, including module order and migration safety.

Positive correction verified: canonical suite **158/0**, syntax **52/0**, diffcheck clean.
