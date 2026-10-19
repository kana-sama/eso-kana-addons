# Sources and verification

Checked 2026-10-19 against installed Character Knowledge 3.1.4 (API 101051).

- [ESO in-game Scribing help](https://eso-hub.com/en/ingame-help/scribing):
  the three script pools, unlocking wings, guild pickups and Class Mastery.
- [Scribing sources](https://eso-hub.com/en/scribing): nine daily sources,
  actual coffer opening, and the additional random-dungeon Affix reward.
- [Daily guarantees and character/account scope](https://forums.elderscrollsonline.com/en-gb/discussion/680449/reconfigured-scribing-has-me-very-confused):
  the correction in the July 2025 discussion distinguishes nine account
  guarantees from the random-dungeon reward per character.
- [ESO API 101051](https://github.com/esoui/esoui/blob/live/ESOUIDocumentation.txt):
  `GetCraftedAbilityScriptAcquireHint`, `GetCraftedAbilityScriptScribingSlot`,
  `GetLootTargetInfo`, `EVENT_LOOT_RECEIVED`, mail attachment events, and
  `GetTimedActivityTypeResetTimeS`.
- Native [English](https://github.com/esoui/esoui/blob/live/esoui/lang/en_client.lua)
  and [Russian](https://github.com/esoui/esoui/blob/live/esoui/lang/ru_client.lua)
  strings: `SI_LFGITEMREWARDTYPE1/2` identify Undaunted reward mail subjects
  without translating or guessing the Russian text.
- [Server daily resets](https://help.elderscrollsonline.com/app/answers/detail/a_id/24640/):
  EU 03:00 UTC, NA 10:00 UTC; fallback if the daily timed-activity reset API
  returns zero, an expired time, or a time more than a day away.
- Pickup instructions: [Mages Guild](https://eso-hub.com/en/guides/guide-to-guild-daily-quests-eso/mages-guild),
  [Fighters Guild](https://eso-hub.com/en/guides/guide-to-guild-daily-quests-eso/fighters-guild),
  [Bolgrul](https://eso-hub.com/en/guides/guide-to-guild-daily-quests-eso/undaunted),
  [Blackwood delve/boss examples](https://eso-hub.com/en/guides/zone-dailies/blackwood-dailies),
  [Galen event example](https://eso-hub.com/en/guides/zone-dailies/galen-dailies),
  [Cyrodiil towns](https://eso-hub.com/es/events/whitestrakes-mayhem),
  [Imperial City district access](https://eso-hub.com/en/guides/imperial-city-guide).

## Source icons

Daily pages show exactly three separate icons, in zone/guild/PvP order.
Random dungeon mail remains recognized by the tracker but is not a fourth
daily icon. Special and unknown scripts keep Character Knowledge's original
markers and native row tooltips. Each source has a short individual tooltip,
anchored left of the entire icon group, with task and pickup instructions.

Icons use native textures already referenced by installed LibSets, MapPins,
LuiExtended and Character Knowledge. Their sizes come from the native suffix
cell. A separate anchor preserves the original name-cell boundary for later
columns while reserving text space for the three icons. Recycled rows restore
the original name width and column anchor; row height and sort keys stay intact.
All added row children have unique names so native `ColorRow` can enumerate
them through `GetChild`. They are `nonRecolorable`; native row text keeps its
normal hover coloring, while source-icon opacity remains controlled by receipts.

An icon has alpha 0.45 only when the selected character received a script
from that source today. Other characters' account receipts are mentioned in
the tooltip but do not dim this character's icon. Visible marks refresh every
second, including character changes and daily expiry. Right-click corrects
only the clicked source. The existing SavedVariables schema is retained.

`CharacterKnowledge/Browser.lua` provides the existing `NameSuffix` cell,
`SetupItemRow` hook, seven quest scripts and nine guild pickups. The library's
`BaseData.101051.lua` maps Class Mastery to script 31 and the latest known script
to 70. Unknown/new script IDs show their native acquire hint without assigning
them an unverified daily pool. Upstream files and SavedVariables are unchanged.

Coffer item IDs and exact English names were checked in the installed
`LibMultilingualName/LibMultilingualName_en/GetRawItemName_en.lua` catalogue.
Runtime resolves localized names using those IDs and filters for containers.
The catalogue is an authoring reference, not a dependency. Shared DLC coffer
names are disambiguated by the script actually received: Focus → delve,
Signature → world boss, Affix → world event. Gold Coast can award both Focus
and Signature. Guild, Cyrodiil, Imperial City and Rewards for the Worthy have
separate name sets. Event bonus boxes, ordinary enemies and unknown containers
are deliberately not mapped to a daily source.

## Tracking boundaries

The optional hide-known filter uses CK's `ratioKnown`, refreshed by
`RefreshKnowledge` for the selected server and character. It removes known
entries from the native search result only in Scribing, before native sorting.
The master list and native known/total counter remain unchanged. The checkbox
shares the search row to the left of its caption, fitting its label into the
available space after the native account filter when that filter is visible.
Search, sort headers and the native scroll area keep their geometry. Other categories and Research
hide the checkbox and retain their original filtering. `hideKnown` defaults
to false in the existing SavedVariables table; the browser and own settings
checkboxes share this value and update immediately without reload.

- A receipt records any ordinary page from an activity, not the particular
  page currently under the pointer. Account status aggregates character
  receipts; correcting one character does not erase another's receipt.
- A new/foreign loot target clears the coffer context. An empty target at the
  final auto-loot event can reuse only a script observed in that open coffer,
  for at most 60 seconds. Loot close and player deactivation clear it.
- Dungeon mail must be system mail with a localized Undaunted reward subject,
  an observed Affix attachment and a successful take-attachments event.
  Merely opening the mail does not count. Bulk mail claim paths that never
  expose readable attachments may be missed. These records are retained for
  compatibility; dungeon mail has no separate source icon or correction menu.
- An older stored reward opened today records today's receipt. This is not a
  server-side query of remaining guarantees. There is no reconstruction of
  receipts before installation, while disabled, or on another installation.
- Other-account data imported into Character Knowledge remains unobserved;
  corrections are limited to the current account and server.
- Both features have separate own-menu checkboxes. Reload is requested after
  changing them so already visible native rows are rebuilt consistently.

## Local checks and client acceptance

Run from the repository root:

```sh
lua KanaScribingScriptSourceHint/tests/test_model.lua
lua KanaScribingScriptSourceHint/tests/test_events.lua
lua KanaScribingScriptSourceHint/tests/test_ui.lua
lua KanaScribingScriptSourceHint/tests/test_integration.lua
lua KanaScribingScriptSourceHint/tests/test_filter.lua
```

Tests cover source exceptions, real receipt vs preview, last-item auto loot,
foreign loot, reset boundaries, per-character/account/server isolation,
manual corrections, mail receipts, three distinct icons, per-source opacity,
reused rows, disabling features, column positions at different name widths,
short screens, scroll access, tooltip shrinkage and preserving native row
highlighting and keyboard actions over source icons.
The integration fixture also executes the native `ColorRow` child traversal
on setup, refresh and hover, including nil results for unnamed children.
Filter tests cover search, sorting, personal knowledge, selected-character
changes, saved state, empty results, other categories and the native scroll
container with a short viewport.

In ESO, after one `/reloadui`, verify together:

1. In Character Knowledge's Scribing list check three distinct icons on each
   ordinary daily page, individual task/pickup tooltips to their left and
   unchanged native markers on special pages. Filter to a motif/recipe and back. Check
   sort headers, character selection, scrolling, normal row menus and clicks,
   row highlighting and the primary keyboard action over the source icon.
2. Open and actually loot a known daily coffer; verify only its source icon
   dims for that character. Another character's icons should stay bright,
   with the account receipt mentioned in the source tooltip. Bank transfers and purchases must not
   set a daily mark. Include auto-loot and closing an unlooted coffer.
3. Use right-click on a source icon: correcting its mark must immediately
   update that source across the visible list, leaving the other two unchanged.
4. Try a small UI viewport, long names, screen edges, moving the cursor into
   the tooltip, scrolling and large-to-small reuse. Other ESO tooltips must
   retain their layout.
5. Correct a mark through the icon menu, change character and reload; verify
   persistence and expiry at the next server daily reset.
6. Toggle «Скрывать известные», search and change the selected character.
   Known scripts and grimoires should disappear for that character only.
   Check the checkbox on the search row and sort arrows at your UI scale, then switch to
   motifs and Research and verify their usual behavior.

Lua mocks validate logic and control structure; they do not validate ESO's
actual rendering, mail/coffer callback order or server-side reward handling.
