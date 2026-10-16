## MODIFIED Requirements

### Requirement: Freshness and staleness

The system SHALL age data by the wall-clock gap between the last successful
refresh and now, SHALL flag data stale once that gap exceeds two refresh
intervals, and SHALL report a subscription whose refreshes are failing as an
error rather than as stale data.

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

### Requirement: Endpoint selection and region detection

The system SHALL probe a subscription's declared endpoints in order, use the
first endpoint whose response reports success, and remember that choice for the
lifetime of the app process. Envelope success and payload emptiness are
different questions: once a host's envelope is accepted, an empty payload is
reported as no data rather than used to fall through to another host.

#### Scenario: primary endpoint healthy

- **WHEN** the first declared endpoint returns a payload the subscription's
  parser accepts
- **THEN** that endpoint is used for that and every later refresh

#### Scenario: region fallback

- **WHEN** MiniMax's international endpoint returns a payload whose
  `base_resp.status_code` is non-zero
- **THEN** the regional `api.minimax.cn` endpoint is probed, and if it succeeds
  it becomes the remembered endpoint for all later refreshes

#### Scenario: an empty plan is not a region problem

- **WHEN** the chosen endpoint reports envelope success but carries no quota
  windows
- **THEN** the subscription reports no data on that endpoint and does not probe
  another host, because the host answered correctly and an empty plan is not a
  regional failure

#### Scenario: all endpoints fail

- **WHEN** every declared endpoint for a subscription fails
- **THEN** the subscription reports the failure of the last probe and the next
  refresh retries from the first endpoint again