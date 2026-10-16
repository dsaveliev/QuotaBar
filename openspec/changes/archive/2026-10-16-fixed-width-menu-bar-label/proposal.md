# Proposal

## Why

The menu bar item changes width on almost every refresh. `59%` is three
characters, `100%` is four, so crossing a digit boundary resizes the item; a
verdict moving between `!` and `!!` resizes it again. AppKit reflows the whole
menu bar each time, and the figures the user is trying to read shift sideways
while they read them.

`PercentFormat` already says it wants a stable width — its comment claims
"the longest text stays four characters wide" — but it caps the value at
`999%` and never pads. The cap bounds the widest case; it does not make every
case that wide.

## What Changes

- **The live label is laid out in fixed-width fields**: a three-character
  provider tag, each percent right-aligned in the four characters its maximum
  needs, the separator, then the verdict glyph in the two characters its widest
  value needs.

  ```
  zai 100%·100% !!
  zai  59%· 47%  !
  ```

  Both are sixteen characters. The item's width stops depending on its contents.

- **Padding goes on the left of each field**, so the separator and the glyph
  hold their positions as figures change, and the title ends on the glyph with
  no trailing whitespace for the layout to trim.

- **The loading and error labels stay short.** `zai …` and `zai ?` remain
  unpadded. Padding them to sixteen characters would leave a gap the width of
  five figures, which reads as missing content rather than as a fixed slot.
  Those states are entered once at launch, not on every refresh.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `menubar-quota-surface`: the status label reserves a fixed width for each of
  its fields, so the item does not resize as figures change.

## Impact

- `Sources/QuotaBarKit/Format/DurationFormat.swift` — a fixed-width percent,
  used only by the menu bar label.
- `Sources/QuotaBarKit/Engine/SubscriptionSnapshot.swift` — `menuBarLabel()`
  composes fixed-width fields.
- `Sources/QuotaBarKit/Engine/Verdict.swift` — nothing; the glyph is already a
  `String` and padding it is one line at the call site.
- Tests: every field's width, and that two labels with different figures have
  identical length. `PercentFormat.text` itself is unchanged, because the panel
  uses it and must not be padded.