# Sources and limits (API 101051)

Native source: [ESO UI repository](https://github.com/esoui/esoui), API documentation `ESOUIDocumentation.txt` (101051), and `esoui/ingame/stats/keyboard/zo_statentry_keyboard.lua`.

`GetPlayerStat(stat, STAT_BONUS_OPTION_APPLY_BONUS)` is the authoritative rating/integer. `DONT_APPLY_BONUS` is captured for investigation, but does not prove a pure base value. Never infer a base from the unexplained remainder.

[ZOS Update 29 notes](https://forums.elderscrollsonline.com/en/discussion/564242/pc-mac-patch-notes-v6-3-5-flames-of-ambition-dlc-update-29) establish base health 16000, magicka/stamina 12000, weapon/spell damage 1000. This rule is limited to API 101051, level 50, CP160+, and explicitly absent battle leveling. Other contexts retain the residual. Base recovery and base critical rating are not guessed.

`GetAttributeDerivedStatPerPointValue(attribute, stat)` supplies the native current delta used by `ZO_AttributeSpinner_Shared` for pending stat bonuses. Committed points use this delta, with operation `effectiveFlat` to avoid multiplying it again. Pending points are separate from current totals.

`GetItemLinkArmorRating(link, true)` includes condition and local traits; `GetItemLinkWeaponPower(link)` is the item's power. Main-hand power is attributed directly; the offhand's effective scaling is a candidate pending evidence. Item-specific enchant descriptions are already adjusted for Infused. Charged glyphs require an active effect. Trait IDs determine the trait's meaning; unrecognized traits do not contribute guessed values.

`GetItemLinkSetInfo(link, true)` returns normal and perfected active equipped counts. Normal thresholds use their sum; perfected thresholds use only perfected count. `GetItemSetUnperfectedSetId` identifies the family. Family, threshold, perfected flag and description deduplicate shared bonuses across links. Conditional proc descriptions remain candidates even at the required item count.

Descriptions support complete RU/EN stat clauses. The parser stops at a conditional/unknown tail, retaining recognized permanent prefixes. It never treats item quantities, proc probability or duration as stat amounts. Raw text, IDs and parsing diagnostics are preserved in dumps.

Critical conversion is calibrated from `GetCriticalStrikeChance(0/1/100/1000/current/current+1000)` on the running client. It validates slope, intercept and saturation before displaying a formula. No universal coefficient is hardcoded.
