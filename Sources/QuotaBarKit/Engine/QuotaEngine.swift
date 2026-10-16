import Foundation

/// Owns all subscription state and performs every refresh.
///
/// Actor isolation is what makes in-flight deduplication an invariant rather
/// than a guard scattered across call sites: while a subscription's task is
/// held in `inFlight`, further triggers await that same task instead of
/// starting a second request.
public actor QuotaEngine {
    private struct SubscriptionState {
        let provider: any QuotaProvider
        var rows: [QuotaRow] = []
        var histories: [String: [Sample]] = [:]
        var previousResetAt: [String: EpochMillis] = [:]
        var updatedAt: EpochMillis?
        var lastAttemptAt: EpochMillis?
        var errorCode: String?
        var stickyEndpoint: URL?
        var loading = true
        /// These figures were restored from a previous run and no refresh this
        /// launch has confirmed them yet. They are measurements, not a forecast.
        var restored = false
        var inFlight: Task<Void, Never>?
    }

    private var states: [String: SubscriptionState] = [:]
    private let credentials: CredentialStore
    private let client: QuotaHTTPClient
    private let historyStore: HistoryStore
    private let snapshotStore: SnapshotStore
    private var intervalMs: Double = Settings.defaultIntervalMs
    private var tightFactor: Double = 1.5
    private var maxHistorySamples: Double = 120
    private var onChange: (@Sendable ([SubscriptionSnapshot]) -> Void)?
    private var now: @Sendable () -> EpochMillis

    public init(
        providers: [any QuotaProvider],
        credentials: CredentialStore,
        client: QuotaHTTPClient,
        historyStore: HistoryStore,
        snapshotStore: SnapshotStore,
        tightFactor: Double = 1.5,
        maxHistorySamples: Double = 120,
        now: @escaping @Sendable () -> EpochMillis = Clock.now
    ) {
        for provider in providers {
            var state = SubscriptionState(provider: provider)
            // Restoring here rather than in an async method: an actor's `init`
            // is nonisolated, and the histories belong to the initial state.
            // Keys are `providerId:label`, so an entry for a provider this
            // instance does not track is simply ignored.
            for (key, samples) in historyStore.load() where Self.providerId(of: key) == provider.id {
                state.histories[key] = samples
                // previousResetAt stays unset on purpose: the first successful
                // refresh after a launch is the first observation of this
                // window, not evidence of a boundary.
            }
            // Last known figures, so the menu bar shows numbers before the first
            // response instead of an ellipsis. Keyed by provider id, so this
            // cannot pick up another subscription's rows.
            if let entry = snapshotStore.load()[provider.id] {
                state.rows = entry.rows
                state.updatedAt = entry.fetchedAt
                state.restored = true
                state.loading = false
            }
            states[provider.id] = state
        }
        self.credentials = credentials
        self.client = client
        self.historyStore = historyStore
        self.snapshotStore = snapshotStore
        self.tightFactor = tightFactor
        self.maxHistorySamples = maxHistorySamples
        self.now = now
    }

    /// Called by the main actor; receives every snapshot after each change.
    public func setObserver(_ observer: @escaping @Sendable ([SubscriptionSnapshot]) -> Void) {
        onChange = observer
    }

    public func apply(settings: Settings) {
        var clamped = settings
        clamped.clamp()
        intervalMs = clamped.intervalMs
        publish()
    }

    public func currentIntervalMs() -> Double { intervalMs }

    /// Refresh one subscription. Concurrent triggers join the in-flight request.
    public func refresh(providerId: String) async {
        guard var state = states[providerId] else { return }
        if let existing = state.inFlight {
            await existing.value
            return
        }
        // The task lives only for the duration of one request and the engine owns it,
        // so capturing `self` here does not outlive the app.
        let task = Task { await performRefresh(providerId: providerId) }
        state.inFlight = task
        states[providerId] = state
        await task.value
        states[providerId]?.inFlight = nil
        publish()
    }

    /// Refresh every tracked subscription concurrently.
    public func refreshAll() async {
        await withTaskGroup(of: Void.self) { group in
            for id in states.keys.sorted() {
                group.addTask { [weak self] in
                    await self?.refresh(providerId: id)
                }
            }
        }
    }

    public func snapshots() -> [SubscriptionSnapshot] {
        buildSnapshots()
    }

    // MARK: - Refresh

    private func performRefresh(providerId: String) async {
        guard var state = states[providerId] else { return }
        let provider = state.provider
        state.lastAttemptAt = now()
        states[providerId] = state

        guard let credential = credentials.resolve(for: provider) else {
            applyError(providerId: providerId, code: QuotaErrorCode.noToken.rawValue)
            return
        }

        // Sticky endpoint first, then the rest in declaration order.
        var candidates = provider.endpoints
        if let sticky = state.stickyEndpoint, let index = candidates.firstIndex(of: sticky) {
            candidates.insert(candidates.remove(at: index), at: 0)
        }

        var lastError = QuotaFetchError.network
        for endpoint in candidates {
            switch await client.fetch(endpoint: endpoint, token: credential.token) {
            case .failure(let error):
                lastError = error
            case .success(let payload):
                guard provider.isSuccessPayload(payload.value) else {
                    // Well-formed but not this region/account: fall through.
                    lastError = .http(200)
                    continue
                }
                applySuccess(providerId: providerId, endpoint: endpoint, rows: provider.parse(payload.value))
                return
            }
        }

        // Every candidate failed: forget the sticky endpoint so the next
        // refresh retries from the declared first.
        states[providerId]?.stickyEndpoint = nil
        applyError(providerId: providerId, code: lastError.code)
    }

    private func applySuccess(providerId: String, endpoint: URL, rows: [QuotaRow]) {
        guard var state = states[providerId] else { return }
        let timestamp = now()

        if rows.isEmpty {
            applyError(providerId: providerId, code: QuotaErrorCode.empty.rawValue)
            return
        }

        let ordered = RowOrder.sort(rows)
        state.rows = ordered
        state.updatedAt = timestamp
        state.errorCode = nil
        state.loading = false
        state.stickyEndpoint = endpoint
        // This launch has now confirmed the figures it was showing.
        state.restored = false

        for row in ordered {
            guard let usage = row.usage else { continue }
            let key = Self.historyKey(providerId, row.label)
            // A moved reset timestamp means a new window: history restarts.
            if let previous = state.previousResetAt[key], previous != row.resetAt {
                state.histories[key] = []
            }
            state.previousResetAt[key] = row.resetAt
            state.histories[key] = SampleHistory.append(
                state.histories[key] ?? [],
                sample: Sample(t: timestamp, usage: usage),
                maxSamples: max(1, Int(maxHistorySamples))
            )
        }

        // Windows that disappeared (a plan tier dropped) release their history.
        let live = Set(ordered.map { Self.historyKey(providerId, $0.label) })
        state.histories = state.histories.filter { live.contains($0.key) }
        state.previousResetAt = state.previousResetAt.filter { live.contains($0.key) }

        states[providerId] = state
        persistHistories()
        persistSnapshot(providerId: providerId, rows: ordered, fetchedAt: timestamp)
    }

    /// Remembers the figures so the next launch can show them before its first
    /// response. Only successes write: an error clears the figures on screen and
    /// must not leave the last good ones on disk to be restored as if current.
    private func persistSnapshot(providerId: String, rows: [QuotaRow], fetchedAt: EpochMillis) {
        var entries = snapshotStore.load()
        entries[providerId] = SnapshotStore.Entry(rows: rows, fetchedAt: fetchedAt)
        snapshotStore.save(entries)
    }

    private func applyError(providerId: String, code: String) {
        guard var state = states[providerId] else { return }
        state.loading = false
        state.errorCode = code
        // Previous numbers are never presented as current.
        state.rows = []
        state.updatedAt = nil
        states[providerId] = state
    }

    // MARK: - Snapshots

    private func buildSnapshots() -> [SubscriptionSnapshot] {
        let timestamp = now()
        return states.values
            .sorted { $0.provider.tag < $1.provider.tag }
            .map { state in
                let stale: Bool
                if state.errorCode != nil {
                    // While failing, freshness tracks the last attempt so a live
                    // but broken endpoint is an error, not "stale data".
                    stale = false
                } else if state.restored {
                    // "Stale" means a refresh was due and did not arrive. At
                    // launch none is due yet, so flagging every restart would
                    // cry wolf on the one day the user least expects it. The
                    // header's age line is what tells the truth here.
                    stale = false
                } else if let updatedAt = state.updatedAt {
                    stale = timestamp - updatedAt > intervalMs * 2
                } else {
                    stale = false
                }

                let windows: [WindowSnapshot] = state.rows.compactMap { row in
                    guard let usage = row.usage else { return nil }
                    let key = Self.historyKey(state.provider.id, row.label)
                    let history = state.histories[key] ?? []
                    let runway = Runway.compute(history: history, row: row, now: timestamp)
                    let verdict = VerdictClassifier.classify(
                        VerdictInput(
                            usage: usage,
                            limit: row.limit,
                            runwayMs: runway.runwayMs,
                            runwayState: runway.state,
                            resetInMs: runway.resetInMs,
                            spanMs: runway.spanMs,
                            stale: stale,
                            tightFactor: tightFactor,
                            windowMs: row.windowMs
                        )
                    )
                    // Measuring is "has a real span, has not watched long enough".
                    // Three exclusions, each a different reason there is nothing
                    // to measure: noData has too few samples, noLimit and
                    // noReset have nothing to project in the first place and
                    // carry no span at all, and blocked is already decided.
                    let required = VerdictClassifier.minimumSpanMs(forWindow: row.windowMs)
                    let isMeasuring = runway.state != .noData
                        && runway.spanMs != nil
                        && (runway.spanMs ?? 0) < required
                        && verdict != .blocked
                    let fraction = required > 0
                        ? min(1, max(0, runway.spanMs.map { $0 / required } ?? 0))
                        : nil
                    return WindowSnapshot(
                        label: row.label,
                        percent: row.percent,
                        usage: row.usage,
                        limit: row.limit,
                        verdict: verdict,
                        resetInMs: runway.resetInMs,
                        windowMs: row.windowMs,
                        runway: runway,
                        isMeasuring: isMeasuring,
                        measuredFraction: isMeasuring ? fraction : nil
                    )
                }

                let visibleState: SubscriptionSnapshot.State
                if state.loading {
                    visibleState = .loading
                } else if let code = state.errorCode {
                    visibleState = .error(code: code)
                } else {
                    visibleState = .live
                }

                return SubscriptionSnapshot(
                    id: state.provider.id,
                    tag: state.provider.tag,
                    displayName: state.provider.displayName,
                    state: visibleState,
                    windows: windows,
                    updatedAt: state.updatedAt,
                    lastAttemptAt: state.lastAttemptAt,
                    stale: stale,
                    // A projection built on a burn rate that stopped being
                    // measured when the app exited is not this morning's
                    // forecast. The figures stand; the verdict waits.
                    verdict: state.restored
                        ? .unknown
                        : VerdictClassifier.worst(windows.map(\.verdict)),
                    restored: state.restored,
                    endpoint: state.stickyEndpoint ?? state.provider.endpoints.first
                )
            }
    }

    private func publish() {
        onChange?(buildSnapshots())
    }

    private static func historyKey(_ providerId: String, _ label: String) -> String {
        "\(providerId):\(label)"
    }

    private static func providerId(of historyKey: String) -> String? {
        guard let separator = historyKey.firstIndex(of: ":") else { return nil }
        return String(historyKey[historyKey.startIndex..<separator])
    }

    // MARK: - History persistence

    private func persistHistories() {
        var all: [String: [Sample]] = [:]
        for state in states.values {
            for (key, samples) in state.histories where !samples.isEmpty {
                all[key] = samples
            }
        }
        historyStore.save(all)
    }
}