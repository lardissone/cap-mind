import AppKit

/// A borderless, full-screen, non-opaque window placed on one NSScreen for the region-capture overlay.
final class OverlayWindow: NSWindow {
    let overlayScreen: NSScreen

    init(screen: NSScreen) {
        self.overlayScreen = screen
        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false,
            screen: screen
        )
        level = .screenSaver
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
