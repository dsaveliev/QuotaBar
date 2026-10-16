import Foundation

/// Per-window severity. Glyphs and colours follow the verdict, never the raw
/// percentage.
public enum Verdict: String, Sendable, CaseIterable, Comparable {
    case ok
    case tight
    case short
    case blocked
    case unknown

    public var severity: Int {
        switch self {
        case .ok: 0
        case .tight: 1
        case .short: 2
        case .blocked: 3
        case .unknown: -1
        }
    }

    public static func < (lhs: Verdict, rhs: Verdict) -> Bool { lhs.severity < rhs.severity }

    public var glyph: String {
        switch self {
        case .ok: "✓"
        case .tight: "!"
        case .short: "!!"
        case .blocked: "✗"
        case .unknown: "?"
        }
    }
}

public struct VerdictInput: Sendable {
    public var usage: Double?
    public var limit: Double?
    public var runwayMs: Double?
    public var runwayState: RunwayState
    public var resetInMs: Double?
    public var spanMs: Double?
    public var stale: Bool
    /// The window's own duration, used to scale how much evidence a verdict
    /// needs. Nil when the provider does not report one.
    public var windowMs: Double?
    /// Validated >= 1 by the settings layer.
    public var tightFactor: Double

    public init(
        usage: Double?,
        limit: Double?,
        runwayMs: Double?,
        runwayState: RunwayState,
        resetInMs: Double?,
        spanMs: Double?,
        stale: Bool,
        tightFactor: Double,
        windowMs: Double? = nil
    ) {
        self.usage = usage
        self.limit = limit
        self.runwayMs = runwayMs
        self.runwayState = runwayState
        self.resetInMs = resetInMs
        self.spanMs = spanMs
        self.stale = stale
        self.tightFactor = tightFactor
        self.windowMs = windowMs
    }
}

public enum VerdictClassifier {
    /// Floor for windows that do not report a duration.
    public static let baseMinimumSpanMs: Double = 60_000

    /// Share of a window's own duration that must be observed before its
    /// verdict is trustworthy.
    ///
    /// A projection is an extrapolation across the whole window, so the evidence
    /// it rests on has to scale with the window. A flat minute is meaningful for
    /// five hours and nonsense for seven days — which is why the weekly window
    /// used to report itself as short minutes after launch.
    public static let spanFraction = 20.0

    /// Observation a window of this duration needs before it may report
    /// anything but `unknown`.
    public static func minimumSpanMs(forWindow windowMs: Double?) -> Double {
        guard let windowMs, windowMs.isFinite, windowMs > 0 else { return baseMinimumSpanMs }
        return max(baseMinimumSpanMs, windowMs / spanFraction)
    }

    /// Ordered ladder. Incomplete, stale, or too-brief evidence never yields a
    /// positive verdict.
    public static func classify(_ input: VerdictInput) -> Verdict {
        // 1. Hard exhaustion outranks every other signal.
        if let usage = input.usage, let limit = input.limit, usage >= limit { return .blocked }
        // 2. A stale sample supports no verdict.
        if input.stale { return .unknown }
        // 3. Too little observation supports no verdict. The bar scales with
        //    the window: a few minutes cannot say anything about a week.
        if let span = input.spanMs, span < minimumSpanMs(forWindow: input.windowMs) { return .unknown }
        // 4. No recorded burn means the window is intact.
        if input.runwayState == .noBurn { return .ok }
        // 5. Missing upstream runway inputs support no verdict.
        if input.runwayState == .noData || input.runwayState == .noLimit || input.runwayState == .noReset {
            return .unknown
        }
        // 6. A missing or non-finite projection or reset distance would poison
        //    the comparisons below.
        guard let runwayMs = input.runwayMs, let resetInMs = input.resetInMs,
              runwayMs.isFinite, resetInMs.isFinite
        else { return .unknown }
        // 7. Runs dry before the reset.
        if runwayMs < resetInMs { return .short }
        // 8. Tight band: reset <= runway < reset * tightFactor (equality lands here).
        if runwayMs < resetInMs * input.tightFactor { return .tight }
        // 9. Comfortably past the reset, equality included.
        return .ok
    }

    /// Most severe verdict present; `unknown` only when nothing is known.
    public static func worst(_ verdicts: [Verdict]) -> Verdict {
        let known = verdicts.filter { $0 != .unknown }
        guard let worst = known.max(by: { $0.severity < $1.severity }) else { return .unknown }
        return worst
    }
}