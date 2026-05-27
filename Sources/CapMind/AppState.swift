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
}
