import Foundation

/// What the menu bar should currently be showing.
///
/// Pure, so the reconciliation the AppKit layer performs is testable without a
/// window server: this function decides *what* should exist, and the delegate
/// only applies the difference.
public enum MenuBarItems {
    /// One menu bar slot. A subscription slot carries the subscription's id;
    /// the recovery slot carries nil.
    public enum Slot: Hashable {
        case subscription(String)
        case recovery

        public var subscriptionId: String? {
            if case .subscription(let id) = self { return id }
            return nil
        }
    }

    /// The one slot the menu bar should contain.
    ///
    /// There is exactly one item: several items would be several entrances to
    /// one panel, and it would never be clear which item opens which provider.
    /// The slot follows the selection; when the selected provider has been
    /// taken out, the first available one stands in, so the menu bar is never
    /// empty while anything is available.
    public static func desired(
        providers: [any QuotaProvider],
        settings: Settings
    ) -> [Slot] {
        let available = providers.sorted { $0.tag < $1.tag }
        guard !available.isEmpty else { return [.recovery] }

        switch settings.selection {
        case .none:
            return [.recovery]
        case .provider(let id) where available.contains(where: { $0.id == id }):
            return [.subscription(id)]
        // `.automatic`, and a recorded selection naming a provider this build no
        // longer offers: the bar must not go empty while anything is available.
        case .automatic, .provider:
            return [.subscription(available[0].id)]
        }
    }

    /// System symbol that encodes a verdict, as a template image so macOS
    /// recolours it for the menu bar's theme.
    public static func symbolName(for verdict: Verdict) -> String {
        switch verdict {
        case .ok: "gauge.with.dots.needle.bottom.50percent"
        case .tight: "exclamationmark.triangle"
        case .short: "exclamationmark.triangle.fill"
        case .blocked: "xmark.octagon.fill"
        case .unknown: "questionmark.circle"
        }
    }

    public static let recoverySymbolName = "checklist"

    /// Menu bar label text for a slot.
    ///
    /// A recovery slot reads `QuotaBar` — it carries no data, and a percent next
    /// to it would imply a number the app does not have.
    public static func label(for slot: Slot, snapshot: SubscriptionSnapshot?) -> String {
        switch slot {
        case .recovery:
            return "QuotaBar"
        case .subscription(let id):
            guard let snapshot, snapshot.id == id else { return id }
            return snapshot.menuBarLabel()
        }
    }

    /// Plain-text explanation of what the label means, shown as the item's
    /// tooltip. The label has to stay narrow, so this is where the unabbreviated
    /// reading lives: every window's own percent, and the verdict in words.
    public static func explanation(for slot: Slot, snapshot: SubscriptionSnapshot?) -> String {
        switch slot {
        case .recovery:
            return "QuotaBar — no providers shown. Open to choose which to display."
        case .subscription(let id):
            guard let snapshot, snapshot.id == id else { return id }
            let windows = snapshot.windows
                .map { window in
                    let state = window.isMeasuring
                        ? " (measuring)"
                        : (window.verdict == .unknown ? "" : " \(window.verdict.glyph)")
                    return "\(window.label) \(PercentFormat.text(window.percent))\(state)"
                }
                .joined(separator: ", ")
            let age = snapshot.updatedAt
                .map { " · updated \(DurationFormat.age($0, now: Clock.now()))" } ?? ""
            return "\(snapshot.displayName) — \(windows) · \(snapshot.verdict.glyph) \(meaning(of: snapshot.verdict))\(age)"
        }
    }

    private static func meaning(of verdict: Verdict) -> String {
        switch verdict {
        case .ok: "on pace"
        case .tight: "close to the reset"
        case .short: "will run out before the reset"
        case .blocked: "limit reached"
        case .unknown: "not enough data yet"
        }
    }
}