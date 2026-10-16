# Proposal

## Why

On launch the menu bar item reads `mmx …` for as long as the first request
takes, and the panel has nothing to show. Two seconds of an empty menu bar is
small, but it is the moment the user looks, and the app already knows what it
showed last time — the sample history survives a restart, only the last figures
do not.

The numbers are not in doubt. What is in doubt is the verdict: a projection
built from a burn rate that stopped being measured when the app exited. So the
figures can be shown and the verdict must not, which is what the existing `?`
glyph already means.

## What Changes

- **The last successful figures are written to disk** per subscription, and read
  back on launch, so the item shows real numbers immediately.
- **Restored figures carry `?` until the first live refresh lands.** The percent
  and the verdict glyph are the two things the menu bar shows; the percent is
  trustworthy, the projection is not, so only the projection is withheld. The
  panel's header already reports the real age, so nothing has to be invented to
  explain where the numbers came from.
- **Restored figures are aged from the moment they were fetched**, so the panel
  says `updated 3h ago` rather than pretending they are seconds old.
- **Restored figures are not flagged stale.** "Stale" means a refresh was due
  and did not arrive. At launch no refresh is due yet, and flagging every
  restart as stale would cry wolf on the one day the user is least expecting it.
- **Nothing older than a week is restored.** A forecast from eight days ago is
  not a forecast; the history file already keeps its samples far longer because
  a burn rate needs a long span, but a displayed figure needs to be recent to
  mean anything.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `menubar-quota-surface`: the loading label now distinguishes "never fetched"
  from "showing the last known figures".
- `quota-subscription-polling`: the last successful payload is persisted across
  restarts, aged from its own timestamp, and excluded from the stale flag while
  it is still unconfirmed.

## Impact

- `Sources/QuotaBarKit/Engine/SnapshotStore.swift` — new, mirroring
  `HistoryStore`'s tolerant read/write.
- `Sources/QuotaBarKit/Engine/QuotaEngine.swift` — seed restored rows, save on
  success, and carry "fetched before this launch" through to the snapshot.
- `Sources/QuotaBarKit/Engine/SubscriptionSnapshot.swift` — a flag that lets the
  surface and the label react to unconfirmed figures.
- `~/Library/Application Support/QuotaBar/snapshot.json` — a new file beside
  `settings.json` and `history.json`. Nothing is migrated; the first launch
  after the upgrade simply has nothing to restore.
- Tests: a store round-trip, the week-old cutoff, per-entry tolerance of a
  malformed file, and that a restored subscription is not stale but is `?`.