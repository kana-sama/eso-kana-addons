# KanaWritRecipes

Adds a gold **[Дейлик]** (Russian client) or **[Writ]** marker before recipe
names in the keyboard/mouse interface:

- Backpack, personal/subscriber bank, guild bank and housing storage lists.
- NPC merchants, selling and buyback.
- Guild trader search results and your listings.

Marks food and drink recipes used for ordinary daily provisioning writs at
all six Recipe Improvement ranks and across all alliances, including already
learned recipes. It does not require an active writ. Master writ recipes and
prepared food/drink are excluded. No dependencies or SavedVariables.

Recipes are matched by item ID, not translated names. Existing item data,
search/sort keys, quality colors and other addons are preserved. The label uses
part of the existing name column; long names may be truncated by the native UI.
Gamepad lists are not supported.

## Data sources

- [BenevolentBowD's provisioning writ list](https://benevolentbowd.ca/games/esotu/eso-provisioning-writs/),
  “Shopping List” and “Writ Group I–VI”, checked 2026-09-27. This uses the
  current six top-rank recipes, not the obsolete twelve-recipe rotation.
- Item IDs resolved from the installed LibMultilingualName English item-name
  database. The runtime addon does not depend on that library.
- UI contracts checked against [ESO UI live sources](https://github.com/esoui/esoui/tree/live/esoui/ingame):
  inventory/inventory.lua, storewindow/keyboard/storewindow_keyboard.lua,
  storewindow/keyboard/buyback_keyboard.lua and
  tradinghouse/keyboard/tradinghouse_keyboard.lua.

## Verification

From the eso-kana-addons directory: `lua KanaWritRecipes/tests/test.lua`.

In ESO, enable the addon and use `/reloadui`. Check a writ recipe in the bag,
bank, NPC store and guild trader. Scroll until the row is reused for another
item and verify that the marker disappears. Visual layout requires this live
check; the Lua tests cover logic and row callback integration only.
