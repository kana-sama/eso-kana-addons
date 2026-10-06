# Mixed-quality set damage: controlled dumps #11–#13

API 101051, addon 1.0.11 for #11/#12 and diagnostic version 1.0.12 for #13. These are native observations, not fitted source rules.

## Confirmed observations

- The same level-34 green lightning staff contributes 608 weapon/spell damage. Both `GetItemLinkWeaponPower` and `GetItemStatValue(BAG_WORN, slot)` return 608 in #13.
- In #12, the staff is the only equipped item. Base 1000 + staff 608 + Untamed Aggression CP 150 = native 1758. Major Brutality is absent. The set counts the staff as two pieces but its three-piece damage bonus is inactive.
- In #13, the level-35 purple ring of the same set is equipped again. Major Brutality is still absent; CP and the staff are unchanged. Native damage is 1819, so activating this set configuration adds exactly 61.
- For both equipped links, `GetItemLinkSetBonusInfo(link, true, 2)` describes the three-piece damage bonus as 63. The item-specific descriptions with `equipped=false` are 58 for the staff and 67 for the ring. `GetItemSetBonusInfo(34, 2)` describes 117; that generic set description is not the equipped amount.
- The two-piece stamina bonus is accurately described and attributed as 535 in #11/#13. Its item-specific values are 497 for the staff and 573 for the ring. Thus applying the same guessed weighting to every set statistic would break an already correct resource calculation.
- In #11, Major Brutality is present. Using the independently observed damage bonus gives `round((1000 + 608 + 150 + 61) * 1.20) = round(2182.8) = 2183`, exactly the native total. Using the described 63 gives 2185 and the observed residual -2.

The damage disagreement already exists without percentages in #13. Neither changing Major Brutality's 20% nor changing offhand power can fix it. The addon reads the description correctly, but its assumption that every equipped set description is an exact applied stat contribution is false in this configuration.

## Limits of the diagnosis

The [native item tooltip](https://github.com/esoui/esoui/blob/live/esoui/publicallingames/tooltip/itemtooltips.lua#L581) displays `GetItemLinkSetBonusInfo` descriptions directly. Its equipped description therefore does not provide an independent numeric measurement of the contribution. Historical [mixed-quality experiments and the UESP author's discussion](https://forums.elderscrollsonline.com/en/discussion/443721/mechanics-article-item-quality-and-its-effect-on-the-computation-of-set-bonus-value/p1) describe discrete scaling, rather than unrestricted arithmetic averaging; they do not establish an exact API 101051 formula for these mixed levels/qualities.

`floor((58 * 2 + 67) / 3) = 61` happens to reproduce the damage observation if the staff is weighted as two set pieces. It is **not a verified general rule**. In particular, the same weighting of stamina would give approximately 522 rather than the confirmed 535. Nor is changing every set damage amount from 63 to 61, or subtracting 2 from every source, justified.

Version 1.0.12 adds independent per-item/set audit readings only to full dumps. It does not change source calculations, hide residuals, or label the unverified weighting as a confirmed formula. Further implementation needs independent native evidence for a general mixed-level/quality damage rule; the three-piece bonus should not be corrected from a residual during normal gameplay.

## Additional quality experiment reported by the user

The user reports that a green ring's individual damage bonus is 58 and a purple ring's is 67. The green staff also describes 58. These measurements isolate the quality difference more directly than the two original links, whose required levels happen to differ as well. The original levels alone do not establish the cause of the damage discrepancy.

| Active combination | Actual damage bonus reported | Equipped description reported |
| --- | ---: | ---: |
| Green staff + green ring | 58 | 58 |
| Green staff + green ring + purple ring | 60 | 61 |
| Green staff + purple ring | 61 | 63 |

The last row is also independently supported by full dump #13. Full dumps for the first two combinations were requested during investigation. The user subsequently instructed us to accept the hypothesis and proceed without further dumps until the next discrepancy.

Two distinct hypotheses reproduce all three reported damage values:

- A weighted numerical mean, counting the staff twice, then flooring: `floor((58 * 2 + 58 + 67) / 4) = 60` and `floor((58 * 2 + 67) / 3) = 61`. Equal values stay 58. This is not established for other weapon arrangements and conflicts with applying the same rule to stamina in #13.
- A numerical mean of physical items, followed by quantization. Using the historical damage step `129 / 86 = 1.5`, first flooring the mean, then flooring to a step and flooring the result gives 60 from a mean of 61 and 61 from a mean of 62.5. Identical item values must remain unchanged for this candidate to reproduce 58. This candidate differs from UESP's final rounding and is not a verified current engine formula.

Thus the reported 58/60/61 alone do not distinguish staff weighting from discrete quality scaling. Existing native resource data is an important counterexample to applying damage weighting to all statistics.

## User-accepted working rule, version 1.0.13

At the user's explicit instruction, flat set weapon/spell damage now uses `floor(sum(individualDamage * activeItemWeight) / sum(activeItemWeight))`. Every active staff, bow, or two-handed axe/mace/sword has weight 2; one-handed weapons, shields, jewelry and armor have weight 1. Individual inputs come from `GetItemLinkSetBonusInfo(link, false, index)`, cached with equipment. Item identities, quality and level do not choose hardcoded amounts. Shared normal bonuses use all active items of the family; perfected-only bonuses use the perfected members. Required count, perfected flag, and description structure identify the corresponding bonus across items. Incomplete readings or unknown weapon metadata preserve the existing equipped-description calculation and record a diagnostic rather than average a subset.

The rule changes only the set's flat damage contribution, before percentage modifiers. It does not change resource/recovery/critical set amounts, signed residuals, or final rounding. Raw inputs, weights and both the equipped and averaged amounts are stored under the source's `damageAverages` in subsequent dumps. This is an explicitly accepted working hypothesis, not a claim that the engine's general quality formula has been independently proved.

Offline replay of the native #11–#13 inputs reconciles both damage totals (2183, 1758, 1819) and the existing stamina totals (27342, 26837, 22406). The original per-item descriptions for unchanged links in #11/#12 are taken from the independently captured audit #13; those older dumps did not record them. Tests also cover the reported 58/60/61 combinations, arbitrary item values and native weapon types, both bars, different set families, normal/perfected membership, unchanged percentage/non-damage clauses, missing inputs and preservation of an unrelated unknown +7. Synthetic arrangements test implementation behavior; they do not establish additional native game measurements.
