# Tooltip fixes, 2026-10-06

The user's eight requested fixes supersede the original critical-rating footer design.

1. Critical rows show percentages. The footer contains only `Итого` and the native total percentage, with no rating/formula.
2. Outer width is the maximum of the native default (350 UI units) and the width required by the longest source name, its icon, column gap and widest value. Description length must not enlarge it. Screen bounds are the only upper limit.
3. Base rows have an icon. Attributes use the same health/magicka/stamina icons as KanaWardrobe's info panel.
4. Explain the universal base 10% critical chance; convert its contribution with the running client's calibrated API rather than a hardcoded rating coefficient.
5. Reconcile rounding of contributions as a whole, preserving raw values and genuine signed unknowns. The observed pattern is 3148 + 14% + 20% = 4218.32, while independent row rounding produces 4219.
6. Preserve content and dimensions throughout native fade-out. Clear only after hiding or before a new tooltip render.
7. Omit zero contributions from the visible breakdown, retaining captured source data in dumps.
8. Stat tooltips must not modify InformationTooltip, used by the map and other native UI.

Use a private native ZO_BaseTooltip control. Keep source collection cached and descriptions measured in logical UI units. Stable content must not change geometry during repeated refreshes. Automated ESO control doubles verify lifecycle and geometry contracts; live rendering requires a client reload and cannot be claimed from those tests.
