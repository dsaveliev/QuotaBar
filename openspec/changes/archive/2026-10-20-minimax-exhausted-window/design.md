# Design

## Context

See `proposal.md` — Why. The specs pin what the system must do; this is how.

The defect is one line in `MiniMaxProvider.makeRow`:

```swift
guard status == 1 else { return nil }  // 1 = active in plan
```

MiniMax's `current_*_status` is a three-value enum — `1` limited, `2`
exhausted, `3` unlimited — so this line deletes the exhausted window along with
the unlimited one.

Two facts make the fix smaller than it looks.

**The model already expresses "limit reached."** `VerdictClassifier.classify`
opens with `usage >= limit → .blocked`, and `QuotaRow` already carries `usage`
and `limit` as separate fields. Z.ai's exhausted weekly window lands on that
rule today without any provider-specific code: its payload reports
`currentValue: 60034, remaining: 0`, so the row's usage equals its limit and
the window is blocked. MiniMax's rows are percent-space — `usage = 100 −
remaining`, `limit = 100` — so an exhausted MiniMax window at `usage = 100,
limit = 100` reaches the same rule by the same route.

**Nothing downstream needs to change.** `usage >= limit` is checked before the
staleness, span, and runway rules, so the verdict is `blocked` without waiting
for evidence. `isMeasuring` is explicitly false for a blocked verdict, so the
panel prints `limit reached · … left` rather than a projection. `WindowRowView`
already renders `limit reached`. The aggregate verdict picks `blocked` as the
most severe, so the menu bar shows `✗`. The engine's `applySuccess` needs at
least one row and will have one.

So the whole change lands in one file, `Sources/QuotaBarKit/Providers/MiniMaxProvider.swift`.

## Goals / Non-Goals

**Goals:**

- The parser distinguishes the three statuses the endpoint actually reports, and
  each one has a stated outcome.
- The change is confined to the provider. `QuotaRow`, the engine, the verdict
  ladder, and the view are untouched.
- The decision is testable at the parser's boundary, where the tests already are.

**Non-Goals:**

- No change to Z.ai, whose payload carries no status field and already behaves
  correctly.
- No new field on `QuotaRow` and no new state in the verdict ladder.
- No change to which model bucket a multi-bucket payload is read from.
  See the proposal's non-goals.

## Decisions

### An exhausted window is a row at 100%, not a new concept

`makeRow` gains one branch and loses its guard:

```swift
private enum PlanStatus {
    case limited
    case exhausted
    case unlimited

