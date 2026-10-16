import Foundation
import QuotaBarKit

// Responders live at file scope so their closures are nonisolated: a closure
// written inside a main-actor test body would inherit main-actor isolation and
// could not be handed to the engine's sendable transport.

/// Payloads are JSON-shaped values; the `@unchecked Sendable` box keeps these
/// reusable across the sendable responders without duplicating each literal.
private struct Plan: @unchecked Sendable { let value: [String: Any] }

private let zaiPlan = Plan(value: [
    "code": 200,
    "success": true,
    "data": ["limits": [
        ["unit": 3, "currentValue": 10, "remaining": 90, "percentage": 10.0],
    ]],
])

private let minimaxPlan = Plan(value: [
    "model_remains": [[
        "end_time": 1_700_000_600_000.0,
        "weekly_end_time": 1_700_600_000_000.0,
        "current_interval_status": 1,
        "current_interval_remaining_percent": 90.0,
        "current_weekly_status": 1,
        "current_weekly_remaining_percent": 95.0,
    ]],
    "base_resp": ["status_code": 0],
])

/// Default: a small plan for whichever provider is asking, so both subscriptions
/// start healthy.
private let flatWindow: @Sendable (URL, Int) -> QuotaFetchResult = { url, _ in
    url.host == "api.minimax.io" || url.host == "api.minimax.cn"
        ? .success(payload: JSONPayload(minimaxPlan.value))
        : .success(payload: JSONPayload(zaiPlan.value))
}

private let twoWindows: @Sendable (URL, Int) -> QuotaFetchResult = { _, _ in
    .success(payload: JSONPayload([
        "data": ["limits": [
            ["unit": 3, "currentValue": 62, "remaining": 38, "percentage": 62.0],
            ["unit": 6, "currentValue": 10, "remaining": 90, "percentage": 41.0],
        ]],
    ]))
}

private let zaiHealthy: @Sendable (URL, Int) -> QuotaFetchResult = { _, _ in
    .success(payload: JSONPayload([
        "data": ["limits": [["unit": 3, "currentValue": 30, "remaining": 70, "percentage": 30.0]]],
    ]))
}

private let zaiServerError: @Sendable (URL, Int) -> QuotaFetchResult = { _, _ in
    .failure(.http(503))
}

private let zaiUnauthorized: @Sendable (URL, Int) -> QuotaFetchResult = { _, _ in
    .failure(.http(401))
}

private let zaiEmptyLimits: @Sendable (URL, Int) -> QuotaFetchResult = { _, _ in
    .success(payload: JSONPayload(["code": 200, "data": ["limits": []]]))
}

private let minimaxRegionalPlan: @Sendable (URL, Int) -> QuotaFetchResult = { _, _ in
    .success(payload: JSONPayload([
        "model_remains": [[
            "end_time": 1_700_000_600_000.0,
            "weekly_end_time": 1_700_600_000_000.0,
            "current_interval_status": 1,
            "current_interval_remaining_percent": 80.0,
            "current_weekly_status": 1,
            "current_weekly_remaining_percent": 50.0,
        ]],
        "base_resp": ["status_code": 0],
    ]))
}

private let minimaxRegionMismatch: @Sendable (URL, Int) -> QuotaFetchResult = { url, _ in
    if url.host == "api.minimax.io" {
        // A 200 carrying a non-zero base_resp status: a region mismatch, not a
        // transport failure.
        return .success(payload: JSONPayload([
            "model_remains": [],
            "base_resp": ["status_code": 1008],
        ]))
    }
    return minimaxRegionalPlan(url, 0)
}

/// A window with a reset an hour out and a flat reading: the projection path is
/// only reachable when the row carries a reset timestamp.
private let zaiWithReset: @Sendable (URL, Int) -> QuotaFetchResult = { _, _ in
    .success(payload: JSONPayload([
        "data": ["limits": [
            ["unit": 3, "currentValue": 10, "remaining": 90, "nextResetTime": 1_700_003_600_000.0],
        ]],
    ]))
}

/// A window with neither a limit nor a reset: the provider knows the window
/// exists but cannot say how much there is or when it ends.
private let zaiWithoutLimitOrReset: @Sendable (URL, Int) -> QuotaFetchResult = { _, _ in
    .success(payload: JSONPayload([
        "data": ["limits": [["unit": 3, "currentValue": 40]]],
    ]))
}

