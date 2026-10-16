# Proposal

## Why

The previous change made the label's *character count* constant and claimed
that made its width constant. It does not, because the menu bar font is
monospaced for digits only.

Measured at 12pt on this machine:

| character | `monospacedDigitSystemFont` | `monospacedSystemFont` |
| --- | --- | --- |
| space | 3.272 | 7.418 |
| `0` | 7.741 | 7.418 |
| `%` | 11.589 | 7.418 |
| `·` | 3.786 | 7.418 |
| `!` | 3.931 | 7.418 |
| `?` | 6.348 | 7.418 |
| `✓` | 10.591 | 7.418 |
| `✗` | 9.814 | 7.418 |

So the four-character percent fields, which the previous change made equal in
characters, were nothing like equal in points:

| field | width |
| --- | --- |
| `␣␣9%` | 25.874 pt |
| `␣59%` | 30.343 pt |
| `100%` | 34.812 pt |

A nine-point spread, three times wider than the item is tall. The item still
moved, exactly as reported.

The glyph was worse: `!!` is two narrow `!`s, while `✓` is a wide fallback
glyph, so a verdict change moved the item too.

## What Changes

- **The menu bar item uses a fully monospaced font.** Every character —
  digit, space, percent sign, separator, and every verdict glyph including
  `✓` and `✗` — is 7.418 pt, so a label's width is its character count times
  one number. `zai 100%·100% !!` and `zai  59%· 47%  !` are both exactly
  118.688 pt.

- **The spec's claim is restated in the terms that are actually true.** The
  previous requirement said the character count is unchanged "so the item keeps
  the same width". That inference was wrong and is what let the defect through.
  The requirement now states the rendered width, and names the font property
  that makes it hold.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `menubar-quota-surface`: the label's rendered width is constant, and the
  requirement says why rather than assuming character count implies it.

## Impact

- `Sources/QuotaBar/StatusItemHost.swift` — one font, at item creation.
- No change to the label's composition; the fixed-width fields from the previous
  change are correct and stay.
- No new tests: the width is an AppKit font property and the app target has no
  test harness. It is verified from the logged item width instead, which is
  exactly the measurement that caught the previous claim being false.