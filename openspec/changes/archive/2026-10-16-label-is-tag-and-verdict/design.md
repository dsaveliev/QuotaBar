# Design

## Context

See `proposal.md` — Why.

Five changes have reordered this label: `fixed-width-menu-bar-label` padded it,
`menu-bar-label-true-width` fixed the font, then the order was tried as
tag-figures-verdict, verdict-figures-tag and figures-tag-verdict. Each cost a
change and a reinstall. This one removes the thing all three were arranging.

## Goals / Non-Goals

**Goals:**

- A six-character label that cannot resize and has no meaningful ordering left.
- The figures reachable without rearranging anything.

**Non-Goals:**

- No change to the panel, to the tooltip, or to how figures are read anywhere.
- Not removing the monospaced font. See below.

## Decisions

### The tooltip is where the figures live, and it already says them

`MenuBarItems.explanation` composes `MiniMax — 5h 58%, 7d 47% · ! close to the
reset · updated 3m ago`: every window with its percent, the verdict in words
rather than as a glyph, and the age of the data. It was written for a label that
carried only a tag and a glyph, and it was never trimmed when the label grew
figures. So the numbers the label is giving up were already duplicated.

Rejected: keep one figure in the label. It would be a compromise nobody asked
for, and it would re-open the question of which window.

### The monospaced font stays

With six characters there is no longer any variation to absorb — the width is
the same whatever the verdict. A proportional font would now work.

Kept anyway, for two reasons. `✓` and `✗` are fallback glyphs in the menu bar's
own font, and they are wider than `!`; the next label that grows a field, or the
next verdict that changes, would reintroduce the jitter for free if the font had
already been relaxed. And the measured cost is small: the whole item is about
45 pt.

### `fixedWidth` goes rather than stays unused

It was added for the figures this change removes. Leaving it would be a
formatter whose only reason to exist has been deleted, and the next person
would use it for the wrong thing. `text` stays, because the panel and the
tooltip both format figures unpadded.

## Risks / Trade-offs

- **Losing the at-a-glance number.** This is the real cost and it is a real
  loss: a user who wanted to read "52%" without moving the mouse will now have
  to hover or open. Accepted as the user's explicit preference after seeing
  four arrangements.

- **The width-invariant test gets trivial.** Six characters, one composition —
  it will pass forever and catch nothing. Worth keeping as a cheap guard
  against a future field being added back unpadded, and worth not overselling:
  it is no longer a meaningful measurement.

## Migration Plan

None. Presentation only.

## Open Questions

None.