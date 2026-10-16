# Design

## Context

See `proposal.md` — Why, which carries the measurements.

Two changes have now touched this label. The first made the fields
fixed-width in characters. The second makes the item fixed-width in points.

## Goals / Non-Goals

**Goals:**

- The item's rendered width does not change when figures change, and does not
  change when the verdict changes.

**Non-Goals:**

- No change to the label's content, the field widths, or the verdict vocabulary.
- Not padding with a computed number of points. See below.

## Decisions

### A fully monospaced font, not per-character padding

`monospacedSystemFont` measures every one of these glyphs at exactly 7.418 pt:
digits, spaces, `%`, `·`, `!`, `?`, and — the part that mattered — `✓` and
`✗`. So one constant turns character count into width, and the glyph no longer
drags the item with it.

Rejected: keep the proportional font and pad the last field by a computed number
of points, using `kern` on a trailing space. It would work, and it is worse:
padding would have to be recomputed whenever the system font size or the
scale changed, the widths would still differ by a rounding point, and the
`✓`/`✗` fallback would need its own compensation. Buying a font property with
per-run arithmetic is the wrong direction.

Rejected: `monospacedDigitSystemFont` for the whole label. Digits would be
monospaced, but the `%` beside them would not, and `59%` and `100%` would still
differ by three digits' worth of nothing.

### What the glyph looked like before

Worth stating because it is not obvious from the label: `!!` is two `!` at
3.931 pt each, `✓` is 10.591 pt and `✗` is 9.814 pt — and both are wider than a
single digit. So the verdict was the single largest source of width change,
and it is now indistinguishable from every other character.

## Risks / Trade-offs

- **SF Mono is a different look.** It is wider per character than the menu bar's
  proportional digits at the same point size, so the item is visually heavier.
  At 12 pt the item goes from about 104-121 pt to about 119 pt for a two-window
  subscription. That is the cost of a width that holds still.

- **A glyph outside SF Mono's coverage would fall back** and reintroduce a
  jump. The vocabulary is checked against the font's actual measurements, and
  all of `✓ ✗ ! ? · %` are covered at full advance width, so the risk is
  closed for the glyphs in use. A new glyph would need re-measuring; the
  measurement script is in the proposal.

- **No unit test can hold this.** Character counts are testable in the domain
  layer; rendered widths are not, and the app target has no harness. Verified
  from the item width the app already logs on every label change — the same
  measurement that disproved the previous claim.

## Migration Plan

None. Presentation only.

## Open Questions

None.