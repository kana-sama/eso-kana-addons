# Season One travel and daily tracking

## Data sources (checked 2026-10-08)

- Bethesda Support confirms 20 Favors per client, tracked separately for each
  character: https://help.bethesda.net/app/answers/detail/a_id/75308/
- ESO UI API 101051 exposes each Lore Library mail list and its unlocked count:
  `GetNumMailLists`, `GetMailListName`, `GetNumUnlockedMailsInMailList`, plus
  `EVENT_MAIL_LISTS_INITIALIZED` and `EVENT_MAIL_LISTS_UPDATED`:
  https://github.com/esoui/esoui/blob/live/ESOUIDocumentation.txt
  The native Lore Library displays these counts under Correspondence:
  https://github.com/esoui/esoui/blob/live/esoui/ingame/lorelibrary/keyboard/lorelibrary_keyboard.lua

- Official Update 50 patch notes: new Thieves Den in Daggerfall:
  https://forums.elderscrollsonline.com/en/discussion/693682
- Official Update 51 PTS notes tie the Ancient Direnni Quasigriff to
  "Heir to the Sage's Legacy":
  https://forums.elderscrollsonline.com/en-gb/discussion/697154/pts-patch-notes-v12-1-0
  ESO-Hub lists its three secret wing seals and final barrier criterion, in
  contrast to "Legend of the Nowhere Vault" for clearing rooms and stashes:
  https://eso-hub.com/en/achievements/heir-to-the-sages-legacy
  https://eso-hub.com/en/achievements/legend-of-the-nowhere-vault
  The Vault entrance is in Daggerfall's Thieves Den; the tab travels to the
  Daggerfall wayshrine, not directly into the Vault.
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

Version 1.4.1 uses ESO's `ZO_WorldMapHouseRow` template for the eight map entries.
That supplies the same name/location anchors, font, and 60-unit row spacing
as the Houses tab. The Season One tab has three `ZoFontHeader2` category labels.
A standalone check icon appears to the left of the name for completed entries.
Left-click travels when the map was opened at a wayshrine; right-click
opens the native menu to correct the mark. Actual rendering and interaction
still require an ESO `/reloadui` review.

The High Seas row has a daily check for turning in "Bounty of the Abecean Sea"
(or "Дары Абесинского моря"). The introduction does not count. Right-click can
correct a missed check manually.
The High Seas row is shown only between the announced dates; the code assumes
10:00 EDT (14:00 UTC) for event start/end because the official dates omit an
hour and the game API does not expose a reliable current-event flag.

The Nowhere Vault row has a permanent account achievement check. It scans the
client's achievement catalog for the 50-point, four-criterion achievement
awarding a Quasigriff, then reads `IsAchievementComplete`; "Legend of the
Nowhere Vault" cannot set it. The achievement's numeric ID and Russian reward
name were not available in published API data, so live `/reloadui` verification
on a Russian client is needed. The row has no manual completion override.

Completion is stored by character ID and server. Completion marks can be corrected
manually, including completions before installation. There is no retrospective
completion timestamp in the quest-history API.

For each Freerunner client, an unlocked Correspondence count of 20 or more
promotes the character's mark to permanent. This catches Favors completed before
installation, provided the game's mail lists have initialized. The addon rescans
on mail-list initialization, updates, and player activation. Daily reset and
right-click correction cannot clear a confirmed 20/20 mark. Mail-list titles are
matched by the client's name in English or Russian; live testing is needed to
confirm the localized list titles and the exact moment the twentieth letter is
added.

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
2. All three groups fit without changing native row spacing; the eight
   discovered wayshrines can be selected.
3. Ordinary map allows viewing/correcting checks, but no paid recall.
4. Final chest name and auto-loot event order on the current client; verify
   each encounter, and verify intermediate chests do not set the check.
5. Complete a Favor at each board; reload and change characters to verify storage.
6. Checks expire at the next server daily reset.
7. The High Seas row disappears after the event, and its daily check appears
   after turning in the quest on both English and Russian clients.
8. A character with 20/20 Correspondence for one client keeps that client's
   check after daily reset and reload; an alternate character does not inherit it.
9. The Nowhere Vault check appears only after "Heir to the Sage's Legacy", both
   immediately when awarded and after `/reloadui`; "Legend of the Nowhere Vault"
   alone leaves it clear.
