# Season One travel and daily tracking

## Data sources (checked 2026-10-05)

- Official Update 50 patch notes: new Thieves Den in Daggerfall:
  https://forums.elderscrollsonline.com/en/discussion/693682
  The map row travels to the Daggerfall wayshrine, not through the Den entrance.
- Official High Seas event dates (September 30–October 14, 2026):
  https://www.elderscrollsonline.com/en-gb/events/2923
- Official community manager: the event starts on the Gold Coast shore by Anvil;
  "Bounty of the Abecean Sea" is the repeatable daily after the introduction:
  https://forums.elderscrollsonline.com/en/discussion/comment/8526178
  The map row travels to the Anvil wayshrine, not straight onto the ship.
- ESO-Hub's Russian achievement text calls the daily "Дары Абесинского моря":
  https://eso-hub.com/ru/achievements/oxotnik-za-sokrovishhami-beskrainix-morei
  ESO-Hub warns that some Russian text is machine translated. The quest title
  and automatic check still need confirmation in the live Russian client.

- ESO UI source and API: https://github.com/esoui/esoui/tree/live
  - `esoui/ingame/map/keyboard/worldmapinfo_keyboard.lua` and `.xml`:
    native `WORLD_MAP_INFO.modeBar` and `ZO_WorldMapInfoContent`.
  - `ESOUIDocumentation.txt`: `EVENT_QUEST_REMOVED`, `QUEST_TYPE_FAVOR`,
    `GetJournalQuestStartingZone`, world-event participation and loot events.
  - `esoui/ingame/timedactivities/timedactivities_manager.lua`:
    `GetTimedActivityTypeResetTimeS` is an absolute timestamp.
- Freerunner boards: https://hyperioxes.com/eso/guides/favors
  Skywatch / Urcelmo, Ebonheart / Holgunn, Aldcroft / Arabelle.
- Per-character Favor limits: https://help.elderscrollsonline.com/app/answers/detail/a_id/75308/
- Server daily resets: https://help.elderscrollsonline.com/app/answers/detail/a_id/24640/
  03:00 UTC EU, 10:00 UTC NA; used when daily timed activities are unavailable.
- Dynamic Encounter Tracker 1.2.0 by R0ctan:
  https://www.esoui.com/downloads/info4726-DynamicEncounterTracker.html
  `DynamicEncounterTracker_Config.lua`: parent instances 98 / 95 / 96,
  final participation steps 35 / 30 / 17, child instance IDs.
  Only these observed identifiers are used; the tracker itself is not required.
- Map icon scaling: LibWorldMapInfoTab 1.2.7 by votan, public domain:
  https://www.esoui.com/downloads/info1568-LibWorldMapInfoTab.html
- Vampire reward fallback: native item ID 225219 = "Shard of Parched Stone",
  confirmed in installed `LibMultilingualName/LibMultilingualName_en/GetRawItemName_en.lua`.
  Encounter-specific drop: https://hyperioxes.com/eso/guides/dynamic-encounters
  ("Drops by Encounter / Vampire Hunt"). The source describes a guaranteed first
  daily shard, but the code does not assume that every run drops one.

## Tracking limits and live acceptance

Version 1.3.0 uses ESO's `ZO_WorldMapHouseRow` template for the eight map entries.
That supplies the same name/location anchors, font, and 60-unit row spacing
as the Houses tab. The Season One tab has three `ZoFontHeader2` category labels.
A standalone check icon appears to the left of the name for entries completed
today. Left-click travels when the map was opened at a wayshrine; right-click
opens the native menu to correct the mark. Actual rendering and interaction
still require an ESO `/reloadui` review.

The High Seas row has a daily check for turning in "Bounty of the Abecean Sea"
(or "Дары Абесинского моря"). The introduction does not count. Right-click can
correct a missed check manually. The permanent Thieves Guild row has no check.
The High Seas row is shown only between the announced dates; the code assumes
10:00 EDT (14:00 UTC) for event start/end because the official dates omit an
hour and the game API does not expose a reliable current-event flag.

Completion is stored by character ID and server. Completion marks can be corrected
manually, including completions before installation. There is no retrospective
completion timestamp in the quest-history API.

Favor checks follow actual quest removal with `isCompleted=true`, using the
cached starting zone rather than the player's current location. Abandonment and
ordinary quests do not count.

ESO does not expose a final-chest ID in the loot callback. Automatic encounter
tracking is therefore a conservative heuristic: final-stage participation,
parent-event deactivation, then personal item loot from a named reward chest
within 60 metres and three minutes. Opening a chest alone is not enough.
Only EN/RU reward-chest names are supported. A generic or differently named
chest may be missed unless its name was learned from the vampire-specific shard;
a delayed intermediate reward chest near the final one
cannot be conclusively distinguished by the API. Correct the checkbox manually
if needed. Loot consisting solely of currency is not detected.

Version 1.1.1 samples native participation every 500ms in the three zones and
on progress events. This catches late state updates after STEP_CHANGED and keeps
the player's position current during the final fight. Sampling never reopens an
ended encounter. A nearby personal loot receipt of item 225219 after the observed
vampire finale also marks completion, independently of chest localization. When
that receipt still has an object/fixture target, its exact name/type is retained
for later runs without a shard. No unverified Russian chest alias was added.

The last 100 diagnostic entries (participation, stages, deactivation, loot target
name/type and rejection checks) are saved per character. `/kstdebug` prints the
last ten. After `/reloadui` the log is available in
`live/SavedVariables/KanaSeasonOneTravel.lua`. The previous missed run cannot be
reconstructed: 1.1.0 had no diagnostic log. Live confirmation is still needed.

Lua tests use mocked ESO callbacks. In-game validation is still required for:

1. `/reloadui`, map opened at a wayshrine, right-side trophy tab "Season 1".
2. All three groups fit; the eight discovered wayshrines can be selected.
3. Ordinary map allows viewing/correcting checks, but no paid recall.
4. Final chest name and auto-loot event order on the current client; verify
   each encounter, and verify intermediate chests do not set the check.
5. Complete a Favor at each board; reload and change characters to verify storage.
6. Checks expire at the next server daily reset.
7. The High Seas row disappears after the event, and its daily check appears
   after turning in the quest on both English and Russian clients.
