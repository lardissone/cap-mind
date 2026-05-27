import ScreenCaptureKit
import CoreImage
import AppKit

enum CaptureError: Error { case noDisplay, noPermission, captureFailed }

@MainActor
final class ScreenshotCaptureService {
    /// Captures `rect` (in the display's points, top-left origin) from `display` at native resolution; returns PNG data.
    ///
    /// `rect` must be in the display's local coordinate space with a top-left origin,
    /// matching the coordinate contract expected by SCStreamConfiguration.sourceRect.
    func capturePNG(display: SCDisplay, rect: CGRect, scale: CGFloat) async throws -> Data {
        guard CGPreflightScreenCaptureAccess() else { throw CaptureError.noPermission }
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.sourceRect = rect
        config.width = Int(rect.width * scale)
        config.height = Int(rect.height * scale)
        config.captureResolution = .best
        config.showsCursor = false
        let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        let ci = CIImage(cgImage: cgImage)
        let ctx = CIContext()
        guard let png = ctx.pngRepresentation(
            of: ci,
            format: .RGBA8,
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!
        ) else { throw CaptureError.captureFailed }
        return png
    }

    /// Maps an NSScreen to its SCDisplay via SCShareableContent. Throws noDisplay if not found.
    func display(for screen: NSScreen) async throws -> SCDisplay {
        let displayID = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        guard let match = content.displays.first(where: { $0.displayID == displayID }) else {
            throw CaptureError.noDisplay
        }
        return match
    }

    @discardableResult
    static func requestPermissionIfNeeded() -> Bool {
        if CGPreflightScreenCaptureAccess() { return true }
        return CGRequestScreenCaptureAccess()
    }
}