    init(_ raw: Double?) {
        switch raw {
        case .some(2): self = .exhausted
        case .some(3): self = .unlimited
        default: self = .limited
        }
    }
}
```

```swift
switch status {
case .exhausted:
    usedPercent = 100
case .limited:
    guard let remainingPercent, remainingPercent.isFinite else { return nil }
    usedPercent = min(100, max(0, 100 - remainingPercent))
case .unlimited:
    return nil
}
```

The row keeps its percent-space shape — `usage = usedPercent`, `limit = 100` —
so `usage >= limit` is what makes it `blocked`, for the same reason Z.ai's does.

Rejected: a `isExhausted` flag on `QuotaRow`. It would express a state the model
already has a representation for, and it would have to be threaded through
`QuotaRow`, `WindowSnapshot`, and the view to reach the same rendering.

Rejected: keeping the exhausted window's reported percentage and trusting it.
The endpoint's own status is the authority on whether a window is spent; a
window that reports 0% remaining while its status says exhausted would render
as an intact window.

### The status outranks the percentage, and the percentage governs otherwise

The status is an override, not the source of truth. It says spent (2) or
unmetered (3); everything else leaves the reported remaining percent in charge.

That includes a status the endpoint does not define. MiniMax's three values are
`1`, `2`, `3`; the value `0` is not one of them, and today a `0` window is
dropped along with the exhausted ones. Under this design an unrecognised status
falls back to the limited reading and the window renders from its percentage.

The reason is which of the two errors is worse. A window that vanishes takes
its quota off the screen with it, and the user cannot tell a missing window
from a healthy one. A window that renders from a percentage the status failed
to qualify is merely less certain, and it is still on the screen.

Rejected: dropping any window whose status is not recognised. That keeps the
existing treatment of `0`, and it keeps the failure mode that caused this bug.

Rejected: treating an absent status as unlimited. An absent status is not a
statement about the plan; the percentage is still there, and upstream
implementations that read this endpoint treat an absent status as "not
exhausted" rather than as "no window".

### Unlimited stays omitted, because the model has no way to say it

A window the plan meters no limit against has nothing to burn and nothing to
project, so there is no figure to show and no severity to express. Omitting it
is the honest representation available today, and it is what the app already
does.

This costs something real: upstream renders an unlimited weekly window as a
full green bar labelled *unlimited*, so a user on such a plan sees nothing here
where upstream shows the window. Expressing it would mean a percent-like
"no limit" state on `QuotaRow`, a verdict that is not `blocked`, and a
distinction in the panel — a larger change than the reported bug, touching
three files the change otherwise leaves alone.

It is also rare where it matters: status `3` is what the endpoint reports for a
model that is not in the plan at all, which for a text-only plan is the video
bucket rather than the coding bucket the app reads.

Recorded as a follow-up, not as part of this change.

### An entry is recognised by its timestamps, and the search skips entries that
yield nothing

`isPlanEntry` currently demands four fields, two of which are the percentages
this change makes optional. It becomes: the entry carries both windows' reset
timestamps, and the remaining percent is not required.

That relaxation has a consequence worth handling. Selecting the first entry
that passes the predicate would newly admit an entry that carries timestamps
but no percentages at all — one that describes no usable window. In a payload
carrying several buckets, such an entry would shadow a later one that describes
the plan properly.

So the selection rule becomes: take the first entry that yields at least one
reportable window. An entry whose timestamps are absent is not a plan entry and
is skipped; an entry whose timestamps are present but which yields no row is
skipped for the same reason. A payload where no entry yields a row produces no
rows, which the engine reports as the empty-payload error.

This is strictly better than today's predicate, which selects on a proxy —
"has all four fields" — for the thing that actually matters, "has something to
report". It also leaves the multi-bucket weakness alone rather than making it
worse: a bucket that reports percentages but an unlimited status still shadows
a later bucket today, and still will.

### The exhausted payload is reconstructed, not captured

`Fixtures/` holds payloads captured from the live endpoints. An exhausted
weekly window cannot be captured without spending the quota, so the exhausted
and unlimited shapes are built inline in `MiniMaxProviderTests`, the way the
existing status test already is.

The cost is that the exhausted shape rests on the documented enum rather than
on an observed response. Four independent upstream implementations — MiniMax's
own CLI, `oh-my-pi`, `ai_usagebar`, and `minimax-usage` — agree that `2` means
exhausted and `3` means unlimited, and the two upstream implementations that
handle exhaustion both let the status override a stale percentage, which is the
behaviour pinned here.

The parser's tolerance for a missing percentage is what makes this safe: if the
endpoint omits the percentage on an exhausted window, the row is still reported
at 100%, and if it reports a stale one, the status still wins.

## Risks / Trade-offs

- **An unrecognised status now renders a window that used to be dropped.** This
  is a behaviour change beyond the reported bug. It is deliberate, and the test
  suite pins both readings — an unlimited window is omitted, an unrecognised
  one is not — so the distinction cannot be lost later by accident.
- **The reset time on an exhausted weekly row comes from the payload, and the
  payload's weekly window does not obviously agree with the console's.** The
  endpoint reports `weekly_start_time` equal to the current interval's
  `start_time` in both observed responses, and `weekly_end_time` about seven
  days later — the weekly window appears to be derived from the five-hour
  window rather than from a fixed weekly boundary. MiniMax's own console showed
  the weekly limit resetting in 1h 34m while the API reported a seven-day
  window ending the following week. The consequence for this change is bounded:
  the verdict is `blocked` regardless, because `usage >= limit` is decided
  before any reset time is consulted, and the reset timestamp is passed through
  exactly as the endpoint reports it. The label under the bar may therefore
  read longer than the console's own countdown. See Open Questions.
- **An exhausted window pins `usage` at 100 for as long as it stays exhausted,
  so no burn rate is recorded for it.** The runway line reports
  `limit reached · … left` rather than a projection, which is the same thing
  Z.ai's exhausted window already says.
- **The upstream `weekly_boost_permille` multiplier is still ignored**, so a
  boosted weekly plan's percentage is read as sent rather than as displayed by
  the console. Unchanged by this work, and named in the proposal's non-goals.
- **The parser gains a branch.** It gains one because the endpoint's field is
  a three-value enum and one of the values was being treated as if it did not
  exist.

## Migration Plan

None. The change is confined to a parser's reading of a payload; no persisted
format, no stored state, and no user-visible setting changes.

A subscription restored from the previous run's snapshot shows the rows the
last successful refresh produced until the next refresh overwrites them, which
is the existing behaviour for every change to a parser.

## Open Questions

- **Is the weekly window's reset time the endpoint reports the same boundary
  the console shows?** Both observed responses carry
  `weekly_start_time == start_time` and a `weekly_end_time` roughly seven days
  out, while the console's weekly countdown reads in hours. Answering it needs
  a response captured while the weekly window is mid-cycle and a console
  reading taken at the same moment.
- **Does the endpoint report a status the app has not seen?** `1`, `2`, and `3`
  are the documented values and `0` is not among them, but nothing in this
  project's evidence shows what an exhausted or unlimited response looks like
  on the wire. The next real exhaustion will show it.
