# Design

## Context

See `proposal.md` for the false alarm and `specs/` for the revised behaviour.
The technical shape:

- The verdict ladder already has a "too-brief evidence" rung, guarded by a flat
  one-minute minimum in `VerdictClassifier`.
- Every window already carries its own duration (`windowMs`), populated by both
  parsers — Z.ai from its unit code, MiniMax from the plan's declared windows.
- `VerdictInput` is the only channel from the engine to the classifier, so the
  duration has to travel through it.

## Goals / Non-Goals

**Goals:**

- Stop the weekly window alarming itself from a few minutes of observation.
- Keep one rule, expressed once, that every subscription obeys.
- Distinguish "still collecting evidence" from "nothing to project".

**Non-Goals:**

- Improving the burn-rate estimate itself. A linear extrapolation is still a
  linear extrapolation; the change only stops it speaking before it has earned
  the right to.
- Changing which windows report a duration. Both parsers already do.
- Making the threshold configurable. It is a correctness rule, not a preference.

## Decisions

### 1. Threshold scales with the window's own duration

`minimumSpanMs(forWindow:) = max(60s, windowMs / 20)`. A five-hour window waits
fifteen minutes, a weekly one about eight hours, and a window that reports no
duration keeps the old one-minute floor so nothing regresses to `unknown`
forever.

*Alternative considered:* an absolute threshold per window label. Rejected: it
encodes provider vocabulary in a rule that should read the same everywhere, and
adding a subscription would mean inventing a number for it.

*Alternative considered:* 1/20 versus 1/100. Rejected the latter: three minutes
of five-hour observation is still a 100× extrapolation and the weekly window
would start alarming after an hour and forty minutes, which is not a fix, just a
slower wrong answer.

### 2. The duration travels through `VerdictInput`

`VerdictInput` gains `windowMs`. The classifier computes the threshold itself,
so the rule lives in exactly one place and callers cannot pass a span without
the duration that gives it meaning. The engine, which already holds the row, is
the only caller that changes.

### 3. `blocked` still short-circuits

Exhaustion needs no history, so it stays first in the ladder. A user at their
limit sees it immediately rather than waiting out a measurement.

### 4. Measuring is a distinct state, not an absence

`WindowSnapshot` gains `isMeasuring` and `measuredFraction`. Below the threshold
the panel reads `runway measuring…` instead of `runway …`, because "I have not
watched long enough" and "I watched and there is nothing to say" are different
answers and only one of them is provisional.

A window with too few samples for any projection stays `noData` and reads
`runway …`; only a window with samples that are simply too young reads
`measuring…`.

### 5. Progress is available, not just a flag

`measuredFraction` lets the panel say how far along the wait is, so a window
that has been measuring for thirteen of its fifteen minutes says so. A bare
`measuring…` with no progress is indistinguishable from a hang.

## Risks / Trade-offs

- **`?` for eight hours on the weekly window** → that is the honest answer: a
  handful of minutes cannot say anything about a week. The measured fraction in
  the panel keeps it from looking broken.
- **A user who expects an early warning loses one** → traded deliberately for
  not crying wolf every launch. The five-hour window still warns within
  fifteen minutes, which covers the "I am about to hit the cap" case.
- **Windows with no duration keep the old floor** → a provider that stops
  reporting a duration silently loses the stricter rule. Both parsers populate
  it today; a regression there would show up as measuring windows that finish
  early rather than as wrong numbers.

## Migration Plan

None. No setting changes. Rebuild and reinstall with `./scripts/install.sh`.