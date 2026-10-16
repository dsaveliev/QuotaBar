## MODIFIED Requirements

### Requirement: Credential resolution

The system SHALL resolve a bearer token per subscription at refresh time by
looking up, in order, the subscription's known credential file entries, then
its known environment variable names, and SHALL report a missing-credential
error when none resolve. Each subscription's environment variable names SHALL
follow one scheme, `<PROVIDER>_TOKEN`, and SHALL be the only names it reads.
When none resolve, the system SHALL distinguish a credential file that could not
be read at all from one that was read and held nothing relevant, because the two
need different corrections.

#### Scenario: credential found in the credential file

- **WHEN** the credential file `~/.local/share/opencode/auth.json` contains a
  non-empty `key` under one of the subscription's known entries
  (Z.ai: `zai-coding-plan`, `zai`; MiniMax: `minimax-coding-plan`,
  `minimax-cn-coding-plan`, `minimax`)
- **THEN** that key is used as the bearer token for that subscription

#### Scenario: credential found in the environment

- **WHEN** no credential file entry resolves
- **THEN** the subscription's environment variable, `ZAI_TOKEN` for Z.ai and
  `MINIMAX_TOKEN` for MiniMax, is used when it is non-empty

#### Scenario: unreadable or malformed credential file

- **WHEN** `~/.local/share/opencode/auth.json` is absent, unreadable, or not
  valid JSON
- **THEN** the file is treated as contributing no entries and resolution falls
  through to the environment variables

#### Scenario: no credential resolves

- **WHEN** neither the credential file nor the subscription's environment
  variable yields a non-empty token, and the credential file could not be read
  at all
- **THEN** that subscription reports that there is no OpenCode credentials file,
  naming the file, and issues no network request for it

#### Scenario: no credential for this subscription

- **WHEN** neither the credential file nor the subscription's environment
  variable yields a non-empty token, and the credential file was readable
- **THEN** that subscription reports a missing token, naming the variable to set
  and signing in with OpenCode as the alternative, and issues no network request

#### Scenario: only the current environment names are read

- **WHEN** the environment holds `Z_AI_TOKEN` or `MINIMAX_API_KEY` but not the
  subscription's current variable
- **THEN** those names are not consulted, and the subscription reports a missing
  token

### Requirement: Error taxonomy

The system SHALL classify every refresh outcome into one of: unreadable
credential file, missing credential, insecure endpoint, network error, HTTP
status, malformed JSON, timeout, empty payload, or success, and SHALL keep the
classification stable across renders.

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
- **THEN** its message names its own variable first and signing in with OpenCode
  second, and differs from the other subscription's only in that variable

#### Scenario: an unreadable file is not blamed on the environment

- **WHEN** the credential file could not be read at all
- **THEN** the message names the file rather than suggesting an environment
  variable, because setting one would be the wrong fix