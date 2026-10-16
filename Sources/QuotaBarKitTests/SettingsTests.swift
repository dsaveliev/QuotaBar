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
        ("a show-none selection round-trips through the store", {
            let file = MemoryFile()
            let store = SettingsStore(url: URL(fileURLWithPath: "/dev/null"), readFile: file.read, writeFile: file.write)
            store.save(Settings(intervalMs: 60_000, selection: .none))
            let loaded = store.load()
            Harness.expectEqual(loaded.selection, .none, "choice preserved verbatim")
            Harness.expectEqual(
                MenuBarItems.desired(providers: [ZaiProvider(), MiniMaxProvider()], settings: loaded),
                [.recovery], "an app showing nothing keeps only the recovery item"
            )
        }),
        ("settings round-trip through the store", {
            let file = MemoryFile()
            let store = SettingsStore(url: URL(fileURLWithPath: "/dev/null"), readFile: file.read, writeFile: file.write)
            store.save(Settings(intervalMs: 300_000, selection: .provider("minimax")))
            let loaded = store.load()
            Harness.expectEqual(loaded.intervalMs, 300_000, "interval")
            Harness.expectEqual(loaded.selection, .provider("minimax"), "selection")
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
            let file = MemoryFile(Data(#"{"intervalMs": "not-a-number", "selection": 7}"#.utf8))
            let store = SettingsStore(url: URL(fileURLWithPath: "/dev/null"), readFile: file.read, writeFile: file.write)
            let loaded = store.load()
            Harness.expectEqual(loaded.intervalMs, Settings.defaultIntervalMs, "interval falls back")
            Harness.expectEqual(loaded.selection, .automatic, "a non-string selection falls back")
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
                snapshotStore: emptySnapshotStore(),
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
                snapshotStore: emptySnapshotStore(),
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
                let settings = Settings(selection: .provider(id))
                Harness.expectEqual(
                    MenuBarItems.desired(providers: providers, settings: settings),
                    [.subscription(id)],
                    "selection \(id)"
                )
            }
        }),
        ("a selection naming an unavailable provider falls back rather than emptying the bar", {
            let settings = Settings(selection: .provider("ghost"))
            Harness.expectEqual(
                MenuBarItems.desired(providers: providers, settings: settings),
                [.subscription("minimax")],
                "an id this build does not offer is inert"
            )
        }),
        ("no preference yet shows the first available provider", {
            Harness.expectEqual(
                MenuBarItems.desired(providers: providers, settings: Settings()),
                [.subscription("minimax")],
                "a fresh install shows something rather than nothing"
            )
        }),
        ("choosing Show none yields the recovery slot", {
            // The regression: the picker passes nil for "Show none", and that
            // used to be indistinguishable from "no preference", so the choice
            // silently fell back to the first provider.
            var settings = Settings()
            settings.selectProvider(nil)
            Harness.expectEqual(settings.selection, .none, "nil from the picker means show none")
            Harness.expectEqual(
                MenuBarItems.desired(providers: providers, settings: settings),
                [.recovery],
                "recovery slot"
            )
        }),
        ("Show none is a choice, and a later pick replaces it", {
            var settings = Settings()
            settings.selectProvider(nil)
            settings.selectProvider("zai")
            Harness.expectEqual(settings.selection, .provider("zai"), "picking again overrides none")
            settings.selectProvider(nil)
            Harness.expectEqual(settings.selection, .none, "and back again")
        }),
        ("selecting none yields the recovery slot", {
            let settings = Settings(selection: .none)
            Harness.expectEqual(
                MenuBarItems.desired(providers: providers, settings: settings),
                [.recovery],
                "recovery slot"
            )
        }),
        ("nothing available yields the recovery slot whatever is selected", {
            for selection in [ProviderSelection.none, .provider("zai"), .automatic] {
                Harness.expectEqual(
                    MenuBarItems.desired(providers: [], settings: Settings(selection: selection)),
                    [.recovery],
                    "recovery slot for \(selection)"
                )
            }
        }),
        ("an unknown selection falls back rather than producing an empty item", {
            let settings = Settings(selection: .provider("ghost"))
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
            let snapshot = SubscriptionSnapshot.placeholder(provider: ZaiProvider())
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
                verdict: .short, restored: false, endpoint: nil
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
            let snapshot = SubscriptionSnapshot.placeholder(provider: ZaiProvider())
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
            store.save(Settings(intervalMs: 60_000, selection: .provider("zai")))
            Harness.expectEqual(store.load().selection, .provider("zai"), "selection persisted")

            store.save(Settings(intervalMs: 60_000, selection: .none))
            Harness.expectEqual(store.load().selection, .none, "show none is persisted as a choice")

            store.save(Settings(intervalMs: 60_000, selection: .automatic))
            Harness.expectEqual(store.load().selection, .automatic, "absent when no preference")
        }),
        ("a settings file from the multi-select era still loads", {
            // `hiddenSubscriptions` is ignored on purpose: it described a
            // selection model that no longer exists, and the first provider
            // standing in is the same thing a fresh install does.
            let file = MemoryFile(
                Data(#"{"intervalMs": 60000, "hiddenSubscriptions": ["zai", "minimax"]}"#.utf8)
            )
            let store = SettingsStore(
                url: URL(fileURLWithPath: "/dev/null"), readFile: file.read, writeFile: file.write
            )
            let loaded = store.load()
            Harness.expectEqual(loaded.selection, .automatic, "no selection invented out of a hidden list")
            Harness.expectEqual(
                MenuBarItems.desired(providers: MenuBarItemsTests.providers, settings: loaded),
                [.subscription("minimax")],
                "and resolves to a provider rather than nothing"
            )
        }),
        ("a pre-selection file that recorded an empty id means show none", {
            // The old writer spelled "show none" as an empty string. Reading it
            // as "no preference" is exactly the bug being fixed here.
            let file = MemoryFile(Data(#"{"intervalMs": 60000, "selectedProviderId": ""}"#.utf8))
            let store = SettingsStore(
                url: URL(fileURLWithPath: "/dev/null"), readFile: file.read, writeFile: file.write
            )
            Harness.expectEqual(store.load().selection, .none, "empty id is the show-none sentinel")
        }),
        ("a pre-selection file with a real id still selects that provider", {
            let file = MemoryFile(Data(#"{"intervalMs": 60000, "selectedProviderId": "zai"}"#.utf8))
            let store = SettingsStore(
                url: URL(fileURLWithPath: "/dev/null"), readFile: file.read, writeFile: file.write
            )
            Harness.expectEqual(store.load().selection, .provider("zai"), "carried over")
        }),

        ("remembered figures survive a restart, and only within the week", {
            let clock = FakeClock(1_700_000_000_000)
            let file = MemoryFile()
            let store = SnapshotStore(
                url: URL(fileURLWithPath: "/dev/null"),
                now: { clock.now },
                readFile: file.read,
                writeFile: file.write
            )
            let rows = [QuotaRow(label: "5h", usage: 20, limit: 100, percent: 20, resetAt: 1_700_003_600_000)]
            store.save(["zai": SnapshotStore.Entry(rows: rows, fetchedAt: clock.now)])
            Harness.expectEqual(store.load()["zai"]?.rows.count, 1, "round-trips through the file")

            clock.advance(by: SnapshotStore.retentionMs - 3_600_000)
            Harness.expectEqual(store.load()["zai"]?.rows.count, 1, "still inside the week")

            clock.advance(by: 2 * 3_600_000)
            Harness.expect(store.load()["zai"] == nil, "past the week, nothing is restored")
        }),

        ("a damaged entry costs only that subscription", {
            let clock = FakeClock(1_700_000_000_000)
            let json = #"{"zai":{"fetchedAt":1700000000000,"rows":[{"label":"5h","percent":12}]},"minimax":{"fetchedAt":1700000000000,"rows":"not-an-array"}}"#
            let file = MemoryFile(Data(json.utf8))
            let store = SnapshotStore(
                url: URL(fileURLWithPath: "/dev/null"),
                now: { clock.now },
                readFile: file.read,
                writeFile: file.write
            )
            let loaded = store.load()
            Harness.expectEqual(loaded["zai"]?.rows.first?.percent, 12, "the good entry survives")
            Harness.expect(loaded["minimax"] == nil, "the broken entry is dropped, not fatal")
        }),

        ("an unreadable file costs nothing and is not fatal", {
            let store = SnapshotStore(
                url: URL(fileURLWithPath: "/dev/null"),
                readFile: { _ in throw CocoaError(.fileReadCorruptFile) },
                writeFile: { _, _ in }
            )
            Harness.expect(store.load().isEmpty, "nothing restored, nothing crashes")
        }),

        ("restored figures keep their own age", {
            let clock = FakeClock(1_700_000_000_000)
            let fetchedAt = clock.now - 3 * 3_600_000
            let file = MemoryFile()
            let store = SnapshotStore(
                url: URL(fileURLWithPath: "/dev/null"),
                now: { clock.now },
                readFile: file.read,
                writeFile: file.write
            )
            store.save([
                "zai": SnapshotStore.Entry(
                    rows: [QuotaRow(label: "5h", usage: 20, limit: 100, percent: 20)],
                    fetchedAt: fetchedAt
                )
            ])
            Harness.expectEqual(
                store.load()["zai"]?.fetchedAt, fetchedAt,
                "aged from when it was fetched, not when when it was restored"
            )
        }),
    ]
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
