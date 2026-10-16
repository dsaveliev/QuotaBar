# Tasks

Two items in this plan changed shape during implementation; both are called out
where they occur rather than silently rewritten.

## 1. Package and test harness

- [x] 1.1 Create `Package.swift` with a `QuotaBarKit` library target, a `QuotaBar` executable target (SwiftUI, macOS 13), and a `QuotaBarKitTests` executable test target; verify `swift build` succeeds and produces all three products
- [x] 1.2 Implement the dependency-free assertion/reporting harness (named cases, expectation failures collected per case so one broken expectation does not hide the rest, non-zero exit, summary line) and verify a deliberately failing case makes `swift run QuotaBarKitTests` exit non-zero
  - The harness is deliberately **not** actor-isolated. A main-actor-isolated reporter forced every case closure to inherit main-actor isolation, which then could not await the engine actor; failures are collected behind an `NSLock` instead.
- [x] 1.3 Add secret-hygiene cases asserting no rendered or persisted string contains a token, and verify they trip on a fixture that embeds one

## 2. Quota row model and formatting

- [x] 2.1 Implement the unified `QuotaRow` (label, usage, limit, percent, resetAt, windowMs) and the row-ordering rule (5h first, 7d second, rest as parsed, duplicate labels dropped first-wins); verify ordering tests pass
- [x] 2.2 Implement compact duration formatting (seconds / minutes / hours+minutes / days+hours) and approximate runway formatting (whole days beyond 48h, rounded half-up); verify boundary cases at 60s, 60min, 48h and 0ms
- [x] 2.3 Implement percent text clamping for display (negative to 0, over 999 to `999%`) and verify the clamp tests pass

## 3. Runway projection and verdicts

- [x] 3.1 Implement sample history append with cap flooring, usage-decrease window-boundary reset, and per-subscription/per-window keying; verify cap, rollover, and cross-subscription isolation tests pass
- [x] 3.2 Implement the burn-rate derivation and runway state machine (`noLimit`, `noReset`, `noData`, `noBurn`, `ok`, `warn`) with the two-sample / one-second minimum and non-finite handling; verify each state is reachable in tests
- [x] 3.3 Implement the ordered verdict ladder (`blocked` first, then `unknown` for stale / sub-minute span / incomplete inputs, then `ok` for no-burn, `short`, `tight`, `ok`) with the plugin's exact boundary semantics; verify the equality cases (usage at limit, span exactly 60s, runway exactly equal to reset, runway exactly at the tight-factor multiple)
- [x] 3.4 Implement worst-verdict aggregation ignoring `unknown` and defaulting to `unknown` when nothing is known; verify the aggregation tests pass

## 4. Provider registry, parsers, credentials, network

- [x] 4.1 Implement the provider protocol and registry with Z.ai (`zai`, `zai-coding-plan`, `zhipuai-coding-plan`) and MiniMax (`minimax`, `minimax-coding-plan`, `minimax-cn-coding-plan`), including tags, labels, auth keys, env names, and endpoint lists
- [x] 4.2 Implement the Z.ai parser: `limits` fast path, bounded recursive scan fallback (depth 6, 16 rows), unit 3/6 window mapping, limit from usage+remaining, percent derivation and 0–100 clamp; verify against captured live payloads and the fallback scan
- [x] 4.3 Implement the MiniMax parser: `model_remains` entry selection, remaining-percent inversion, status gating, declared 5h/7d window durations, and percent-space pseudo-usage/limit; verify against a captured live payload including the non-zero `base_resp.status_code` region fallback
- [x] 4.4 Implement credential resolution: read-only auth.json parse, per-provider key order, env fallback, per-entry tolerance for malformed JSON and unreadable files; verify each precedence path
- [x] 4.5 Implement the HTTP client with bearer auth, https enforcement, per-request timeout, and the error taxonomy (no-token, insecure-endpoint, network, http-N, bad-json, timeout, empty); verify each code is produced by a stubbed transport
- [x] 4.6 Implement endpoint selection with sticky per-subscription winner and fall-through from the first endpoint after a full failure; verify the probe order and sticky behaviour

## 5. Engine, persistence, settings

- [x] 5.1 Implement the engine actor: per-subscription state, sample-history integration, last-attempt tracking for freshness, in-flight request deduplication, and interval clamping (10s … platform ceiling)
  - Envelope success and payload emptiness are deliberately separate: only a genuine envelope failure (MiniMax `base_resp.status_code` non-zero, Z.ai `code` >= 400) falls through to the next endpoint. A 200 carrying no windows is `empty`, not a reason to probe the next host.
- [x] 5.2 Implement freshness and staleness derivation (stale beyond two intervals; error state ages from the last attempt); verify both branches
- [x] 5.3 Implement history persistence to `~/Library/Application Support/QuotaBar/history.json` with per-entry tolerance for corrupt content, and verify a round trip plus a corrupt-file recovery
- [x] 5.4 Implement settings persistence (interval, per-subscription visibility) and verify clamping, persistence across instances, and that the last visible item cannot be hidden

## 6. Menu bar surface

- [x] 6.1 Implement the main-actor view model bridging engine snapshots onto the main actor, and verify a refresh updates published state without views touching engine internals
  - Implemented as `ObservableObject`/`@Published`, not `@Observable`: the Observation macro is macOS 14+ and the package pins a macOS 13 floor, which the specs require the app to keep.
- [x] 6.2 Implement the app scene with one menu bar item per visible subscription, dynamic label (tag, highest consumed percent, verdict glyph) and the loading / error / missing-credential label states
  - `@SceneBuilder` cannot express a dynamic list of scenes, so the scene declares four `MenuBarExtra` slots whose `isInserted:` bindings follow the visible subscriptions. A hidden subscription therefore loses its menu bar item entirely while continuing to poll.
- [x] 6.3 Implement the dropdown: header with subscription name and data age, per-window block (label, usage bar with pace marker, percent, verdict glyph, time to reset, runway line), shortfall and blocked annotations, stale styling
- [x] 6.4 Implement the controls: refresh now, interval picker, show/hide item toggle with a re-enable list for hidden subscriptions, and quit — with refresh-on-open when data is older than the interval
- [x] 6.5 Verify the surface live: launch the built app and confirm both items render from the real endpoints and a real refresh updates values without reopening the menu

## 7. Build, install, docs

- [x] 7.1 Implement `scripts/build-app.sh`: assemble `QuotaBar.app` with `LSUIElement`, ad-hoc `codesign`, and fail loudly on signing errors; verify the bundle is produced, signed, and `codesign -v` passes
- [x] 7.2 Implement `scripts/install.sh`: copy to `/Applications`, write and bootstrap the LaunchAgent, launch the agent; verify `launchctl print` shows it running
- [x] 7.3 Write `README.md` covering build, install, uninstall, the label and verdict vocabulary, credential sources, the runway method, and the privacy posture; verify every command in it runs as written
- [x] 7.4 Implement `scripts/uninstall.sh` and verify it removes the LaunchAgent and the app bundle and leaves unrelated files untouched

## 8. Final verification

- [x] 8.1 Run `swift build` and `swift run QuotaBarKitTests` clean (117 cases), and `openspec validate macos-menubar-quota --strict` passes
- [x] 8.2 End-to-end smoke against the live endpoints: confirm both subscriptions report real rows, and that the Z.ai token never appears in any output, log, or on-disk state