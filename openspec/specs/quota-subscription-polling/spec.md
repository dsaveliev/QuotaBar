# quota-subscription-polling Specification

## Purpose
Owns how the app learns what each coding-plan subscription currently has left:
which credentials to use, which endpoint to call, how each provider's payload is
read, how often to ask, and what is shown when an answer does not arrive.

## Requirements

### Requirement: Dual subscription support

The system SHALL track the Z.ai coding plan and the MiniMax token plan as two
independent subscriptions, polling both concurrently without requiring any
editor, terminal agent, or OpenCode session to be running.

#### Scenario: both subscriptions polled

- **WHEN** the app is running and both subscriptions have usable credentials
- **THEN** each subscription's quota is refreshed on its own schedule and a
  failure in one does not suppress or delay the other

#### Scenario: one subscription unconfigured

- **WHEN** credentials for only one of the two subscriptions resolve
- **THEN** the configured subscription reports live data and the other reports
  its own missing-credential state without blocking the first

### Requirement: Credential resolution

The system SHALL resolve a bearer token per subscription at refresh time by
looking up, in order, the subscription's known credential file entries, then
its known environment variable names, and SHALL report a missing-credential
error when none resolve.

#### Scenario: credential found in the credential file

- **WHEN** the credential file `~/.local/share/opencode/auth.json` contains a
  non-empty `key` under one of the subscription's known entries
  (Z.ai: `zai-coding-plan`, `zai`; MiniMax: `minimax-coding-plan`,
  `minimax-cn-coding-plan`, `minimax`)
- **THEN** that key is used as the bearer token for that subscription

#### Scenario: credential found in the environment

- **WHEN** no credential file entry resolves
- **THEN** the first non-empty environment variable among the subscription's
  names (Z.ai: `ZAI_TOKEN`, `Z_AI_TOKEN`; MiniMax: `MINIMAX_API_KEY`) is used

#### Scenario: unreadable or malformed credential file

- **WHEN** `~/.local/share/opencode/auth.json` is absent, unreadable, or not
  valid JSON
- **THEN** the file is treated as contributing no entries and resolution falls
  through to the environment variables without surfacing an error of its own

#### Scenario: no credential resolves

- **WHEN** neither the credential file nor any environment variable yields a
  non-empty token for a subscription
- **THEN** that subscription's state becomes the missing-credential error and no
  network request is issued for it

### Requirement: Credential secrecy

The system SHALL transmit the resolved token only to the subscription's own
quota endpoint as an `Authorization: Bearer` header over https, and SHALL never
write, log, or display it.

#### Scenario: token never reaches a user-visible surface

- **WHEN** any state — success, failure, or diagnostic — is rendered or written
  to disk
- **THEN** no token value appears in that state, and no log line contains the
  token or any request header

#### Scenario: insecure endpoint refused

- **WHEN** an endpoint is configured with a non-https scheme
- **THEN** the request is refused and the failure is reported as an insecure
  endpoint rather than as a network error

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

### Requirement: Z.ai payload interpretation

The system SHALL read the Z.ai quota payload into per-window rows where the
five-hour window and the weekly window are identified by their unit code, where
a limit is derived from consumed plus remaining when both are present, and
where a percent is clamped into 0–100.

#### Scenario: named windows

- **WHEN** the payload lists quota entries whose unit code is 3 or 6
- **THEN** those entries are reported as the `5h` and `7d` rows respectively and
  are ordered five-hour first, weekly second

#### Scenario: percent derived when absent

- **WHEN** an entry carries consumed and remaining counts but no explicit
  percent
- **THEN** the percent is computed as consumed divided by consumed plus
  remaining, and the limit is reported as that sum

#### Scenario: out-of-range percent clamped

- **WHEN** an entry reports a percent outside 0–100
- **THEN** the reported percent is clamped into 0–100

#### Scenario: unknown shape yields no rows

- **WHEN** the payload contains no recognisable quota entries
- **THEN** the subscription reports the empty-payload error

### Requirement: MiniMax payload interpretation

The system SHALL read the MiniMax token-plan payload into a five-hour row and a
weekly row whose window durations are the declared plan durations, whose
percent is the complement of the payload's *remaining* percent, and whose plan
status is honoured.

#### Scenario: active plan with two windows

- **WHEN** a plan entry reports a remaining percent for both the current
  interval and the weekly window, and both statuses indicate an active plan
- **THEN** the `5h` and `7d` rows are reported with usage percent equal to
  100 minus the remaining percent

#### Scenario: inactive window omitted

- **WHEN** a window's status does not indicate an active plan
- **THEN** that window's row is omitted and the other window is still reported

#### Scenario: percent-space projection basis

- **WHEN** a MiniMax row is produced
- **THEN** the row exposes a usage figure and a limit on a 0–100 percent scale
  so that burn rate is expressible in percent points per unit time

### Requirement: Unified quota row model

The system SHALL normalise every subscription's payload into rows carrying a
window label, consumed amount, limit, consumed percent, reset timestamp, and —
where the provider supplies one — the window duration.

#### Scenario: row ordering

- **WHEN** a subscription yields more than two rows
- **THEN** the five-hour row is ordered first, the weekly row second, remaining
  rows keep their parsed order, and duplicate labels are dropped keeping the
  first occurrence

#### Scenario: absent window duration

- **WHEN** a provider does not supply a window duration for a row
- **THEN** the row still reports label, usage, limit, percent, and reset
  timestamp, and is displayed without a pace marker

### Requirement: Refresh cadence and deduplication

The system SHALL refresh each subscription every 60 seconds by default, allow
the interval to be configured, reject configured intervals below 10 seconds or
above the platform timer ceiling, and collapse refresh triggers that arrive
while a request for the same subscription is already in flight.

#### Scenario: timer cadence

- **WHEN** the app has been running for longer than one interval with no manual
  trigger
- **THEN** each configured subscription issues a new refresh

#### Scenario: overlapping triggers

- **WHEN** a timer, menu-open, and manual refresh all fire while a request for
  the same subscription is in flight
- **THEN** exactly one network request is in flight and the completed result
  satisfies all of them

#### Scenario: rejected interval

- **WHEN** the configured interval is below 10 seconds, above the platform
  ceiling, or not a finite number
- **THEN** the value is clamped into the supported range rather than crashing or
  being ignored

### Requirement: Error taxonomy

The system SHALL classify every refresh outcome into one of: missing
credential, insecure endpoint, network error, HTTP status, malformed JSON,
timeout, empty payload, or success, and SHALL keep the classification stable
across renders.

#### Scenario: transport failures distinguished

- **WHEN** a request cannot connect, exceeds the timeout, or returns a status of
  400 or above
- **THEN** the outcome is classified as network error, timeout, or the
  corresponding HTTP status respectively, and never as success

#### Scenario: unusable success payload

- **WHEN** a 2xx response body is not valid JSON, or parses to no quota rows
- **THEN** the outcome is classified as malformed JSON or empty payload

#### Scenario: error clears on recovery

- **WHEN** a refresh succeeds after an earlier refresh failed
- **THEN** the earlier error state is discarded and the subscription reports
  live data again

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
