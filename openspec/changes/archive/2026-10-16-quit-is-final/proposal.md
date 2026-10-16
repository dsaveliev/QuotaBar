# Why

The Quit button does not quit. `scripts/install.sh` registers the LaunchAgent
with an unconditional `<key>KeepAlive</key><true/>`, and `AppModel.quit()`
terminates cleanly with exit status 0. launchd restarts a KeepAlive job on
*any* exit, so the app is back in the menu bar a second after the user closes
it. The user cannot turn the plugin off.

This is the "never let a menu bar app die silently" instinct applied too
broadly. Crash recovery is wanted; overriding the user's explicit decision is
not.

# What Changes

`KeepAlive` becomes a dictionary that restarts the job only on a
non-successful exit:

```xml
<key>KeepAlive</key>
<dict>
    <key>SuccessfulExit</key>
    <false/>
</dict>
```

The three behaviours then separate cleanly:

| event | before | after |
| --- | --- | --- |
| Quit button / graceful AppleEvent quit | comes back | **stays off** |
| crash, `kill -9`, OOM | comes back | comes back |
| login | starts | starts |

`RunAtLoad` already covers the login case, so nothing is lost there.

`scripts/install.sh` also needs one follow-on fix: it runs
`osascript -e 'quit app "QuotaBar"'` before replacing the bundle. Under the new
rule that quit is final and the agent stays down — which is correct, because
the script bootstraps and kickstarts it again immediately afterwards. The
ordering already does this; the comment must say so, so nobody later "cleans
up" the quit and silently breaks the upgrade path.

The delta lands on the existing `Requirement: Quit` in
`spec/menubar-quota-surface`, which already promises "terminate cleanly".
That promise is what the user is entitled to; this change makes the installed
system match the spec it was written against.

# Non-goals

- No UI change. The Quit button stays exactly where it is; it just is now true.
- No new settings, no "start on login" toggle. Out of scope.
- No change to the manual escape hatch: `launchctl bootout gui/$UID/dev.dmitrii.quotabar`
  remains the way to stop the app for the rest of the login session.