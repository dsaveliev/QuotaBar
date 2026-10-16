import Foundation

/// What the UI needs to know about one window. Derived entirely from the row
/// and its projection; carries no engine internals.
public struct WindowSnapshot: Identifiable, Sendable, Equatable {
    public var label: String
    public var percent: Double?
    public var usage: Double?
    public var limit: Double?
    public var verdict: Verdict
    public var resetInMs: Double?
    public var windowMs: Double?
    public var runway: RunwayResult
    /// True while the window has samples but has not yet been observed for
    /// long enough to support a verdict. Distinct from having too few samples
    /// to project at all: this one is provisional, that one has nothing.
    public var isMeasuring: Bool
    /// How far along the wait to a trustworthy verdict this window is, 0...1.
    public var measuredFraction: Double?

    public var id: String { label }

    public init(
        label: String,
        percent: Double?,
        usage: Double?,
        limit: Double?,
        verdict: Verdict,
        resetInMs: Double?,
        windowMs: Double?,
        runway: RunwayResult,
        isMeasuring: Bool = false,
        measuredFraction: Double? = nil
    ) {
        self.label = label
        self.percent = percent
        self.usage = usage
        self.limit = limit
        self.verdict = verdict
        self.resetInMs = resetInMs
        self.windowMs = windowMs
        self.runway = runway
        self.isMeasuring = isMeasuring
        self.measuredFraction = measuredFraction
    }

    /// Share of the window already elapsed, 0...1, or nil when the row carries
    /// no window duration or no reset time. Drives the pace marker position:
    /// fill left of the marker is quota consumed so far, and the distance from
    /// the marker to the right edge is how much window is left.
    public func elapsedFraction() -> Double? {
        guard let windowMs, windowMs > 0, let resetInMs else { return nil }
        let elapsed = windowMs - resetInMs
        return min(1, max(0, elapsed / windowMs))
    }
}

/// Everything the UI needs about one subscription.
public struct SubscriptionSnapshot: Identifiable, Sendable, Equatable {
    /// Data state of the subscription, independent of the data itself.
    public enum State: Sendable, Equatable {
        case loading
        case live
        case error(code: String)
    }

    public var id: String
    public var tag: String
    public var displayName: String
    public var state: State
    public var windows: [WindowSnapshot]
    public var updatedAt: EpochMillis?
    public var lastAttemptAt: EpochMillis?
    public var stale: Bool
    public var verdict: Verdict
    /// The endpoint currently in use, shown in the dropdown so a region
    /// fallback is visible rather than mysterious.
    public var endpoint: URL?

    public init(
        id: String,
        tag: String,
        displayName: String,
        state: State,
        windows: [WindowSnapshot],
        updatedAt: EpochMillis?,
        lastAttemptAt: EpochMillis?,
        stale: Bool,
        verdict: Verdict,
        endpoint: URL?
    ) {
        self.id = id
        self.tag = tag
        self.displayName = displayName
        self.state = state
        self.windows = windows
        self.updatedAt = updatedAt
        self.lastAttemptAt = lastAttemptAt
        self.stale = stale
        self.verdict = verdict
        self.endpoint = endpoint
    }

    /// Highest consumed percent across the subscription's windows — the one
    /// number the menu bar label carries.
    public var headPercent: Double? {
        windows.compactMap(\.percent).max()
    }

    public var isError: Bool {
        if case .error = state { return true }
        return false
    }

    /// Menu bar label: `zai 1%·52% ✓`, `mmx …` before the first result,
    /// `zai ?` while failing.
    ///
    /// Every window's percent is shown, not just the highest: the five-hour and
    /// weekly windows move independently, and a single number hides which one is
    /// about to run out. The label has to stay narrow, so windows are joined with
    /// a middle dot and the unabbreviated reading lives in the tooltip.
    public func menuBarLabel() -> String {
        switch state {
        case .loading:
            return "\(tag) …"
        case .error:
            return "\(tag) ?"
        case .live:
            let percents = windows.compactMap(\.percent).map(PercentFormat.text)
            guard !percents.isEmpty else { return "\(tag) …" }
            return "\(tag) \(percents.joined(separator: "·")) \(verdict.glyph)"
        }
    }

    public static func placeholder(
        provider: any QuotaProvider
    ) -> SubscriptionSnapshot {
        SubscriptionSnapshot(
            id: provider.id,
            tag: provider.tag,
            displayName: provider.displayName,
            state: .loading,
            windows: [],
            updatedAt: nil,
            lastAttemptAt: nil,
            stale: false,
            verdict: .unknown,
            endpoint: nil
        )
    }
}

public enum Clock {
    /// Milliseconds since the Unix epoch — the unit every provider timestamp
    /// uses, so this is the clock all comparisons are made against.
    public static func now() -> EpochMillis {
        Date().timeIntervalSince1970 * 1000
    }
}