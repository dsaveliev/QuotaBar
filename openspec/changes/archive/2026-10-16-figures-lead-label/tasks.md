# Tasks

## 1. The label

- [x] 1.1 Compose the label as the windows' percents, then the tag, then the
  verdict glyph, separated by spaces and nothing else. Verify: `100% 100% mmx !!`
  and ` 62% 41% zai  ✓` are both sixteen characters
- [x] 1.2 Keep the verdict's left pad so the label ends on the glyph rather than
  on padding, and its right edge does not move between `✓` and `!!`

## 2. Tests

- [x] 2.1 Update the cases pinning exact label strings to the new order. Verify:
  the suite passes
- [x] 2.2 Keep the width invariant covering every verdict and figure combination
  untouched, since reordering cannot change it. Verify: still sixteen characters
  everywhere, including the single-window case

## 3. Verify and ship

- [x] 3.1 `swift run QuotaBarKitTests`. Verify: 149 pass
- [x] 3.2 `./scripts/install.sh`, then confirm the logged item width has not
  moved. Verify: `w=139`, unchanged by the reorder
- [x] 3.3 Update the README's example label. Verify: it reads ` 1% 52% zai  ✓`
- [x] 3.4 Archive and validate. Verify: `openspec validate --specs --strict`
  reports no advisory