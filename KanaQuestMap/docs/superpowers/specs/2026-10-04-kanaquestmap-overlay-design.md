# KanaQuestMap as a QuestMap overlay

## Goal

Make `KanaQuestMap` an update-safe extension of the installed `QuestMap`
addon. Updating the upstream `QuestMap` folder must never overwrite Kana's
features.

## Scope

The upstream `QuestMap` folder remains unmodified. `KanaQuestMap` becomes a
small dependent addon rather than a renamed copy of QuestMap.

The overlay preserves the currently installed Kana behavior:

- DLC chronology in QuestMap pin tooltips, using The Questing Guide when it is
  available;
- suppression of pins in Kana's permanent quest blacklist;
- special pin priority for started quests and already-completed repeatable
  quests;
- removal of LibQuestData's false Stonefalls/Davon's Watch pin for quest 4493,
  “A Fair Warning”;
- completion checkmark for an already-completed repeatable quest in the
  keyboard quest journal;
- the Kana blacklist UI.

## Addon boundary and load order

`KanaQuestMap.addon` declares `QuestMap` as a required dependency, so ESO
loads QuestMap first. The manifest loads only Kana-owned modules. It no longer
loads copied `Init.lua`, `PC/Main.lua`, `PC/Settings.lua`, `console/Main.lua`,
translations, or QuestMap icon assets.

The new code owns the global `KanaQuestMap` table. It reads the public
`QuestMap` table created by the upstream addon but does not replace it.

## Pin integration

After QuestMap has registered its pin types, the overlay installs a narrow
wrapper around LibMapPins' `CreatePin` method.

The wrapper acts only on QuestMap's registered quest pin types and only when
the pin tag is QuestMap's `{ id = questId, pinName = ... }` table. It:

1. returns without creating a pin when `questId` is in Kana's blacklist;
2. redirects started quests to QuestMap's started-pin type;
3. redirects a completed repeatable quest to QuestMap's completed-pin type;
4. leaves all non-QuestMap pins and unmodified QuestMap quests untouched.

The overlay decorates the existing tooltip creators of QuestMap pin types,
retaining their original output and adding one chronology line when TQG can
identify the quest. It does not change the pin name supplied by QuestMap.

For the known LibQuestData error, the overlay wraps only
`LibQuestData:get_quest_list(mapTexture)`. It removes quest 4493 only from
`stonefalls/davonswatch_base_0` and `stonefalls/stonefalls_base_0`, leaving all
other library callers and locations unmodified.

## Settings and saved variables

The original QuestMap settings panel remains upstream-owned. Kana settings are
shown in their own `KanaQuestMap` LibAddonMenu panel. The panel contains the
blacklist input, the list of blacklisted IDs, and deletion buttons.

`KanaQuestMap_SavedVariables` remains the authoritative store for
Kana-specific settings, especially the blacklist. On first overlay load, a
one-time migration fills only missing entries in `QuestMap_SavedVariables`
from the old fork's QuestMap settings. Existing upstream QuestMap values always
win. Nested tables are merged by missing key, so the migration preserves both
old manual hides and any settings already used in upstream QuestMap.

## Journal indicator

On keyboard UI clients, the overlay post-hooks the native quest-journal detail
refresh. It shows the existing checkmark only when the currently selected quest
is repeatable and the exact journal quest ID is in `LibQuestData.completed_quests`.
It has no effect on the quest-list rows or console UI.

## Compatibility and failure behavior

The overlay requires QuestMap. TQG is optional: without it, pins and
blacklisting still work and the chronology line is omitted. If an expected
QuestMap pin type or tooltip creator is absent after an upstream update, that
single extension feature is skipped with a debug message rather than breaking
QuestMap's map.

## Verification

Automated Lua/Python tests will cover manifest dependencies, the non-copying
file list, migration merge behavior, pin filtering/reclassification, chronology
decoration, and journal completion behavior. Every loaded Lua module will pass
`luac -p`.

Live acceptance requires `/reloadui`, then confirming:

1. both QuestMap and KanaQuestMap load;
2. QuestMap settings are still present;
3. KanaQuestMap's blacklist input/list render;
4. a blacklisted quest has no map pin;
5. a normal QuestMap pin has its chronology tooltip line.
