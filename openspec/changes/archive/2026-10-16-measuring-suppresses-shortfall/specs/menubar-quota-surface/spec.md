## MODIFIED Requirements

### Requirement: Shortfall annotation

The system SHALL state, for a window whose projection runs dry before its reset,
how much earlier it runs out, on its own line beneath that window's runway line,
in muted text rather than in the verdict's colour. The runway figure itself
SHALL be presented identically for every window, regardless of verdict. A window
whose projection is not yet trustworthy SHALL NOT be given a shortfall, and a
window's runway line and its annotation below SHALL never make claims that
contradict one another.

#### Scenario: runway line is uniform

- **WHEN** two windows are shown, one on pace and one short
- **THEN** both runway readings begin with the same `runway` label and show the
  projected duration alone

#### Scenario: shortfall stated

- **WHEN** a window's projection falls before its reset
- **THEN** a line beneath it says how much earlier it ends, in muted text

#### Scenario: blocked window

- **WHEN** a window's verdict is `blocked`
- **THEN** its runway line states that the limit is reached and when it resets,
  rather than projecting a runway

#### Scenario: a measuring window states no shortfall

- **WHEN** a window's projection would fall before its reset but the window has
  not yet been observed for long enough to trust that projection
- **THEN** the line beneath it says the measurement is still in progress, and
  does not state how much earlier the window ends

#### Scenario: at most one line beneath the runway

- **WHEN** a window is shown
- **THEN** it carries either a shortfall, a measurement in progress, or neither,
  and never both