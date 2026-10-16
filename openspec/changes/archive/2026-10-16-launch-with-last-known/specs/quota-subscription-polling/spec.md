## MODIFIED Requirements

### Requirement: Freshness and staleness

The system SHALL age data by the wall-clock gap between the last successful
refresh and now, SHALL flag data stale once that gap exceeds two refresh
intervals, and SHALL report a subscription whose refreshes are failing as an
error rather than as stale data. Data restored from a previous run is aged from
the moment it was fetched, not from the moment it was restored.

#### Scenario: fresh data

- **WHEN** the last successful refresh is younger than two intervals
- **THEN** the subscription is reported as fresh and its age is displayed

#### Scenario: stale data

- **WHEN** the last successful refresh is older than two intervals
- **THEN** the subscription is flagged stale, supports no positive verdict, and
  the age is displayed in a warning style

#### Scenario: failing but attempting

- **WHEN** refreshes keep being attempted and keep failing
- **THEN** freshness is measured from the most recent attempt, so a live but
  failing endpoint is reported as an error rather than as stale data

#### Scenario: figures from before this launch are not stale

- **WHEN** the app starts and shows figures restored from a previous run
- **THEN** their true age is reported, they are not flagged stale, because no
  refresh was due yet, and they support no verdict until one confirms them

## ADDED Requirements

### Requirement: Last known figures across restarts

The system SHALL remember the figures reported by each subscription's last
successful refresh, and SHALL restore them when the app starts so the menu bar
shows numbers before the first response arrives. Restored figures SHALL be
presented as measurements only: they carry no verdict until a refresh this launch
confirms them. The system SHALL NOT restore figures older than one week.

#### Scenario: figures survive a restart

- **WHEN** the app is started after a previous run fetched a subscription's
  figures
- **THEN** those figures are shown immediately, before the first refresh of this
  launch returns

#### Scenario: one subscription never leaks into another

- **WHEN** figures are restored
- **THEN** each subscription receives only the figures that were recorded for
  it

#### Scenario: the first live answer replaces them

- **WHEN** a refresh returns fresh figures for a subscription that had restored
  ones
- **THEN** the fresh figures replace them, the restored flag is cleared, and the
  verdict is offered again

#### Scenario: figures older than a week are discarded

- **WHEN** the app starts and the newest figures recorded for a subscription are
  more than a week old
- **THEN** nothing is restored for that subscription, and it shows no figures
  until a refresh returns

#### Scenario: a damaged file costs only what it damages

- **WHEN** the remembered figures cannot be read, or one subscription's entry is
  malformed
- **THEN** the app starts normally, restores whatever entries are intact, and
  treats the rest as never fetched