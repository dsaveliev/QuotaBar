# Proposal

## Why

The panel can say two contradictory things about the same window at once:

```
7d                              56%  ?
resets in 4d 19h        runway measuring…
ends 4d 3h before the reset
```

The runway line says the projection is still being measured — that there is not
yet enough evidence to say anything. The muted line beneath it then says how
much earlier the window ends, which is a projection, stated as fact, on the
authority of evidence the line above just declared insufficient.

This is not a wording problem. `WindowRowView` checks for a shortfall
*before* it checks whether the window is measuring, and both can be true at
once: a weekly window with two samples already spans enough of the burn-rate
window to produce a rate, so `runway.state` is `warn`, while its span is still
short of the eight hours the weekly threshold wants. The shortfall line was
written before `Measuring state` existed and was never demoted when it did.

## What Changes

- **A measuring window states no shortfall.** The muted line under it says how
  far along the measurement is, or that it is measuring, and nothing else. The
  question "how much earlier does it end?" is not answerable until the evidence
  is in, so the panel stops answering it out loud.
- **The decision moves into `WindowSnapshot`.** The view today computes a
  shortfall string and a measuring string and picks between them, which is how
  the wrong one got drawn. The snapshot gains a single `annotation` that says
  which of those it is — or nothing — and the view renders exactly what it is
  told.

That second point is what makes the fix stickable. The view is in the app
target, which has no test harness; the model is in `QuotaBarKit`, which has
149 cases.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `menubar-quota-surface`: the shortfall annotation applies only to windows
  whose projection is trustworthy.
- `runway-projection`: a measuring window's annotation is the measurement, and
  it takes precedence.

## Impact

- `Sources/QuotaBarKit/Engine/SubscriptionSnapshot.swift` — `WindowSnapshot`
  gains `annotation`.
- `Sources/QuotaBar/WindowRowView.swift` — renders one string instead of
  choosing between two.
- `QuotaEngine` unchanged: the data needed for both lines is already computed,
  and the precedence is a presentation rule.
- Tests in `EngineTests` or `RunwayTests` can now cover this; previously the
  rule lived in a view and had no coverage at all.