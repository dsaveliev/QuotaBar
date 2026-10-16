## REMOVED Requirements

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

Retired only to retitle its scenarios: two of them shared a title, and the
second's title contradicted its own body. Re-added below with distinct titles.


## ADDED Requirements

#
