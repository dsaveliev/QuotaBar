# Tasks

## 1. Fixed-width fields

- [x] 1.1 Add a percent that is right-aligned in four characters, alongside —
  not in place of — the existing `PercentFormat.text`, which the panel uses and
  must not pad. Verify: `swift build` is clean and `text(62)` still returns
  `62%` with no padding
- [x] 1.2 Compose the live label from fixed-width fields: tag in three
  characters, each percent in four, the glyph in two, padding on the left of
  each. Verify: `zai 100%·100% !!` and `zai  59%· 47%  !` are both sixteen
  characters
- [x] 1.3 Leave the loading and error labels unpadded. Verify: `zai …` and
  `zai ?` are unchanged in length

## 2. Tests

- [x] 2.1 Assert that two labels with different figures have the same character
  count, across two windows and one, and across every verdict in the
  vocabulary. Verify: a case over all verdicts finds no length that varies
- [x] 2.2 Assert that no live label ends in whitespace, so AppKit cannot trim
  the last field away. Verify: a case checking `hasSuffix(" ")` is false for
  every verdict
- [x] 2.3 Assert the field widths directly, including a percent above 100 and an
  unknown percent. Verify: `PercentFormat.fixedWidth` returns four characters
  for `62%`, `0%`, `100%`, `999%` and `?`

## 3. Verify and ship

- [x] 3.1 Run `swift run QuotaBarKitTests`. Verify: all cases pass
- [x] 3.2 `./scripts/install.sh`, then let several refreshes land and confirm
  the item's logged width does not move. Verify: consecutive `menu bar:` log
  lines for the same subscription all report the same `w=`
- [ ] 3.3 Open the panel and confirm its figures are still flush left, with no
  padding introduced. Verify: a screenshot of the panel
- [x] 3.4 Archive and validate. Verify: `openspec validate --specs --strict`
  reports no advisory