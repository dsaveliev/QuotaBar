# Design

## Context

See `proposal.md` — Why.

The label is currently `tag · windows · glyph` in fixed-width fields, rendered
in a fully monospaced font so its width is its character count times 7.418 pt.
Reordering the fields costs nothing: the count is the same either way.

## Goals / Non-Goals

**Goals:**

- The verdict is the first thing in the line.
- No punctuation between the figures.

**Non-Goals:**

- No change to any field width, to the font, or to the verdict vocabulary.
- No change to the tooltip, which already names its windows individually.

## Decisions

### Leading space inside the glyph field

The glyph field is two characters wide, so a one-character verdict is rendered
` ✓`, not `✓`. That leading space is what makes the glyph's *right* edge land on
the same x as a two-character verdict's, and it is also what keeps the label
ending on a figure rather than on trailing padding.

Rejected: centring the glyph with a trailing space instead. A trailing space in
a status item title is layout-dependent, and a trimmed last field is the width
jitter the previous two changes were spent removing.

### A space is the separator, not nothing

The windows must stay separated. At two digits the left padding of the second
field does it — ` 62%` ` 47%` reads as two figures with the padding between
them. At three digits there is no padding left, and the label becomes `100%100%`.

So the separator remains one character and simply stops being a dot. Since
every character is the same width, swapping `·` for a space costs nothing
measurable, and the padding still does its job at the widths where it can.

Rejected: `·` kept only between figures at three digits. Conditional separators
are a rule the reader has to hold in their head, and they change the label's
character count — no, they would not change the count here, but they would
change its meaning per refresh. A label that formats differently depending on
the numbers in it is harder to parse, not easier.

### One line, three fields, unchanged total

`glyph(2) · space · tag(3) · space · percent(4)` per window. Sixteen
characters for two windows, exactly as before.

## Risks / Trade-offs

- **Reordering is not reversible by muscle memory.** Someone who has looked at
  this label for a week will find the verdict in the wrong place for a moment.
  Accepted: the version being replaced put the part that matters last.

- **`1%` next to `52%` reads as `  1% 52%`**, with the two-space gap the
  padding leaves. Slightly airy, and the price of not padding at all.

- **No width measurement is needed to check this.** Reordering the same
  characters cannot change the sum, and the app logs the rendered width on every
  label change, so `w=` is still the verification.

## Migration Plan

None. Presentation only.

## Open Questions

None.