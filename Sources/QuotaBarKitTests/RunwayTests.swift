import Foundation
import QuotaBarKit

enum SampleHistoryTests {
    static let cases: [TestCase] = [
        ("increasing and equal usage append without resetting", {
            let base = [Sample(t: 0, usage: 100)]
            Harness.expectEqual(
                SampleHistory.append(base, sample: Sample(t: 1_000, usage: 150), maxSamples: 120).count, 2, "increased"
            )
            Harness.expectEqual(
                SampleHistory.append(base, sample: Sample(t: 1_000, usage: 100), maxSamples: 120).count, 2, "equal"
            )
        }),
        ("a usage decrease restarts history from the new sample alone", {
            let history = [
                Sample(t: 0, usage: 100),
                Sample(t: 1_000, usage: 200),
                Sample(t: 2_000, usage: 300),
            ]
            let next = SampleHistory.append(history, sample: Sample(t: 3_000, usage: 12), maxSamples: 120)
            Harness.expectEqual(next.count, 1, "restarted")
            Harness.expectEqual(next[0], Sample(t: 3_000, usage: 12), "kept the new sample")
        }),
        ("history is trimmed to the cap, dropping the oldest samples", {
            var history: [Sample] = []
            for index in 0..<10 {
                history = SampleHistory.append(history, sample: Sample(t: Double(index) * 1_000, usage: Double(index)), maxSamples: 4)
            }
            Harness.expectEqual(history.count, 4, "capped")
            Harness.expectEqual(history.first?.t, 6_000, "oldest dropped")
            Harness.expectEqual(history.last?.t, 9_000, "newest kept")
        }),
        ("a degenerate cap floors to one so an append never empties history", {
            for cap in [0, -5, 0.4] {
                let history = [Sample(t: 0, usage: 10)]
                let next = SampleHistory.append(history, sample: Sample(t: 1_000, usage: 20), maxSamples: Int(cap))
                Harness.expectEqual(next.count, 1, "cap \(cap)")
            }
        }),
        ("a negative fractional cap floors toward zero rather than trapping", {
            let history = [Sample(t: 0, usage: 10)]
            let next = SampleHistory.append(history, sample: Sample(t: 1_000, usage: 20), maxSamples: Int(-2.7))
            Harness.expectEqual(next.count, 1, "floored cap")
        }),
    ]
}

enum RunwayProjectionTests {
    static let now: EpochMillis = 1_700_000_000_000

    private static func row(
        usage: Double? = 60,
        limit: Double? = 100,
        resetAt: EpochMillis? = now + 600_000
    ) -> QuotaRow {
        QuotaRow(label: "5h", usage: usage, limit: limit, percent: 60, resetAt: resetAt, windowMs: 18_000_000)
    }

    static let cases: [TestCase] = [
        ("no limit reports no-limit and still computes the reset distance", {
            let result = Runway.compute(
                history: [Sample(t: 0, usage: 10)],
                row: row(limit: nil, resetAt: now + 5_000),
                now: now
            )
            Harness.expectEqual(result.state, .noLimit, "state")
            Harness.expectEqual(result.resetInMs, 5_000, "resetInMs")
            Harness.expectEqual(result.spanMs, nil, "spanMs")
        }),
        ("no reset reports no-reset with nothing projected", {
            let result = Runway.compute(history: [Sample(t: 0, usage: 10)], row: row(resetAt: nil), now: now)
            Harness.expectEqual(result.state, .noReset, "state")
            Harness.expectEqual(result.runwayMs, nil, "runwayMs")
        }),
        ("a non-finite resetAt is treated as absent, never as a real timestamp", {
            let result = Runway.compute(history: [Sample(t: 0, usage: 10)], row: row(resetAt: .nan), now: now)
            Harness.expectEqual(result.state, .noReset, "state")
        }),
        ("empty history and a single sample both report no-data", {
            let empty = Runway.compute(history: [], row: row(), now: now)
            Harness.expectEqual(empty.state, .noData, "empty")
            Harness.expectEqual(empty.spanMs, nil, "empty span")

            let single = Runway.compute(history: [Sample(t: 0, usage: 10)], row: row(), now: now)
            Harness.expectEqual(single.state, .noData, "single")
            Harness.expectEqual(single.spanMs, 0, "single span")
        }),
        ("a span under one second reports no-data and reports that span", {
            let history = [Sample(t: now, usage: 10), Sample(t: now + 999, usage: 20)]
            let result = Runway.compute(history: history, row: row(), now: now)
            Harness.expectEqual(result.state, .noData, "state")
            Harness.expectEqual(result.spanMs, 999, "spanMs")
        }),
        ("exactly one second of span is enough to project", {
            let history = [Sample(t: now, usage: 60), Sample(t: now + 1_000, usage: 61)]
            let result = Runway.compute(history: history, row: row(), now: now)
            // burn 1/1000 per ms, 40 remaining -> 40 000 ms, well before reset
            Harness.expectEqual(result.state, .warn, "state")
            Harness.expectEqual(result.runwayMs, 40_000, "runwayMs")
        }),
        ("flat usage over a long span reports no-burn rather than no-data", {
            let history = [Sample(t: now, usage: 60), Sample(t: now + 600_000, usage: 60)]
            Harness.expectEqual(Runway.compute(history: history, row: row(), now: now).state, .noBurn, "flat")
        }),
        ("a crafted decreasing history also reports no-burn, never a negative runway", {
            let history = [Sample(t: now, usage: 80), Sample(t: now + 600_000, usage: 20)]
            let result = Runway.compute(history: history, row: row(), now: now)
            Harness.expectEqual(result.state, .noBurn, "decreasing")
            Harness.expectEqual(result.runwayMs, nil, "runwayMs")
        }),
        ("projection landing before the reset warns, and exactly at the reset does not", {
            // burn 30 per 60 000 ms with 40 remaining -> 80 000 ms of runway
            // against a 600 000 ms reset: short.
            let before = [Sample(t: now, usage: 60), Sample(t: now + 60_000, usage: 90)]
            Harness.expectEqual(Runway.compute(history: before, row: row(), now: now).state, .warn, "short")

            // burn exactly 24/524288 per ms with 24 remaining -> 524 288 ms of
            // runway, and a reset 524 288 ms away: the equality case.
            let exact = Runway.compute(
                history: [Sample(t: 0, usage: 512), Sample(t: 1_024, usage: 512 + 1_024 * 24 / 524_288)],
                row: QuotaRow(label: "5h", usage: 1_000, limit: 1_024, resetAt: 2_048 + 524_288),
                now: 2_048
            )
            Harness.expectEqual(exact.state, .ok, "exactly at the reset is ok")
            Harness.expectEqual(exact.runwayMs, exact.resetInMs, "runway equals reset distance")
        }),
        ("a past resetAt clamps the reset distance to zero", {
            let result = Runway.compute(
                history: [Sample(t: 0, usage: 10), Sample(t: 60_000, usage: 20)],
                row: row(resetAt: now - 10_000),
                now: now
            )
            Harness.expectEqual(result.resetInMs, 0, "clamped resetInMs")
        }),
    ]
}

