import Foundation

/// Absolute time, in milliseconds since the Unix epoch. Both providers report
/// every timestamp in this unit (Z.ai `nextResetTime`, MiniMax `end_time` /
/// `weekly_end_time`), and `Date.timeIntervalSince1970 * 1000` is the clock
/// value compared against them.
public typealias EpochMillis = Double

/// One quota window of a subscription, normalised across providers.
///
/// `windowMs` is absent when the provider cannot supply a window duration; such
/// a row is displayed without a pace marker.
public struct QuotaRow: Equatable, Sendable {
    public var label: String
    /// Consumed amount in the provider's own unit — for MiniMax's percent-space
    /// rows this is percent points consumed.
    public var usage: Double?
    public var limit: Double?
    /// Consumed percent, already clamped to 0...100 by the parsers.
    public var percent: Double?
    public var resetAt: EpochMillis?
    public var windowMs: Double?

    public init(
        label: String,
        usage: Double? = nil,
        limit: Double? = nil,
        percent: Double? = nil,
        resetAt: EpochMillis? = nil,
        windowMs: Double? = nil
    ) {
        self.label = label
        self.usage = usage
        self.limit = limit
        self.percent = percent
        self.resetAt = resetAt
        self.windowMs = windowMs
    }
}

/// Row ordering: the five-hour row first, the weekly row second, everything else
/// in parsed order, duplicate labels dropped keeping the first occurrence.
public enum RowOrder {
    public static func sort(_ rows: [QuotaRow]) -> [QuotaRow] {
        var seen = Set<String>()
        var ordered: [QuotaRow] = []
        ordered.reserveCapacity(rows.count)

        func appendIfNew(_ row: QuotaRow) {
            if seen.insert(row.label).inserted { ordered.append(row) }
        }

        rows.first { $0.label == "5h" }.map(appendIfNew)
        rows.first { $0.label == "7d" }.map(appendIfNew)
        for row in rows { appendIfNew(row) }
        return ordered
    }
}