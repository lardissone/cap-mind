import AppKit

@MainActor
final class StatusItemController: NSObject {
    // MARK: - Icon enum

    enum Icon {
        case normal
        case attention
        case sending
        case aboutToReceive
    }

    // MARK: - Closures

    var onNewNote: (() -> Void)?
    var onCaptureRegion: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onCheckForUpdates: (() -> Void)?

    // MARK: - State

    private let settings: AppSettings
    private let statusItem: NSStatusItem
    private var statusLine: NSMenuItem!

    // MARK: - Init

    init(settings: AppSettings) {
        self.settings = settings
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        setIcon(.normal)
        buildMenu()
    }

    // MARK: - Icon

    func setIcon(_ icon: Icon) {
        guard let button = statusItem.button else { return }

        let isFilled = settings.iconStyle == .filled

        let symbolName: String
        let tintColor: NSColor?

        switch icon {
        case .normal:
            symbolName = isFilled ? "tray.fill" : "tray"
            tintColor = nil
        case .attention:
            symbolName = isFilled ? "tray.fill" : "tray"
            tintColor = .systemRed
        case .sending:
            symbolName = isFilled ? "arrow.up.circle.fill" : "arrow.up.circle"
            tintColor = nil
        case .aboutToReceive:
            symbolName = isFilled ? "tray.and.arrow.down.fill" : "tray.and.arrow.down"
            tintColor = nil
        }

        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: AppConstants.appName)
        button.contentTintColor = tintColor
    }

    // MARK: - Menu

    private func buildMenu() {
        let menu = NSMenu()

        // Status line (disabled, reflects app state)
        let statusLineItem = NSMenuItem(title: AppConstants.appName, action: nil, keyEquivalent: "")
        statusLineItem.isEnabled = false
        menu.addItem(statusLineItem)
        self.statusLine = statusLineItem

        menu.addItem(.separator())

        // New note
        let newNoteItem = NSMenuItem(title: "New note", action: #selector(handleNewNote), keyEquivalent: "")
        newNoteItem.target = self
        menu.addItem(newNoteItem)

        // Capture region
        let captureItem = NSMenuItem(title: "Capture region", action: #selector(handleCaptureRegion), keyEquivalent: "")
        captureItem.target = self
        menu.addItem(captureItem)

        menu.addItem(.separator())

        // Open Settings
        let settingsItem = NSMenuItem(title: "Open Settings\u{2026}", action: #selector(handleOpenSettings), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)

        // Check for Updates
        let updatesItem = NSMenuItem(title: "Check for Updates\u{2026}", action: #selector(handleCheckForUpdates), keyEquivalent: "")
        updatesItem.target = self
        menu.addItem(updatesItem)

        // About
        let aboutItem = NSMenuItem(
            title: "About \(AppConstants.appName)",
            action: #selector(handleAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit", action: #selector(handleQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    // MARK: - Menu actions

    @objc private func handleNewNote() {
        onNewNote?()
    }

    @objc private func handleCaptureRegion() {
        onCaptureRegion?()
    }

    @objc private func handleOpenSettings() {
        onOpenSettings?()
    }

    @objc private func handleCheckForUpdates() {
        onCheckForUpdates?()
    }

    @objc private func handleAbout() {
        NSApplication.shared.orderFrontStandardAboutPanel(nil)
    }

    @objc private func handleQuit() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Status line

    func setStatusLine(_ text: String) {
        statusLine?.title = text
    }
}
