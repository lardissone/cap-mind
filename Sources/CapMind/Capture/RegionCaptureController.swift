// MANUAL TEST (§14.6–14.8):
// 1. Press capture hotkey → dim crosshair overlay appears on every connected display simultaneously.
// 2. Drag a rectangle on any display → live pixel-dimension label updates (e.g. "512 × 384") near cursor.
// 3. Release mouse → overlay disappears; console prints "Captured: <ObjectRef id>" within a few seconds.
//    Verify the uploaded PNG is native-resolution (2× on Retina) and covers only the selected area.
// 4. Press Escape at any point (before or during drag) → overlay disappears with no upload triggered.
// 5. Without screen-recording permission → an NSAlert appears with a button to open Privacy settings.

import AppKit
import ScreenCaptureKit

@MainActor
final class RegionCaptureController {

    // MARK: - Dependencies

    private let client: MyMindClient
    private let onResult: (Result<ObjectRef, Error>) -> Void
    private let service = ScreenshotCaptureService()

    /// Called right before the PNG upload begins, so the caller can show a sending icon/status.
    var onUploadingStarted: (() -> Void)?

    // MARK: - Overlay state

    private var overlayWindows: [(window: OverlayWindow, view: OverlayView)] = []

    // MARK: - Init

    init(client: MyMindClient, onResult: @escaping (Result<ObjectRef, Error>) -> Void) {
        self.client = client
        self.onResult = onResult
    }

    // MARK: - Public API

    func begin() {
        guard ScreenshotCaptureService.requestPermissionIfNeeded() else {
            showPermissionAlert()
            return
        }
        showOverlays()
    }

    // MARK: - Overlays

    private func showOverlays() {
        teardown()

        // Bring the app forward so the overlay windows can become key and receive
        // the first click without an extra activating tap.
        NSApp.activate(ignoringOtherApps: true)

        NSCursor.crosshair.push()

        for screen in NSScreen.screens {
            let window = OverlayWindow(screen: screen)
            let view = OverlayView(frame: CGRect(origin: .zero, size: screen.frame.size))
            window.contentView = view

            view.onCancel = { [weak self] in
                self?.cancel()
            }

            view.onComplete = { [weak self] viewRect in
                self?.complete(on: screen, viewRect: viewRect)
            }

            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(view)

            overlayWindows.append((window: window, view: view))
        }
    }

    // MARK: - Completion

    private func complete(on screen: NSScreen, viewRect: CGRect) {
        // Coordinate conversion:
        // AppKit view coordinates: bottom-left origin. The view fills the screen frame (screen.frame),
        // so view.y=0 corresponds to the bottom of the screen in AppKit global coordinates.
        //
        // SCStreamConfiguration.sourceRect expects a top-left origin within the display's points.
        // The display height in points is screen.frame.height.
        //
        // Conversion: given (viewX, viewY, w, h) in bottom-left-origin view coords,
        //   topLeftY = screenHeight - (viewY + h)
        // So the converted rect is: CGRect(x: viewRect.minX, y: screenHeight - viewRect.maxY, w: w, h: h)

        let screenHeight = screen.frame.height
        let captureRect = CGRect(
            x: viewRect.minX,
            y: screenHeight - viewRect.maxY,  // flip Y: bottom-left → top-left origin
            width: viewRect.width,
            height: viewRect.height
        )
        let scale = screen.backingScaleFactor

        teardown()

        Task { @MainActor in
            do {
                let scDisplay = try await service.display(for: screen)
                let pngData = try await service.capturePNG(display: scDisplay, rect: captureRect, scale: scale)
                let timestamp = Self.timestamp()
                let filename = "capmind-\(timestamp).png"
                // Notify the caller that the upload is about to start.
                onUploadingStarted?()
                let ref = try await client.createObjectFromFile(pngData, mimeType: "image/png", filename: filename)
                onResult(.success(ref))
            } catch {
                onResult(.failure(error))
            }
        }
    }

    private func cancel() {
        teardown()
    }

    // MARK: - Teardown

    private func teardown() {
        NSCursor.pop()
        for pair in overlayWindows {
            pair.window.orderOut(nil)
        }
        overlayWindows = []
    }

    // MARK: - Permission alert

    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Screen Recording permission needed"
        alert.informativeText = "CapMind requires Screen Recording access to capture a region. Open Privacy & Security settings to grant it."
        alert.addButton(withTitle: "Open Privacy Settings")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(
                URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
            )
        }
    }

    // MARK: - Helpers

    private static func timestamp() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyyMMdd-HHmmss"
        return fmt.string(from: Date())
    }
}