enum VerdictTests {
    private static let ok: RunwayState = .ok

    private static func input(
        usage: Double? = 60,
        limit: Double? = 100,
        runwayMs: Double? = 600_000,
        state: RunwayState = ok,
        resetInMs: Double? = 300_000,
        spanMs: Double? = 600_000,
        stale: Bool = false,
        tightFactor: Double = 1.5
    ) -> VerdictInput {
        VerdictInput(
            usage: usage,
            limit: limit,
            runwayMs: runwayMs,
            runwayState: state,
            resetInMs: resetInMs,
            spanMs: spanMs,
            stale: stale,
            tightFactor: tightFactor
        )
    }

    static let cases: [TestCase] = [
        ("usage at the limit is blocked regardless of every other signal", {
            Harness.expectEqual(
                VerdictClassifier.classify(input(usage: 100, limit: 100, runwayMs: 10_000_000, resetInMs: 1)),
                .blocked, "exactly at the limit"
            )
            Harness.expectEqual(
                VerdictClassifier.classify(input(usage: 120, limit: 100, runwayMs: 10_000_000, resetInMs: 1, stale: true)),
                .blocked, "over the limit and stale"
            )
        }),
        ("a stale sample supports no verdict even when the numbers read safe", {
            Harness.expectEqual(
                VerdictClassifier.classify(input(runwayMs: 10_000_000, resetInMs: 300_000, stale: true)),
                .unknown, "stale"
            )
        }),
        ("a measurement span under one minute supports no verdict, exactly at 60s does", {
            Harness.expectEqual(
                VerdictClassifier.classify(input(spanMs: 59_999)), .unknown, "just under a minute"
            )
            Harness.expectEqual(
                VerdictClassifier.classify(input(spanMs: 60_000)), .ok, "exactly one minute"
            )
        }),
        ("the evidence threshold scales with the window's own duration", {
            let fiveHours: Double = 5 * 60 * 60 * 1000
            let week: Double = 7 * 24 * 60 * 60 * 1000
            Harness.expectEqual(
                VerdictClassifier.minimumSpanMs(forWindow: fiveHours),
                fiveHours / 20, "five-hour window waits fifteen minutes"
            )
            Harness.expectEqual(
                VerdictClassifier.minimumSpanMs(forWindow: week),
                week / 20, "weekly window waits about eight hours"
            )
            Harness.expectEqual(
                VerdictClassifier.minimumSpanMs(forWindow: nil),
                VerdictClassifier.baseMinimumSpanMs, "unknown duration keeps the floor"
            )
            Harness.expectEqual(
                VerdictClassifier.minimumSpanMs(forWindow: 0),
                VerdictClassifier.baseMinimumSpanMs, "a zero duration cannot raise the floor"
            )
            Harness.expectEqual(
                VerdictClassifier.minimumSpanMs(forWindow: .nan),
                VerdictClassifier.baseMinimumSpanMs, "a non-finite duration cannot raise the floor"
            )
        }),
        ("a window below its threshold is unknown, at the threshold it proceeds", {
            let fiveHours: Double = 5 * 60 * 60 * 1000
            let required = VerdictClassifier.minimumSpanMs(forWindow: fiveHours)
            let base = input(runwayMs: 10, state: .warn, resetInMs: 600_000, spanMs: required - 1)

            func withSpan(_ span: Double) -> VerdictInput {
                VerdictInput(
                    usage: base.usage, limit: base.limit, runwayMs: base.runwayMs,
                    runwayState: base.runwayState, resetInMs: base.resetInMs,
                    spanMs: span, stale: false, tightFactor: base.tightFactor,
                    windowMs: fiveHours
                )
            }
            Harness.expectEqual(VerdictClassifier.classify(withSpan(required - 1)), .unknown, "below")
            Harness.expectEqual(VerdictClassifier.classify(withSpan(required)), .short, "at the threshold")
        }),
        ("the same span is enough for a five-hour window and not for a weekly one", {
            let span: Double = 20 * 60 * 1000
            let fiveHours: Double = 5 * 60 * 60 * 1000
            let week: Double = 7 * 24 * 60 * 60 * 1000
            let base = input(runwayMs: 10, state: .warn, resetInMs: 600_000, spanMs: span)

            func withWindow(_ windowMs: Double) -> VerdictInput {
                VerdictInput(
                    usage: base.usage, limit: base.limit, runwayMs: base.runwayMs,
                    runwayState: base.runwayState, resetInMs: base.resetInMs,
                    spanMs: span, stale: false, tightFactor: base.tightFactor, windowMs: windowMs
                )
            }
            Harness.expectEqual(
                VerdictClassifier.classify(withWindow(fiveHours)), .short, "five-hour window decides"
            )
            Harness.expectEqual(
                VerdictClassifier.classify(withWindow(week)), .unknown, "weekly window waits"
            )
        }),
        ("no recorded burn reads as an intact window", {
            Harness.expectEqual(
                VerdictClassifier.classify(input(runwayMs: nil, state: .noBurn)), .ok, "no-burn"
            )
        }),
        ("incomplete projection inputs support no verdict", {
            for state in [RunwayState.noData, .noLimit, .noReset] {
                Harness.expectEqual(
                    VerdictClassifier.classify(input(runwayMs: nil, state: state)), .unknown, "\(state)"
                )
            }
            Harness.expectEqual(VerdictClassifier.classify(input(runwayMs: nil)), .unknown, "missing runway")
            Harness.expectEqual(VerdictClassifier.classify(input(resetInMs: nil)), .unknown, "missing reset")
            Harness.expectEqual(VerdictClassifier.classify(input(runwayMs: .nan)), .unknown, "NaN runway")
            Harness.expectEqual(
                VerdictClassifier.classify(input(runwayMs: .infinity)), .unknown, "infinite runway"
            )
        }),
        ("a projection landing before the reset is short", {
            Harness.expectEqual(
                VerdictClassifier.classify(input(runwayMs: 299_999, resetInMs: 300_000)), .short, "just short"
            )
        }),
        ("the tight band is reset <= runway < reset * factor, with equality landing inside it", {
            Harness.expectEqual(
                VerdictClassifier.classify(input(runwayMs: 300_000, resetInMs: 300_000)), .tight, "exactly at reset"
            )
            Harness.expectEqual(
                VerdictClassifier.classify(input(runwayMs: 449_999, resetInMs: 300_000)), .tight, "just under the band"
            )
            Harness.expectEqual(
                VerdictClassifier.classify(input(runwayMs: 450_000, resetInMs: 300_000)), .ok, "exactly at the band"
            )
            Harness.expectEqual(
                VerdictClassifier.classify(input(runwayMs: 300_001, resetInMs: 200_000, tightFactor: 1.5)), .ok,
                "factor is honoured when configured"
            )
        }),
        ("aggregation picks the most severe verdict and ignores unknown", {
            Harness.expectEqual(VerdictClassifier.worst([.ok, .tight, .unknown]), .tight, "tight wins")
            Harness.expectEqual(VerdictClassifier.worst([.ok, .unknown]), .ok, "ok survives unknown")
            Harness.expectEqual(VerdictClassifier.worst([.short, .blocked]), .blocked, "blocked wins")
            Harness.expectEqual(VerdictClassifier.worst([.unknown, .unknown]), .unknown, "all unknown")
            Harness.expectEqual(VerdictClassifier.worst([]), .unknown, "empty")
        }),
        ("glyphs and severities match the documented vocabulary", {
            Harness.expectEqual(Verdict.ok.glyph, "✓", "ok")
            Harness.expectEqual(Verdict.tight.glyph, "!", "tight")
            Harness.expectEqual(Verdict.short.glyph, "!!", "short")
            Harness.expectEqual(Verdict.blocked.glyph, "✗", "blocked")
            Harness.expectEqual(Verdict.unknown.glyph, "?", "unknown")
            Harness.expect(Verdict.ok < Verdict.blocked, "ok is less severe than blocked")
        }),
    ]
}