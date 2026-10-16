# Design

## Context

See `proposal.md` — Why.

The label is composed in `SubscriptionSnapshot.menuBarLabel()` from a tag, a
percent per window, and a verdict glyph, and handed to `NSStatusBarButton.title`
as a single string. The button's width follows the string. Nothing in the app
reserves space, so every digit boundary costs a reflow.

The button already uses `monospacedDigitSystemFont`, so character counts are
the whole story: a fixed character count is a fixed width.

## Goals / Non-Goals

**Goals:**

- Two labels showing different figures have the same rendered width.
- No trailing whitespace in the title.
- The panel's own figures must not gain padding.

**Non-Goals:**

- No change to which figures are shown, to the verdict vocabulary, or to the
  glyphs.
- No padding on the loading and error labels; see the proposal.
- Not a monospaced font for the whole title. The tag and glyphs are already
  narrow and stable; only the numbers move.

## Decisions

### A second percent function, not a change to the existing one

`PercentFormat.text` is used in the panel rows and in the tooltip. Padding there
would indent every figure in the panel, so the menu bar gets its own function
and shares none of the call sites.

Rejected: adding a `width:` parameter to `text` defaulting to nil. It would put
an optional-layout concern into a formatter that has one job, and every caller
would have to know to pass it.

### Pad left, including the glyph

Right-aligning each field means padding on the left. That keeps the separator
and the glyph at fixed positions instead of letting the numbers shove them
along.

Padding the glyph on the left rather than the right puts the pad inside the
string rather than at its end. A trailing space in a status item title is
layout-dependent — AppKit is free to trim it, and if it did, the width would
silently stop being fixed, which is the one thing this change is for. Leading
padding cannot be trimmed.

The cost is that `!` is preceded by a space rather than followed by one. In a
menu bar that is invisible.

### Widths come from the largest value each field can hold

Four for a percent, because `100%` is four characters — and the existing
`999%` cap means nothing longer can appear. Two for the glyph, because `!!` is
the widest verdict in the vocabulary. Three for the tag, which both providers
already satisfy; it is padded anyway so a shorter future tag cannot shift the
figures.

## Risks / Trade-offs

- **The widest case is now the only case.** `100%·100%` leaves no slack, so
  every other value carries visible padding inside the item. That is the point
  — the alternative is the item moving — but it does make a low-usage item look
  slightly airy.

- **A window whose percent is unknown** renders `?` padded to four. Consistent
  with the rest of the field, and unambiguous next to a verdict `?`.

- **Widths are constants in two places** — the formatter and the label. If the
  verdict vocabulary ever gains a three-character glyph, the glyph field needs
  widening. Recorded as a test rather than left to chance.

## Migration Plan

None. Presentation only.

## Open Questions

None.