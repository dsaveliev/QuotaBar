# runway-projection Specification

## Purpose
Turns a stream of quota readings into an answer to one question per window: at
the rate the user is consuming, will this quota last until the window resets?
Owns the sampling, the burn-rate projection, and the verdict derived from it.

## Requirements

### Requirement: Usage sampling

The system SHALL record one usage sample per window per refresh, keyed by
subscription and window label so that samples from one subscription never
contribute to another's projection, and SHALL keep at most a configurable number
of samples per window.

#### Scenario: samples accumulate

- **WHEN** consecutive refreshes report the same window label for the same
  subscription
- **THEN** each refresh appends one sample and the retained history grows up to
  the configured cap

#### Scenario: history capped

- **WHEN** the history reaches the configured maximum sample count
- **THEN** the oldest sample is dropped on the next append so the retained
  count never exceeds the cap

#### Scenario: samples never mix subscriptions

- **WHEN** the user has both subscriptions configured and both report a `5h`
  window
- **THEN** each projection is computed only from that subscription's own samples

#### Scenario: degenerate cap still records

- **WHEN** the configured history cap is zero, negative, or fractional
- **THEN** it is floored to at least one sample so an append can never empty the
  history

### Requirement: Window-boundary history reset

The system SHALL discard a window's sample history when the window boundary
moves — detected by a change in the reported reset timestamp or a decrease in
consumed usage — and SHALL restart history from the newest sample alone.

#### Scenario: reset timestamp changed

- **WHEN** a refresh reports a different reset timestamp for a window than the
  previous refresh
- **THEN** that window's history is discarded and restarts with the new sample

#### Scenario: usage counter rolled over

- **WHEN** a refresh reports a lower consumed figure for a window than the
  previous refresh
- **THEN** that window's history is discarded and restarts with the new sample,
  because the counter has rolled over for a new window

### Requirement: History persistence across restarts

The system SHALL persist per-window sample histories so that a restart resumes
projection from prior samples rather than starting from nothing.

#### Scenario: projection survives restart

- **WHEN** the app is restarted with a persisted history containing at least two
  samples spanning at least one second
- **THEN** the runway projection is available on the first refresh after launch
  instead of reporting insufficient data

#### Scenario: corrupt or partial history file

- **WHEN** the persisted history cannot be read or contains malformed entries
- **THEN** the unreadable portion is discarded, the app starts with empty
  histories, and polling continues normally

### Requirement: Burn-rate derivation

The system SHALL derive the burn rate for a window from the oldest and newest
retained samples as the change in consumed amount over the elapsed time between
them, and SHALL require at least two samples spanning at least one second before
projecting anything.

#### Scenario: too little history

- **WHEN** fewer than two samples exist, or the newest and oldest samples are
  less than one second apart
- **THEN** the window reports insufficient data and no runway figure

#### Scenario: no consumption

- **WHEN** two or more samples exist but the consumed amount has not grown
- **THEN** the window reports no burn, which is treated as an intact window

#### Scenario: single moving window

- **WHEN** exactly one sample exists, however far below the limit its consumed
  amount sits
- **THEN** the window reports insufficient data, because a rate needs two
  readings to divide

### Requirement: Verdict classification

The system SHALL assign each window exactly one verdict — `ok`, `tight`,
`short`, `blocked`, or `unknown` — from an ordered ladder, and SHALL NOT report a
positive verdict from incomplete, stale, or too-brief evidence. The evidence a
window must have before it can report anything but `unknown` SHALL scale with that
window's own duration: a window of known duration requires an observation span of
at least one twentieth of it, and a window of unknown duration requires one
minute.

#### Scenario: exhausted window

- **WHEN** a window's consumed amount is at or above its limit
- **THEN** the verdict is `blocked`, regardless of any other signal, and without
  waiting for any observation

#### Scenario: stale evidence

- **WHEN** the window's data is flagged stale
- **THEN** the verdict is `unknown`, even if the underlying numbers would
  otherwise read as safe

#### Scenario: brief measurement span

- **WHEN** the samples behind the projection span less than one minute and the
  window reports no duration
- **THEN** the verdict is `unknown`

#### Scenario: measurement span below the window's threshold

- **WHEN** a window reports a duration and the samples span less than one
  twentieth of it
