import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    enum Status: Equatable {
        case ready
        case sending
        case error(String)
    }

    var status: Status = .ready
    var isConfigured = false

    // Note panel state
    var noteText: String = ""
    var sendStatus: SendStatus = .idle
    var focusEditorTrigger: Int = 0
}
