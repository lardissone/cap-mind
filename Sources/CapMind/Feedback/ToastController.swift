import AppKit
import SwiftUI

// MARK: - Toast style

enum ToastStyle {
    case progress
    case success
    case error

    var systemImageName: String {
        switch self {
        case .progress: return "arrow.up.circle"
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .progress: return .secondary
        case .success: return .green
        case .error: return .red
        }
    }
}

// MARK: - Toast content view

private struct ToastContentView: View {
    let message: String
    let style: ToastStyle
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: style.systemImageName)
                .foregroundStyle(style.color)
                .imageScale(.medium)

            Text(message)
                .font(.callout)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minWidth: 180, maxWidth: 320)
        .contentShape(Rectangle())
        .onTapGesture {
            onDismiss()
        }
    }
}

// MARK: - ToastController

/// Shows a small status popover anchored to the menu-bar status-item button.
///
/// - `progress` style: stays until `update(_:)` or `dismiss()` is called.
/// - `success` style: auto-dismisses after the requested interval (default 1.5 s).
/// - `error` style: persists until the user clicks the popover or `dismiss()` is called.
@MainActor
final class ToastController {

    // MARK: - State

    private var popover: NSPopover?
    private var currentMessage: String = ""
    private var currentStyle: ToastStyle = .progress
    private var autoDismissTask: Task<Void, Never>?

    // MARK: - Button provider

    private let buttonProvider: () -> NSStatusBarButton?

    init(buttonProvider: @escaping () -> NSStatusBarButton?) {
        self.buttonProvider = buttonProvider
    }

    // MARK: - Public API

    func show(_ message: String, style: ToastStyle, autoDismissAfter interval: TimeInterval?) {
        cancelAutoDismiss()
        currentMessage = message
        currentStyle = style

        if let existing = popover, existing.isShown {
            // Already visible — refresh content in place.
            refreshContent()
        } else {
            presentPopover()
        }

        if let interval {
            scheduleAutoDismiss(after: interval)
        }
    }

    func update(_ message: String) {
        guard let p = popover, p.isShown else {
            show(message, style: .progress, autoDismissAfter: nil)
            return
        }
        currentMessage = message
        refreshContent()
    }

    func dismiss() {
        cancelAutoDismiss()
        popover?.close()
        popover = nil
    }

    // MARK: - Private helpers

    private func presentPopover() {
        guard let button = buttonProvider() else { return }

        let p = NSPopover()
        p.behavior = .transient
        p.animates = true
        p.contentViewController = makeContentVC()
        p.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover = p
    }

    private func refreshContent() {
        popover?.contentViewController = makeContentVC()
    }

    private func makeContentVC() -> NSViewController {
        let view = ToastContentView(
            message: currentMessage,
            style: currentStyle,
            onDismiss: { [weak self] in self?.dismiss() }
        )
        let hosting = NSHostingController(rootView: view)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        return hosting
    }

    private func scheduleAutoDismiss(after interval: TimeInterval) {
        autoDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.dismiss() }
        }
    }

    private func cancelAutoDismiss() {
        autoDismissTask?.cancel()
        autoDismissTask = nil
    }
}