/// A window with a limit but no reset time.
private let zaiWithoutReset: @Sendable (URL, Int) -> QuotaFetchResult = { _, _ in
    .success(payload: JSONPayload([
        "data": ["limits": [["unit": 3, "currentValue": 40, "remaining": 60]]],
    ]))
}

/// A window sitting exactly on its limit: blocked needs no history.
private let spentOut: @Sendable (URL, Int) -> QuotaFetchResult = { _, _ in
    .success(payload: JSONPayload([
        "data": ["limits": [
            ["unit": 3, "currentValue": 90, "remaining": 0, "nextResetTime": 1_700_003_600_000.0],
        ]],
    ]))
}

private let rollingResetAt: @Sendable (URL, Int) -> QuotaFetchResult = { _, attempt in
    let resetAt = attempt < 2 ? 1_700_000_600_000.0 : 1_700_003_600_000.0
    return .success(payload: JSONPayload([
        "data": ["limits": [[
            "unit": 3,
            "currentValue": Double(attempt + 1),
            "remaining": 90,
            "nextResetTime": resetAt,
        ]]],
    ]))
}

private let counterRollover: @Sendable (URL, Int) -> QuotaFetchResult = { _, attempt in
    let usage = attempt < 2 ? Double(attempt + 1) * 10 : 2
    return .success(payload: JSONPayload([
        "data": ["limits": [
            ["unit": 3, "currentValue": usage, "remaining": 90, "nextResetTime": 1_700_000_600_000.0],
        ]],
    ]))
}

/// Z.ai sits still at 0%; MiniMax burns on every refresh, in percent space.
private let burningZaiIdleMinimax: @Sendable (URL, Int) -> QuotaFetchResult = { url, attempt in
    if url.host == "api.minimax.io" {
        let burned = min(80, Double(attempt) * 5)
        return .success(payload: JSONPayload([
            "model_remains": [[
                "end_time": 1_700_000_600_000.0,
                "weekly_end_time": 1_700_600_000_000.0,
                "current_interval_status": 1,
                "current_interval_remaining_percent": 100 - burned,
                "current_weekly_status": 1,
                "current_weekly_remaining_percent": 100 - burned,
            ]],
            "base_resp": ["status_code": 0],
        ]))
    }
    return .success(payload: JSONPayload([
        "data": ["limits": [
            ["unit": 3, "currentValue": 0, "remaining": 90, "nextResetTime": 1_700_000_600_000.0],
        ]],
    ]))
}

private let minimaxFailsZaiHealthy: @Sendable (URL, Int) -> QuotaFetchResult = { url, _ in
    url.host == "api.z.ai" || url.host == "open.bigmodel.cn" ? zaiHealthy(url, 0) : .failure(.http(500))
}

/// A recorded request, for asserting probe order and stickiness.
final class CallRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var endpoints: [String] = []

    func record(_ endpoint: URL) {
        lock.lock(); defer { lock.unlock() }
        endpoints.append(endpoint.host ?? endpoint.absoluteString)
    }

    var hosts: [String] {
        lock.lock(); defer { lock.unlock() }
        return endpoints
    }

    func reset() {
        lock.lock(); defer { lock.unlock() }
        endpoints = []
    }
}

/// The most recent snapshots the engine published.
final class SnapshotSink: @unchecked Sendable {
    private let lock = NSLock()
    private var snapshots: [SubscriptionSnapshot] = []

    func record(_ value: [SubscriptionSnapshot]) {
        lock.lock(); defer { lock.unlock() }
        snapshots = value
    }

    var latest: [SubscriptionSnapshot] {
        lock.lock(); defer { lock.unlock() }
        return snapshots
    }

    func snapshot(id: String) -> SubscriptionSnapshot? {
        latest.first { $0.id == id }
    }
}

/// Counts transport invocations.
final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    func increment() {
        lock.lock(); defer { lock.unlock() }
        count += 1
    }

    var value: Int {
        lock.lock(); defer { lock.unlock() }
        return count
    }
}

/// Builds an engine wired to in-memory credentials, transport, and persistence,
/// driven by a hand-set clock, so every case is deterministic.
enum EngineFixture {
    struct Fixture {
        let engine: QuotaEngine
        let clock: FakeClock
        let historyFile: MemoryFile
        let calls: CallRecorder
        let published: SnapshotSink
    }

