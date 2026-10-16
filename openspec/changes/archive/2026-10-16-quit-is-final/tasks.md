# Tasks

## 1. Conditional KeepAlive

- [x] 1.1 Replace the bare `<true/>` under `KeepAlive` in `scripts/install.sh` with a dictionary carrying `SuccessfulExit = false`
- [x] 1.2 Update the script's header comment: it restarts the app on abnormal exit, not on every exit
- [x] 1.3 Note on the pre-install quit block that the agent is brought back by the `bootstrap` + `kickstart` below it and must not be reordered or dropped

## 2. Documentation

- [x] 2.1 Add to the README that Quit is now final, that a crash still returns, and how to start the app again within the same login session (`launchctl kickstart`)

## 3. Verify

- [x] 3.1 Validate the change with `openspec validate quit-is-final --strict`
- [x] 3.2 Reinstall and run the suite; confirm the installed plist lints clean
- [x] 3.3 Prove the graceful branch: send a quit AppleEvent, confirm the process stays gone past the 10s throttle interval
- [x] 3.4 Prove the abnormal branch: `kill -9`, confirm the app comes back on its own with a new pid
- [x] 3.5 Confirm the login case is unaffected by reading `RunAtLoad` in the installed plist
- [x] 3.6 Archive the change and commit