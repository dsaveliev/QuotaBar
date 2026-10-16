# Proposal

## Why

The menu bar label has been rearranged five times in a row and is still being
changed. The reason is visible in the string itself: it is trying to be a
dashboard. ` 63%  47% mmx !` carries two measurements, a name and a verdict in
forty-five points of menu bar, which is more than the bar can give a glance
before the eye moves on.

Strip it to what the item is for — which subscription, and whether it needs
attention:

```
mmx !!
zai  ✓
```

Six characters, fixed forever, nothing to reorder.

Nothing is lost. The numbers were already in two other places, one of which is
a hover away: the item's tooltip spells out every window with its percent, the
verdict in words, and how old the data is — `MiniMax — 5h 58%, 7d 47% · !
close to the reset · updated 3m ago` — and the panel shows them against their
bars. The label never needed to duplicate them.

## What Changes

- **The label is the tag and the verdict, and nothing else.** Six characters:
  three for the tag, one space, two for the glyph.
- **`PercentFormat.fixedWidth` goes with them.** It existed only to reserve room
  for figures in this label, and with no figures there is nothing to reserve.
  `PercentFormat.text` stays: the panel and the tooltip still use it.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `menubar-quota-surface`: the label carries the provider tag and the verdict;
  the figures move to the tooltip and the panel, which already carried them.

## Impact

- `Sources/QuotaBarKit/Engine/SubscriptionSnapshot.swift` — `menuBarLabel()`
  becomes two fields.
- `Sources/QuotaBarKit/Format/DurationFormat.swift` — `fixedWidth` and
  `menuBarWidth` removed as dead.
- Tests pinning exact label strings, and the width-invariant case, which now
  asserts a constant that cannot move.
- `README.md`, whose whole opening example is the old label.
- The fully monospaced font stays: it is what made the width stable, and a
  six-character label still lands on the same pixels whichever verdict shows.