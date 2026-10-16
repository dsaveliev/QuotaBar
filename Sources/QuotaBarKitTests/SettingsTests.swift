import Foundation
import QuotaBarKit

enum SettingsTests {
    static let cases: [TestCase] = [
        ("the default interval is one minute", {
            Harness.expectEqual(Settings().intervalMs, 60_000, "default interval")
        }),
        ("an out-of-range interval is clamped into the supported band", {
            var settings = Settings(intervalMs: 5)
            settings.clamp()
            Harness.expectEqual(settings.intervalMs, 10_000, "below the floor")

            settings = Settings(intervalMs: 1e18)
            settings.clamp()
            Harness.expectEqual(settings.intervalMs, Double(Int32.max), "above the ceiling")

            settings = Settings(intervalMs: .nan)
            settings.clamp()
            Harness.expectEqual(settings.intervalMs, Settings.defaultIntervalMs, "not a number")

            settings = Settings(intervalMs: .infinity)
            settings.clamp()
            Harness.expectEqual(settings.intervalMs, Settings.defaultIntervalMs, "infinite")
        }),
        ("an in-range interval is left untouched", {
            var settings = Settings(intervalMs: 300_000)
            settings.clamp()
            Harness.expectEqual(settings.intervalMs, 300_000, "unchanged")
        }),
        ("hiding is allowed even for the last shown subscription", {
            var settings = Settings()
            settings.setHidden(true, providerId: "zai")
            Harness.expectEqual(settings.hiddenSubscriptions, ["zai"], "first hide")

            settings.setHidden(true, providerId: "minimax")
            Harness.expectEqual(
                settings.hiddenSubscriptions, ["zai", "minimax"],
                "hiding every subscription is permitted; the surface keeps a recovery item"
            )

            settings.setHidden(false, providerId: "zai")
            Harness.expectEqual(settings.hiddenSubscriptions, ["minimax"], "re-enabled")
        }),
        ("hiding an already hidden subscription is a no-op", {
            var settings = Settings(hiddenSubscriptions: ["zai"])
            settings.setHidden(true, providerId: "zai")
            Harness.expectEqual(settings.hiddenSubscriptions, ["zai"], "unchanged")
        }),
        ("a full-hide selection round-trips through the store", {
            let file = MemoryFile()
            let store = SettingsStore(url: URL(fileURLWithPath: "/dev/null"), readFile: file.read, writeFile: file.write)
            store.save(Settings(intervalMs: 60_000, hiddenSubscriptions: ["zai", "minimax"]))
            let loaded = store.load()
            Harness.expectEqual(loaded.hiddenSubscriptions, ["zai", "minimax"], "selection preserved verbatim")
            Harness.expectEqual(
                MenuBarItems.desired(providers: [ZaiProvider(), MiniMaxProvider()], settings: loaded),
                [.recovery], "a fully hidden app shows only the recovery item"
            )
        }),
        ("settings round-trip through the store", {
            let file = MemoryFile()
            let store = SettingsStore(url: URL(fileURLWithPath: "/dev/null"), readFile: file.read, writeFile: file.write)
            store.save(Settings(intervalMs: 300_000, hiddenSubscriptions: ["zai"]))
            let loaded = store.load()
            Harness.expectEqual(loaded.intervalMs, 300_000, "interval")
            Harness.expectEqual(loaded.hiddenSubscriptions, ["zai"], "hidden set")
        }),
        ("a missing settings file loads the defaults", {
            let store = SettingsStore(
                url: URL(fileURLWithPath: "/dev/null"),
                readFile: MemoryFile(nil).read,
                writeFile: { _, _ in }
            )
            Harness.expectEqual(store.load(), Settings(), "defaults")
        }),
        ("a corrupt settings file is clamped rather than rejected", {
            let file = MemoryFile(Data(#"{"intervalMs": "not-a-number", "hiddenSubscriptions": [1, 2]}"#.utf8))
            let store = SettingsStore(url: URL(fileURLWithPath: "/dev/null"), readFile: file.read, writeFile: file.write)
            let loaded = store.load()
            Harness.expectEqual(loaded.intervalMs, Settings.defaultIntervalMs, "interval falls back")
            Harness.expectEqual(loaded.hiddenSubscriptions, [], "hidden set falls back")
        }),
        ("saving clamps so a corrupt value can never reach the poll loop", {
            let file = MemoryFile()
            let store = SettingsStore(url: URL(fileURLWithPath: "/dev/null"), readFile: file.read, writeFile: file.write)
            store.save(Settings(intervalMs: 1))
            Harness.expectEqual(store.load().intervalMs, 10_000, "clamped on the way out")
        }),
        ("the app writes only under its own Application Support directory", {
            Harness.expectEqual(
                AppPaths.directory(home: URL(fileURLWithPath: "/Users/tester")).path,
                "/Users/tester/Library/Application Support/QuotaBar",
                "app directory"
            )
        }),
    ]
}

enum HistoryStoreTests {
    static let cases: [TestCase] = [
        ("histories round-trip through the store", {
            let file = MemoryFile()
            let store = HistoryStore(url: URL(fileURLWithPath: "/dev/null"), readFile: file.read, writeFile: file.write)
            store.save(["zai:5h": [Sample(t: 1_000, usage: 10), Sample(t: 2_000, usage: 20)]])
            let loaded = store.load()
            Harness.expectEqual(loaded.count, 1, "one history")
            Harness.expectEqual(loaded["zai:5h"]?.count, 2, "sample count")
            Harness.expectEqual(loaded["zai:5h"]?[1], Sample(t: 2_000, usage: 20), "sample value")
        }),
        ("a missing file loads no history rather than failing", {
            let store = HistoryStore(
                url: URL(fileURLWithPath: "/dev/null"),
                readFile: MemoryFile(nil).read,
                writeFile: { _, _ in }
            )
            Harness.expectEqual(store.load().count, 0, "empty")
        }),
        ("one malformed entry does not discard the others", {
            let raw = #"{"samples": {"zai:5h": [{"t": 1000, "usage": 5}, {"t": "bad", "usage": 6}, {"t": 2000}], "minimax:7d": "not-an-array", "zai:7d": [{"t": 3000, "usage": 9}]}}"#
            let file = MemoryFile(Data(raw.utf8))
            let store = HistoryStore(url: URL(fileURLWithPath: "/dev/null"), readFile: file.read, writeFile: file.write)
            let loaded = store.load()
            Harness.expectEqual(loaded["zai:5h"]?.count, 1, "valid samples survive")
            Harness.expectEqual(loaded["minimax:7d"], nil, "non-array entry dropped")
            Harness.expectEqual(loaded["zai:7d"]?.count, 1, "unrelated history survives")
        }),
        ("an empty sample list is not restored", {
            let file = MemoryFile(Data(#"{"samples": {"zai:5h": []}}"#.utf8))
            let store = HistoryStore(url: URL(fileURLWithPath: "/dev/null"), readFile: file.read, writeFile: file.write)
            Harness.expectEqual(store.load().count, 0, "empty dropped")
        }),
    ]
}

enum SecretHygieneTests {
    static let secret = "sk-do-not-leak-this-value"

    static let cases: [TestCase] = [
        ("no token ever reaches a rendered snapshot in any state", {
            let file = MemoryFile(Data(#"{"zai": {"key": "\#(secret)"}}"#.utf8))
            let clock = FakeClock(1_700_000_000_000)
            let sink = SnapshotSink()
            let engine = QuotaEngine(
                providers: [ZaiProvider(), MiniMaxProvider()],
                credentials: CredentialStore(readFile: file.read, environment: { _ in nil }),
                client: QuotaHTTPClient(timeoutMs: 200, transport: { _, _, _ in
                    TransportResponse(status: 401, text: "unauthorized")
                }),
                historyStore: HistoryStore(url: URL(fileURLWithPath: "/dev/null")),
                home: URL(fileURLWithPath: "/Users/tester"),
                now: { clock.now }
            )
            await engine.setObserver { sink.record($0) }
            await engine.refreshAll()
            for snapshot in sink.latest {
                Harness.expect(
                    !snapshot.menuBarLabel().contains(secret),
                    "\(snapshot.tag) label must not carry the token"
                )
                Harness.expect(
                    !errorTextShown(for: snapshot).contains(secret),
                    "\(snapshot.tag) error text must not carry the token"
                )
            }
        }),
        ("nothing persisted to disk contains the token", {
            let historyFile = MemoryFile()
            let clock = FakeClock(1_700_000_000_000)
            let engine = QuotaEngine(
                providers: [ZaiProvider()],
                credentials: CredentialStore(
                    readFile: MemoryFile(Data(#"{"zai": {"key": "\#(secret)"}}"#.utf8)).read,
                    environment: { _ in nil }
                ),
                client: QuotaHTTPClient(timeoutMs: 200, transport: { _, _, _ in
                    TransportResponse(
                        status: 200,
                        text: #"{"data":{"limits":[{"unit":3,"currentValue":10,"remaining":90}]}}"#
                    )
                }),
                historyStore: HistoryStore(
                    url: URL(fileURLWithPath: "/dev/null"),
                    readFile: historyFile.read,
                    writeFile: historyFile.write
                ),
                home: URL(fileURLWithPath: "/Users/tester"),
                now: { clock.now }
            )
            await engine.refresh(providerId: "zai")
            let persisted = String(decoding: historyFile.stored ?? Data(), as: UTF8.self)
            Harness.expect(!persisted.isEmpty, "history was written")
            Harness.expect(!persisted.contains(secret), "persisted history must not carry the token")
        }),
        ("error text for a missing credential names the environment variables, never a value", {
            let provider = ZaiProvider()
            let text = provider.errorText(.noToken)
            Harness.expect(text.contains("ZAI_TOKEN"), "names the env var")
            Harness.expect(!text.contains(secret), "never a value")
            Harness.expectEqual(
                QuotaErrorCode.displayText(for: "http-403", provider: provider), "http-403", "http codes pass through"
            )
        }),
    ]
}

/// Renders a snapshot's error text exactly as the dropdown does, so the secrecy
/// check covers the user-visible surface and not just the stored state.
private func errorTextShown(for snapshot: SubscriptionSnapshot) -> String {
    guard case .error(let code) = snapshot.state else { return "" }
    let provider = ProviderRegistry.all.first { $0.id == snapshot.id }
    guard let provider else { return code }
    return QuotaErrorCode.displayText(for: code, provider: provider)
}

enum MenuBarItemsTests {
    static let providers: [any QuotaProvider] = [ZaiProvider(), MiniMaxProvider()]

    nonisolated(unsafe) static let cases: [TestCase] = [
        ("with no preference the first provider by tag is shown", {
            Harness.expectEqual(
                MenuBarItems.desired(providers: providers, settings: Settings()),
                [.subscription("minimax")],
                "mmx sorts first, so it stands in"
            )
        }),
        ("the selection decides which single provider is shown", {
            for id in ["minimax", "zai"] {
                let settings = Settings(selectedProviderId: id)
                Harness.expectEqual(
                    MenuBarItems.desired(providers: providers, settings: settings),
                    [.subscription(id)],
                    "selection \(id)"
                )
            }
        }),
        ("hiding the selected provider falls back to one that is available", {
            let settings = Settings(
                hiddenSubscriptions: ["minimax"],
                selectedProviderId: "minimax"
            )
            Harness.expectEqual(
                MenuBarItems.desired(providers: providers, settings: settings),
                [.subscription("zai")],
                "selected provider is gone, zai stands in"
            )
        }),
        ("selecting none yields the recovery slot", {
            let settings = Settings(selectedProviderId: "")
            Harness.expectEqual(
                MenuBarItems.desired(providers: providers, settings: settings),
                [.recovery],
                "recovery slot"
            )
        }),
        ("hiding everything yields the recovery slot whatever is selected", {
            let settings = Settings(
                hiddenSubscriptions: ["zai", "minimax"],
                selectedProviderId: "zai"
            )
            Harness.expectEqual(
                MenuBarItems.desired(providers: providers, settings: settings),
                [.recovery],
                "recovery slot"
            )
        }),
        ("an unknown selection falls back rather than producing an empty item", {
            let settings = Settings(selectedProviderId: "ghost")
            Harness.expectEqual(
                MenuBarItems.desired(providers: providers, settings: settings),
                [.subscription("minimax")],
                "unknown id is inert"
            )
        }),
        ("the result is stable regardless of provider declaration order", {
            let reversed: [any QuotaProvider] = [MiniMaxProvider(), ZaiProvider()]
            Harness.expectEqual(
                MenuBarItems.desired(providers: reversed, settings: Settings()),
                MenuBarItems.desired(providers: providers, settings: Settings()),
                "ordering is by tag, not declaration"
            )
        }),
        ("every verdict maps to a distinct symbol name", {
            let names = Verdict.allCases.map { MenuBarItems.symbolName(for: $0) }
            Harness.expectEqual(Set(names).count, Verdict.allCases.count, "symbols are distinct")
            Harness.expect(names.allSatisfy { !$0.isEmpty }, "no empty symbol names")
        }),
        ("the recovery label names the app and claims no percentage", {
            Harness.expectEqual(
                MenuBarItems.label(for: .recovery, snapshot: nil), "QuotaBar", "recovery label"
            )
            Harness.expect(!MenuBarItems.label(for: .recovery, snapshot: nil).contains("%"), "no fake number")
        }),
        ("the tooltip spells out each window and the verdict in words", {
            let snapshot = SubscriptionSnapshot.placeholder(provider: ZaiProvider(), hidden: false)
            let live = SubscriptionSnapshot(
                id: snapshot.id,
                tag: snapshot.tag,
                displayName: snapshot.displayName,
                state: .live,
                windows: [
                    WindowSnapshot(
                        label: "5h", percent: 7, usage: 7, limit: 100,
                        verdict: .ok, resetInMs: 60_000, windowMs: nil,
                        runway: RunwayResult(state: .noBurn, runwayMs: nil, resetInMs: 60_000, spanMs: nil)
                    ),
                    WindowSnapshot(
                        label: "7d", percent: 42, usage: 42, limit: 100,
                        verdict: .short, resetInMs: 60_000, windowMs: nil,
                        runway: RunwayResult(state: .warn, runwayMs: 1, resetInMs: 60_000, spanMs: nil)
                    ),
                ],
                updatedAt: nil, lastAttemptAt: nil, stale: false,
                verdict: .short, hidden: false, endpoint: nil
            )
            let text = MenuBarItems.explanation(for: .subscription("zai"), snapshot: live)
            Harness.expect(text.contains("5h 7%"), "five-hour window named")
            Harness.expect(text.contains("7d 42%"), "weekly window named")
            Harness.expect(text.contains("will run out before the reset"), "verdict in words")
        }),
        ("the recovery tooltip explains how to get back", {
            let text = MenuBarItems.explanation(for: .recovery, snapshot: nil)
            Harness.expect(text.contains("no providers shown"), "states the state")
            Harness.expect(text.contains("choose"), "states the way out")
        }),
        ("a subscription slot renders that subscription's label", {
            let snapshot = SubscriptionSnapshot.placeholder(provider: ZaiProvider(), hidden: false)
            Harness.expectEqual(
                MenuBarItems.label(for: .subscription("zai"), snapshot: snapshot), "zai …", "placeholder label"
            )
            Harness.expectEqual(
                MenuBarItems.label(for: .subscription("minimax"), snapshot: snapshot), "minimax", "id fallback"
            )
        }),
        ("the selected provider survives a save and load", {
            let file = MemoryFile()
            let store = SettingsStore(url: URL(fileURLWithPath: "/dev/null"), readFile: file.read, writeFile: file.write)
            store.save(Settings(intervalMs: 60_000, selectedProviderId: "zai"))
            Harness.expectEqual(store.load().selectedProviderId, "zai", "selection persisted")

            store.save(Settings(intervalMs: 60_000, selectedProviderId: nil))
            Harness.expectEqual(store.load().selectedProviderId, nil, "absent when not selected")
        }),
        ("a settings file written before the selection existed still loads", {
            let file = MemoryFile(Data(#"{"intervalMs": 60000, "hiddenSubscriptions": []}"#.utf8))
            let store = SettingsStore(url: URL(fileURLWithPath: "/dev/null"), readFile: file.read, writeFile: file.write)
            let loaded = store.load()
            Harness.expectEqual(loaded.selectedProviderId, nil, "absent, not invented")
            Harness.expectEqual(
                MenuBarItems.desired(providers: MenuBarItemsTests.providers, settings: loaded),
                [.subscription("minimax")],
                "and resolves to a provider rather than nothing"
            )
        }),
    ]
}
