## MODIFIED Requirements

### Requirement: Quit

The system SHALL terminate cleanly on quit and persist settings and sample
history, so the next launch resumes with the same configuration and projection
basis. A normal exit SHALL be final: the app stays off until the user starts it
again. An abnormal exit SHALL be recovered automatically, and the app SHALL be
running whenever the user is logged in.

#### Scenario: quit and relaunch

- **WHEN** the user quits the app and launches it again
- **THEN** the interval setting, item visibility choices, and sample histories
  are as they were at quit

#### Scenario: a graceful quit stays off

- **WHEN** the user quits the app from its panel
- **THEN** the app is no longer running and is not started again by itself

#### Scenario: an abnormal exit is recovered

- **WHEN** the app terminates without exiting normally, such as a crash or a
  forced kill
- **THEN** the app is started again automatically

#### Scenario: the app is present at login

- **WHEN** the user logs in
- **THEN** the app is running