# Design

## Context

See `proposal.md` — Why, which records that this reverses the field order set
one change ago.

The label has been reordered twice now. What has not changed is the invariant
underneath both reorderings: every character is the same width, every field is
padded to its widest value, and the label is sixteen characters. Reordering
cannot move any of that, which is why this is cheap.

## Goals / Non-Goals

**Goals:**

- Figures first, verdict last, tag between them.

**Non-Goals:**

- No change to widths, padding, font, separator, or the verdict vocabulary.
- Not re-litigating the order. It was tried both ways on screen, and the figures
  first is the one the user reads better.

## Decisions

### The tag goes between, not first

`100% 100% mmx !!` rather than `mmx 100% 100% !!`.

With the tag first, the figures are preceded by `mmx` and the eye has to skip
past it to reach the numbers. With it in the middle, the tag ends the run of
digits and begins the verdict — so it reads as a separator between "what is
consumed" and "what that means", which is exactly the job it ends up doing.

That was the shape before `verdict-leads-label` moved the glyph to the front,
and it is the shape now.

### The glyph keeps its left pad

` ✓` rather than `✓ `. The label ends on the verdict, and a trailing space is
something a status item's layout may trim — which would silently break the
fixed width this whole sequence of changes exists to provide.

The cost is a visible extra space before a one-character verdict, which is the
same trade already made and accepted.

## Risks / Trade-offs

- **The verdict is last again**, so the glance-first argument for leading with
  it is lost. This is a deliberate reversal on the user's judgement after
  seeing both, not an oversight, and it is recorded here so the next person does
  not "fix" it a third time.

- **No new risk in the width.** Same sixteen characters, same font, verified by
  the item width the app already logs.

## Migration Plan

None. Presentation only.

## Open Questions

None.