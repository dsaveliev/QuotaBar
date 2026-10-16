# Tasks

## 1. The label

- [x] 1.1 Render the live label as the tag and the verdict glyph, with no
  percent and no separator. Verify: `zai✓` and `mmx!!`
- [x] 1.2 Write the tag and the glyph as one word, with no separator and
  no padding between them: `zai✓`, `mmx!!`
- [x] 1.3 Keep the tooltip unchanged, and confirm it still names every window
  with its percent. Verify: the explanation reads
  `MiniMax — 5h 58%, 7d 47% · ! close to the reset · updated 3m ago`
- [x] 1.4 Keep the fully monospaced font. Verify: `✓` and `✗` remain the same
  width as `!`, so a verdict change cannot move the item

## 2. Dead code

- [x] 2.1 Remove `PercentFormat.fixedWidth` and `menuBarWidth`; both existed only
  to reserve room for figures in this label. Verify: nothing references them and
  `swift build` is clean
- [x] 2.2 Keep `PercentFormat.text` untouched; the panel and the tooltip still
  format figures unpadded. Verify: `text(62)` is still `62%`

## 3. Tests

- [x] 3.1 Update the cases pinning exact label strings. Verify: the suite passes
- [x] 3.2 Rewrite the width-invariant case for a label that cannot vary: assert
  the tag plus glyph for every verdict and for one and several windows, and say
  in the case name that it is now a guard rather than a measurement. Verify: it
  passes and would fail if a figure were added back
- [x] 3.3 Drop the `fixedWidth` cases from the formatter tests

## 4. Verify and ship

- [x] 4.1 `swift run QuotaBarKitTests`. Verify: the count drops by the formatter
  cases removed, and everything else passes
- [x] 4.2 `./scripts/install.sh`, then confirm the item reads as the tag and the
  verdict and that its width no longer depends on anything. Verify: `w=` is a
  single value across verdicts
- [x] 4.3 Update the README: the opening example is the old label, and the
  "What the numbers mean" section has to say where the figures are read now.
  Verify: neither still claims the label carries percentages
- [x] 4.4 Archive and validate. Verify: `openspec validate --specs --strict`
  reports no advisory