import AppKit

/// A borderless, full-screen, non-opaque window placed on one NSScreen for the region-capture overlay.
final class OverlayWindow: NSWindow {
    let overlayScreen: NSScreen

    init(screen: NSScreen) {
        self.overlayScreen = screen
        // `screen.frame` is in the global display coordinate space, which is what
        // NSWindow's designated initializer expects for `contentRect`, so the window
        // lands on the intended screen. The `screen:`-variant initializer is not the
        // designated one and crashes here: AppKit re-dispatches to the designated
        // initializer, which Swift leaves unimplemented on this subclass.
        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
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
