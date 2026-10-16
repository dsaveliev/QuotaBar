## MODIFIED Requirements

### Requirement: Quit

The system SHALL terminate cleanly on quit, persisting settings and sample
history so the next launch resumes with the same configuration and projection
basis, and SHALL treat that quit as final: once the app has exited normally it
SHALL stay off until the user starts it again, either by launching the app
directly or by asking the service manager to start the job. The system SHALL
restart the app automatically only when it exits abnormally, so that a crash
cannot leave a quota display silently absent.

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