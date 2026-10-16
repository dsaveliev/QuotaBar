# Spec Delta

## MODIFIED Requirements

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

## ADDED Requirements

### Requirement: Measuring state

The system SHALL distinguish a window that is still collecting evidence from a
window that has evidence and found nothing to project, and SHALL report the first
as measuring rather than as an absence of data.

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