# Proposal

## Why

`label-is-tag-and-verdict` removed the glyph's padding along with the
separator, which was one change too many: the label went from a fixed six
characters to four or five, and the item now moves a character every time the
verdict changes.

```
zai ✓      wanted
zai✓       shipped
zai!!      shipped
```

The padding was doing a second job. It was introduced to stop the verdict
moving the item, and only its second use — separating the tag from the glyph —
was removed. Put the padding back and drop the separator, and the space between
them is the padding: ` ✓` reads as a space, `!!` needs none.

```
zai ✓
zai!!
mmx!!
```

Six characters, always.

## What Changes

- **The verdict glyph is reserved two characters, padded on the left.** No
  separate separator between the tag and the glyph, because the padding already
  provides the gap when the glyph is one character.
- **The item's width is constant again.** Six characters for every verdict,
  which reverses the one-character movement the previous change accepted.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `menubar-quota-surface`: the label reserves two characters for the verdict
  glyph, and MAY NOT change width when the verdict changes.

## Impact

- `Sources/QuotaBarKit/Engine/SubscriptionSnapshot.swift` — `menuBarLabel()`
  composes the glyph field again; the tag needs no padding of its own.
- Tests pinning exact label strings.
- `README.md`.
- `PercentFormat` stays as the previous change left it: `fixedWidth` is gone and
  is not coming back, because there are no figures left to pad.