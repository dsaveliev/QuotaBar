## ADDED Requirements

### Requirement: MiniMax window boundaries

The system SHALL take each MiniMax window's reset timestamp from that window's
own boundary in the payload — the five-hour row from the interval window's end
and the weekly row from the weekly window's end — and SHALL NOT derive one
window's reset from the other window's timestamps. The two windows are
independent, so the weekly window's end is reported even when the weekly window
began before the current five-hour window did.

#### Scenario: each row takes its own window's end

- **WHEN** a MiniMax plan entry reports an interval window and a weekly window
  with different ends
- **THEN** the `5h` row's reset timestamp is the interval window's end, and the
  `7d` row's reset timestamp is the weekly window's end

#### Scenario: the weekly window's own end is used

- **WHEN** a MiniMax plan entry's weekly window began before the current
  five-hour window did
- **THEN** the `7d` row's reset timestamp is still the weekly window's own end,
  not the five-hour window's end

#### Scenario: the weekly window's remaining time counts down to its own end

- **WHEN** a MiniMax plan entry reports a weekly window that is partway through
  its seven days
- **THEN** the payload's weekly remaining time is the distance from the capture
  to the weekly window's end, and is shorter than the window's full length
