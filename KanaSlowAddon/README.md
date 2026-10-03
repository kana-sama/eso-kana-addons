# KanaSlowAddon

Personal local fork of SlowDialogs 1.13 by Shinni. Original license and translations retained.

Disable SlowDialogs and enable KanaSlowAddon in the ESO addon list, then reload the UI.
Do not enable both: both replace the same dialogue functions.

During a keyboard dialogue, `/kslow` toggles instant text for the current speaker or board.
The preference is saved account-wide, keyed by the raw interaction name and client language.
Identical names share a preference. Changing the client language uses a separate list.
The command reports the new state; outside a dialogue it changes nothing.
Enabling instant mode reveals the current line. Disabling affects subsequent lines.
The original automatic bank, shop, stable and trading-house bypasses remain active.

While a line is appearing, the primary action reveals it and the answers without selecting
an answer. The next press behaves normally. Clicking the speaker title also reveals text.

Settings and saved speaker preferences use KanaSlowAddon_SavedVariables, independent of SlowDialogs.
This fork retains the original keyboard dialogue scope; it does not add a gamepad renderer.

Tests (Python with lupa installed): `python tests/run.py /path/to/KanaSlowAddon`
Live acceptance: toggle a companion/board twice, reload after enabling instant mode,
then check the primary action on a regular slow dialogue.
