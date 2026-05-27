import AppKit
import SwiftUI

/// Manages a persistent, non-activating settings panel for CapMind.
///
/// Because the app runs with `.accessory` activation policy (no dock icon),
/// a standard SwiftUI `Settings` scene would require `.regular` policy and
/// breaks menu-bar-only operation. Instead we use a dedicated `NSPanel` —
/// the same pattern as `NotePanelController` — which works without changing
/// the activation policy.
@MainActor
final class SettingsWindowController: NSObject {

    private let settings: AppSettings
    private let appState: AppState
    private let client: MyMindClient
    private let onConfigured: () -> Void

    private var panel: NSPanel?

    init(
        settings: AppSettings,
        appState: AppState,
        client: MyMindClient,
        onConfigured: @escaping () -> Void
    ) {
        self.settings = settings
        self.appState = appState
        self.client = client
        self.onConfigured = onConfigured
    }

    // MARK: - Public API

    func show() {
        let panel = panel ?? makePanel()
        self.panel = panel

        if !panel.isVisible {
            panel.center()
        }
        panel.makeKeyAndOrderFront(nil)
        // Briefly become active so the panel receives keyboard focus.
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        panel?.orderOut(nil)
    }

    // MARK: - Private helpers

    private func makePanel() -> NSPanel {
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 420),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        p.title = "CapMind Settings"
        p.titlebarAppearsTransparent = false
        p.isMovableByWindowBackground = true
        p.isReleasedWhenClosed = false
        p.animationBehavior = .utilityWindow
        p.level = .floating
        p.hidesOnDeactivate = false

        let view = SettingsView(
            settings: settings,
            appState: appState,
            client: client,
            onConfigured: onConfigured
        )
        let hosting = NSHostingView(rootView: view)
        hosting.autoresizingMask = [.width, .height]
        p.contentView = hosting
        p.delegate = self
        return p
    }
}

// MARK: - NSWindowDelegate

extension SettingsWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // No cleanup needed — panel is kept alive for quick reopen.
    }
}
