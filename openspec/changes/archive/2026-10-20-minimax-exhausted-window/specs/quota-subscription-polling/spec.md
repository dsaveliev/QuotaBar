## MODIFIED Requirements

### Requirement: MiniMax payload interpretation

The system SHALL read the MiniMax token-plan payload into a five-hour row and a
weekly row whose window durations are the declared plan durations, and SHALL
report each window by the plan status the payload reports for it: a limited
window's percent is 100 minus its remaining percent, an exhausted window's
percent is 100 whether or not it reports a remaining percent, an unlimited
window is omitted, and a status the endpoint does not define is read as
limited.

#### Scenario: active plan with two windows

- **WHEN** a plan entry reports a remaining percent for both the current
  interval and the weekly window, and both statuses report a limited plan
- **THEN** the `5h` and `7d` rows are reported with usage percent equal to
  100 minus the remaining percent

#### Scenario: inactive window omitted

- **WHEN** a window's status reports an unlimited plan, so the plan meters no
  limit against it
- **THEN** that window's row is omitted and the other window is still reported

#### Scenario: exhausted window reported as consumed

- **WHEN** a window's status reports an exhausted plan
- **THEN** that window's row is reported with usage percent 100, and the other
  window is still reported

#### Scenario: exhausted status outranks a stale percentage

- **WHEN** a window's status reports an exhausted plan and the payload reports
  a remaining percent above zero for that same window
- **THEN** that window's row is reported with usage percent 100 rather than the
  complement of that percent

#### Scenario: an undefined status is read as limited

- **WHEN** a window reports a status the endpoint does not define
- **THEN** that window's row is reported from its remaining percent, as a
  limited window would be

#### Scenario: percent-space projection basis

- **WHEN** a MiniMax row is produced
- **THEN** the row exposes a usage figure and a limit on a 0–100 percent scale
  so that burn rate is expressible in percent points per unit time

## ADDED Requirements

### Requirement: MiniMax plan entry recognition

The system SHALL recognise a MiniMax plan entry as carrying a plan when it
reports the timestamps of both quota windows, and SHALL NOT require it to report
a remaining percent for every window: a window whose percent the payload omits
is reported from its plan status alone, and the windows the payload does
describe are still reported.

#### Scenario: entry accepted without a percentage

- **WHEN** a MiniMax plan entry reports both windows' timestamps but omits the
  remaining percent for a window whose status reports an exhausted plan
- **THEN** the entry is recognised, that window is reported as fully consumed,
  and the window the payload does describe is still reported

#### Scenario: entry without window timestamps yields no rows

- **WHEN** a MiniMax payload's entries report no quota window timestamps
- **THEN** the subscription reports the empty-payload error
