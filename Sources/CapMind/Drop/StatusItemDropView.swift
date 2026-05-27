import AppKit

/// An `NSView` that fills the status-item button and acts as a drag destination.
///
/// ### Menu-vs-drop strategy
/// Assigning `statusItem.menu` causes AppKit to intercept `mouseDown` for the button
/// so it can open the menu itself — this also swallows the drag events that
/// `NSDraggingDestination` requires.  To support BOTH menus and drops we do NOT
/// assign `statusItem.menu`; instead this view is embedded as a subview of
/// `statusItem.button` and handles mouse clicks by popping the menu manually via
/// `NSMenu.popUp(positioning:at:in:)`.
///
/// **Risk / tradeoff**: `popUp(positioning:at:in:)` anchors below the button correctly
/// on macOS 15, but does not set the system "menu-bar item highlighted" appearance
/// that the native path provides.  The menu itself is fully functional; the visual
/// difference is acceptable.  If the native highlight is required in the future,
/// the alternative is to temporarily set `statusItem.menu`, call
/// `statusItem.button?.performClick(nil)`, then clear it — that pattern works but
/// can flicker on rapid successive clicks.
final class StatusItemDropView: NSView {
    // MARK: - Closures

    /// Called with `true` when a drag enters, `false` when it exits or ends.
    var onDragStateChanged: (Bool) -> Void = { _ in }

    /// Called when the user drops items onto this view.
    var onDrop: (NSPasteboard) -> Void = { _ in }

    /// Called on a plain mouse-click (not a drag).
    var onClick: () -> Void = {}

    // MARK: - Init

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL, .string, .URL, .png, .tiff, .pdf])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL, .string, .URL, .png, .tiff, .pdf])
    }

    // MARK: - NSDraggingDestination

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        onDragStateChanged(true)
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onDragStateChanged(false)
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        // draggingEnded fires after performDragOperation; reset state here too
        // so we don't stay in hover state if the drop was performed.
        onDragStateChanged(false)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        onDrop(sender.draggingPasteboard)
        return true
    }

    // MARK: - Mouse click passthrough

    override func mouseDown(with event: NSEvent) {
        // Only treat as a click if no drag session is in progress.
        onClick()
    }

    // MARK: - Hit testing

    /// Allow the button's own subviews (image, label) to be hit-tested through this view.
    override func hitTest(_ point: NSPoint) -> NSView? {
        // Return self for any point within our bounds so we receive all mouse/drag events.
        bounds.contains(point) ? self : nil
    }
}
