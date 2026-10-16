# QuotaBar

A macOS menu bar agent that shows how much of your **Z.ai** and **MiniMax**
coding-plan allowance is left, and — the part that matters — **whether the
current pace outlasts the window**.

```
✓ zai   1% 52%
```

One item, whichever provider you last selected: the verdict leads, because it
is the only part that answers "do I need to do something". Both subscriptions are polled at
once and independently of anything else on the machine: there is no editor,
terminal agent, or OpenCode session involved. The app runs at login, reads your
credentials from the file OpenCode already writes, and keeps a single status
item in the menu bar. One entrance to the panel means there is never a question
of which item a figure belongs to.

Open a dropdown for the full picture:

```
Z.ai                                    ✓
just now · api.z.ai

5h                              52%   !!
██████████████░░░░░░░░░░░░░░░░
resets in 3h 12m            runway ~2h 5m
ends 1h 7m before the reset

7d                              41%   ✓
██████████░░░░░░░░░░░░░░░░░░░░░░
resets in 3d 4h            runway ~10d
```

The runway line has the same shape whatever the verdict; a shortfall is said on
the muted line beneath it, never by colouring the number.

## What the numbers mean

Each window gets one verdict, and the glyph and the bar colour follow the
verdict — not the raw percentage.

| Glyph | Verdict | Meaning |
| --- | --- | --- |
| `✓` | ok | the projection comfortably outlasts the reset |
| `!` | tight | the projection lands within 1.5× the distance to the reset |
| `!!` | short | at this pace the quota runs dry **before** it resets |
| `✗` | blocked | the limit is already reached |
| `?` | unknown | not enough evidence yet — a fresh install, or stale data |

The marker on each bar is *now*: fill to the left of it is quota consumed so
far, and the gap to the right edge is how much of the window's time is left.

The label is drawn in a font where every character is the same width, and each
part of it is padded to the width its widest value needs, so the item does not
resize as figures change. Reordering the same characters cannot change the sum,
so the label is as many characters as it has always been.

## Where the runway comes from

Runway is a burn-rate projection, not a guess:

1. Every refresh records one usage sample per window, in a history keyed by
   `provider:window`, so the two subscriptions never mix.
2. Once at least two samples span a minute, burn rate is
   `(newest − oldest usage) ÷ elapsed`.
3. `runway = (limit − usage) ÷ burn rate`, compared against `reset − now`.
4. A verdict needs evidence proportional to the window: at least **1/20 of its
   own duration**. A five-hour window therefore needs fifteen minutes and a
   weekly one about eight hours. Until then the glyph is `?`, the panel's runway
   line reads `runway measuring…`, and the muted line beneath it says how far
   along the wait is — e.g. `measuring 68% of the evidence it needs`, because a
   bare "wait" reads as a hang. Without this the weekly window reported itself
   as
   `short` minutes after launch — a fifteen-minute extrapolation across seven
   days, which is noise, not a warning.
5. Exhaustion never waits: a window at its limit reads `✗` immediately.

The history is written to `~/Library/Application Support/QuotaBar/history.json`,
so the projection survives a restart and is available on the first refresh
after launch instead of warming up from scratch.

A window boundary — a changed reset timestamp, or a counter that rolled over —
discards that window's samples and starts over.

## Credentials

The token is resolved **on every refresh**, so logging in after the app started
is picked up on the next tick. Order:

1. `~/.local/share/opencode/auth.json`
   - Z.ai: `zai-coding-plan`, then `zai`
   - MiniMax: `minimax-coding-plan`, `minimax-cn-coding-plan`, then `minimax`
2. Environment: `ZAI_TOKEN` / `Z_AI_TOKEN`, or `MINIMAX_API_KEY`

The file is opened **read-only** and never written. The token is sent only to
that subscription's own quota endpoint, as `Authorization: Bearer`, over
https. It is never logged, never written to disk, and never rendered — including
in error text, which names *where* to put a credential rather than echoing one.

## Install

Requires macOS 13+ and a Swift 6 toolchain (Command Line Tools are enough — no
Xcode needed).

```sh
swift build                 # compile everything
swift run QuotaBarKitTests  # run the test suite
./scripts/install.sh        # build, install to /Applications, register at login
```

`install.sh` builds a release binary, assembles `QuotaBar.app` with
`LSUIElement` set (no Dock tile, no app switcher), ad-hoc signs it, copies it to
`/Applications`, and registers a `LaunchAgent`
(`~/Library/LaunchAgents/dev.dmitrii.quotabar.plist`) with `RunAtLoad` and a
`KeepAlive` that fires **only on an abnormal exit**.

That distinction is the whole reason **Quit** works. The app terminates with
status 0 when you quit it, so launchd leaves it alone: a clean quit is final
and the icon does not come back. If the app crashes or is killed with `kill -9`,
launchd starts it again, because a quota display that silently vanished is
worse than one you did not ask for.

To bring it back within the same login session:

