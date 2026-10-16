# Tasks

## 1. The label

- [x] 1.1 Restore the glyph's reserved field of two characters, padded on the
  left, and drop the separator between the tag and the glyph: `✓` supplies its
  own gap. Verify: `zai ✓`, `zai!!`, `mmx!!`
- [x] 1.2 Leave the tag unpadded; it leads, so there is nothing before it to
  misalign against. Verify: both providers' tags are three characters

## 2. Tests

- [x] 2.1 Update the cases pinning exact label strings. Verify: the suite
  passes
- [x] 2.2 Assert the label is six characters for every verdict in the
  vocabulary, and that no separator sits between the tag and the glyph. Verify:
  it fails if the padding is dropped

## 3. Verify and ship

- [x] 3.1 `swift run QuotaBarKitTests`. Verify: 149 pass
- [x] 3.2 `./scripts/install.sh`, then confirm the item's logged width is one
  value across a verdict change. Verify: the same `w=` for `zai ✓` and `zai!!`
- [x] 3.3 Update the README, which states the item moves a character on a
  verdict change. Verify: it no longer says so
- [x] 3.4 Archive and validate. Verify: `openspec validate --specs --strict`
  reports no advisory