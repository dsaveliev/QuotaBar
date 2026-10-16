# Design

## Context

See `proposal.md` for motivation and `specs/` for the behavioural contract.
Constraints that shape the approach, discovered while surveying the source
plugin and this machine:

- **No full Xcode.** Only `/Library/Developer/CommandLineTools` is installed.
  `xcodebuild` is unavailable, so an `.xcodeproj` would not build here.
  Verified instead: `swiftc -parse-as-library -target arm64-apple-macosx13.0`
  compiles a `MenuBarExtra` app against the CommandLineTools SDK, and `swift
  build`/`swift run` work through SwiftPM.
- **No XCTest and no swift-testing.** Neither `import XCTest` nor `import Testing`
  resolves against this SDK (no `XCTest.framework`, no `Testing.swiftmodule`),
  so `swift test` cannot run at all on this machine.
- **The source plugin is an OpenCode TUI plugin.** Its domain logic (row model,
  runway projection, verdict ladder, formatters, provider parsers, credential
  lookup) is pure and portable, but its wiring layer is bound to an OpenCode
  session and its active model. Reusing it at runtime would mean depending on
  `bun` plus a running OpenCode host — neither is acceptable for a login-time
  menu bar agent.
- macOS 15.7.9, arm64. Both providers have live credentials present in
  `~/.local/share/opencode/auth.json`, so the integration can be verified
  against the real endpoints.

## Goals / Non-Goals

**Goals:**

- Behavioural parity with `opencode-quota`'s domain layer for the same inputs,
  including its edge cases, so the menu bar and the TUI panel never disagree.
- A build and install path that works with the toolchain that is actually
  installed, and a test suite that runs on it.
- A login-persistent agent that is safe to run unattended: read-only on the
  credential file, writes confined to its own Application Support directory.

**Non-Goals:**

- Reimplementing or shipping the OpenCode TUI plugin surface (panel, chip,
  keymap, `/quota-runway` command). That stays in `opencode-quota`.
- Provider configurability UI (custom endpoints, adding a third subscription).
  The registry is code-level for now; the surface exposes only interval,
  visibility, refresh, and quit.
- Any write path to the OpenCode auth file, and any token storage of our own.

## Decisions

### 1. Swift + SwiftUI `MenuBarExtra`, deployment target macOS 13

`MenuBarExtra` gives a menu bar item with a SwiftUI dropdown directly from a
scene declaration, which is the smallest surface that satisfies the dropdown
requirements. *Alternative considered:* `NSStatusItem` + `NSMenu`, which works
back to macOS 10.10 and gives native menus with less code — but it requires
hand-rolled item/section construction, custom views via `NSHostingView`, and
menu lifecycle callbacks for "refresh on open", and it buys compatibility with
an OS release this app will not target. macOS 13 is the floor.

*Alternative considered:* a single combined menu bar item showing both
subscriptions. Rejected: it forces a second click path to reach one
subscription and halves the information available at a glance; two items keep
each subscription independently glanceable, which is the point of the app. The
cost is two menu bar slots, mitigated by per-subscription visibility toggles.

### 2. Port the domain layer to Swift rather than driving the TypeScript plugin

