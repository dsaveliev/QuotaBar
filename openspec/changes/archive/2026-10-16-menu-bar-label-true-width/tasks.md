# Tasks

## 1. The font

- [x] 1.1 Render the menu bar item in a fully monospaced font, in which every
  glyph it uses has the same advance width. Verify: `swift build` is clean

## 2. Verify against the real thing

- [x] 2.1 Confirm the fix is not just plausible: drop the polling interval so
  several refreshes land quickly, then read the item width the app logs on each
  label change. Verify: every logged `w=` for a subscription is the same number
  across at least four consecutive refreshes with differing figures
- [x] 2.2 Confirm the width holds across a verdict change as well, not only
  across figure changes. Verify: two logged widths that differ only in the
  verdict glyph still report the same `w=`
- [x] 2.3 Put the polling interval back. Verify: the stored interval is the one
  the user chose, not the one used for the measurement

## 3. Ship

- [x] 3.1 Run `swift run QuotaBarKitTests`. Verify: unchanged, and passing —
  nothing in this change is reachable from the domain layer
- [x] 3.2 Archive and validate. Verify: `openspec validate --specs --strict`
  reports no advisory