    /// Credential file holding one token per subscription.
    static let defaultAuthJSON = """
    {"zai-coding-plan": {"key": "zai-token"}, "minimax-coding-plan": {"key": "mmx-token"}}
    """

    static func make(
        providers: [any QuotaProvider] = [ZaiProvider(), MiniMaxProvider()],
        authJSON: String = EngineFixture.defaultAuthJSON,
        start: EpochMillis = 1_700_000_000_000,
        respond: @escaping @Sendable (URL, Int) -> QuotaFetchResult = flatWindow,
        restoredJSON: String = ""
    ) async -> Fixture {
        let clock = FakeClock(start)
        let file = MemoryFile(Data(authJSON.utf8))
        let historyFile = MemoryFile()
        let calls = CallRecorder()
        let sink = SnapshotSink()

        let credentials = CredentialStore(
            readFile: file.read,
            environment: { _ in nil }
        )
        let client = QuotaHTTPClient(timeoutMs: 1_000, transport: { url, _, _ in
            calls.record(url)
            switch respond(url, calls.hosts.count - 1) {
            case .success(let payload):
                let data = try JSONSerialization.data(withJSONObject: payload.value)
                return TransportResponse(status: 200, text: String(decoding: data, as: UTF8.self))
            case .failure(let error):
                return TransportResponse(status: httpStatus(of: error), text: "{}")
            }
        })
        let history = HistoryStore(
            url: URL(fileURLWithPath: "/dev/null"),
            readFile: historyFile.read,
            writeFile: historyFile.write
        )

        let engine = QuotaEngine(
            providers: providers,
            credentials: credentials,
            client: client,
            historyStore: history,
            snapshotStore: SnapshotStore(
                url: URL(fileURLWithPath: "/dev/null"),
                now: { clock.now },
                readFile: MemoryFile(Data(restoredJSON.utf8)).read,
                writeFile: { _, _ in }
            ),
            home: URL(fileURLWithPath: "/Users/tester"),
            now: { clock.now }
        )
        await observe(sink, engine)
        return Fixture(
            engine: engine,
            clock: clock,
            historyFile: historyFile,
            calls: calls,
            published: sink
        )
    }
}

/// Subscribes a sink to the engine. Declared at file scope so the observer
/// closure is nonisolated and can cross into the engine's actor.
func observe(_ sink: SnapshotSink, _ engine: QuotaEngine) async {
    await engine.setObserver { snapshots in sink.record(snapshots) }
}

/// Fires `count` overlapping refreshes at one subscription. File scope for the
/// same reason as `observe`.
func fireConcurrently(_ engine: QuotaEngine, providerId: String, count: Int) async {
    await withTaskGroup(of: Void.self) { group in
        for _ in 0..<count {
            group.addTask { await engine.refresh(providerId: providerId) }
        }
    }
}

/// Lets a stub express an HTTP failure as a transport response.
private func httpStatus(of error: QuotaFetchError) -> Int {
    if case .http(let status) = error { return status }
    return 500
}

