import AppKit
import SwiftUI

@MainActor
final class NotePanelController: NSObject {
    private let client: MyMindClient
    private let settings: AppSettings
    private let appState: AppState

    private var panel: NotePanel?

    private let defaultSize = NSSize(width: 480, height: 260)

    init(client: MyMindClient, settings: AppSettings, appState: AppState) {
        self.client = client
        self.settings = settings
        self.appState = appState
    }

    // MARK: - Public API

    func show() {
        if appState.sendStatus == .sent {
            appState.sendStatus = .idle
        }

        let panel = panel ?? makePanel()
        self.panel = panel

        positionPanel(panel)

        let level: NSWindow.Level = settings.alwaysOnTop ? .floating : .normal
        panel.level = level

        panel.makeKeyAndOrderFront(nil)
        triggerEditorFocus()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func submit() {
        guard appState.sendStatus != .sending else { return }

        let trimmed = appState.noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        appState.sendStatus = .sending

        Task { @MainActor in
            let sendStart = Date()
            do {
                _ = try await client.createObjectFromContent(trimmed)

                // Honor a minimum "Sending…" duration of ~200ms for visual clarity.
                let elapsed = Date().timeIntervalSince(sendStart)
                if elapsed < 0.2 {
                    try? await Task.sleep(nanoseconds: UInt64((0.2 - elapsed) * 1_000_000_000))
                }

                appState.sendStatus = .sent
                // Show "Sent" for ~600ms, then close and clear.
                try? await Task.sleep(nanoseconds: 600_000_000)
                appState.noteText = ""
                appState.sendStatus = .idle
                self.hide()
            } catch {
                // Fix D: user-friendly error message instead of raw Swift description.
                let message = (error as? MyMindError)?.userMessage ?? error.localizedDescription
                appState.sendStatus = .error(message)
                // NOTE: Fix A — NotePanelController has no access to StatusItemController,
                // so auth-failure icon reset for note submit is handled by AppDelegate
                // (the result handler is in-process; AppDelegate owns the status controller).
            }
        }
    }

    // MARK: - Private helpers

    private func makePanel() -> NotePanel {
        let panel = NotePanel(contentRect: NSRect(origin: .zero, size: defaultSize))

        let view = NoteInputView(
            appState: appState,
            onSubmit: { [weak self] in self?.submit() },
            onCancel: { [weak self] in
                // Fix E (spec §14.5): Esc discards content so reopening starts empty.
                // Text is NOT cleared on send-failure to allow retry (spec §12).
                self?.appState.noteText = ""
                self?.appState.sendStatus = .idle
                self?.hide()
            }
        )
        let hosting = NSHostingView(rootView: view)
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting

        panel.delegate = self
        return panel
    }

    private func positionPanel(_ panel: NotePanel) {
        switch settings.panelPosition {
        case .centered:
            panel.setContentSize(defaultSize)
            panel.center()
        case .atCursor:
            panel.setContentSize(defaultSize)
            positionAtCursor(panel)
        case .lastUsed:
            if let origin = settings.savedWindowOrigin {
                panel.setContentSize(defaultSize)
                panel.setFrameOrigin(clampOriginToVisibleScreen(origin, size: panel.frame.size))
            } else {
                panel.setContentSize(defaultSize)
                panel.center()
            }
        }
    }

    private func positionAtCursor(_ panel: NotePanel) {
        let cursor = NSEvent.mouseLocation
        let size = panel.frame.size
        let origin = NSPoint(
            x: cursor.x - size.width / 2,
            y: cursor.y - size.height / 2
        )
        panel.setFrameOrigin(clampOriginToVisibleScreen(origin, size: size))
    }

    private func clampOriginToVisibleScreen(_ origin: NSPoint, size: NSSize) -> NSPoint {
        let center = NSPoint(x: origin.x + size.width / 2, y: origin.y + size.height / 2)
        let screen = NSScreen.screens.first(where: { $0.frame.contains(center) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let bounds = screen?.visibleFrame else { return origin }

        var clamped = origin
        clamped.x = max(bounds.minX, min(clamped.x, bounds.maxX - size.width))
        clamped.y = max(bounds.minY, min(clamped.y, bounds.maxY - size.height))
        return clamped
    }

    private func triggerEditorFocus() {
        // Tiny delay so the panel becomes key before SwiftUI applies focus.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.appState.focusEditorTrigger &+= 1
        }
    }
}

// MARK: - NSWindowDelegate

extension NotePanelController: NSWindowDelegate {
    nonisolated func windowDidMove(_ notification: Notification) {
        Task { @MainActor in
            self.persistCurrentOrigin()
        }
    }

    nonisolated func windowDidResize(_ notification: Notification) {
        Task { @MainActor in
            self.persistCurrentOrigin()
        }
    }

    @MainActor
    private func persistCurrentOrigin() {
        guard let panel else { return }
        settings.savedWindowOrigin = panel.frame.origin
    }
}
