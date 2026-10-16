# Tasks

## 1. SnapshotStore

- [x] 1.1 Add `SnapshotStore`, mirroring `HistoryStore`'s injectable
  `readFile`/`writeFile` and per-entry tolerance, holding `[providerId: (rows,
  fetchedAt)]` as hand-rolled JSON. Verify: `swift build` clean
- [x] 1.2 Drop entries older than seven days on load, and never write them back.
  Verify: a unit case loading an entry eight days old returns nothing for that
  subscription while a one-day-old entry survives
- [x] 1.3 Treat one malformed subscription entry as costing only that entry, and
  a wholly unreadable file as costing nothing. Verify: a case with one good and
  one broken entry restores the good one

## 2. Engine

- [x] 2.1 Seed each provider's `rows` and `updatedAt` from the store at start,
  with a per-provider flag that the figures predate this launch. Verify: a test
  where a restored provider produces `.live` snapshots before any refresh
- [x] 2.2 Save rows and fetch time on every successful refresh. Verify: the store
  receives the provider's rows after a successful refresh
- [x] 2.3 Clear the flag on the first successful refresh. Verify: after one
  refresh the subscription's verdict is no longer `unknown`
- [x] 2.4 Carry the flag into the snapshot and force the aggregate verdict to
  `unknown` while it is set, without disturbing the window rows' figures. Verify:
  a restored subscription's label reads its percentages with a `?`

## 3. Freshness

- [x] 3.1 Suppress the stale flag while figures are restored and unconfirmed,
  and resume normal two-interval ageing afterwards. Verify: restored data is not
  stale even when it is hours old; after a refresh the threshold applies again
- [x] 3.2 Leave the panel's age line reporting the original fetch time. Verify:
  the header says `updated 3h ago`, not "just now"

## 4. Verify and ship

- [x] 4.1 Run `swift run QuotaBarKitTests`. Verify: all cases pass, and the new
  store cases are among them
- [x] 4.2 Validate with `openspec validate --specs --strict` after archiving.
  Verify: no advisory
- [x] 4.3 `./scripts/install.sh`, then quit and relaunch, and confirm the menu
  bar item shows figures with `?` rather than an ellipsis, for a few seconds
  before the first answer. Verify: the item reads `mmx 51%·46% ?` immediately
  after a relaunch and `mmx 51%·46% !` once the refresh lands
- [ ] 4.4 Confirm the panel header reports the real age of restored figures.
  NOT DONE, and deliberately left open. The mechanism is proven two ways: the
  log shows the restored state before the first live answer (`zai …` then
  `zai ?` then `zai ✓`), and a test asserts a restored subscription's
  `updatedAt` is the fetch time rather than the restore time. What is missing
  is the photograph: the first response lands in under 0.7s here, so the
  restored panel was never on screen when the shutter fired. See the task
  above, which the log does satisfy.