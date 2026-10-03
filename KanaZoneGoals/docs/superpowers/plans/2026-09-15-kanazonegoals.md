# KanaZoneGoals implementation plan

Goal: Add selectable extra completion categories inside the exploration panel on the keyboard world map.
Approved design: conversation 2026-09-15; account-wide category preferences; no Eidetic Memory.
Architecture: pure progress model; ESO/API and existing library providers; an additional section in the native grid; LibAddonMenu settings. A new sibling addon, leaving KanaSSS untouched.

1. Test progress rules: only selected local criteria count, unknown data never becomes complete, disabled categories leave the denominator, duplicates are removed.
2. Implement Core.lua with ordered categories and grouped goal progress.
3. Implement Providers.lua: item sets via LibSets + ESO collection API; fishing via RareFishTracker; antiquities/codex via ESO API; side quests via LibQuestData + ESO quest API; sourced achievement/map associations for meetings, museums, local objectives and public dungeon bosses. Import additional maintained datasets when available. Track achievement/collectible unlocks, never guessed completion.
4. Add XML row/header templates and UI.lua using WORLD_MAP_ZONE_STORY_KEYBOARD.list; append after native RefreshInfo and commit the scroll list. Category rows expand to goal rows; goal tooltips show remaining criteria.
5. Add Settings.lua with one account-wide checkbox per category, hide-completed option, defaults reset, and refresh immediately after changes. Add custom achievement bindings for goals beyond source coverage.
6. Validate Lua syntax, model/provider/UI contract tests, manifest/XML, source provenance, and installation byte hashes. Document source coverage and in-game acceptance: open the world map exploration panel, switch zones, expand rows, toggle a category, reload, verify no duplication.
7. Install /AddOns/KanaZoneGoals with filesystem authorization. Report actual automated verification and remaining in-game acceptance separately.
