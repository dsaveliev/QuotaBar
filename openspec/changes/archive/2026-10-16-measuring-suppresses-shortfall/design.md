# Design

## Context

See `proposal.md` — Why.

The two lines are computed in `WindowRowView`:

```swift
if let shortfallText {
    Text(shortfallText)          // "ends 4d 3h before the reset"
} else if window.isMeasuring {
    Text(measuringText)          // "measuring 68% of the evidence it needs"
}
```

`shortfallText` guards only on `runway.state == .warn`. `isMeasuring` guards on
the span against the threshold. Neither implies the other, and a weekly window
with two samples satisfies both — which is exactly the state the weekly window
sits in for its first several hours.

## Goals / Non-Goals

**Goals:**

- One muted line per window, never two, and never a claim the row above
  disclaims.
- The rule becomes testable.

**Non-Goals**

- No change to what either string says, to the threshold, or to the verdict.
- No change to the runway line itself. It already reads `runway measuring…`
  while measuring, which is correct.

## Decisions

### The precedence rule goes in the model

`WindowSnapshot` gains:

```swift
public var annotation: String? {
    if isMeasuring { … measuring text … }
    guard runway.state == .warn, … else { return nil }
    return "ends … before the reset"
}
```

The view becomes `if let annotation = window.annotation { Text(annotation) }`.

The reason this is not gold-plating: the bug is a missing `else`. A missing
`else` in a view is invisible to the 149 tests, because the view is not in
`QuotaBarKit` and `QuotaBar` has no test target at all — the test suite is an
executable target for the kit, and wiring an app-target test target into a
toolchain that ships neither XCTest nor swift-testing is a project of its own.
Putting the rule where the tests are is the cheapest way to make the next one
impossible to miss.

Rejected: fixing the `else` in place and leaving it untested. It is a one-line
fix today and an untested one-line fix is exactly what produced this.

Rejected: dropping the shortfall line at the source — do not compute it while
measuring. That would spread "am I allowed to state this?" across the engine as
well as the view, and the engine does not know what the row is about to print.

### Measuring wins, because it is the more urgent of the two

If both are true, the window is short of evidence and would also end early. The
evidence-short state is the one that resolves by itself in hours; the shortfall
may or may not be real. Reporting the transient over the unconfirmed is the
ordering that stops the panel over-claiming, and it also means the line is
never overwritten: the shortfall appears when the threshold is crossed, and the
verdict with it.

## Risks / Trade-offs

- **A genuinely short weekly window shows no shortfall for its first hours.** It
  shows `?` instead, which is already what the menu bar says. That is the cost
  of not over-claiming, and it lasts until the evidence arrives.
- **One string, so the muted line's content is decided in the model.** A view
  that wanted to phrase it differently would have to change the model. That is
  the intended coupling.

## Migration Plan

None. Presentation only.

## Open Questions

None.