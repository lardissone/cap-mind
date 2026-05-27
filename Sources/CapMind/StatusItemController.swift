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

    /// Set by AppDelegate to route dropped pasteboard items to DropController.
    var onDrop: ((NSPasteboard) -> Void)?

    // MARK: - State

    private let settings: AppSettings
    private let statusItem: NSStatusItem

    /// The underlying status-bar button, used to anchor the toast popover.
    var statusBarButton: NSStatusBarButton? { statusItem.button }
    private var statusLine: NSMenuItem!
    private var menu: NSMenu!
    private var dropView: StatusItemDropView?
    private var dropInProgress = false

    // MARK: - Init

    init(settings: AppSettings) {
        self.settings = settings
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        setIcon(.normal)
        buildMenu()
        installDropView()
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

    /// Resets the icon to the correct idle state based on whether the app is configured.
    func resetIcon() {
        setIcon(settings.isConfigured ? .normal : .attention)
    }

    /// Called when a drop session begins: owns the sending icon state.
    func dropStarted() {
        dropInProgress = true
        setIcon(.sending)
    }

    /// Called when the drop session upload finishes: clears the flag and resets the icon.
    func dropFinished() {
        dropInProgress = false
        resetIcon()
    }

    /// Generic alias for any upload operation starting (capture, note, etc.).
    func operationStarted() { dropStarted() }

    /// Generic alias for any upload operation finishing (capture, note, etc.).
    func operationFinished() { dropFinished() }

    // MARK: - Menu

    private func buildMenu() {
        let m = NSMenu()

        // Status line (disabled, reflects app state)
        let statusLineItem = NSMenuItem(title: AppConstants.appName, action: nil, keyEquivalent: "")
        statusLineItem.isEnabled = false
        m.addItem(statusLineItem)
        self.statusLine = statusLineItem

        m.addItem(.separator())

        // New note
        let newNoteItem = NSMenuItem(title: "New note", action: #selector(handleNewNote), keyEquivalent: "")
        newNoteItem.target = self
        m.addItem(newNoteItem)

        // Capture region
        let captureItem = NSMenuItem(title: "Capture region", action: #selector(handleCaptureRegion), keyEquivalent: "")
        captureItem.target = self
        m.addItem(captureItem)

        m.addItem(.separator())

        // Open Settings
        let settingsItem = NSMenuItem(title: "Open Settings\u{2026}", action: #selector(handleOpenSettings), keyEquivalent: "")
        settingsItem.target = self
        m.addItem(settingsItem)

        // Check for Updates
        let updatesItem = NSMenuItem(title: "Check for Updates\u{2026}", action: #selector(handleCheckForUpdates), keyEquivalent: "")
        updatesItem.target = self
        m.addItem(updatesItem)

        // About
        let aboutItem = NSMenuItem(
            title: "About \(AppConstants.appName)",
            action: #selector(handleAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        m.addItem(aboutItem)

        m.addItem(.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit", action: #selector(handleQuit), keyEquivalent: "q")
        quitItem.target = self
        m.addItem(quitItem)

        // NOTE: We intentionally do NOT assign `statusItem.menu = m` here.
        // Doing so causes AppKit to intercept mouseDown on the button to open the menu,
        // which prevents NSDraggingDestination from receiving drag events on StatusItemDropView.
        // Instead, we keep the menu reference and pop it manually from StatusItemDropView.onClick.
        // See StatusItemDropView for the full explanation and tradeoff note.
        self.menu = m
    }

    // MARK: - Drop view installation

    /// Embeds a `StatusItemDropView` as a subview of `statusItem.button`, filling it.
    /// This view handles both drag-and-drop (NSDraggingDestination) and click-to-show-menu.
    private func installDropView() {
        guard let button = statusItem.button else { return }

        let view = StatusItemDropView(frame: button.bounds)
        view.autoresizingMask = [.width, .height]
        button.addSubview(view)
        self.dropView = view

        view.onClick = { [weak self] in
            self?.showMenu()
        }

        view.onDragStateChanged = { [weak self] hovering in
            guard let self else { return }
            if hovering {
                self.setIcon(.aboutToReceive)
            } else if !self.dropInProgress {
                self.resetIcon()
            }
        }

        view.onDrop = { [weak self] pasteboard in
            self?.dropStarted()
            self?.onDrop?(pasteboard)
        }
    }

    // MARK: - Manual menu presentation

    /// Pops the menu below the status-item button without requiring `statusItem.menu` to be set.
    ///
    /// `NSMenu.popUp(positioning:at:in:)` is the documented way to show a menu at an arbitrary
    /// location.  The only visual difference from the native path is that the menu-bar button
    /// does not receive the system highlight appearance while the menu is open.
    /// See `StatusItemDropView` for the full tradeoff discussion.
    private func showMenu() {
        guard let button = statusItem.button else { return }
        // Anchor below the bottom-left corner of the button in screen coordinates.
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 2), in: button)
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
