import AppKit
import Combine
import Foundation
import QuotaBarKit

/// Main-actor view state over the engine actor.
///
/// The engine publishes snapshots; this object is what SwiftUI observes. It
/// owns the poller, the settings file, and every action the dropdown offers.
/// Views read `snapshots` and call the intent methods here — never the engine.
@MainActor
final class AppModel: ObservableObject {
    /// Window width every menu is sized to, so the bar blocks line up.
    static let menuWidth: CGFloat = 300

    /// Refresh cadences offered in the interval picker.
    static let intervalChoices: [Double] = [30_000, 60_000, 120_000, 300_000, 900_000]

    /// How many menu bar slots the app scene declares. Slots past the number
    /// of tracked subscriptions are simply never inserted, so a new provider
    /// needs no scene surgery while it stays within this count.
    static let slotCount = 4

    @Published private(set) var snapshots: [SubscriptionSnapshot] = []
    /// True while a refresh is in flight, so the panel can show what the button
    /// is doing instead of appearing inert.
    @Published private(set) var isRefreshing = false
    @Published private(set) var settings: Settings

    let engine: QuotaEngine

    private let store: SettingsStore
    private let home: URL
    private var timer: Timer?
    private var intervalMs: Double

    init(home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        precondition(
            ProviderRegistry.all.count <= Self.slotCount,
            "QuotaBarApp declares \(Self.slotCount) menu bar slots; add one there for the new provider"
        )
        self.home = home
        let directory = AppPaths.directory(home: home)
        AppPaths.ensureDirectory(at: directory)
        self.store = SettingsStore(url: directory.appending(path: "settings.json"))
        let loaded = store.load()
        self.settings = loaded
        self.intervalMs = loaded.intervalMs
        self.engine = QuotaEngine(
            providers: ProviderRegistry.all,
            credentials: CredentialStore(),
            client: QuotaHTTPClient(timeoutMs: 20_000),
            historyStore: HistoryStore(url: directory.appending(path: "history.json")),
            home: home
        )
        self.snapshots = ProviderRegistry.all.map {
            SubscriptionSnapshot.placeholder(provider: $0)
        }
    }

    // MARK: - Lifecycle

    func start() {
        let engine = engine
        let settings = settings
        Task {
            // The engine runs off the main actor; hop back before touching
            // published state. Observer first, so the first refresh publishes.
            await engine.setObserver { snapshots in
                Task { @MainActor [weak self] in
                    self?.snapshots = snapshots
                }
            }
            await engine.apply(settings: settings)
            await engine.refreshAll()
        }
        scheduleTimer()
    }

    private func scheduleTimer() {
        timer?.invalidate()
        let seconds = max(1, intervalMs / 1000)
        let engine = engine
        let timer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: true) { _ in
            Task { await engine.refreshAll() }
        }
        // Keeps ticking while a menu is open or a window is being dragged.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    // MARK: - Derived state

    /// The subscription the menu bar item shows, or nil when the user chose to
    /// show none. Resolved through `MenuBarItems.desired` so the rule for what
    /// belongs in the bar lives in exactly one place.
    var shown: SubscriptionSnapshot? {
        guard case .subscription(let id) = MenuBarItems.desired(
            providers: ProviderRegistry.all, settings: settings
        ).first else { return nil }
        return snapshots.first { $0.id == id }
    }

    var shownCount: Int { shown == nil ? 0 : 1 }

    func snapshot(forSlot slot: Int) -> SubscriptionSnapshot? {
        slot == 0 ? shown : nil
    }

    func isSlotInserted(_ slot: Int) -> Bool {
        snapshot(forSlot: slot) != nil
    }

    func snapshot(id: String) -> SubscriptionSnapshot? {
        snapshots.first { $0.id == id }
    }

    /// The tracked subscription with this id. Matched on the provider's own id
    /// (`zai`, `minimax`), not on the OpenCode provider aliases the registry
    /// resolves for the plugin.
    func provider(for id: String) -> (any QuotaProvider)? {
        ProviderRegistry.all.first { $0.id == id }
    }

    /// Where a token for this provider would be read from — shown on the
    /// error path so the fix is actionable. The token itself never appears.
    func credentialLocation(for id: String) -> String {
        let file = CredentialStore.defaultAuthFileURL(home: home).path
        let envs = provider(for: id)?.tokenEnvNames ?? []
        let env = envs.isEmpty ? "" : ", or env \(envs.joined(separator: " / "))"
        return "\(file)\(env)"
    }

    // MARK: - Intents

    func refreshAll() {
        guard !isRefreshing else { return }
        isRefreshing = true
        Task { [engine] in
            await engine.refreshAll()
            isRefreshing = false
        }
    }

    /// Called when a dropdown is presented: refresh when the data on screen is
    /// older than the cadence, so opening a menu never shows expired numbers.
    func refreshIfStale(id: String) {
        guard !isRefreshing else { return }
        let now = Clock.now()
        let snapshot = snapshot(id: id)
        let age = snapshot?.updatedAt.map { now - $0 } ?? .infinity
        guard age > intervalMs else { return }
        Task { [engine] in await engine.refresh(providerId: id) }
    }

    func setInterval(_ ms: Double) {
        var updated = settings
        updated.intervalMs = ms
        updated.clamp()
        settings = updated
        intervalMs = updated.intervalMs
        store.save(updated)
        Task { [engine] in await engine.apply(settings: updated) }
        scheduleTimer()
    }

    /// The provider the picker should show as current, or nil for `Show none`.
    var selectedProviderId: String? {
        switch settings.selection {
        case .none: return nil
        case .provider(let id): return id
        case .automatic: return shown?.id
        }
    }

    /// Choose which provider the panel and menu bar item show.
    func selectProvider(_ providerId: String?) {
        var updated = settings
        updated.selectProvider(providerId)
        guard updated != settings else { return }
        settings = updated
        store.save(updated)
        Task { [engine] in await engine.apply(settings: updated) }
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }
}