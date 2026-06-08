import AppKit

/// Bridges the macOS Services menu ("Add to MyMind") to the same pasteboard
/// handling the menu-bar drop target uses. macOS invokes `addToMyMind(_:userData:error:)`
/// with the current selection's pasteboard; the registered handler does the upload.
@MainActor
final class ServicesProvider: NSObject {
    var onPerform: (NSPasteboard) -> Void = { _ in }

    func register() {
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
    }

    @objc func addToMyMind(
        _ pasteboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString>?
    ) {
        onPerform(pasteboard)
    }
}
