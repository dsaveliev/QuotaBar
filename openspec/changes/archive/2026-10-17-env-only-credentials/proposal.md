# Proposal

## Why

The app reads a credential file written by another tool and only falls back to
the environment. That inverts the useful order and creates a dependency the
user did not ask for: if OpenCode is not installed, or moves its data
directory, or is not the thing that issued the token, this app stops working
and says nothing about why.

There is also a trap waiting behind the obvious fix. The app runs as a
LaunchAgent, and a LaunchAgent inherits launchd's environment, **not the user's
shell**. A token exported in `~/.zshrc` is invisible to it — demonstrated
here: `MINIMAX_TOKEN` is exported in `~/.zshrc`, is absent from launchd's
environment, and MiniMax reports no token. So "just use the environment" is not
a source swap, it is a delivery problem.

## What Changes

- **The environment is the only credential source.** Reading
  `~/.local/share/opencode/auth.json` goes away entirely, along with the keys
  looked up in it, the unreadable-file outcome, and the `noCredentialFile` code
  and its message. One source, no precedence to reason about.

- **`install.sh` writes the token into the LaunchAgent plist** as
  `EnvironmentVariables`, taking the value from the shell that runs the script.
  That is what makes it survive a reboot, since `launchctl setenv` lasts only
  for the current login session.

- **The plist is written with owner-only permissions**, because it now holds a
  secret.

- **The missing-token message says to re-run `install.sh`**, because setting the
  variable is not sufficient on its own.

## The promise this changes

The README and `SECURITY.md` both say the token is never written to disk, and
`Credential secrecy` says the same. That was true and is no longer. After this
change:

- the token **is** on disk, in `~/Library/LaunchAgents/dev.dmitrii.quotabar.plist`,
  readable by the user who owns it, and by anything running as that user
- it is still never logged, never rendered, and never sent anywhere but the
  subscription's own endpoint

This is the tradeoff of making it work after a reboot without asking anyone to
remember a command. It is recorded in the spec rather than left as a gap
between the docs and the code.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `quota-subscription-polling`: the environment is the only source, and where a
  token is stored changes.
- `menubar-quota-surface`: the missing-token message says how to make the
  variable visible to the agent.

## Impact

- `Sources/QuotaBarKit/Net/CredentialStore.swift` — file reading, the auth-file
  source, `isAuthFileUnreadable`.
- `Sources/QuotaBarKit/Providers/` — `authKeys`, the `noCredentialFile` case.
- `Sources/QuotaBarKit/Engine/QuotaEngine.swift` — the unreadable-file consult.
- `Sources/QuotaBarKit/Engine/QuotaEngine.swift`, `QuotaErrorCode` — one fewer
  error code.
- `scripts/install.sh` — writes `EnvironmentVariables`, chmods the plist.
- `README.md`, `SECURITY.md`, and the specs' secrecy wording, which all promise
  the opposite of what will now be true.
- Removing the OpenCode dependency is a **breaking change for anyone relying on
  it** — every existing user of the file path must export a variable instead.