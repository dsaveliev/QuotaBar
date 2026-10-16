# Design

## Context

See `proposal.md` — Why.

Two persistence files already exist in `~/Library/Application Support/QuotaBar`:
`settings.json` and `history.json`. `HistoryStore` is the template: hand-rolled
`JSONSerialization`, per-entry tolerance, injected `readFile`/`writeFile` so it
is testable without touching disk. `QuotaRow` has six optional fields and is not
`Codable`, so a third hand-rolled file is the consistent choice rather than a
new dependency.

`QuotaEngine` keeps `rows` and `updatedAt` per provider in memory, and drops
both on `applyError`. There is currently no place that knows what the figures
were at shutdown.

## Goals / Non-Goals

**Goals:**

- Real figures in the menu bar immediately after launch.
- Nothing shown as more certain than it is.
- One week of retention, per-entry tolerance of a corrupt file.

**Non-Goals:**

- No change to how a refresh works, to the parsers, or to the history format.
- No speculative rendering of a projection from restored figures. The `?` is
  not cosmetic; it is the honest state until a live answer arrives.
- No offline mode. The app still polls on the same schedule from the moment it
  starts; this only fills the gap before the first answer.

## Decisions

### Persist rows, not a rendered snapshot

`SnapshotStore` saves the provider's parsed rows and the fetch time, keyed by
provider id — the same shape as `HistoryStore` and for the same reason: one
subscription's figures can never leak into another's panel.

Rejected: persisting the built `SubscriptionSnapshot`. It would have to be
revalidated on load against the current provider set, it couples the file format
to the view model, and nothing in it is not derivable from rows plus a
timestamp.

### "Unconfirmed" is a per-snapshot flag, not a separate state

`SubscriptionSnapshot.State` has three cases and adding a fourth would ripple
through the label, the panel and the picker for a distinction that is about the
verdict rather than the data.

Instead the restored rows are loaded into the provider's state as normal rows,
with `updatedAt` set to the moment they were fetched, plus a boolean saying they
have not yet been confirmed this launch. The snapshot carries that boolean as
`isRestored`. Everything downstream then treats restored data as live data
except the two things that must not: the verdict is forced to `unknown`, and the
stale flag is suppressed.

That makes the whole feature two lines at the point where verdicts are built,
and no new case anywhere.

Rejected: comparing `updatedAt` against the app's start time at read time. Same
outcome, but it makes "restored" a derived fact that changes meaning if the
clock moves, instead of a recorded fact.

### `?` is withheld only from the verdict, not from the percent

The menu bar label is `tag p1·p2 <glyph>`. The percent is a measurement; the
glyph is a forecast. Forcing the aggregate verdict to `unknown` withholds
exactly the glyph and leaves the figures — which is the entire point of the
change.

The panel's window rows follow the same rule, and the header's existing
`updated 3h ago` line is the explanation. No new UI.

### Not stale until confirmed

`stale` currently means "the last successful refresh is older than two
intervals". On a restart that is true of nearly every restore, and the panel
would open with a `stale` chip on every launch.

Stale describes a *failed expectation*: a refresh was scheduled and did not
arrive. At launch none is due yet. So restored-and-unconfirmed data is not
stale; once the first refresh lands, normal ageing resumes. If that refresh
fails, the error path already replaces the figures entirely rather than leaving
stale ones on screen.

Rejected: relaxing the two-interval threshold at launch. It would keep the chip
but weaken the rule that catches a dead poll loop everywhere else.

### One week, enforced on read

Retention is a read-side filter: an entry older than seven days is dropped when
loading and never written back, so the file does not grow without bound.

Rejected: pruning by age on write. A user who never opens the app would keep
every file at whatever it was.

Rejected: keeping the figure forever and letting staleness handle it. It would
put an eight-day-old percent next to a live-looking menu bar item, which is the
specific thing this change is trying not to do.

## Risks / Trade-offs

- **A wrong file becomes a wrong number on screen.** Restored figures are not
  re-validated against the provider before display. → Mitigation: entries are
  keyed by provider id, parsed with the same optional-tolerant reads as
  `HistoryStore`, discarded when malformed or over a week old, and the verdict
  is withheld so the wrong figure cannot become a wrong forecast.

- **The `?` on every launch is mild friction**, and it will be there until the
  first response lands. Accepted: it is two seconds, and it is the difference
  between showing a measurement and showing a prediction.

- **Two files now describe overlapping time.** `history.json` keeps samples
  far longer because a burn rate needs the span. A figure in `snapshot.json` is
  capped at a week; a sample used to derive a rate is not. That asymmetry is
  deliberate and should not be "unified" later.

## Migration Plan

None. A new file with nothing in it restores nothing, and the first successful
refresh populates it. Removing the file at any time costs at most the figures
until the next refresh.

## Open Questions

None. Glyph behaviour and retention were resolved with the user before drafting.