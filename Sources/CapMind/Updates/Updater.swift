import Sparkle

/// Singleton wrapper around Sparkle's `SPUStandardUpdaterController`.
///
/// The controller drives the update-check loop and exposes the underlying
/// `SPUUpdater` for finer-grained settings access (auto-check toggle,
/// background download, manual `checkForUpdates`).
///
/// For Sparkle to actually fetch an appcast, the bundled `Info.plist` must
/// contain `SUFeedURL` and `SUPublicEDKey`. In a bare `swift run` development
/// build those keys are absent, so update checks fail gracefully — the wiring
/// is identical once we ship a signed `.app`.
@MainActor
enum Updater {
    static let controller: SPUStandardUpdaterController = {
        SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }()

    static func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
