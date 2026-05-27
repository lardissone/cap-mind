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
    private var notePanelController: NotePanelController!
    private var regionCaptureController: RegionCaptureController!

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
        notePanelController = NotePanelController(client: client, settings: settings, appState: appState)

        regionCaptureController = RegionCaptureController(client: client) { [weak self] result in
            switch result {
            case .success(let ref):
                print("[CapMind] Captured: \(ref.id)")
                self?.appState.status = .ready
            case .failure(let error):
                print("[CapMind] Capture failed: \(error)")
                self?.appState.status = .error(error.localizedDescription)
            }
        }

        // Wiring for later phases:
        statusController.onOpenSettings = { /* Phase 6 */ }
        statusController.onNewNote = { [weak self] in self?.notePanelController.show() }
        statusController.onCaptureRegion = { [weak self] in self?.regionCaptureController.begin() }
        statusController.onCheckForUpdates = { [weak self] in
            self?.updaterController.updater.checkForUpdates()
        }

        KeyboardShortcuts.onKeyDown(for: .openNote) { [weak self] in self?.notePanelController.show() }
        KeyboardShortcuts.onKeyDown(for: .captureRegion) { [weak self] in self?.regionCaptureController.begin() }
    }
}
