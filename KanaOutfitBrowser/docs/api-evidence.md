# KanaOutfitBrowser: evidence for catalog and outfit preview APIs

Checked against the local `esoui` live source cache on 2026-09-21. The cache identifies API 101050 in `/tmp/esoui-live/ESOUIDocumentation.txt`. This is source-level evidence, not a successful run in the ESO client.

## Catalog contract

`ZO_COLLECTIBLE_DATA_MANAGER:GetAllCollectibleDataObjects(categoryFilters, collectibleFilters, sorted)` is defined in `esoui/ingame/collections/collectibledatamanager.lua:1481-1487`. `Catalog.Build()` passes no category filter, one `IsOutfitStyle() and IsArmorStyle()` collectible filter, and `sorted=true`.

For every returned data object:

- `data:GetId()` is the collectible ID used by `GetEligibleOutfitSlotsForCollectible(collectibleId)`, `CanCollectibleBePreviewed`, and the preview payload.
- `data:GetReferenceId()` is the outfit-style ID. It must not be used as a collectible ID.
- `data:GetOutfitStyleItemStyleId()` calls `GetOutfitStyleItemStyleId(referenceId)` and supplies the stable motif/item-style family. See `collectibledata_base.lua:311-316`.
- `data:GetVisualArmorType()` calls `GetOutfitStyleVisualArmorType(referenceId)`. See `collectibledata_base.lua:299-301`.
- `GetEligibleOutfitSlotsForCollectible` has variable returns, so the implementation captures `{ GetEligibleOutfitSlotsForCollectible(collectibleId) }`. See `ESOUIDocumentation.txt:22927-22929`.
- The actual enum globals are `VISUAL_ARMORTYPE_LIGHT`, `VISUAL_ARMORTYPE_MEDIUM`, and `VISUAL_ARMORTYPE_HEAVY`. The same enum also contains `CLOTHING`, `NONE`, `SIGNATURE`, and `UNDAUNTED`; see `ESOUIDocumentation.txt:5877-5884`.

Standard variants use `itemstyle:<itemStyleId>` as their `styleKey` and logical weights 1/2/3. Nontraditional visual armor types retain the raw enum in `itemstyle:<itemStyleId>:visual:<rawType>` and use logical weight 4, so two special types cannot collide. Zero or missing outfit-style/item-style IDs are omitted with a diagnostic; names are never used to guess a family.

ESO exposes no verified cuirass-versus-robe subtype API for two candidates targeting `OUTFIT_SLOT_CHEST`. The catalog therefore uses only canonical icon-path tokens (`chest` or `cuirass` before `robe`) as a deterministic heuristic, reports that limitation in diagnostics, and falls back to the lower collectible ID when the icon is unresolved. It never parses localized names. Diagnostics are development evidence and are capped; they should not be rendered as a long block in the normal UI.

`knownCount` counts the selected parts whose collectible data reports unlocked. `partCount` counts actual geometry supplied by the variant. `missingSlots` is the authoritative list for an incomplete outfit; locked but previewable parts are not geometrically missing.

## Live-client rejection — supersedes the original preview design

The user supplied an actual ESO screenshot showing `outfit_manager.lua:212: Attempt to access a private function AddOutfitSlotPreviewElementToPreviewCollection from insecure code`. This establishes that the native Lua wrapper is not an addon extension point. The original source-based feasibility claim was wrong; engine doubles in the original tests concealed the trust restriction.

API 101050 explicitly marks outfit-slot staging private (`ESOUIDocumentation.txt:22989`); `PreviewCollectible` is private too (23004). Public clear/apply functions do not provide a way to stage arbitrary armor collectibles. `PreviewItemLink` is public (23028), but no current native caller or demonstrated full-set batching was found. `SetPreviewingOutfitIndexInPreviewCollection` selects an existing outfit; it cannot describe a new arbitrary set. No speculative item-link loop is shipped.

Version 0.1.2 removes the rejected adapter. Preview.Open returns unavailable with a short Russian explanation; Select and Close touch no native preview APIs. The scene keeps normal FRAME_TARGET_STANDARD_RIGHT_PANEL player framing and no longer attaches item-preview/options fragments. The actual current appearance is explicitly distinguished from the selected catalog set. Full-set preview remains unimplemented.

Catalog completeness is also unresolved: screenshot shows eight variants. The native iterator path matches Collections, and logs show an omitted collectible, but its rejected ID field was not captured. `Catalog.lastDiagnostics` now records bounded omission samples with actual IDs/types plus counts. The controller saves this snapshot at catalog build/refresh for later inspection; grouping/filter logic has not been speculatively changed.

References:

- https://github.com/esoui/esoui/blob/live/ESOUIDocumentation.txt
- https://github.com/esoui/esoui/blob/live/esoui/ingame/outfits/outfit_manager.lua
- https://www.esoui.com/downloads/fileinfo.php?id=1598&page=2&so=DESC (historical author report of the same private API restriction)

## 0.1.3 — direct native input experiment

User requested further work on viewing sets; catalog work paused. `ZO_OutfitManipulator.UpdatePreviews` (native outfit_manager.lua:466–481) consumes only `self.outfitSlotManipulators`, runs native per-slot staging, and applies once. Version 0.1.3 assigns the original function reference directly to a dedicated button OnClicked and root OnKeyUp. No addon callback invokes that function. Prepared adapters contain seven slots, use original native slot methods via metatable, and use equal zero current/pending fields to clear absent parts. They do not refer to native saved/pending player outfits.

This is a different call entry hypothesis: engine → original native callback, rather than engine → addon function → native wrapper. The source proves the callback/payload contract, but not that the engine preserves trust when assigning it to addon controls. A real user click is required to confirm. No blanket claim that all addon preview paths are impossible is justified by the previous failed wrapper alone.

Native options/preview fragments restored in their required order; `forcePreparePreview=true`. After mode preparation, only ready owned-scene controls receive the native handler. Close unbinds targets and clears owned preview via public APIs. A failed mode setup does not arm handlers; nil selection clears and cancels readback. Public readback compares IDs/material indices for seven slots after actual input and emits ready only on match. This proves data equality, not visible rendering or engine trust.

Additional primary-source checks: downloaded Vestige Mirror 1.4.0 to `/tmp/kob-vestige-source` — its Preview.ShowAppearance returns immediately for isShared and only previews existing local outfit indices. Its shared links do not solve arbitrary full-set model preview. Votan 1.4.6 source downloaded to `/tmp/kob-votan-source`; advertised removed capabilities do not prove direct-native callback feasibility either. ESO-Hub Fashion Editor uses uploaded images, so is not treated as a 3D fallback.

## 0.1.4 — direct-native input rejected in real client

User supplied native-only stack: Outfit_Manager.lua:212 UpdatePreview → :476 UpdatePreviews, untrusted 2 stack frames. The direct-handler hypothesis is refuted. Disabled both handler entry points and item-preview fragment; button hidden. Regression ensures Open/Select/input cannot rearm native staging. No further catalog work. Full-set model-view objective remains unfulfilled; static reference galleries are an alternative requiring a user preference decision.