enum QuotaEngineTests {
    static let cases: [TestCase] = [
        ("both subscriptions poll and report live data independently", {
            let fixture = await EngineFixture.make()
            await fixture.engine.refreshAll()
            let snapshots = fixture.published.latest
            Harness.expectEqual(snapshots.count, 2, "subscription count")
            Harness.expectEqual(snapshots.map(\.tag), ["mmx", "zai"], "ordered by tag")
            for snapshot in snapshots {
                Harness.expectEqual(snapshot.state, .live, "\(snapshot.tag) state")
            }
        }),

        ("the item's width does not depend on its figures", {
            // The whole point: crossing a digit boundary, or the verdict moving
            // between one and two characters, must not change the length.
            func label(percents: [Double?], verdict: Verdict) -> String {
                SubscriptionSnapshot(
                    id: "zai", tag: "zai", displayName: "Z.ai", state: .live,
                    windows: percents.enumerated().map { index, percent in
                        WindowSnapshot(
                            label: index == 0 ? "5h" : "7d",
                            percent: percent,
                            usage: percent,
                            limit: 100,
                            verdict: verdict,
                            resetInMs: 3_600_000,
                            windowMs: 18_000_000,
                            runway: RunwayResult(
                                state: .ok, runwayMs: 7_200_000,
                                resetInMs: 3_600_000, spanMs: 1_200_000
                            )
                        )
                    },
                    updatedAt: 1_700_000_000_000, lastAttemptAt: nil, stale: false,
                    verdict: verdict, restored: false, endpoint: nil
                ).menuBarLabel()
            }

            for verdict in [Verdict.ok, .tight, .short, .blocked, .unknown] {
                for percents in [[9.0, 9.0], [59.0, 47.0], [100.0, 100.0], [5.0, 100.0]] {
                    let text = label(percents: percents, verdict: verdict)
                    Harness.expectEqual(
                        text.count, 16, "\(percents) \(verdict) is \(text.debugDescription)"
                    )
                    Harness.expect(!text.hasSuffix(" "), "never ends on padding: \(text.debugDescription)")
                }
                // An unknown percent occupies its field too.
                Harness.expectEqual(
                    label(percents: [nil, 50.0], verdict: verdict).count, 16, "nil percent"
                )
            }

            // A single-window subscription is its own fixed width.
            Harness.expectEqual(
                label(percents: [7.0], verdict: .ok).count,
                label(percents: [100.0], verdict: .short).count,
                "one window has one width of its own"
            )
            Harness.expectEqual(label(percents: [7.0], verdict: .ok), "zai   7%  ✓", "single window")
        }),

        ("the label renders every window's percent, then the aggregate glyph", {
            let fixture = await EngineFixture.make(providers: [ZaiProvider()], respond: twoWindows)
            await fixture.engine.refresh(providerId: "zai")
            Harness.expectEqual(
                fixture.published.snapshot(id: "zai")?.menuBarLabel(),
                "zai  62%· 41%  ?",
                "both windows shown; ? because there is no verdict history yet"
            )
        }),

        ("a missing credential reports no-token and issues no request", {
            let fixture = await EngineFixture.make(authJSON: "{}")
            await fixture.engine.refreshAll()
            for snapshot in fixture.published.latest {
                guard case .error(let code) = snapshot.state else {
                    Harness.expect(false, "\(snapshot.tag) should be in an error state")
                    continue
                }
                Harness.expectEqual(code, "no-token", "\(snapshot.tag) error code")
                Harness.expectEqual(snapshot.menuBarLabel(), "\(snapshot.tag) ?", "\(snapshot.tag) label")
            }
            Harness.expectEqual(fixture.calls.hosts, [], "no request issued")
        }),

        ("one failing subscription does not suppress the other", {
            let fixture = await EngineFixture.make(respond: minimaxFailsZaiHealthy)
            await fixture.engine.refreshAll()
            Harness.expectEqual(fixture.published.snapshot(id: "zai")?.state, .live, "zai live")
            guard case .error(let code) = fixture.published.snapshot(id: "minimax")?.state else {
                return Harness.expect(false, "minimax should be in an error state")
            }
            Harness.expectEqual(code, "http-500", "minimax error")
        }),

        ("previous numbers are not presented as current after a failure", {
            let healthy = await EngineFixture.make(providers: [ZaiProvider()], respond: twoWindows)
            await healthy.engine.refresh(providerId: "zai")
            Harness.expectEqual(healthy.published.snapshot(id: "zai")?.windows.count, 2, "windows while healthy")

            let failing = await EngineFixture.make(providers: [ZaiProvider()], respond: zaiServerError)
            await failing.engine.refresh(providerId: "zai")
            let snapshot = failing.published.snapshot(id: "zai")
            Harness.expectEqual(snapshot?.windows.count, 0, "windows cleared on error")
            Harness.expectEqual(snapshot?.updatedAt, nil, "no updatedAt while failing")
            Harness.expect(snapshot?.lastAttemptAt != nil, "the attempt is still timestamped")
        }),

        ("a 2xx body with no usable rows reports empty", {
            let fixture = await EngineFixture.make(providers: [ZaiProvider()], respond: zaiEmptyLimits)
            await fixture.engine.refresh(providerId: "zai")
            guard case .error(let code) = fixture.published.snapshot(id: "zai")?.state else {
                return Harness.expect(false, "expected an error state")
            }
            Harness.expectEqual(code, "empty", "empty payload")
        }),

        ("a failed region falls through to the next endpoint and sticks", {
            let fixture = await EngineFixture.make(providers: [MiniMaxProvider()], respond: minimaxRegionMismatch)
            await fixture.engine.refresh(providerId: "minimax")
            Harness.expectEqual(
                fixture.calls.hosts, ["api.minimax.io", "api.minimax.cn"], "probed in declaration order"
            )
            Harness.expectEqual(
                fixture.published.snapshot(id: "minimax")?.endpoint?.host, "api.minimax.cn", "winner sticks"
            )
            Harness.expectEqual(
                fixture.published.snapshot(id: "minimax")?.windows.count, 2, "rows from the regional host"
            )
        }),

        ("the sticky endpoint is tried first on the next refresh", {
            let fixture = await EngineFixture.make(providers: [MiniMaxProvider()], respond: minimaxRegionMismatch)
            await fixture.engine.refresh(providerId: "minimax")
            fixture.calls.reset()
            await fixture.engine.refresh(providerId: "minimax")
            Harness.expectEqual(fixture.calls.hosts, ["api.minimax.cn"], "sticky endpoint first")
        }),

        ("when every endpoint fails the next refresh restarts from the first", {
            let fixture = await EngineFixture.make(providers: [MiniMaxProvider()], respond: zaiServerError)
            await fixture.engine.refresh(providerId: "minimax")
            Harness.expectEqual(
                fixture.calls.hosts, ["api.minimax.io", "api.minimax.cn"], "both probed"
            )
            fixture.calls.reset()
            await fixture.engine.refresh(providerId: "minimax")
            Harness.expectEqual(
                fixture.calls.hosts, ["api.minimax.io", "api.minimax.cn"], "declared order restored"
            )
        }),

        ("overlapping refreshes collapse into one in-flight request", {
            let box = Counter()
            let clock = FakeClock(1_700_000_000_000)
            let engine = QuotaEngine(
                providers: [ZaiProvider()],
                credentials: CredentialStore(
                    readFile: MemoryFile(Data(#"{"zai": {"key": "t"}}"#.utf8)).read,
                    environment: { _ in nil }
                ),
                client: QuotaHTTPClient(timeoutMs: 1_000, transport: { _, _, _ in
                    box.increment()
                    try? await Task.sleep(nanoseconds: 50_000_000)
                    return TransportResponse(
                        status: 200,
                        text: #"{"data":{"limits":[{"unit":3,"currentValue":1,"remaining":9}]}}"#
                    )
                }),
                historyStore: HistoryStore(url: URL(fileURLWithPath: "/dev/null")),
                snapshotStore: emptySnapshotStore(),
                home: URL(fileURLWithPath: "/Users/tester"),
                now: { clock.now }
            )
            await fireConcurrently(engine, providerId: "zai", count: 5)
            Harness.expectEqual(box.value, 1, "exactly one request for five overlapping triggers")
        }),

        ("an interval below the floor is clamped rather than honoured", {
            let fixture = await EngineFixture.make()
            await fixture.engine.apply(settings: Settings(intervalMs: 5))
            Harness.expectEqual(await fixture.engine.currentIntervalMs(), 10_000, "clamped to the floor")
        }),

        ("data is flagged stale only after two intervals without a refresh", {
            let fixture = await EngineFixture.make(providers: [ZaiProvider()])
            await fixture.engine.apply(settings: Settings(intervalMs: 60_000))
            await fixture.engine.refresh(providerId: "zai")

            func staleNow() async -> Bool? {
                await fixture.engine.snapshots().first { $0.id == "zai" }?.stale
            }

            Harness.expectEqual(await staleNow(), false, "fresh right after a refresh")

            fixture.clock.advance(by: 119_999)
            Harness.expectEqual(await staleNow(), false, "just under two intervals")

            fixture.clock.advance(by: 2)
            Harness.expectEqual(await staleNow(), true, "past two intervals")
        }),

        ("while failing, freshness tracks the attempt so the endpoint is not called stale", {
            let clock = FakeClock(1_700_000_000_000)
            let engine = QuotaEngine(
                providers: [ZaiProvider()],
                credentials: CredentialStore(
                    readFile: MemoryFile(Data(#"{"zai": {"key": "t"}}"#.utf8)).read,
                    environment: { _ in nil }
                ),
                client: QuotaHTTPClient(timeoutMs: 1_000, transport: { _, _, _ in
                    TransportResponse(status: 500, text: "{}")
                }),
                historyStore: HistoryStore(url: URL(fileURLWithPath: "/dev/null")),
                snapshotStore: emptySnapshotStore(),
                home: URL(fileURLWithPath: "/Users/tester"),
                now: { clock.now }
            )
            await engine.apply(settings: Settings(intervalMs: 10_000))
            let sink = SnapshotSink()
            await observe(sink, engine)
            await engine.refresh(providerId: "zai")
            clock.advance(by: 600_000)
            await engine.refresh(providerId: "zai")
            Harness.expectEqual(sink.snapshot(id: "zai")?.stale, false, "a live but failing endpoint is an error")
            guard case .error = sink.snapshot(id: "zai")?.state else {
                return Harness.expect(false, "expected an error state")
            }
        }),

        ("a moved reset timestamp restarts that window's history", {
            let fixture = await EngineFixture.make(providers: [ZaiProvider()], respond: rollingResetAt)
            await fixture.engine.refresh(providerId: "zai")
            fixture.clock.advance(by: 60_000)
            await fixture.engine.refresh(providerId: "zai")
            Harness.expectEqual(
                await windowRunway(fixture.engine, providerId: "zai"), .ok, "verdict before the boundary"
            )

            fixture.clock.advance(by: 60_000)
            await fixture.engine.refresh(providerId: "zai")
            Harness.expectEqual(
                await windowRunway(fixture.engine, providerId: "zai"), .noData, "history restarted at the new window"
            )
        }),

        ("a usage decrease restarts that window's history", {
            let fixture = await EngineFixture.make(providers: [ZaiProvider()], respond: counterRollover)
            await fixture.engine.refresh(providerId: "zai")
            fixture.clock.advance(by: 60_000)
            await fixture.engine.refresh(providerId: "zai")
            Harness.expectEqual(await windowRunway(fixture.engine, providerId: "zai"), .ok, "burning")

            fixture.clock.advance(by: 60_000)
            await fixture.engine.refresh(providerId: "zai")
            Harness.expectEqual(
                await windowRunway(fixture.engine, providerId: "zai"), .noData, "counter rollover restarted history"
            )
        }),

        ("samples from one subscription never feed another's projection", {
            let fixture = await EngineFixture.make(respond: burningZaiIdleMinimax)
            // Spans must clear the evidence threshold (five-hour window / 20 =
            // fifteen minutes) before a verdict is offered at all.
            for _ in 0..<3 {
                fixture.clock.advance(by: 600_000)
                await fixture.engine.refreshAll()
            }
            let snapshots = await fixture.engine.snapshots()
            let zai = snapshots.first { $0.id == "zai" }
            let mmx = snapshots.first { $0.id == "minimax" }
            Harness.expectEqual(zai?.windows.first?.percent, 0, "zai never burns")
            Harness.expectEqual(zai?.windows.first?.verdict, .ok, "a flat window is intact")
            Harness.expect(mmx?.windows.first?.percent != nil, "minimax reports its own rows")
        }),

        ("history is persisted after a refresh and reloaded on the next launch", {
            let first = await EngineFixture.make(providers: [ZaiProvider()])
            await first.engine.refresh(providerId: "zai")
            Harness.expect(first.historyFile.stored != nil, "history written to disk")

            let clock = first.clock
            let reloaded = QuotaEngine(
                providers: [ZaiProvider()],
                credentials: CredentialStore(
                    readFile: MemoryFile(Data(#"{"zai":{"key":"t"}}"#.utf8)).read,
                    environment: { _ in nil }
                ),
                client: QuotaHTTPClient(timeoutMs: 1_000, transport: { _, _, _ in
                    TransportResponse(
                        status: 200,
                        text: #"{"data":{"limits":[{"unit":3,"currentValue":20,"remaining":95,"nextResetTime":1700000600000}]}}"#
                    )
                }),
                historyStore: HistoryStore(
                    url: URL(fileURLWithPath: "/dev/null"),
                    readFile: first.historyFile.read,
                    writeFile: first.historyFile.write
                ),
                snapshotStore: emptySnapshotStore(),
                home: URL(fileURLWithPath: "/Users/tester"),
                now: { clock.now }
            )
            // Past the five-hour window's evidence threshold, so the restored
            // history is what the verdict rests on.
            clock.advance(by: 1_200_000)
            await reloaded.refresh(providerId: "zai")
            let snapshots = await reloaded.snapshots()
            let window = snapshots.first { $0.id == "zai" }?.windows.first
            Harness.expectEqual(window?.runway.state, .ok, "projection available immediately after relaunch")
            Harness.expect(window?.verdict != .unknown, "verdict supported by the restored history")
        }),

        ("a corrupt history file is discarded without stopping polling", {
            let file = MemoryFile(Data(
                #"{"samples": {"zai:5h": "not-an-array", "minimax:7d": [{"t":"x","usage":1}]}}"#.utf8
            ))
            let store = HistoryStore(
                url: URL(fileURLWithPath: "/dev/null"),
                readFile: file.read,
                writeFile: file.write
            )
            Harness.expectEqual(store.load().count, 0, "every malformed entry is dropped")

            let fixture = await EngineFixture.make(providers: [ZaiProvider()])
            await fixture.engine.refresh(providerId: "zai")
            Harness.expectEqual(fixture.published.snapshot(id: "zai")?.state, .live, "polling continues")
        }),

        ("a window with nothing to project is not measuring, it is absent", {
            // No limit and no reset: the projection has no inputs at all, so
            // there is no evidence to gather and nothing to wait for. Reading
            // this as "measuring" would show a progress line forever at 0%.
            let noLimit = await EngineFixture.make(
                providers: [ZaiProvider()], respond: zaiWithoutLimitOrReset
            )
            for _ in 0..<3 {
                noLimit.clock.advance(by: 120_000)
                await noLimit.engine.refresh(providerId: "zai")
            }
            Harness.expectEqual(
                await windowRunway(noLimit.engine, providerId: "zai"), .noLimit,
                "the projection reports no limit"
            )
            Harness.expectEqual(
                await windowMeasuring(noLimit.engine, providerId: "zai"), false,
                "a window with no limit is not measuring"
            )

            // A limit but no reset: a burn rate can be derived, but there is no
            // reset to compare it against, so the verdict stays unknown for a
            // reason that waiting will not fix.
            let noReset = await EngineFixture.make(
                providers: [ZaiProvider()], respond: zaiWithoutReset
            )
            for _ in 0..<3 {
                noReset.clock.advance(by: 120_000)
                await noReset.engine.refresh(providerId: "zai")
            }
            Harness.expectEqual(
                await windowRunway(noReset.engine, providerId: "zai"), .noReset,
                "the projection reports no reset"
            )
            Harness.expectEqual(
                await windowMeasuring(noReset.engine, providerId: "zai"), false,
                "a window with no reset is not measuring"
            )
        }),

        ("figures from before this launch are shown at once, without a verdict", {
            // Restored figures are measurements; the projection behind them is
            // not, so the label carries the percent and withholds the glyph.
            let restored = #"{"zai":{"fetchedAt":1700000000000,"rows":[{"label":"5h","usage":20,"limit":100,"percent":20,"resetAt":1700003600000}]}}"#
            let fixture = await EngineFixture.make(restoredJSON: restored)
            let before = await fixture.engine.snapshots().first { $0.id == "zai" }
            Harness.expectEqual(before?.state, .live, "figures are live, not loading")
            Harness.expectEqual(before?.windows.first?.percent, 20, "the percent is right there")
            Harness.expectEqual(before?.verdict, .unknown, "but the projection is withheld")
            Harness.expectEqual(before?.restored, true, "and the snapshot says why")
            Harness.expectEqual(before?.stale, false, "no refresh was due yet, so not stale")
            Harness.expectEqual(
                before?.menuBarLabel(), "zai  20%  ?", "numbers now, glyph once confirmed"
            )
            Harness.expectEqual(before?.updatedAt, 1_700_000_000_000, "aged from when it was fetched")

            // Three hours later, still unconfirmed: still not stale.
            fixture.clock.advance(by: 3 * 3_600_000)
            await fixture.engine.refreshAll()
            let later = await fixture.engine.snapshots().first { $0.id == "minimax" }
            Harness.expectEqual(later?.restored, false, "a confirmed provider clears the flag")
        }),

        ("a successful refresh replaces restored figures and restores the verdict", {
            let restored = #"{"zai":{"fetchedAt":1700000000000,"rows":[{"label":"5h","usage":20,"limit":100,"percent":20,"resetAt":1700003600000}]}}"#
            let fixture = await EngineFixture.make(respond: zaiWithReset, restoredJSON: restored)
            Harness.expectEqual(
                await windowState(fixture.engine, providerId: "zai"), .unknown, "withheld before"
            )
            await fixture.engine.refresh(providerId: "zai")
            let after = await fixture.engine.snapshots().first { $0.id == "zai" }
            Harness.expectEqual(after?.restored, false, "confirmed by this launch")
            Harness.expectEqual(
                after?.windows.first?.percent, 10, "fresh figures, not the restored ones"
            )
            Harness.expectEqual(after?.verdict, .unknown, "still measuring: one sample is not a rate")
        }),

        ("figures older than a week are not restored", {
            let stale = #"{"zai":{"fetchedAt":1699000000000,"rows":[{"label":"5h","usage":20,"limit":100,"percent":20}]}}"#
            let fixture = await EngineFixture.make(restoredJSON: stale)
            let snapshot = await fixture.engine.snapshots().first { $0.id == "zai" }
            Harness.expectEqual(snapshot?.state, .loading, "nothing to show, so still loading")
            Harness.expectEqual(snapshot?.restored, false, "and nothing is claimed as restored")
        }),

        ("a window below its evidence threshold reports measuring, not a verdict", {
            let fixture = await EngineFixture.make(providers: [ZaiProvider()], respond: zaiWithReset)
            await fixture.engine.refresh(providerId: "zai")
            // One sample so far: the five-hour window needs fifteen minutes.
            Harness.expectEqual(
                await windowState(fixture.engine, providerId: "zai"), .unknown, "no verdict yet"
            )
            let measuring: Bool? = await windowMeasuring(fixture.engine, providerId: "zai")
            Harness.expectEqual(
                measuring, false,
                "a single sample is too few to project, which is not the same as measuring"
            )

            for _ in 0..<2 {
                fixture.clock.advance(by: 60_000)
                await fixture.engine.refresh(providerId: "zai")
            }
            let measuringMid: Bool? = await windowMeasuring(fixture.engine, providerId: "zai")
            Harness.expectEqual(measuringMid, true, "samples but still short of the threshold")
            let fraction = await windowFraction(fixture.engine, providerId: "zai")
            Harness.expect(fraction != nil, "progress towards the threshold is reported")
            Harness.expect((fraction ?? 0) > 0 && (fraction ?? 1) < 1, "progress is partial")

            for _ in 0..<15 {
                fixture.clock.advance(by: 60_000)
                await fixture.engine.refresh(providerId: "zai")
            }
            let measuringDone: Bool? = await windowMeasuring(fixture.engine, providerId: "zai")
            Harness.expectEqual(measuringDone, false, "past the threshold")
        }),
        ("an exhausted window is blocked while it is still measuring", {
            let fixture = await EngineFixture.make(providers: [ZaiProvider()], respond: spentOut)
            await fixture.engine.refresh(providerId: "zai")
            let blockedVerdict: Verdict? = await windowState(fixture.engine, providerId: "zai")
            Harness.expectEqual(blockedVerdict, .blocked, "blocked")
            let measuringBlocked: Bool? = await windowMeasuring(fixture.engine, providerId: "zai")
            Harness.expectEqual(measuringBlocked, false, "exhaustion needs no history, so it never waits")
        }),
        ("the settings interval reaches the engine", {
            let fixture = await EngineFixture.make()
            await fixture.engine.apply(settings: Settings(intervalMs: 300_000))
        }),
    ]
}

@MainActor
private func windowState(_ engine: QuotaEngine, providerId: String) async -> Verdict? {
    await engine.snapshots().first { $0.id == providerId }?.windows.first?.verdict
}

@MainActor
private func windowMeasuring(_ engine: QuotaEngine, providerId: String) async -> Bool? {
    await engine.snapshots().first { $0.id == providerId }?.windows.first?.isMeasuring
}

@MainActor
private func windowFraction(_ engine: QuotaEngine, providerId: String) async -> Double? {
    await engine.snapshots().first { $0.id == providerId }?.windows.first?.measuredFraction
}

@MainActor
private func windowRunway(_ engine: QuotaEngine, providerId: String) async -> RunwayState? {
    await engine.snapshots()
        .first { $0.id == providerId }?
        .windows
        .first?
        .runway
        .state
}
/// A snapshot store that restores nothing and writes nowhere, for tests that
/// are not about the restore path.
private func emptySnapshotStore() -> SnapshotStore {
    SnapshotStore(
        url: URL(fileURLWithPath: "/dev/null"),
        readFile: { _ in Data() },
        writeFile: { _, _ in }
    )
}
