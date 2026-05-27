import SwiftUI
import KeyboardShortcuts
import Sparkle

@main
struct CapMindApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene { Settings { EmptyView() } }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = AppSettings()
    let appState = AppState()
    private var statusController: StatusItemController!
    private(set) var client: MyMindClient!
    private var updaterController: SPUStandardUpdaterController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        client = MyMindClient(credentialsProvider: settings)
        appState.isConfigured = settings.isConfigured

        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        statusController = StatusItemController(settings: settings)

        // Wiring for later phases:
        statusController.onOpenSettings = { /* Phase 6 */ }
        statusController.onNewNote = { /* Phase 3 */ }
        statusController.onCaptureRegion = { /* Phase 4 */ }
        statusController.onCheckForUpdates = { [weak self] in
            self?.updaterController.updater.checkForUpdates()
        }

        KeyboardShortcuts.onKeyDown(for: .openNote) { /* Phase 3 */ }
        KeyboardShortcuts.onKeyDown(for: .captureRegion) { /* Phase 4 */ }
    }
}
