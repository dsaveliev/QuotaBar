import Foundation
import QuotaBarKit

// MARK: - Row ordering

enum RowOrderTests {
    static let cases: [TestCase] = [
        ("5h is hoisted first, 7d second, rest keep parsed order", {
            let rows = [
                QuotaRow(label: "7d", percent: 41),
                QuotaRow(label: "promo", percent: 5),
                QuotaRow(label: "5h", percent: 62),
            ]
            Harness.expectEqual(RowOrder.sort(rows).map(\.label), ["5h", "7d", "promo"], "order")
        }),
        ("duplicate labels are dropped keeping the first occurrence", {
            let first = QuotaRow(label: "5h", percent: 62)
            let second = QuotaRow(label: "5h", percent: 99)
            let sorted = RowOrder.sort([first, second, QuotaRow(label: "7d")])
            Harness.expectEqual(sorted.count, 2, "row count")
            Harness.expectEqual(sorted[0].percent, 62, "kept first occurrence")
        }),
        ("rows without a known label keep their relative order", {
            let rows = [QuotaRow(label: "a"), QuotaRow(label: "b"), QuotaRow(label: "c")]
            Harness.expectEqual(RowOrder.sort(rows).map(\.label), ["a", "b", "c"], "order")
        }),
        ("a lone 5h row is not reordered", {
            Harness.expectEqual(RowOrder.sort([QuotaRow(label: "5h")]).map(\.label), ["5h"], "order")
        }),
    ]
}

// MARK: - Duration formatting

enum DurationFormatTests {
    static let cases: [TestCase] = [
        ("non-positive and non-finite durations render as 0m", {
            Harness.expectEqual(DurationFormat.duration(0), "0m", "zero")
            Harness.expectEqual(DurationFormat.duration(-5_000), "0m", "negative")
            Harness.expectEqual(DurationFormat.duration(.nan), "0m", "nan")
            Harness.expectEqual(DurationFormat.duration(.infinity), "0m", "infinity")
        }),
        ("under a minute renders whole seconds", {
            Harness.expectEqual(DurationFormat.duration(999), "0s", "sub-second")
            Harness.expectEqual(DurationFormat.duration(1_000), "1s", "one second")
            Harness.expectEqual(DurationFormat.duration(59_999), "59s", "just under a minute")
        }),
        ("under an hour renders whole minutes", {
            Harness.expectEqual(DurationFormat.duration(60_000), "1m", "one minute")
            Harness.expectEqual(DurationFormat.duration(3_599_999), "59m", "just under an hour")
        }),
        ("under two days renders hours with an optional minutes tail", {
            Harness.expectEqual(DurationFormat.duration(3_600_000), "1h", "exactly one hour")
            Harness.expectEqual(DurationFormat.duration(3_600_000 + 60_000), "1h 1m", "hours and minutes")
            Harness.expectEqual(DurationFormat.duration(2 * 3_600_000 + 59 * 60_000), "2h 59m", "near the boundary")
        }),
        ("two days and beyond renders days with an optional hours tail", {
            Harness.expectEqual(DurationFormat.duration(172_800_000), "2d", "exactly two days")
            Harness.expectEqual(DurationFormat.duration(2 * 86_400_000 + 3 * 3_600_000), "2d 3h", "days and hours")
            Harness.expectEqual(DurationFormat.duration(10 * 86_400_000), "10d", "whole days")
        }),
        ("approximate runway collapses beyond 48h to whole days", {
            Harness.expectEqual(DurationFormat.approximate(7_500_000), "~2h 5m", "under 48h")
            Harness.expectEqual(DurationFormat.approximate(48 * 3_600_000 - 1), "~47h 59m", "just under 48h")
            Harness.expectEqual(DurationFormat.approximate(48 * 3_600_000), "~2d", "exactly 48h")
            Harness.expectEqual(DurationFormat.approximate(60 * 3_600_000), "~3d", "60h rounds to 3d")
            Harness.expectEqual(DurationFormat.approximate(70 * 3_600_000), "~3d", "70h rounds to 3d")
            Harness.expectEqual(DurationFormat.approximate(-1), "~0m", "negative")
        }),
        ("data age steps through every tier", {
            let now: EpochMillis = 1_000_000_000
            Harness.expectEqual(DurationFormat.age(now, now: now), "just now", "fresh")
            Harness.expectEqual(DurationFormat.age(now - 9_999, now: now), "just now", "just under 10s")
            Harness.expectEqual(DurationFormat.age(now - 10_000, now: now), "10s ago", "10s")
            Harness.expectEqual(DurationFormat.age(now - 59_999, now: now), "59s ago", "just under a minute")
            Harness.expectEqual(DurationFormat.age(now - 60_000, now: now), "1m ago", "one minute")
            Harness.expectEqual(DurationFormat.age(now - 3_599_999, now: now), "59m ago", "just under an hour")
            Harness.expectEqual(DurationFormat.age(now - 3_600_000, now: now), "1h ago", "one hour")
            Harness.expectEqual(DurationFormat.age(now - 98.5 * 3_600_000, now: now), "98h ago", "just under 99h")
            Harness.expectEqual(DurationFormat.age(now - 100 * 3_600_000, now: now), "4d ago", "past 99h")
        }),
    ]
}

// MARK: - Percent formatting

enum PercentFormatTests {
    static let cases: [TestCase] = [
        ("a missing percent renders as ?", {
            Harness.expectEqual(PercentFormat.text(nil), "?", "nil")
            Harness.expectEqual(PercentFormat.text(.nan), "?", "nan")
        }),
        ("negative and zero percent clamp to 0%", {
            Harness.expectEqual(PercentFormat.text(-5.4), "0%", "negative")
            Harness.expectEqual(PercentFormat.text(0), "0%", "zero")
        }),
        ("percent rounds to a whole number", {
            Harness.expectEqual(PercentFormat.text(62.4), "62%", "rounds down")
            Harness.expectEqual(PercentFormat.text(62.6), "63%", "rounds up")
            Harness.expectEqual(PercentFormat.text(100), "100%", "full")
        }),
        ("display clamps at 999% so the text never exceeds four characters", {
            Harness.expectEqual(PercentFormat.text(999), "999%", "at the cap")
            Harness.expectEqual(PercentFormat.text(1_500), "999%", "above the cap")
            Harness.expect(PercentFormat.text(1_500).count <= 4, "display text must stay 4 characters wide")

            // The menu bar pads; the panel does not.
            for value in [Double?(nil), -5.4, 0, 0.4, 62.6, 100, 999, 1_500] {
                Harness.expectEqual(
                    PercentFormat.fixedWidth(value).count, 4,
                    "menu bar field is always \(value) in four characters"
                )
            }
            Harness.expectEqual(PercentFormat.fixedWidth(62), " 62%", "right-aligned")
            Harness.expectEqual(PercentFormat.fixedWidth(100), "100%", "the widest value needs no padding")
            Harness.expectEqual(PercentFormat.text(62), "62%", "the panel's text is untouched")
        }),
    ]
}