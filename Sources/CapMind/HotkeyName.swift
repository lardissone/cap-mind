import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let openNote = Self(
        "openNote",
        default: .init(.m, modifiers: [.command, .shift, .option])
    )
    static let captureRegion = Self(
        "captureRegion",
        default: .init(.s, modifiers: [.command, .shift, .option])
    )
}