```sh
launchctl kickstart gui/$UID/dev.dmitrii.quotabar
```

A crash is not a quit. `kill -TERM` counts as abnormal and the app returns.

To run the bundle without installing it:

```sh
./scripts/build-app.sh
open build/QuotaBar.app
```

To remove it:

```sh
./scripts/uninstall.sh
```

That unloads the agent and deletes the bundle. Your sample history in
`~/Library/Application Support/QuotaBar` is left alone; delete that directory
too if you want a clean slate.

## Choosing which provider to show

Every panel carries a **provider** picker in its footer:

```
provider  [ Z.ai        ▾ ]
```

It is a single-selection control, not a checklist, and that is deliberate: a
checklist can express "two providers shown, one displayed", which is exactly
the state that leaves you unsure which provider a figure belongs to. Switching
switches the menu bar item immediately — no restart, and the panel stays open.
Both subscriptions keep polling and keep their sample history either way, so
switching back costs nothing.

Pick **Show none** and the menu bar item becomes a plain `QuotaBar` whose panel
is just the picker. You are never left without a way back.

The choice is remembered across restarts.

## Controls

Each panel carries its own controls, so they are always one click away:

- **Refresh** — refresh both subscriptions immediately.
- **every** — the polling cadence: 30s, 60s, 2m, 5m, or 15m.
- **provider** — the picker described above, `Show none` included.
- **Quit** — the app exits and stays out until you start it again.

A panel also refreshes on open when the data on screen is older than the
current cadence.

## Troubleshooting

| Symptom | Cause |
| --- | --- |
| Label reads `zai ?` | the last refresh failed; open the dropdown for the reason |
| Label reads `zai …` | no successful refresh yet |
| `no token (zai login or ZAI_TOKEN)` | nothing in `auth.json` and no env var |
| `http-401` / `http-403` | the stored token is rejected by the provider |
| `empty` | the endpoint's envelope succeeded but carried no quota windows |
| `timeout` / `network error` | the endpoint did not answer in time |
| `stale` in the header | refreshes stopped landing for more than two intervals |

Logs, if you need them: `~/Library/Logs/QuotaBar/quotabar.err.log`.

## Architecture

```
Sources/
  QuotaBarKit/          the domain, no UI
    Model/              QuotaRow and its ordering
    Runway/             sample history, burn-rate projection, verdict ladder
    Format/             duration and percent formatting
    Providers/          the provider protocol, Z.ai and MiniMax parsers, registry
    Net/                credential resolution and the fetch wrapper
    Engine/             the polling actor, settings, history persistence
  QuotaBar/             the menu bar surface (NSStatusItem + NSPopover)
  QuotaBarKitTests/     the test suite (see below)
```

Four design notes worth knowing before changing things:

- **The engine is an actor, and that is load-bearing.** While a subscription's
  refresh is in flight, further triggers (timer, panel open, Refresh) join that
  same request instead of starting another. The deduplication is an invariant of
  the actor, not a guard scattered across call sites.
- **The menu bar is reconciled, not declared.** The status item is an
  `NSStatusItem`
  created and removed to match the current selection, rather than SwiftUI
  `MenuBarExtra` slots bound to `isInserted:`. A variable number of scene slots
  was observed to drop an item silently; here a missing item is a visible bug in
  one `reconcile()` function. Each item's panel is an `NSPopover` hosting real
  SwiftUI, so bars and colour render as interface elements rather than as
  flattened menu rows.
- **The log names the menu bar contents.** A menu bar agent has no window to
  complain in, so every change to the set of items is written to
  `~/Library/Logs/QuotaBar/quotabar.err.log` as `menu bar: …`.
- **Envelope success and payload emptiness are different questions.** A 200
  whose body reports no windows is `empty`, not a reason to probe the next
  host; only a genuine envelope failure (a MiniMax `base_resp.status_code`
  that is non-zero, a Z.ai `code` at or above 400) falls through to the next
  endpoint.

### Tests

`swift test` does not work on a Command Line Tools-only install — neither
`XCTest` nor the swift-testing module ships with that SDK. The suite is
therefore an ordinary executable target with a small lock-based harness:

```sh
swift run QuotaBarKitTests
```

It covers the row model, formatting, the sample history and its boundary resets,
every runway state, the full verdict ladder including each equality boundary,
both payload parsers against fixtures captured from the live endpoints
(`Fixtures/`), credential precedence, the error taxonomy, in-flight
deduplication, endpoint stickiness, staleness, which menu bar items should
exist for a given selection, persistence round-trips, and the guarantee that no
token ever reaches a rendered surface or the disk.

## Privacy

- Reads `~/.local/share/opencode/auth.json` (read-only, never modified).
- Writes only inside `~/Library/Application Support/QuotaBar` and
  `~/Library/Logs/QuotaBar`.
- Makes exactly two kinds of network request: each subscription's own quota
  endpoint, over https, bearer-authenticated. Nothing else is contacted.

## License

MIT