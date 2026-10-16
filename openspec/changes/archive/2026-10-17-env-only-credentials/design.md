# Design

## Context

See `proposal.md` — Why, which carries the measurement that `~/.zshrc` does not
reach a LaunchAgent.

## Goals / Non-Goals

**Goals:**

- One credential source.
- It works after a reboot without anyone remembering anything.
- No claim in the docs that the code does not honour.

**Non-Goals:**

- No credential file of our own. The app reads the environment and nothing else.
- No keychain. It would work and be better, and it is a bigger change than this.
- No attempt to preserve the OpenCode path as a fallback.

## Decisions

### The environment only, because one source beats a precedence

The file path was a dependency on another tool's data layout. Every future
question about it — "what if it moves", "what if it is malformed", "which of
the two wins" — was answered by code that existed only to manage the
dependency. Deleting it deletes those questions.

Rejected: keep the file and make it the fallback. That keeps the precedence, the
unreadable-file outcome, and the failure mode the user just reported.

### The plist carries the token, because there is nowhere else

A LaunchAgent needs its variables at the moment launchd starts it. The three
places they can come from:

| | survives reboot | where the token lives | cost |
| --- | --- | --- | --- |
| `launchctl setenv` | no | nowhere | a command after every login |
| `EnvironmentVariables` in the plist | yes | the plist | token on disk |
| a file the app reads at runtime | yes | that file | a credential store we would own |

The middle one is chosen: it is the mechanism launchd already provides for
exactly this, it adds no new file, and `uninstall.sh` already removes the plist,
so the token's lifetime matches the app's.

Rejected: `launchctl setenv` from a login hook. It survives only until reboot, so
it needs another agent to re-run it, which is the same complexity with more
moving parts.

Rejected: our own credentials file. It is a credential store, and it would put
us back in the business of reading and writing secrets — the thing this change
is meant to reduce.

### 0600 on the plist

The plist holds a bearer token for two providers. It is created with owner-only
permissions, and `install.sh` sets them explicitly rather than trusting
`umask`.

### The message tells you to re-run the installer

Setting `ZAI_TOKEN` in a shell changes nothing for an agent that has already
been registered. That is exactly the confusion this change creates, so the
error message names the second step rather than leaving the user to discover it
after a reboot.

## Risks / Trade-offs

- **The token is on disk.** Stated plainly in the proposal, the spec and
  `SECURITY.md`. It is readable by the user and by anything running as them,
  which is also true of `~/.zshrc` — where the token already was.
- **Existing users of the file path break.** They must export a variable and
  re-run the installer. Stated in the README as a breaking change.
- **`install.sh` now handles a secret.** It does not echo it, does not write it
  anywhere else, and the plist is the single copy.

## Migration Plan

1. Export `ZAI_TOKEN` and `MINIMAX_TOKEN` in the shell.
2. Run `./scripts/install.sh`. It reads the environment, writes the plist, and
   registers the agent.
3. The OpenCode credentials file is no longer read and may be left alone.

## Open Questions

None.