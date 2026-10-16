import Foundation

public enum DurationFormat {
    private static let second: Double = 1_000
    private static let minute: Double = 60 * second
    private static let hour: Double = 60 * minute
    private static let day: Double = 24 * hour

    /// Human-readable duration: seconds, minutes, hours (+minutes), days (+hours).
    public static func duration(_ ms: Double) -> String {
        guard ms.isFinite, ms > 0 else { return "0m" }
        if ms < minute { return "\(Int((ms / second).rounded(.down)))s" }
        if ms < hour { return "\(Int((ms / minute).rounded(.down)))m" }
        if ms < 2 * day {
            let h = Int((ms / hour).rounded(.down))
            let m = Int(((ms.truncatingRemainder(dividingBy: hour)) / minute).rounded(.down))
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        let d = Int((ms / day).rounded(.down))
        let h = Int(((ms.truncatingRemainder(dividingBy: day)) / hour).rounded(.down))
        return h > 0 ? "\(d)d \(h)h" : "\(d)d"
    }

    /// Approximate runway: "~" + exact duration below 48h, otherwise a single
    /// whole-day figure rounded half-up with no tail.
    public static func approximate(_ ms: Double) -> String {
        guard ms.isFinite, ms > 0 else { return "~0m" }
        let totalHours = ms / hour
        if totalHours < 48 { return "~" + duration(ms) }
        return "~\(Int((totalHours / 24).rounded()))d"
    }

    /// Data age in the panel header: "just now" / "42s ago" / "12m ago" /
    /// "5h ago" / "3d ago".
    public static func age(_ ms: Double, now: EpochMillis) -> String {
        let elapsed = max(0, now - ms)
        if elapsed < 10 * second { return "just now" }
        if elapsed < minute { return "\(Int((elapsed / second).rounded(.down)))s ago" }
        if elapsed < hour { return "\(Int((elapsed / minute).rounded(.down)))m ago" }
        if elapsed < 99 * hour { return "\(Int((elapsed / hour).rounded(.down)))h ago" }
        return "\(Int((elapsed / day).rounded(.down)))d ago"
    }
}

public enum PercentFormat {
    /// The width `100%` needs, and the cap above makes it the widest a percent
    /// can ever be.
    public static let menuBarWidth = 4

    /// Percent text for display: nil -> "?", negative clamps to 0%, values over
    /// 999 clamp to "999%" so the longest text stays four characters wide.
    /// The underlying value used for bars and projections stays raw.
    public static func text(_ percent: Double?) -> String {
        guard let percent, percent.isFinite else { return "?" }
        if percent <= 0 { return "0%" }
        if percent >= 999 { return "999%" }
        let rounded = Int(percent.rounded())
        return "\(rounded)%"
    }

    /// The same text, right-aligned in the width its widest value needs, so a
    /// menu bar item does not resize every time a figure gains a digit.
    ///
    /// Separate from `text` because the panel shows these figures flush left and
    /// padding them there would indent everything.
    public static func fixedWidth(_ percent: Double?) -> String {
        let rendered = text(percent)
        guard rendered.count < menuBarWidth else { return rendered }
        return String(repeating: " ", count: menuBarWidth - rendered.count) + rendered
    }
}