# Design

## Context

See `proposal.md` — Why.

The label has been six changes in a row. What is actually being decided is one
question: is the glyph's slot reserved, or is it not? Everything else — figures
in or out, separator or none, tag first or last — follows from that.

## Goals / Non-Goals

**Goals:**

- Six characters, always.
- The tag and the glyph read as one word.

**Non-Goals:**

- No change to what the label says, to the font, or to the figures' absence.
- No per-glyph padding table. The widest glyph is two characters and the
  vocabulary is closed.

## Decisions

### Two characters for the glyph, padded on the left

```
 ✓    ok, tight, blocked, unknown
!!    short
```

Two is set by `!!`, the widest in the vocabulary.

Left rather than right, because right padding puts a space at the end of the
title and a trailing space in a status item title is something the layout may
trim. A trimmed last field would be the width jitter again, silently.

### No separator, because the padding is one

With the glyph padded left, `✓` already yields ` ✓`. A separate space on top of
that would put two characters between the tag and the glyph, and one of them
would be doing nothing.

This is the difference from two changes ago, which shipped `zai  ✓` — the
separator and the padding, both. One was always redundant.

### The tag needs no padding of its own

It leads, so a tag shorter than three characters would only shift the glyph
left; there is nothing to the left of it to misalign against. Both providers
are three, and nothing downstream is laid out against the tag's width.

## Risks / Trade-offs

- **A verdict wider than two characters would need this revisited.** The
  vocabulary is closed and tested, so this is a note rather than a concern; the
  design keeps the width as a named constant so the next reader sees where to
  change it.

- **None of this touches the figures.** They remain in the tooltip and the
  panel, per the previous change, and a test pins both halves.

## Migration Plan

None. Presentation only.

## Open Questions

None.