- **THEN** the verdict is `unknown`, because a short observation cannot support
  an extrapolation across the whole window

#### Scenario: measurement span at the window's threshold

- **WHEN** a window reports a duration and the samples span exactly one
  twentieth of it
- **THEN** the threshold is met and the ladder proceeds

#### Scenario: weekly window is not alarmed early

- **WHEN** a seven-day window has been observed for less than its threshold
- **THEN** the verdict is `unknown`, rather than a shortfall extrapolated from a
  few minutes of use

#### Scenario: no burn recorded

- **WHEN** the window reports no burn and its evidence is sufficient, it is not
  stale, and it is not exhausted
- **THEN** the verdict is `ok`

#### Scenario: projection incomplete

- **WHEN** the projection reports insufficient data, no limit, no reset, or a
  non-finite runway or reset distance
- **THEN** the verdict is `unknown`

#### Scenario: runs dry before reset

- **WHEN** the projected exhaustion lands strictly before the reset
- **THEN** the verdict is `short`

#### Scenario: tight band

- **WHEN** the projection lands at or after the reset but within a configurable
  multiple of the remaining reset distance
- **THEN** the verdict is `tight`

#### Scenario: comfortable

- **WHEN** the projection lands beyond that multiple
- **THEN** the verdict is `ok`

### Requirement: Aggregate verdict

The system SHALL reduce the per-window verdicts of a subscription to one
summary verdict for its menu bar label, choosing the most severe verdict
present.

#### Scenario: severity order

- **WHEN** windows carry a mix of verdicts
- **THEN** the summary is the most severe in the order `ok`, `tight`, `short`,
  `blocked`

#### Scenario: only unknown verdicts

- **WHEN** every window of a subscription is `unknown`
- **THEN** the summary is `unknown`

#### Scenario: windows on separate subscriptions

- **WHEN** two subscriptions are tracked simultaneously
- **THEN** each subscription's summary is derived only from its own windows

### Requirement: Runway and duration presentation

The system SHALL present durations in a compact human form — seconds, minutes,
hours with minutes, days with hours — and SHALL present projected runway as an
approximation that collapses to whole days beyond two days.

#### Scenario: compact durations

- **WHEN** a duration is under a minute, under an hour, or under two days
- **THEN** it is rendered as seconds, as minutes, or as hours with an optional
  minutes tail respectively

#### Scenario: distant runway collapsed

- **WHEN** a projected runway exceeds two days
- **THEN** it is rendered as whole days rounded to the nearest day, with no
  hours or minutes tail

#### Scenario: unprojectable runway markers

- **WHEN** the projection reports no burn, insufficient data, no limit, or no
  reset
- **THEN** the row says which of those four cases it is — no burn, insufficient
  data, no limit, or no reset — rather than showing a number, so a missing
  projection is never mistaken for a short one

### Requirement: Measuring state

The system SHALL distinguish a window that is still collecting evidence from a
window that has evidence and found nothing to project, and SHALL report the first
as measuring rather than as an absence of data. When both would apply, the
measurement SHALL take precedence over anything the projection would otherwise
have to say.

#### Scenario: window below its threshold

- **WHEN** a window is below its evidence threshold but has samples
- **THEN** it reports itself as measuring, and its share of the way to the
  threshold is available for display

#### Scenario: window with no samples

- **WHEN** a window has fewer than the samples needed to project at all
- **THEN** it reports an absence of data rather than a measurement in progress

#### Scenario: measuring window shows no runway figure

- **WHEN** a window is measuring
- **THEN** the panel does not present a runway figure for it, since no figure
      drawn from so little evidence should be acted on

#### Scenario: trust threshold is one shared rule

- **WHEN** the evidence threshold is consulted
- **THEN** it is the same rule for every subscription, defined once rather than
  per provider or per window label

#### Scenario: measuring outranks the projection

- **WHEN** a window is below its evidence threshold and its projection, if taken
  at face value, would fall before its reset
- **THEN** it is reported as measuring, and the projection is not asserted

#### Scenario: the measurement outlasts the threshold

- **WHEN** a window that was measuring crosses its evidence threshold
- **THEN** it stops reporting a measurement in progress, and any shortfall its
  now-trusted projection shows is stated instead
