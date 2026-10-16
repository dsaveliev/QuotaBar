# Context

The installed system and the written spec disagree. `Requirement: Quit` says
the app "SHALL terminate cleanly on quit"; the LaunchAgent says a quit is
indistinguishable from a crash. The bug is in the installer, not in the app.

# Decisions

## Restart only on failure, not on every exit

`KeepAlive` accepts a dictionary rather than a bare boolean. With
`SuccessfulExit = false`, launchd relaunches the job only when the process
exits non-zero. A graceful `NSApplication.terminate` exits 0 and stays down.

Chosen over the alternatives:

- **`Crashed = true` only.** Rejected: `kill -TERM` (how many people stop a
  background agent) does not register as a crash, so a deliberate kill would
  leave it down — the failure mode we are trying to remove.
- **`bootout` from inside the Quit handler.** Rejected: it makes every
  restart-in-this-login-session a manual `launchctl` incantation, which is
  the non-obvious behaviour we are trying to remove. It also couples the app
  binary to launchctl and breaks under any future sandboxing.
- **Bare `KeepAlive = true`.** Rejected: this is the bug.

## The app needs no code change

`AppModel.quit()` already terminates with status 0. Nothing in Swift moves.

## The installer's own quit must stay ordered

`install.sh` quits the running instance before overwriting the bundle. Under
the new rule that quit is final, so the script is solely responsible for
bringing the agent back. It already does — `bootstrap` plus `kickstart -k` run
after the copy. The comment on that block records the dependency, because
removing the quit would look like a harmless tidy-up and would in fact break
reinstalls.

# Risks

- **A user who relied on "Quit" coming back** now has to relaunch. That is the
  requested behaviour; the manual path for the current session is
  `launchctl kickstart gui/$UID/dev.dmitrii.quotabar`.
- **`kickstart` after an explicit quit** is the one way to get the app back in
  this session, and it is not obvious. Worth a line in the README.

# Migration

Re-running `./scripts/install.sh` rewrites the plist, so the fix lands for
existing installs on the next upgrade. No separate migration step.