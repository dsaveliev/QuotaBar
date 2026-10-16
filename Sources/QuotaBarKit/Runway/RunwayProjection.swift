import Foundation

public struct Sample: Equatable, Sendable {
    public var t: EpochMillis
    public var usage: Double

    public init(t: EpochMillis, usage: Double) {
        self.t = t
        self.usage = usage
    }
}

/// Outcome of projecting one window's exhaustion time.
public enum RunwayState: String, Sendable {
    case noLimit
    case noReset
    case noData
    case noBurn
    case ok
    case warn

    var markerText: String {
        switch self {
        case .noLimit: "—"
        case .noReset: "—"
        case .noData: "…"
        case .noBurn: "∞"
        case .ok: ""
        case .warn: ""
        }
    }
}

public struct RunwayResult: Equatable, Sendable {
    public var state: RunwayState
    public var runwayMs: Double?
    public var resetInMs: Double?
    /// History span behind the decision (last.t - first.t). Reporting only.
    /// nil when decided before history inspection; 0 for a single sample or
    /// identical timestamps.
    public var spanMs: Double?

    public init(state: RunwayState, runwayMs: Double?, resetInMs: Double?, spanMs: Double?) {
        self.state = state
        self.runwayMs = runwayMs
        self.resetInMs = resetInMs
        self.spanMs = spanMs
    }
}

public enum Runway {
    /// Two samples at least this far apart are required before projecting.
    public static let minimumSpanMs: Double = 1_000

    /// Project the time until the limit is exhausted versus the time until the
    /// window resets. Pure: inputs are never mutated. A non-finite resetAt is
    /// absent, never a real timestamp.
    public static func compute(
        history: [Sample],
        row: QuotaRow,
        now: EpochMillis
    ) -> RunwayResult {
        let resetAt = row.resetAt.flatMap { $0.isFinite ? $0 : nil }

        guard let limit = row.limit else {
            return RunwayResult(
                state: .noLimit,
                runwayMs: nil,
                resetInMs: resetAt.map { max(0, $0 - now) },
                spanMs: nil
            )
        }
        guard let resetAt else {
            return RunwayResult(state: .noReset, runwayMs: nil, resetInMs: nil, spanMs: nil)
        }

        let resetInMs = max(0, resetAt - now)

        guard let usage = row.usage, history.count >= 2 else {
            let spanMs = history.isEmpty ? nil : history[history.count - 1].t - history[0].t
            return RunwayResult(state: .noData, runwayMs: nil, resetInMs: resetInMs, spanMs: spanMs)
        }

        let first = history[0]
        let last = history[history.count - 1]
        let spanMs = last.t - first.t
        guard spanMs >= minimumSpanMs else {
            return RunwayResult(state: .noData, runwayMs: nil, resetInMs: resetInMs, spanMs: spanMs)
        }

        let burnPerMs = (last.usage - first.usage) / spanMs
        guard burnPerMs > 0 else {
            return RunwayResult(state: .noBurn, runwayMs: nil, resetInMs: resetInMs, spanMs: spanMs)
        }

        let runwayMs = (limit - usage) / burnPerMs
        guard runwayMs.isFinite else {
            return RunwayResult(state: .noBurn, runwayMs: nil, resetInMs: resetInMs, spanMs: spanMs)
        }
        return RunwayResult(
            state: runwayMs < resetInMs ? .warn : .ok,
            runwayMs: runwayMs,
            resetInMs: resetInMs,
            spanMs: spanMs
        )
    }
}

public enum SampleHistory {
    /// Append a sample, returning a new array. A usage decrease relative to the
    /// last sample marks a quota-window boundary, so history restarts from the
    /// new sample alone. A degenerate cap is floored to 1 so trimming can never
    /// empty the history.
    public static func append(
        _ history: [Sample],
        sample: Sample,
        maxSamples: Int
    ) -> [Sample] {
        let cap = max(1, maxSamples)
        if let last = history.last, sample.usage < last.usage {
            return [sample]
        }
        var next = history
        next.append(sample)
        if next.count > cap { next.removeFirst(next.count - cap) }
        return next
    }
}