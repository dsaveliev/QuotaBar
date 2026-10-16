## MODIFIED Requirements

### Requirement: Credential secrecy

The system SHALL transmit the resolved token only to the subscription's own
quota endpoint as an `Authorization: Bearer` header over https, and SHALL never
write, log, or display it. The system itself SHALL NOT persist a token to disk:
where a token is stored so that the login agent can present it is the
installer's concern, not the running app's.

#### Scenario: token never reaches a user-visible surface

- **WHEN** any state — success, failure, or diagnostic — is rendered or written
  to disk
- **THEN** no token value appears in that state, and no log line contains the
  token or any request header

#### Scenario: insecure endpoint refused

- **WHEN** an endpoint is configured with a non-https scheme
- **THEN** the request is refused and the failure is reported as an insecure
  endpoint rather than as a network error

#### Scenario: the app does not persist a token

- **WHEN** the app runs
- **THEN** it writes no token to disk, and the token it holds exists in its
  process environment only

## REMOVED Requirements

### Requirement: Credential resolution

The system SHALL resolve a bearer token per subscription at refresh time by
looking up, in order, the subscription's known credential file entries, then
its known environment variable names, and SHALL report a missing-credential
error when none resolve.

Removed because the credential file is gone: two of its scenarios describe
reading one, and one describes an unreadable file, which can no longer happen.
Replaced by `Environment credential resolution`.

### Requirement: Error taxonomy

The system SHALL classify every refresh outcome into one of: unreadable
credential file, missing credential, insecure endpoint, network error, HTTP
status, malformed JSON, timeout, empty payload, or success, and SHALL keep the
classification stable across renders.

Removed because the unreadable-credential-file outcome no longer exists, and
one of its five scenarios is about that file. Replaced by
`Refresh outcome taxonomy`.

## ADDED Requirements

### Requirement: Environment credential resolution

The system SHALL resolve a bearer token per subscription at refresh time from
the environment alone, reading the subscription's variable `ZAI_TOKEN` for Z.ai
and `MINIMAX_TOKEN` for MiniMax, and SHALL report a missing-credential error
when none resolves. The system SHALL NOT read any credential file, and SHALL
have no credential source other than the environment.

#### Scenario: credential found in the environment

- **WHEN** the subscription's variable holds a non-empty value in the process
  environment
- **THEN** that value is used as the bearer token for that subscription

#### Scenario: a blank value is not a credential

- **WHEN** the subscription's variable is absent or holds only whitespace
- **THEN** no token resolves for that subscription, and no network request is
  issued for it

#### Scenario: no credential file is read

- **WHEN** the system looks for a token
- **THEN** it consults the environment only, and neither opens nor requires any
  file to hold a credential

#### Scenario: no credential resolves

- **WHEN** the subscription's variable yields no non-empty token
- **THEN** that subscription reports a missing token, naming the variable and
  the step that makes it visible to the agent, and issues no network request

#### Scenario: only the current environment names are read

- **WHEN** the environment holds `Z_AI_TOKEN` or `MINIMAX_API_KEY` but not the
  subscription's current variable
- **THEN** those names are not consulted, and the subscription reports a missing
  token

### Requirement: Refresh outcome taxonomy

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

#### Scenario: missing-credential messages are parallel

- **WHEN** either subscription reports a missing token
- **THEN** its message names its own variable first and the step that makes it
  visible to the agent second, and differs from the other subscription's only in
  that variable