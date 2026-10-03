# Data provenance

Snapshot assembled 2026-09-15. Names, descriptions and completion values are read from ESO at runtime.
Only factual identifiers and source associations are retained in the bundled catalogs.

| Source | Usage |
| --- | --- |
| Installed MapPins 1.100.22, `MapPins.lua` | 1017 map / achievement / criterion associations in Data.lua; public dungeon pins filtered using LibSets. MIT notice in THIRD_PARTY_NOTICES.txt. |
| [USPF 7.5.0](https://www.esoui.com/downloads/info1863.html), `USPF.lua` | Public dungeon group-event achievement IDs and parent zones. |
| [Zone Dailies Achievement Tracker](https://www.esoui.com/downloads/info4077.html), `Data/Achievements.lua` | Final tier daily achievement IDs and wayshrine IDs; region resolved through the game API. |
| [LibMotif](https://www.esoui.com/downloads/info3036.html), `LibMotif_Data.lua` | IDs of 25 motif-learning achievements; acquisition zones verified against individual UESP style pages. |
| [UESP Styles](https://en.uesp.net/wiki/Online:Styles) and individual linked style pages | Motif acquisition-zone associations in ExtraData.lua (Trinimac through House Hexos). |
| [UESP Public Dungeon Fragments](https://en.uesp.net/wiki/Online:Fragments#Public_Dungeon_Fragments) | Collectible IDs and their public-dungeon locations, in ExtraData.lua. |
| [Lead List 50.1.1](https://www.esoui.com/downloads/info4159.html) | Runtime mythic item IDs, lead sources and find-versus-excavation zone overrides; maintained dependency. |
| Installed LibSets | Runtime set-to-drop-zone and public-dungeon classification. |
| Installed LibMapData | Runtime map texture to map ID lookup. |
| Installed RareFishTracker, `RFT.zoneToAchievement` | Runtime fishing achievements; optional dependency. |
| Installed LibQuestData | Runtime quest IDs, repeat/prologue classification; optional dependency. |
| [ESO UI source](https://github.com/esoui/esoui) and ESOUIDocumentation.txt | Native world map exploration scroll-list extension and progress APIs; no replacement of the native activity list. |

The two generated factual tables do not automatically update when MapPins/USPF/ZDAT change.
LibSets, RareFishTracker and LibQuestData data are consumed from the installed versions at runtime.
No quest chronology database, guessed coordinates or Eidetic Memory entries are included.
