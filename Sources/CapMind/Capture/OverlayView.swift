import AppKit

/// Layer-backed NSView that covers the full overlay window.
/// Draws: a translucent dim (black ~0.25 alpha), a crosshair at the cursor,
/// and a live selection rectangle that "punches through" the dim.
/// Also shows a pixel-size label near the cursor during drag.
final class OverlayView: NSView {

    // MARK: - Closures

    /// Called when the user releases the mouse; receives the rect in view coordinates (bottom-left origin).
    var onComplete: (CGRect) -> Void = { _ in }
    /// Called when the user presses Escape.
    var onCancel: () -> Void = {}

    // MARK: - Private state

    private var anchor: CGPoint?
    private var current: CGPoint?
    private var selectionRect: CGRect = .zero

    private let dimLayer = CALayer()
    private let selectionLayer = CAShapeLayer()
    private let crosshairLayer = CAShapeLayer()
    private let labelLayer = CATextLayer()

    // MARK: - Init

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true

        // Dim layer: full view, black at 25% opacity
        dimLayer.backgroundColor = NSColor.black.withAlphaComponent(0.25).cgColor
        dimLayer.frame = bounds
        layer?.addSublayer(dimLayer)

        // Selection cutout: uses "clear" blend to punch through dim
        selectionLayer.fillColor = NSColor.clear.cgColor
        selectionLayer.strokeColor = NSColor.white.cgColor
        selectionLayer.lineWidth = 1.5
        selectionLayer.lineDashPattern = [6, 3]
        layer?.addSublayer(selectionLayer)

        // Crosshair lines
        crosshairLayer.strokeColor = NSColor.white.withAlphaComponent(0.6).cgColor
        crosshairLayer.lineWidth = 1
        crosshairLayer.fillColor = nil
        layer?.addSublayer(crosshairLayer)

        // Size label
        labelLayer.fontSize = 11
        labelLayer.foregroundColor = NSColor.white.cgColor
        labelLayer.backgroundColor = NSColor.black.withAlphaComponent(0.55).cgColor
        labelLayer.cornerRadius = 3
        labelLayer.contentsScale = (window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor) ?? 2
        labelLayer.isHidden = true
        layer?.addSublayer(labelLayer)

        // Track mouse moves even without button held
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    // MARK: - NSView overrides

    override var acceptsFirstResponder: Bool { true }

    /// Deliver the very first click to the view even when the overlay window is not
    /// yet key — otherwise the initial mouse-down is swallowed activating the window
    /// and the user has to click a second time to start a selection.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func layout() {
        super.layout()
        dimLayer.frame = bounds
    }

    // MARK: - Mouse events

    override func mouseDown(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        anchor = pt
        current = pt
        selectionRect = .zero
        updateLayers(at: pt)
    }

    override func mouseDragged(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        current = pt
        guard let anchor else { return }
        selectionRect = rectFromPoints(anchor, pt)
        updateLayers(at: pt)
    }

    override func mouseUp(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        current = pt
        guard let anchor else { return }
        let rect = rectFromPoints(anchor, pt)
        guard rect.width > 2 && rect.height > 2 else {
            onCancel()
            return
        }
        onComplete(rect)
    }

    override func mouseMoved(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        current = pt
        updateLayers(at: pt)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            onCancel()
        } else {
            super.keyDown(with: event)
        }
    }

    // MARK: - Layer update

    private func updateLayers(at cursor: CGPoint) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        // Crosshair
        let crossPath = CGMutablePath()
        crossPath.move(to: CGPoint(x: 0, y: cursor.y))
        crossPath.addLine(to: CGPoint(x: bounds.width, y: cursor.y))
        crossPath.move(to: CGPoint(x: cursor.x, y: 0))
        crossPath.addLine(to: CGPoint(x: cursor.x, y: bounds.height))
        crosshairLayer.path = crossPath

        // Selection rect + punch-through dim
        if selectionRect.width > 0 && selectionRect.height > 0 {
            let outerPath = CGMutablePath()
            outerPath.addRect(bounds)
            outerPath.addRect(selectionRect)

            // Dim path with hole (even-odd fills the outer rect minus the selection)
            let dimPath = CGMutablePath()
            dimPath.addRect(bounds)
            dimPath.addRect(selectionRect)
            let dimShape = CAShapeLayer()
            dimShape.path = dimPath
            dimShape.fillRule = .evenOdd
            dimShape.fillColor = NSColor.black.withAlphaComponent(0.25).cgColor
            dimLayer.mask = dimShape

            // Selection border
            let selPath = CGPath(rect: selectionRect, transform: nil)
            selectionLayer.path = selPath
            selectionLayer.isHidden = false

            // Size label
            let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
            let pw = Int(selectionRect.width * scale)
            let ph = Int(selectionRect.height * scale)
            let text = "\(pw) × \(ph)" as NSString
            labelLayer.string = text
            let labelSize = CGSize(width: text.size(withAttributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)]).width + 10, height: 18)
            // Position label near cursor, nudging it inside view bounds
            var labelOrigin = CGPoint(x: cursor.x + 10, y: cursor.y + 10)
            if labelOrigin.x + labelSize.width > bounds.width { labelOrigin.x = cursor.x - labelSize.width - 6 }
            if labelOrigin.y + labelSize.height > bounds.height { labelOrigin.y = cursor.y - labelSize.height - 6 }
            labelLayer.frame = CGRect(origin: labelOrigin, size: labelSize)
            labelLayer.isHidden = false
        } else {
            dimLayer.mask = nil
            selectionLayer.isHidden = true
            labelLayer.isHidden = true
        }

        CATransaction.commit()
    }

    // MARK: - Helpers

    private func rectFromPoints(_ a: CGPoint, _ b: CGPoint) -> CGRect {
        CGRect(
            x: min(a.x, b.x),
            y: min(a.y, b.y),
            width: abs(b.x - a.x),
            height: abs(b.y - a.y)
        )
    }
}
