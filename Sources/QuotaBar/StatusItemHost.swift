import AppKit
import Combine
import QuotaBarKit
import SwiftUI

/// Owns the menu bar item and its popover.
///
/// The menu bar is reconciled from the desired slot list rather than declared as
/// scenes: a variable number of `MenuBarExtra(isInserted:)` slots has been
/// observed to drop an item silently, so a missing item here is a visible bug in
/// `reconcile` rather than a scene-graph quirk.
///
/// There is exactly one item, created once. Which provider it shows is
/// *content*, not identity: the slot changes when the selection changes, and
/// changing it updates the item in place. Keying the item by slot - which is
/// what this did before - turned every provider switch into a remove and an add,
/// so the popover closed under the user mid-read.
@MainActor
final class StatusItemHost {
    private let model: AppModel
    private var item: NSStatusItem?
    private var popover: NSPopover?
    /// What the item is currently displaying. `nil` until the item is created.
    private var currentSlot: MenuBarItems.Slot?
    private var cancellables = Set<AnyCancellable>()
    private var lastLoggedState: String?

    /// Panel width; fixed so rows align and long text wraps predictably rather
    /// than reflowing the whole panel. The panel is laid out against this, so
    /// every row can assume the same content width.
    static let panelWidth: CGFloat = 280

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
        // `desired` yields exactly one slot; the fallback only exists so this
        // cannot silently produce a menu bar with nothing in it.
        let slot = MenuBarItems
            .desired(providers: ProviderRegistry.all, settings: model.settings)
            .first ?? .recovery

        if item == nil { createItem() }

        if currentSlot != slot { currentSlot = slot }

        // Unconditional, and deliberately so. Reconcile runs on every refresh
        // and on every settings change, not only when the selection moves, so
        // this is where the label picks up new figures. Guarding it on a slot
        // change — which is what this did at first — means a refresh never
        // repaints the item and the menu bar silently freezes on whatever it
        // showed when the slot last moved.
        updateContents()
        logStateIfChanged()
    }

    /// Logs what the menu bar now contains, whenever that changes.
    ///
    /// "My provider is missing from the menu bar" is otherwise undiagnosable
    /// from the outside: an item that fails to appear produces no error, no UI,
    /// and no log line. One line here names the item and its current label.
    private func logStateIfChanged() {
        guard let slot = currentSlot, let button = item?.button else { return }
        // Frame width is logged because an item that AppKit failed to lay out is
        // invisible while still "existing" - the exact failure this whole
        // surface was rebuilt to make impossible to miss.
        let summary = "\(button.title) w=\(Int(button.frame.width)) [\(slot)]"
        guard summary != lastLoggedState else { return }
        lastLoggedState = summary
        Log.write("menu bar: \(summary)")
    }

    private func createItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        button.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        button.target = self
        button.action = #selector(togglePopover(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = false
        // One hosting controller for the life of the app. The root view reads
        // the selection from the model on every render, so a provider switch
        // repaints the panel that is already open instead of needing a new one.
        popover.contentViewController = NSHostingController(rootView: PanelRootView(model: model))
        popover.contentSize = NSSize(width: Self.panelWidth, height: 0)

        self.popover = popover
        item = statusItem
    }

    private func updateContents() {
        guard let button = item?.button, let slot = currentSlot else { return }
        let snapshot = slot.subscriptionId.flatMap { model.snapshot(id: $0) }
        button.title = MenuBarItems.label(for: slot, snapshot: snapshot)
        button.toolTip = MenuBarItems.explanation(for: slot, snapshot: snapshot)

        // The verdict is already the trailing glyph of the title. A symbol here
        // stated it twice, in front of and behind the same text. The recovery
        // slot keeps one because its label, `QuotaBar`, carries no glyph.
        guard case .recovery = slot else {
            button.image = nil
            return
        }
        let symbol = MenuBarItems.recoverySymbolName
        let image = NSImage(
            systemSymbolName: symbol,
            accessibilityDescription: MenuBarItems.explanation(for: slot, snapshot: snapshot)
        )
        image?.isTemplate = true
        button.image = image
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        guard let popover else { return }

        if popover.isShown {
            popover.performClose(sender)
            return
        }
        // Refresh on open when what is on screen is older than the cadence.
        if let id = currentSlot?.subscriptionId {
            model.refreshIfStale(id: id)
        }
        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: NSRectEdge.minY)
        popover.contentViewController?.view.window?.makeKey()
    }
}

/// The panel's root view: subscription content while one is selected, the
/// picker when none is.
///
/// Choosing between the two from the model's selection, rather than at popover
/// construction, is what lets `Show none` and switching back happen without
/// rebuilding anything the user is looking at.
struct PanelRootView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        if model.shown == nil {
            RecoveryPanelView(model: model)
        } else {
            SubscriptionMenuView(model: model)
        }
    }
}

/// Shown when no subscription is selected: the picker, and a way back. This is
/// what makes showing nothing reversible without reinstalling.
struct RecoveryPanelView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("No providers shown")
                    .font(.system(size: 13, weight: .semibold))
                // "Pick", not "tick": the picker is single-selection, and there
                // is no checkbox anywhere in this app.
                Text("Choose a provider to put its limits back in the menu bar. Both keep polling either way.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            HStack(alignment: .top, spacing: ControlGrid.columnSpacing) {
                Button("Quit QuotaBar") { model.quit() }
                    .buttonStyle(.borderless)
                    .font(.system(size: 11))
                Spacer(minLength: 0)
                ProviderPicker(model: model)
                    .frame(width: ControlGrid.columnWidth, alignment: .leading)
            }
        }
        .padding(12)
        .frame(width: StatusItemHost.panelWidth, alignment: .leading)
    }
}