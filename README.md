# QuotaBar

A macOS menu bar agent that shows how much of your **Z.ai** and **MiniMax**
coding-plan allowance is left, and — the part that matters — **whether the
current pace outlasts the window**.

```
zai 52% ?          mmx 41% ✓
```

Both subscriptions are polled at once and independently of anything else on the
machine. There is no editor, terminal agent, or OpenCode session involved: the
app runs at login, reads your credentials from the file OpenCode already
writes, and keeps two status items in the menu bar.

Open a dropdown for the full picture:

```
Z.ai                                    ✓
just now · api.z.ai

5h                              52%   !!
██████████████░░░░░░░░░░░░░░░░
resets in 3h 12m        runs out in ~2h 5m (1h 7m short)

7d                              41%   ✓
██████████░░░░░░░░░░░░░░░░░░░░░░
resets in 3d 4h          runs out in ~10d
```

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

## Where the runway comes from

Runway is a burn-rate projection, not a guess:

1. Every refresh records one usage sample per window, in a history keyed by
   `provider:window`, so the two subscriptions never mix.
2. Once at least two samples span a minute, burn rate is
   `(newest − oldest usage) ÷ elapsed`.
3. `runway = (limit − usage) ÷ burn rate`, compared against `reset − now`.
4. A verdict needs evidence proportional to the window: at least **1/20 of its
   own duration**. A five-hour window therefore needs fifteen minutes and a
   weekly one about eight hours. Until then the glyph is `?` and the panel reads
   `runway measuring… <n>% of the evidence it needs` rather than a projection
   drawn from too little. Without this the weekly window reported itself as
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
(`~/Library/LaunchAgents/dev.dmitrii.quotabar.plist`) with `RunAtLoad` and
`KeepAlive`.

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

## Choosing which providers to show

Every panel has a **Providers** section at the bottom:

```
Providers
☑ Z.ai                 52%
☑ MiniMax              42%
```

Ticking or unticking one puts its menu bar item there immediately — no restart,
and the panel stays open. A hidden provider keeps polling and keeps its sample
history; only its menu bar item disappears.

Untick everything and a single `QuotaBar` item stays in the menu bar whose
panel is just the picker, so you can always bring providers back. You are never
left unable to reach the app.

The choice is remembered across restarts.

## Controls

Each panel carries its own controls, so they are always one click away:

- **Refresh** — refresh both subscriptions immediately.
- **every** — the polling cadence: 30s, 60s, 2m, 5m, or 15m.
- **Providers** — the picker described above.
- **Quit**.

A panel also refreshes on open when the data on screen is older than the
current cadence.

## Troubleshooting

| Symptom | Cause |
| --- | --- |
| Label reads `zai ?` | the last refresh failed; open the dropdown for the reason |
| Label reads `zai …` | no successful refresh yet |
| `no token (zai login or ZAI_TOKEN)` | nothing in `auth.json` and no env var |
| `HTTP 401` / `HTTP 403` | the stored token is rejected by the provider |
| `no data` | the endpoint answered but carried no quota windows |
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

Two design notes worth knowing before changing things:

- **The engine is an actor, and that is load-bearing.** While a subscription's
  refresh is in flight, further triggers (timer, panel open, Refresh) join that
  same request instead of starting another. The deduplication is an invariant of
  the actor, not a guard scattered across call sites.
- **The menu bar is reconciled, not declared.** Status items are `NSStatusItem`s
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
  whose body reports no windows is `no data`, not a reason to probe the next
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