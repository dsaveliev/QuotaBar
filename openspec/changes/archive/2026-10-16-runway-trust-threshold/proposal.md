# Proposal

## Why

The weekly window reads `short` almost immediately after launch, and it is
wrong. The runway is a burn rate measured over the samples collected so far and
extrapolated across the whole window: fifteen minutes of observation is
extrapolated over seven days, so an ordinary burst of use looks like the weekly
allowance will be gone in three days. The verdict is a false alarm, and a
permanent false alarm trains the user to ignore the one signal the app exists to
give.

The current guard is a flat one-minute minimum, which is meaningful for a
five-hour window and meaningless for a weekly one. The guard should scale with
the window it is judging.

## What Changes

- A window's verdict requires an observation span proportional to that window's
  own duration: at least **1/20** of it. A five-hour window therefore waits
  fifteen minutes, a weekly one about eight hours. Windows that report no
  duration keep the existing one-minute minimum.
- Below the threshold the verdict is `unknown`, and the panel says
  `measuring…` rather than showing a runway figure it cannot stand behind.
- The threshold is one named constant, not a per-provider setting, so the rule
  reads the same for every subscription.
- Exhaustion is unaffected: a window at its limit is `blocked` immediately,
  because that verdict needs no history at all.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `runway-projection`: the verdict classification requirement gains a
  window-proportional evidence threshold and a measuring state.

## Impact

- Affected code: `Sources/QuotaBarKit/Runway/Verdict.swift` (the threshold),
  `Sources/QuotaBarKit/Engine/{QuotaEngine,SubscriptionSnapshot}.swift` (passing
  the window duration through and deriving the measuring flag), and the panel
  views.
- Test suite: the verdict cases that asserted a one-minute minimum gain
  window-proportional counterparts, and one engine case that expected a verdict
  from a two-minute history must now wait past the threshold.
- No settings and no migration: this is a rule, not a preference.