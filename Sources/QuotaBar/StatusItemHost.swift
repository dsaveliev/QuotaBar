import AppKit
import Combine
import QuotaBarKit
import SwiftUI

/// Owns the menu bar items and their popovers.
///
/// The menu bar is reconciled from the desired slot list rather than declared as
/// scenes: item count is user-controlled, and a variable number of
/// `MenuBarExtra(isInserted:)` slots has been observed to drop an item silently.
/// Here a missing item is a visible bug in `reconcile`, not a scene-graph quirk.
@MainActor
final class StatusItemHost {
    private let model: AppModel
    private var items: [MenuBarItems.Slot: NSStatusItem] = [:]
    private var popovers: [ObjectIdentifier: NSPopover] = [:]
    private var slotsByButton: [ObjectIdentifier: MenuBarItems.Slot] = [:]
    private var cancellables = Set<AnyCancellable>()
    private var lastLoggedState: String?

    /// Panel width; fixed so rows align across items and long text wraps
    /// predictably rather than reflowing the whole panel.
    static let panelWidth: CGFloat = 320

    init(model: AppModel) {
        self.model = model
        model.$snapshots
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.reconcile() }
            .store(in: &cancellables)
        model.$settings
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.reconcile() }
            .store(in: &cancellables)
    }

    // MARK: - Reconciliation

    func reconcile() {
        let desired = MenuBarItems.desired(providers: ProviderRegistry.all, settings: model.settings)

        for slot in items.keys where !desired.contains(slot) {
            removeItem(for: slot)
        }
        for slot in desired where items[slot] == nil {
            addItem(for: slot)
        }
        for slot in desired {
            updateLabel(for: slot)
        }
        logStateIfChanged()
    }

    /// Logs what the menu bar now contains, whenever that changes.
    ///
    /// "My provider is missing from the menu bar" is otherwise undiagnosable
    /// from the outside: an item that fails to appear produces no error, no UI,
    /// and no log line. One line here names every slot and its current label.
    private func logStateIfChanged() {
        let summary = items.keys
            .map { slot -> String in
                guard let button = items[slot]?.button else { return "? [\(slot)]" }
                // Frame width is logged because an item that AppKit failed to lay
                // out is invisible while still "existing" — the exact failure
                // this whole surface was rebuilt to make impossible to miss.
                let width = Int(button.frame.width)
                return "\(button.title) w=\(width) [\(slot)]"
            }
            .sorted()
            .joined(separator: " | ")
        guard summary != lastLoggedState else { return }
        lastLoggedState = summary
        Log.write("menu bar: \(summary.isEmpty ? "(none)" : summary)")
    }

    private func addItem(for slot: MenuBarItems.Slot) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = item.button else { return }
        button.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        button.target = self
        button.action = #selector(togglePopover(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = false
        popover.contentViewController = NSHostingController(rootView: panel(for: slot))
        popover.contentSize = NSSize(width: Self.panelWidth, height: 0)

        let key = ObjectIdentifier(button)
        popovers[key] = popover
        slotsByButton[key] = slot
        items[slot] = item
        updateLabel(for: slot)
    }

    private func removeItem(for slot: MenuBarItems.Slot) {
        guard let item = items.removeValue(forKey: slot), let button = item.button else { return }
        let key = ObjectIdentifier(button)
        popovers[key]?.close()
        popovers[key] = nil
        slotsByButton[key] = nil
        NSStatusBar.system.removeStatusItem(item)
    }

    private func updateLabel(for slot: MenuBarItems.Slot) {
        guard let button = items[slot]?.button else { return }
        let snapshot = slot.subscriptionId.flatMap { model.snapshot(id: $0) }
        button.title = MenuBarItems.label(for: slot, snapshot: snapshot)
        button.toolTip = MenuBarItems.explanation(for: slot, snapshot: snapshot)

        // A template image is the right mechanism here: macOS recolours it for
        // light and dark menu bars, which a hand-supplied icon cannot.
        let symbol = symbolName(for: slot, snapshot: snapshot)
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: symbolDescription(for: slot, snapshot: snapshot))
        image?.isTemplate = true
        button.image = image
        button.imagePosition = .imageLeading
        button.imageHugsTitle = true
    }

    private func symbolName(for slot: MenuBarItems.Slot, snapshot: SubscriptionSnapshot?) -> String {
        switch slot {
        case .recovery: return MenuBarItems.recoverySymbolName
        case .subscription(let id):
            guard let snapshot, snapshot.id == id else { return "questionmark.circle" }
            return MenuBarItems.symbolName(for: snapshot.verdict)
        }
    }

    private func symbolDescription(for slot: MenuBarItems.Slot, snapshot: SubscriptionSnapshot?) -> String {
        MenuBarItems.explanation(for: slot, snapshot: snapshot)
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        let key = ObjectIdentifier(sender)
        guard let popover = popovers[key] else { return }

        if popover.isShown {
            popover.performClose(sender)
            return
        }
        // Refresh on open when what is on screen is older than the cadence.
        if let id = slotsByButton[key]?.subscriptionId {
            model.refreshIfStale(id: id)
        }
        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: NSRectEdge.minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    // MARK: - Panels

    @ViewBuilder
    private func panel(for slot: MenuBarItems.Slot) -> some View {
        switch slot {
        case .recovery:
            RecoveryPanelView(model: model)
        case .subscription(let id):
            // The view resolves the snapshot from the model on every render.
            // Capturing it here would freeze the panel on whatever it showed at
            // creation time — the panel then reads "loading" forever while the
            // rest of the app has live data.
            SubscriptionMenuView(model: model, subscriptionId: id)
        }
    }
}

/// Shown when no subscription is selected: the picker, and nothing else. This
/// is what makes hiding every provider reversible without reinstalling.
struct RecoveryPanelView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("No providers shown")
                .font(.system(size: 13, weight: .semibold))
            Text("Tick a provider to put its limits back in the menu bar. Both keep polling either way.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Divider()
            ProviderPicker(model: model)
            Divider()
            Button("Quit QuotaBar") { model.quit() }
                .buttonStyle(.borderless)
                .font(.system(size: 11))
        }
        .padding(12)
        .frame(width: StatusItemHost.panelWidth, alignment: .leading)
    }
}