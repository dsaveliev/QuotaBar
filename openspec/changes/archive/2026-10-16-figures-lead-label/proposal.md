# Proposal

## Why

`verdict-leads-label` put the verdict first on the argument that it is the only
part of the label answering "do I need to do something". That was a reasonable
read and the wrong one: what the menu bar is *for* is the figures, and reading
them is what the user does most of the time. The verdict is a qualifier.

Put the figures first, then the tag, then the verdict:

```
100% 100% mmx !!
  1%  52% zai  ✓
```

The tag sits between them deliberately: it separates "these numbers" from "and
this is what they mean", so the figures are never mistaken for the verdict and
the verdict never mistaken for another figure.

## What Changes

- **Field order becomes figures, tag, verdict.** Sixteen characters before and
  after — the same characters in a different order, so the item's width does not
  move. The installed app logs `w=139` either way, which is the verification.

Everything else stands: no dot, spaces as separators, a fully monospaced font,
each field padded to its widest value, the verdict padded on the left so its
right edge does not shift between `✓` and `!!`.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `menubar-quota-surface`: the label's fields run figures, tag, verdict.

## Impact

- `Sources/QuotaBarKit/Engine/SubscriptionSnapshot.swift` — `menuBarLabel()`
  composition only.
- Tests that pin exact label strings.
- `README.md`'s example label.