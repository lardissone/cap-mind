import SwiftUI
import KeyboardShortcuts

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
    private var notePanelController: NotePanelController!
    private var regionCaptureController: RegionCaptureController!
    private var dropController: DropController!
    private var settingsWindowController: SettingsWindowController!
    private var toastController: ToastController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        client = MyMindClient(credentialsProvider: settings)
        appState.isConfigured = settings.isConfigured

        statusController = StatusItemController(settings: settings)

        toastController = ToastController()

        settingsWindowController = SettingsWindowController(
            settings: settings,
            appState: appState,
            client: client,
            onConfigured: { [weak self] in self?.statusController.resetIcon() }
        )

        notePanelController = NotePanelController(client: client, settings: settings, appState: appState)

        regionCaptureController = RegionCaptureController(client: client) { [weak self] result in
            guard let self else { return }
            // Fix B: clear the sending icon on both success and failure.
            self.statusController.operationFinished()
            switch result {
            case .success:
                self.toastController.show("Uploaded \u{2713}", style: .success, autoDismissAfter: 1.5)
                self.appState.status = .ready
                // Fix C: reflect success in the menu status line.
                self.reflect("Ready")
            case .failure(let error):
                let msg: String
                if let mmError = error as? MyMindError {
                    msg = mmError.userMessage
                    // Fix A: mid-session auth failure → surface unconfigured state + red icon.
                    if case .unauthorized = mmError {
                        self.appState.isConfigured = self.settings.isConfigured
                        self.statusController.resetIcon()
                    }
                } else {
                    msg = error.localizedDescription
                }
                self.toastController.show(msg, style: .error, autoDismissAfter: nil)
                self.appState.status = .error(msg)
                // Fix C: reflect error in the menu status line.
                self.reflect("Last error: \(msg)")
            }
        }

        // Fix B: show sending icon when the PNG upload actually begins (after interactive selection).
        regionCaptureController.onUploadingStarted = { [weak self] in
            guard let self else { return }
            self.statusController.operationStarted()
            // Fix C: reflect upload start in the menu status line.
            self.reflect("Sending\u{2026}")
        }

        dropController = DropController(client: client)

        dropController.onProgress = { [weak self] completed, total in
            guard let self else { return }
            let progressText = "Uploading \(completed)/\(total)\u{2026}"
            if completed == 1 && total >= 1 {
                // Show the initial progress toast at the start of the first item.
                self.toastController.show(progressText, style: .progress, autoDismissAfter: nil)
            } else {
                self.toastController.update(progressText)
            }
            // Fix C: reflect upload progress in the menu status line.
            self.reflect("Sending\u{2026}")
        }

        dropController.onFinished = { [weak self] succeeded, failed in
            guard let self else { return }
            if failed.isEmpty {
                let msg = succeeded == 1 ? "Uploaded \u{2713}" : "\(succeeded) uploaded \u{2713}"
                self.toastController.show(msg, style: .success, autoDismissAfter: 1.5)
                // Fix C: reflect success in the menu status line.
                self.reflect("Ready")
            } else {
                let msg = "\(succeeded) uploaded, \(failed.count) failed"
                self.toastController.show(msg, style: .error, autoDismissAfter: nil)
                // Fix C: reflect partial failure in the menu status line.
                self.reflect("Last error: \(failed.count) item(s) failed")
            }
            self.statusController.dropFinished()
        }

        // Fix A: mid-session auth failure during a drop → surface unconfigured state + red icon.
        dropController.onAuthFailure = { [weak self] in
            guard let self else { return }
            self.appState.isConfigured = self.settings.isConfigured
            self.statusController.resetIcon()
        }

        statusController.onDrop = { [weak self] pasteboard in
            guard let self else { return }
            guard self.settings.isConfigured else {
                self.toastController.show("Set up your MyMind access key in Settings", style: .error, autoDismissAfter: nil)
                self.settingsWindowController.show()
                return
            }
            self.dropController.handle(pasteboard)
        }

        statusController.onOpenSettings = { [weak self] in
            self?.settingsWindowController.show()
        }

        statusController.onNewNote = { [weak self] in
            guard let self else { return }
            guard self.settings.isConfigured else {
                self.toastController.show("Set up your MyMind access key in Settings", style: .error, autoDismissAfter: nil)
                self.settingsWindowController.show()
                return
            }
            self.notePanelController.show()
        }

        statusController.onCaptureRegion = { [weak self] in
            guard let self else { return }
            guard self.settings.isConfigured else {
                self.toastController.show("Set up your MyMind access key in Settings", style: .error, autoDismissAfter: nil)
                self.settingsWindowController.show()
                return
            }
            self.regionCaptureController.begin()
        }

        statusController.onCheckForUpdates = {
            Updater.checkForUpdates()
        }

        KeyboardShortcuts.onKeyDown(for: .openNote) { [weak self] in
            guard let self else { return }
            guard self.settings.isConfigured else {
                Task { @MainActor in
                    self.toastController.show("Set up your MyMind access key in Settings", style: .error, autoDismissAfter: nil)
                    self.settingsWindowController.show()
                }
                return
            }
            self.notePanelController.show()
        }

        KeyboardShortcuts.onKeyDown(for: .captureRegion) { [weak self] in
            guard let self else { return }
            guard self.settings.isConfigured else {
                Task { @MainActor in
                    self.toastController.show("Set up your MyMind access key in Settings", style: .error, autoDismissAfter: nil)
                    self.settingsWindowController.show()
                }
                return
            }
            self.regionCaptureController.begin()
        }

        // Set initial icon state (red when not configured).
        statusController.resetIcon()
        // Fix C: set an initial status line so it's never blank.
        reflect(settings.isConfigured ? "Ready" : "Not configured")
    }

    // MARK: - Helpers

    /// Fix C: Updates the menu-bar status line (the disabled top item in the menu).
    private func reflect(_ text: String) {
        statusController.setStatusLine(text)
    }
}
