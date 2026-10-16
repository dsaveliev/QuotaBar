import QuotaBarKit
import SwiftUI

/// One quota window as a single compact block: identity and severity on the
/// first line, a full-width bar underneath, then reset and runway.
///
/// The bar spans the panel rather than sitting in a column, so the consumed
/// fraction is comparable across windows at a glance — which is the whole point
/// of looking at this panel.
struct WindowRowView: View {
    let window: WindowSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(window.label)
                    .font(.system(size: 12, weight: .semibold))
                Spacer(minLength: 4)
                Text(PercentFormat.text(window.percent))
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(.secondary)
                Text(window.verdict.glyph)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(VerdictStyle.color(for: window.verdict))
            }

            UsageBar(window: window)

            HStack(spacing: 6) {
                Text(resetText)
                Spacer(minLength: 4)
                Text(runwayText)
            }
            .font(.system(size: 11).monospacedDigit())
            .foregroundStyle(.secondary)

            // The model says which line this row has, if any. It used to be
            // chosen here, and choosing wrongly drew a shortfall under a row
            // that had just declined to stand behind its own projection.
            if let annotation = window.annotation {
                Text(annotation)
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var resetText: String {
        guard let reset = window.resetInMs else { return "no reset time" }
        return "resets in \(DurationFormat.duration(reset))"
    }

    /// Always the same shape, whatever the verdict. The projection does not
    /// change its appearance when severity changes — only an extra line appears.
    private var runwayText: String {
        if window.isMeasuring { return "runway measuring…" }
        if window.verdict == .blocked {
            guard let reset = window.resetInMs else { return "limit reached" }
            return "limit reached · \(DurationFormat.duration(reset)) left"
        }
        let runway = window.runway
        switch runway.state {
        case .ok, .warn:
            guard let ms = runway.runwayMs else { return "runway …" }
            return "runway \(DurationFormat.approximate(ms))"
        case .noBurn:
            return "runway ∞"
        case .noData:
            return "runway …"
        case .noLimit:
            return "runway — no limit"
        case .noReset:
            return "runway — no reset"
        }
    }

}

/// Proportional usage bar with a pace marker. The marker is *now*: fill to its
/// left is quota consumed so far, the gap to the right edge is how much of the
/// window's time is left. Reading fill against marker is the "am I ahead or
/// behind pace" check the panel exists for.
private struct UsageBar: View {
    let window: WindowSnapshot

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let fraction = min(1, max(0, (window.percent ?? 0) / 100))
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.18))
                Capsule()
                    .fill(VerdictStyle.color(for: window.verdict).opacity(0.85))
                    .frame(width: max(0, width * fraction))
                if let elapsed = window.elapsedFraction() {
                    Rectangle()
                        .fill(Color.primary.opacity(0.6))
                        .frame(width: 1.5)
                        .offset(x: max(0, min(width - 1.5, width * elapsed)))
                }
            }
        }
        .frame(height: 7)
    }
}