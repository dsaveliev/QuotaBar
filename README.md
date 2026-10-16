# QuotaBar

[![CI](https://github.com/dsaveliev/QuotaBar/actions/workflows/ci.yml/badge.svg)](https://github.com/dsaveliev/QuotaBar/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![macOS](https://img.shields.io/badge/macOS-13%2B-lightgrey.svg)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/swift-6-orange.svg)](Package.swift)

A macOS menu bar agent that shows how much of your **Z.ai** and **MiniMax**
coding-plan allowance is left, and — the part that matters — **whether the
current pace outlasts the window**.

![The panel, with a five-hour window past its evidence threshold and a
weekly window still gathering it](docs/panel.webp)

*Real panel, real usage, with permission. The five-hour window has enough
history to be acted on; the weekly one is still gathering evidence, and says
so instead of guessing.*

```
zai ✓
```

One item, whichever provider you last selected: the subscription and its state,
nothing else, in a label whose width never changes. Hover it for the figures;
open it for the bars. Both subscriptions are polled at once and independently of
anything else on the machine — there is no editor, terminal agent, or OpenCode
session involved. The app runs at login, reads two environment variables, and
keeps a single status item in the menu bar. One entrance to the panel means
there is never a question of which item a figure belongs to.

The runway line has the same shape whatever the verdict, so the numbers never
jump around while you read them. A shortfall is said on the muted line beneath
it, never by colouring the number. A window still gathering evidence says how
far along it is rather than guessing.

The label is drawn in a font where every character is the same width, and the
glyph is reserved two characters, so `zai ✓` and `zai!!` are the same length and
the item cannot resize — not as figures change, since it carries none, and not
as the verdict changes either. The figures are not in the label: hover for them.

## Contents

- [What the numbers mean](#what-the-numbers-mean)
- [Where the runway comes from](#where-the-runway-comes-from)
- [Credentials](#credentials)
- [Install](#install)
- [Choosing which provider to show](#choosing-which-provider-to-show)
- [Controls](#controls)
- [Troubleshooting](#troubleshooting)
- [Architecture](#architecture)
- [Development](#development)
- [Privacy](#privacy)
- [Contributing](#contributing)
- [Security](#security)

## What the numbers mean

The menu bar item carries a verdict, not a number. Hovering it reads the whole
picture out:

```
MiniMax — 5h 58%, 7d 47% · ! close to the reset · updated 3m ago
```

Each window gets its own verdict, and the glyph and the bar colour follow that
verdict rather than the raw percentage:

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
2. Once at least two samples span a second, burn rate is
   `(newest − oldest usage) ÷ elapsed`. A second is enough to compute a rate;
   deciding whether to *trust* it is a separate, stricter rule — see below.
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

The token comes from the environment, and only from the environment. Export one
variable per subscription:

| Subscription | Variable |
| --- | --- |
| Z.ai | `ZAI_TOKEN` |
| MiniMax | `MINIMAX_TOKEN` |

```sh
export ZAI_TOKEN=…
export MINIMAX_TOKEN=…
./scripts/install.sh
```

**The installer must run after you export them.** QuotaBar is a login agent, and
a login agent inherits launchd's environment, not your shell's — a variable you
export in `~/.zshrc` is invisible to it. `install.sh` reads the two variables
and writes them into `~/Library/LaunchAgents/dev.dmitrii.quotabar.plist` with
owner-only permissions, which is how the agent gets them at login. That plist
therefore holds your tokens in plain text; `uninstall.sh` removes it.

This replaced an earlier dependency on `~/.local/share/opencode/auth.json`.
**That is a breaking change**: if you were relying on the file, export the
variables instead.

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

Pick **Show none** and the menu bar item becomes `QuotaBar` with a checklist
symbol. Its panel says no providers are shown and offers the picker and Quit —
you are never left without a way back.

The choice is remembered across restarts.

## Controls

Each panel carries its own controls, so they are always one click away:

- **Refresh** — refresh both subscriptions immediately.
- **every** — the polling cadence: 30s, 1m, 2m, 5m, or 15m.
- **provider** — the picker described above, `Show none` included.
- **Quit** — the app exits and stays out until you start it again.

A panel also refreshes on open when the data on screen is older than the
current cadence.

## Troubleshooting

| Symptom | Cause |
| --- | --- |
| Label reads `zai ?` | either the last refresh failed — open the dropdown for the reason — or the figures are restored from the previous run and no refresh this launch has confirmed them yet. The panel tells them apart: live figures with a withheld verdict means restored |
| Label reads `zai …` | no successful refresh yet |
| `no token — set ZAI_TOKEN, then run ./scripts/install.sh so the agent can see it` | the agent cannot see the variable; re-run the installer after exporting it |
| `http-401` / `http-403` | the stored token is rejected by the provider |
| `empty` | the endpoint's envelope succeeded but carried no quota windows |
| `timeout` / `network` | the endpoint did not answer in time |
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
- **The menu bar is reconciled, not declared.** The status item is a single
  `NSStatusItem` created once at launch, rather than SwiftUI `MenuBarExtra`
  slots bound to `isInserted:`. A variable number of scene slots was observed to
  drop an item silently. Because the item never changes identity, switching
  provider cannot destroy and rebuild it: the label is repainted in place and an
  open panel stays open. Its panel is an `NSPopover` hosting real SwiftUI, so
  bars and colour render as interface elements rather than flattened menu rows.
- **The log names the menu bar contents.** A menu bar agent has no window to
  complain in, so every change to the set of items is written to
  `~/Library/Logs/QuotaBar/quotabar.err.log` as `menu bar: …`.
- **Envelope success and payload emptiness are different questions.** A 200
  whose body reports no windows is `empty`, not a reason to probe the next
  host; only a genuine envelope failure (a MiniMax `base_resp.status_code`
  that is non-zero, a Z.ai `code` at or above 400) falls through to the next
  endpoint.

## Development

```sh
swift build                 # compile
swift run QuotaBarKitTests  # 149 cases
./scripts/install.sh        # build, install, register at login
```

`swift test` does not work and is not an oversight: this toolchain ships
neither XCTest nor the swift-testing module, so the suite is an executable
target with a small lock-based harness that exits non-zero on failure.

Behaviour is **specified before it is built**. Every requirement lives in
`openspec/specs/`, each change is a directory under `openspec/changes/` with a
proposal, deltas, a design note and tasks, and archiving a change folds its
deltas into the specs. That way a change is reviewable twice: once as
behaviour, once as code.

See [CONTRIBUTING.md](CONTRIBUTING.md) for the workflow.

### Tests

`swift test` does not work on a Command Line Tools-only install — neither
`XCTest` nor the swift-testing module ships with that SDK. The suite is
therefore an ordinary executable target with a small lock-based harness:

```sh
swift run QuotaBarKitTests
```

It covers the row model, formatting, the sample history and its boundary resets,
every runway state, the full verdict ladder including each equality boundary,
both payload parsers against payloads captured from the live endpoints with
their consumption figures replaced (`Fixtures/`; that README lists what was
replaced and what was deliberately kept), credential resolution, the error
taxonomy, in-flight
deduplication, endpoint stickiness, staleness, which menu bar items should
exist for a given selection, persistence round-trips, and the guarantee that no
token ever reaches a rendered surface or the disk.

## Privacy

- Reads only the environment for a token. No credential file is opened, read, or
  required.
- Writes only inside `~/Library/Application Support/QuotaBar` and
  `~/Library/Logs/QuotaBar`. The app itself never writes a token to disk.
- Makes exactly two kinds of network request: each subscription's own quota
  endpoint, over https, bearer-authenticated. Nothing else is contacted.
- The installer writes the token into the login agent's plist, owner-readable.
  That is the launchd's own mechanism for passing variables to an agent, and it
  is where the token lives between login and launch.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Bug reports and feature requests use the
issue templates — the logs the app writes are the most useful thing to attach.

## Security

Report a vulnerability privately rather than in a public issue; see
[SECURITY.md](SECURITY.md) for what is in scope and what is simply the app
doing its job.

## License

MIT — see [LICENSE](LICENSE).