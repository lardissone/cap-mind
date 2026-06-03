import AppKit
import KeyboardShortcuts

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

        let symbolName: String
        let tintColor: NSColor?

        switch icon {
        case .normal:
            symbolName = "figure.mind.and.body"
            tintColor = nil
        case .attention:
            symbolName = "figure.mind.and.body"
            tintColor = .systemRed
        case .sending:
            symbolName = "arrow.up.circle"
            tintColor = nil
        case .aboutToReceive:
            symbolName = "tray.and.arrow.down"
            tintColor = nil
        }

        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: AppConstants.appName)?
            .withSymbolConfiguration(config)
        image?.isTemplate = true
        button.image = image
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

        // New note — shows the user's recorded shortcut, kept in sync automatically.
        let newNoteItem = NSMenuItem(title: "New note", action: #selector(handleNewNote), keyEquivalent: "")
        newNoteItem.target = self
        newNoteItem.setShortcut(for: .openNote)
        m.addItem(newNoteItem)

        // Capture region
        let captureItem = NSMenuItem(title: "Capture region", action: #selector(handleCaptureRegion), keyEquivalent: "")
        captureItem.target = self
        captureItem.setShortcut(for: .captureRegion)
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

        m.delegate = self

        // We keep the menu in a property rather than assigning `statusItem.menu`
        // permanently: a persistent menu makes AppKit intercept the button's mouseDown
        // and swallow the drag events StatusItemDropView needs. `showMenu()` assigns it
        // only transiently per click. See StatusItemDropView for the full explanation.
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

    /// Shows the menu using AppKit's native status-item presentation.
    ///
    /// Assigning `statusItem.menu` is what gives correct positioning (dropping below
    /// the menu bar) and the system highlight appearance. It normally also makes AppKit
    /// intercept the button's `mouseDown`, which would swallow the drag events the drop
    /// view needs — so we assign it only for the duration of this synchronous click and
    /// clear it immediately, leaving `statusItem.menu` nil at rest so drops keep working.
    private func showMenu() {
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
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

// MARK: - NSMenuDelegate

extension StatusItemController: NSMenuDelegate {
    /// While the menu is open `NSMenu` puts the thread in tracking mode, which buffers
    /// global hotkey events and fires them when the menu closes. Disabling the shortcuts
    /// for the menu's lifetime prevents that; the menu items' own key equivalents still work.
    func menuWillOpen(_ menu: NSMenu) {
        KeyboardShortcuts.disable(.openNote, .captureRegion)
    }

    func menuDidClose(_ menu: NSMenu) {
        KeyboardShortcuts.enable(.openNote, .captureRegion)
    }
}
