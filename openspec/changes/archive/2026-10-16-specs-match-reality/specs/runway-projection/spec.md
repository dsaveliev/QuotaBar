## MODIFIED Requirements

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

### Requirement: Runway projection

The system SHALL project, per window, the time at which the consumed amount
would reach the limit at the derived burn rate, and SHALL compare that
projection against the time remaining until the window resets.

#### Scenario: projection outlasts the reset

- **WHEN** the projected exhaustion time is at or after the reset time
- **THEN** the window's runway is reported as ok with the projected duration

#### Scenario: projection outlasts the reset

- **WHEN** the projected exhaustion time falls before the reset time
- **THEN** the window's runway is reported as short, together with the amount by
  which it falls short of the reset

#### Scenario: no limit to project against

- **WHEN** the window carries no limit
- **THEN** no projection is reported and the window is annotated as having no
  limit

#### Scenario: no reset to project against

- **WHEN** the window carries no reset timestamp, or the timestamp is not finite
- **THEN** no projection is reported and the window is annotated as having no
  reset

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