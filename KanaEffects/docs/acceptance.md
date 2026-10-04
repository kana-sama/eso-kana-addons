# Positive panel membership — correction

Public function: `on_panel("Panel name")`, true for admitted effects and false for
absent effects or missing/ambiguous/cyclic references. Explicit exclusion uses
`not on_panel("Panel name")`. Old saved call names normalize to the positive
spelling on load, without inserting negation or rewriting unrelated strings.

Canonical Lua5.1 tests **158 passed / 0 failed**, syntax **52 / 0**, independent
review clean. Log: `/tmp/ke-on-panel-tests.log`. Native UI check not repeated;
reload ESO to activate. Previous feature validation follows below.

---

# Panel-reference filters — 5 October 2026

`not_on_panel("Panel name")` excludes observations admitted by the named panel.
Missing/ambiguous/cyclic calls return false without rejecting configuration,
with a visible warning even on empty consuming panels. Hover explains the issue;
click opens its Effects page. Referenced renames ask for confirmation and atomically
update profile code and recognized references in retained editor buffers.

Full Lua5.1 suite **555 passed / 0 failed**, retained canonical suites **155 / 0**,
syntax **52 / 0**, manifest40 paths/XML valid, diffcheck clean. Independent review
complete. Full log: `/tmp/ke-panel-final-full2.log`.

Current source is `AddOns/eso-kana-addons/KanaEffects`, in the monorepo working
tree. No copy from the obsolete worktree and no external SavedVariables writes.
No native game check this follow-up: icon/dialog visuals need `/reloadui` and
actual client inspection.
