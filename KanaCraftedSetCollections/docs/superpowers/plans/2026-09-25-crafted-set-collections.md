# Crafted Set Collections Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show crafted sets inside the keyboard Item Set Collections location categories, searchable by the native search field, with one collected-looking example item and a visible trait requirement.

**Architecture:** `Catalog.lua` builds a read-only index from public LibSets APIs. `Integration.lua` extends the keyboard book's category filtering and grid commit at display time, using view-model proxies for crafted entries. `Tile.lua` prevents reconstruction and supplies crafted tooltips. No game collection data manager mutation or set database is allowed.

**Tech Stack:** ESO Lua addon, LibSets 0.9.x public API, native `ITEM_SET_COLLECTIONS_BOOK_KEYBOARD` and grid controls, standalone Lua tests.

**Spec:** `KanaCraftedSetCollections/docs/superpowers/specs/2026-09-25-crafted-set-collections-design.md`

## Global Constraints

- Keep the upstream ESO UI and LibSets files untouched.
- Add no hand-maintained set-to-zone or set-to-item table.
- Support the keyboard Collections book; hide crafted entries at a transmute station.
- Preserve native category and summary progress counts.
- Keep map controls and the crafted-header progress bar out of the reference entries.
- The AddOns workspace has no Git repository, so there are no commit steps.

## Review Focus

- A crafted set present in two zones appears once per matching location category.
- Crafted-only search results keep their native location categories visible.
- A fallback entry appears when no native location category maps to a set.
- A crafted tile cannot trigger reconstruction even though it looks collected.
- Switching to reconstruction or native categories leaves no stale custom controls.

---

### Task 1: LibSets catalog

**Files:** Create `KanaCraftedSetCollections/Catalog.lua`, `KanaCraftedSetCollections/tests/catalog_test.lua`.

**Interfaces:** `KanaCraftedSetCollections.BuildCatalog(lib) -> { byCategory, fallback, all }`; each row contains `setId`, `name`, `itemLink`, `icon`, `traitsNeeded`, and `zoneIds`. `KanaCraftedSetCollections.FilterRows(rows, query) -> rows`.

- [x] Write a failing Lua test with fixed LibSets-shaped input: one single-zone set, one multi-zone set, one unmapped set, and a duplicated zone; assert exact category membership and one row per category.
- [x] Run `lua KanaCraftedSetCollections/tests/catalog_test.lua` and observe a failure because catalog functions do not exist.
- [x] Implement `BuildCatalog` using `GetSetTypeSetsData(LIBSETS_SETTYPE_CRAFTED)`, `GetItemSetCollectionToZoneIds`, `GetSetName`, `GetSetItemId`, `buildItemLink`, `GetTraitsNeeded`, and `GetZoneIds`. Accept only zone-backed non-dungeon/trial/arena mapping records. Derive a display icon from the example item link.
- [x] Implement case-insensitive localized name filtering. Re-run the test and confirm all assertions pass.

### Task 2: Crafted view-model and safety boundaries

**Files:** Create `KanaCraftedSetCollections/Tile.lua`, `KanaCraftedSetCollections/tests/tile_test.lua`.

**Interfaces:** `KanaCraftedSetCollections.MakeHeader(row) -> headerProxy` and `KanaCraftedSetCollections.MakePiece(row) -> pieceProxy`; `KanaCraftedSetCollections.InstallTileHooks()` extends native tile/header behavior for proxies only.

- [x] Write a failing test for header progress `1/1`, piece unlocked appearance, example item link, no new status, and `CanReconstruct() == false` for a crafted tile.
- [x] Run `lua KanaCraftedSetCollections/tests/tile_test.lua` and observe the expected missing-function failure.
- [x] Implement proxies that mark their own row as crafted; hook native tile reconstruction and tooltip methods only when that marker is present. Render a normal item-link tooltip for crafted tiles and keep native behavior for all others.
- [x] Re-run the test and confirm both crafted and native behavior assertions pass.

### Task 3: Native category, search, and grid integration

**Files:** Create `KanaCraftedSetCollections/Integration.lua`, `KanaCraftedSetCollections/tests/integration_test.lua`.

**Interfaces:** `KanaCraftedSetCollections.InstallBookHooks(book, catalog)` installs idempotent keyboard UI hooks and restores native header controls on reuse.

- [x] Write a failing integration test with a minimal real-method-shaped keyboard book fixture: crafted-only query keeps a matching category visible; grid commit appends one crafted entry; reconstruction and a nonmatching query append none; native entries remain untouched.
- [x] Run `lua KanaCraftedSetCollections/tests/integration_test.lua` and observe the expected missing-hook failure.
- [x] Wrap category filtering during native category refresh so a category passes when native matches or local crafted-name matches. Add a fallback category when needed. Before the native grid commit, append crafted proxies for the selected category, filtered by the search field.
- [x] Add a full-width requirement line below the crafted name; hide native progress and reconstruction cost, and restore them whenever a reused header displays a native set. No map button is created.
- [x] Re-run the integration test and verify normal categories, search, fallback, requirement visibility, and reconstruction guards.

### Task 4: Addon wiring and verification

**Files:** Create `KanaCraftedSetCollections/KanaCraftedSetCollections.txt`, `KanaCraftedSetCollections/Main.lua`, `KanaCraftedSetCollections/README.md`; update any test fixtures needed for the final API shape.

- [x] Add a manifest with `LibSets` as a dependency and load the catalog, proxy, integration, and main files in that order.
- [x] Initialize after both LibSets and `ITEM_SET_COLLECTIONS_BOOK_KEYBOARD` are available; install hooks once and fail closed with one session message if integration is unavailable.
- [x] Run all addon Lua tests and `luac -p` on every Lua file. Inspect the resulting files and confirm no upstream file was changed.
- [ ] Verify in ESO when a game session is available: crafted and dropped sets in one zone, Russian-name search, fallback, full requirement text, no crafted progress bar or map button, no reconstruction, and unchanged native category progress. The in-game check remains outstanding.

## Execution notes

- The AddOns directory is not a Git repository; files were added directly under the new addon directory, with no upstream edits or commit.
- Ruling: sets without an example item link are omitted from the display catalog because they cannot produce the requested collected-looking tile or bonus tooltip. Cost if wrong: an incomplete LibSets entry stays undiscoverable until its item ID is supplied.
- Superseded by user screenshot: the previous requirement label was constrained between the progress bar and the map button, leaving only “Требуется” visible. The revised header removes both controls and gives the requirement the full line below the name.
