# Tasks

## 1. The label

- [x] 1.1 Compose the label as verdict, tag, then one fixed-width percent per
  window separated by a space, with no other character between windows. Verify:
  `!! mmx  63% 47%` and ` ? mmx  62%  47%` are both sixteen characters
- [x] 1.2 Keep the glyph's leading pad so its right edge does not move between a
  one-character and a two-character verdict, and the label starts on its
  reading rather than on a space. Verify: ` ✓` and `!!` are both two characters
- [x] 1.3 Leave the tooltip alone; it already names each window individually and
  has no separator to remove. Verify: the tooltip format is untouched

## 2. Tests

- [x] 2.1 Update the cases pinning exact label strings to the new composition.
  Verify: 149 cases pass
- [x] 2.2 Keep the width invariant covering every verdict and every figure
  combination, and add the single-window case. Verify: the case asserts sixteen
  characters for two windows and equal widths across every verdict

## 3. Verify and ship

- [x] 3.1 Run `swift run QuotaBarKitTests`. Verify: 149 pass
- [x] 3.2 `./scripts/install.sh`, then confirm the logged item width has not
  moved. Verify: `w=139`, the same as before the reorder, which is the whole
  claim — reordering the same characters cannot change their sum
- [x] 3.3 Update the README's example label. Verify: it reads `✓ zai   1% 52%`
- [x] 3.4 Archive and validate. Verify: `openspec validate --specs --strict`
  reports no advisory