The parsers, projection, classifier, and formatters are reimplemented in Swift
with the same inputs, outputs, and edge-case ordering as the plugin (unit-code
window mapping, percent clamping, usage-decrease history reset, the verdict
ladder's precedence, the `>`-vs-`>=` boundary in the tight band). *Alternative
considered:* shelling out to `bun` to run the plugin's modules. Rejected: it
puts a JS runtime in the login path, forces the plugin's OpenCode host types
into the process boundary, and makes the app fail whenever the plugin repo is
moved — the exact failure mode the plugin repo's own README works to avoid with
a stable symlink.

Parity is a real risk when two implementations of one algorithm exist, so it is
mitigated structurally rather than by convention: both the verdict ladder and
the runway state machine are written as explicit ordered checks with the
plugin's precedence preserved, and each is covered by a test asserting the
boundary case (span exactly 60 s, runway exactly equal to reset, usage exactly
at limit).

### 3. Build with SwiftPM; assemble the `.app` with a script

The package produces a plain executable. `scripts/build-app.sh` creates
`QuotaBar.app/Contents/{MacOS,Resources}`, writes an `Info.plist` with
`LSUIElement = true` and deployment target 13.0, copies the binary in, and
ad-hoc signs with `codesign -s -`. *Alternative considered:* an `.xcodeproj`
via XcodeGen or hand-written `project.pbxproj`. Rejected: it cannot be built or
run on this machine, which makes the project's own verification story
untestable. The package stays openable as an Xcode project if Xcode is ever
installed, but nothing in the workflow requires it.

Ad-hoc signing is sufficient because the bundle is built locally and never
leaves the machine; no notarization, no Developer ID, no provisioning profile.

### 4. `LaunchAgent` plist for login persistence, not `SMAppService`

`SMAppService.mainApp` requires a properly signed, registered app bundle and
degrades silently to "not registered" for an ad-hoc signed one. A
`~/Library/LaunchAgents/dev.dmitrii.quotabar.plist` with `RunAtLoad` and
`KeepAlive` bootstrapped via `launchctl` is inspectable, testable, and works
with ad-hoc signing. *Alternative considered:* neither — the user launches by
hand. Rejected: the app's whole value proposition is ambient presence; manual
launch defeats it.

### 5. Self-contained test harness instead of XCTest / swift-testing

Neither testing module exists in this SDK, so the package ships its own
executable test target (`swift run quotabar-tests`) built on a ~60-line
assertion and reporting harness: named cases, `#expect`-style predicates,
non-zero exit on failure, and a summary line. *Alternative considered:*
installing Xcode to get XCTest. Rejected as a build dependency: it would make
the suite unrunnable on a stock CommandLineTools machine, and nothing here
needs XCTest's features (discovery, async matchers, reporting) — the suite is a
flat list of deterministic pure-function cases.

### 6. Concurrency: `@MainActor` view state over an `actor` engine

The engine is an `actor` owning per-subscription state: latest rows, sample
history, last attempt time, sticky endpoint, and the in-flight request task.
Refresh triggers (timer, menu open, manual) call `refresh(subscription)`; if a
request for that subscription is already in flight, the call joins it instead of
starting a second — the deduplication the spec requires, expressed as an actor
invariant rather than as a guard scattered across call sites. UI state is a
single `@Observable` object on the main actor that the engine writes snapshots
into, so views never read engine internals.

Network I/O uses `URLSession` with an explicit per-request timeout, so a hung
endpoint cannot occupy the in-flight slot indefinitely.

### 7. History persisted as JSON under Application Support

`~/Library/Application Support/QuotaBar/history.json` holds per-subscription,
per-window sample arrays, rewritten after each refresh (bounded to the cap, so
the file stays a few KB and the write is not worth debouncing). On launch the
file is loaded; any unreadable or malformed entry is discarded individually
rather than failing the whole load. Writing outside this directory never
happens; the OpenCode auth file is opened read-only.

### 8. Credentials re-resolved on every refresh

Rather than caching a token at launch, each refresh resolves it again through
the same precedence as the plugin (auth.json keys, then environment names), so
a user who logs in after the agent started is picked up on the next tick. This
costs one small file read per refresh.

## Risks / Trade-offs

- **Duplicate algorithm in two languages** (Swift app, TypeScript plugin) can
  drift silently → parity tests assert each boundary case named in Decision 2;
  the specs pin the observable ladder rather than the code, so a future change
  to either must be checked against the other's behaviour.
- **Menu bar agent that dies silently** → `KeepAlive` in the LaunchAgent
  restarts it; the dropdown's data age makes a stale agent obvious rather than
  indistinguishable from a quiet one.
- **First launch shows `?` on every window** because the verdict ladder needs a
  one-minute measurement span → persisted history removes the wait on every
  launch after the first, and the `?` glyph is honest about the missing
  evidence rather than showing a fabricated verdict.
- **Z.ai's payload shape is not contractually stable**; the plugin defends with
  a bounded recursive scan for recognisable entries → same tolerant scan, capped
  at depth 6 and 16 rows, falling back to the empty-payload error rather than
  throwing.
- **MiniMax region detection depends on a non-`io` endpoint being reachable**
  → the probe falls through both declared endpoints and remembers the winner;
  if neither answers, the last probe's failure is reported and the next refresh
  restarts from the first endpoint.
- **Ad-hoc signing could be rejected on a future macOS** → the build script
  fails loudly if `codesign` errors rather than emitting an unsigned bundle, and
  the app is never distributed; a Developer ID rebuild is a one-line change to
  the script if it ever is.
- **Custom harness instead of XCTest** loses IDE integration and parallel test
  execution → accepted; the suite is pure, fast, and fully deterministic, and
  failure output names the case and the expectation.

## Migration Plan

New repository, nothing to migrate. Deployment order:

1. `swift build` — compiles the package and runs nothing.
2. `swift run quotabar-tests` — pure-logic suite green.
3. `scripts/build-app.sh` — produces `build/QuotaBar.app`, ad-hoc signed.
4. `scripts/install.sh` — copies the bundle to `/Applications`, writes and
   bootstraps the LaunchAgent, then launches it.
5. Verify live: both menu bar items appear with real percentages from the two
   real endpoints.

Rollback: quit the agent, `launchctl bootout` the label, delete
`~/Library/LaunchAgents/dev.dmitrii.quotabar.plist` and
`/Applications/QuotaBar.app`. Nothing outside the agent's Application Support
directory holds state, so removing it is optional.

## Open Questions

None that affect the specs, the approach, or the task breakdown.