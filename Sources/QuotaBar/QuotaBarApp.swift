import AppKit
import QuotaBarKit

/// Entry point for the menu bar agent.
///
/// A plain AppKit launch, not the SwiftUI `App` lifecycle: an app whose only
/// SwiftUI scene is `Settings` never reaches
/// `applicationDidFinishLaunching`, so the delegate that creates the status
/// items never runs and the menu bar silently stays empty. SwiftUI is still
/// used for the panel content, hosted in an `NSPopover`.
@main
enum Main {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = AppDelegate()
        app.delegate = delegate
        // The delegate must outlive this call; NSApplication holds it weakly,
        // so the strong reference lives here for the process lifetime.
        objc_setAssociatedObject(app, &delegateKey, delegate, .OBJC_ASSOCIATION_RETAIN)
        app.run()
    }
}

nonisolated(unsafe) var delegateKey: UInt8 = 0

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel?
    private var host: StatusItemHost?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let model = AppModel()
        self.model = model
        let host = StatusItemHost(model: model)
        self.host = host

        model.start()
        host.reconcile()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}