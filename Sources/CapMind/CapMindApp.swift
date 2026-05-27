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

        toastController = ToastController(buttonProvider: { [weak self] in
            self?.statusController.statusBarButton
        })

        settingsWindowController = SettingsWindowController(
            settings: settings,
            appState: appState,
            client: client,
            onConfigured: { [weak self] in self?.statusController.resetIcon() }
        )

        notePanelController = NotePanelController(client: client, settings: settings, appState: appState)

        regionCaptureController = RegionCaptureController(client: client) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                self.toastController.show("Uploaded \u{2713}", style: .success, autoDismissAfter: 1.5)
                self.appState.status = .ready
            case .failure(let error):
                let msg: String
                if let mmError = error as? MyMindError {
                    msg = mmError.userMessage
                } else {
                    msg = error.localizedDescription
                }
                self.toastController.show(msg, style: .error, autoDismissAfter: nil)
                self.appState.status = .error(msg)
            }
        }

        dropController = DropController(client: client)

        dropController.onProgress = { [weak self] completed, total in
            guard let self else { return }
            if completed == 1 && total >= 1 {
                // Show the initial progress toast at the start of the first item.
                self.toastController.show("Uploading \(completed)/\(total)\u{2026}", style: .progress, autoDismissAfter: nil)
            } else {
                self.toastController.update("Uploading \(completed)/\(total)\u{2026}")
            }
        }

        dropController.onFinished = { [weak self] succeeded, failed in
            guard let self else { return }
            if failed.isEmpty {
                let msg = succeeded == 1 ? "Uploaded \u{2713}" : "\(succeeded) uploaded \u{2713}"
                self.toastController.show(msg, style: .success, autoDismissAfter: 1.5)
            } else {
                let msg = "\(succeeded) uploaded, \(failed.count) failed"
                self.toastController.show(msg, style: .error, autoDismissAfter: nil)
            }
            self.statusController.dropFinished()
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
    }
}
