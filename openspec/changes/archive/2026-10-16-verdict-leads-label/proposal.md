# Proposal

## Why

The label reads `mmx  62%· 47% !!`: the provider, the figures, then the verdict.
The verdict is the only part that answers "do I need to do something", and it is
the last thing in the line — which is where an eye does not land first when it
glances at the menu bar.

The middle dot between the windows has also outstayed its welcome. It was there
to separate two percentages; the fields are fixed-width now, so the padding
already does that work, and a third separator character is noise between the
figures and the tag.

## What Changes

- **The verdict leads.** The glyph reads as a status light: first thing seen,
  and it stays in the same place whether it is one character or two.

  ```
  !! mmx  62% 47%
  ✓ zai   1% 52%
  ```

- **The middle dot goes.** The separator between windows becomes a space, which
  is what a dot was standing in for. It occupies exactly one character, so the
  label's width does not change: still sixteen characters, still 118.688 pt.

A space rather than nothing is deliberate. Removing the dot outright leaves
`100%100%` when both windows are full — the padding that separates ` 62%` from
` 47%` comes from a field that has no padding left to give at three digits. The
separator must survive as a character; it just stops being punctuation.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `menubar-quota-surface`: the label leads with the verdict and separates its
  windows with a space.

## Impact

- `Sources/QuotaBarKit/Engine/SubscriptionSnapshot.swift` — `menuBarLabel()`
  only; the field widths and the monospaced font are untouched.
- Tests that pin exact label strings.
- `README.md`, which shows the label twice.
- The tooltip is deliberately not changed: it names each window by its own
  label (`5h 62%`), so it needs no separator and has none.