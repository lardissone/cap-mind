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

/// Shows a small HUD-style toast floating at the bottom-center of the active screen.
///
/// - `progress` style: stays until `update(_:)` or `dismiss()` is called.
/// - `success` style: auto-dismisses after the requested interval (default 1.5 s).
/// - `error` style: persists until the user clicks the toast or `dismiss()` is called.
@MainActor
final class ToastController {

    // MARK: - State

    private var panel: NSPanel?
    private var hostingView: NSHostingView<ToastContentView>?
    private var currentMessage: String = ""
    private var currentStyle: ToastStyle = .progress
    private var autoDismissTask: Task<Void, Never>?

    /// Distance from the bottom of the screen's visible frame to the toast.
    private let bottomMargin: CGFloat = 90

    init() {}

    // MARK: - Public API

    func show(_ message: String, style: ToastStyle, autoDismissAfter interval: TimeInterval?) {
        cancelAutoDismiss()
        currentMessage = message
        currentStyle = style

        if panel != nil {
            refreshContent()
        } else {
            presentPanel()
        }

        if let interval {
            scheduleAutoDismiss(after: interval)
        }
    }

    func update(_ message: String) {
        guard panel != nil else {
            show(message, style: .progress, autoDismissAfter: nil)
            return
        }
        currentMessage = message
        refreshContent()
    }

    func dismiss() {
        cancelAutoDismiss()
        panel?.orderOut(nil)
        panel = nil
        hostingView = nil
    }

    // MARK: - Private helpers

    private func presentPanel() {
        let hosting = NSHostingView(rootView: makeContentView())
        hosting.translatesAutoresizingMaskIntoConstraints = false

        let effect = NSVisualEffectView()
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 12
        effect.layer?.masksToBounds = true
        effect.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: effect.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: effect.bottomAnchor)
        ])

        let p = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isFloatingPanel = true
        p.level = .statusBar
        p.hidesOnDeactivate = false
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        p.contentView = effect

        panel = p
        hostingView = hosting
        layoutAndPosition()
        p.orderFrontRegardless()
    }

    private func refreshContent() {
        hostingView?.rootView = makeContentView()
        layoutAndPosition()
    }

    private func makeContentView() -> ToastContentView {
        ToastContentView(
            message: currentMessage,
            style: currentStyle,
            onDismiss: { [weak self] in self?.dismiss() }
        )
    }

    /// Sizes the panel to its content and centers it near the bottom of the active screen.
    private func layoutAndPosition() {
        guard let panel, let hostingView else { return }
        let size = hostingView.fittingSize
        guard let screen = NSScreen.main else {
            panel.setContentSize(size)
            return
        }
        let visible = screen.visibleFrame
        let origin = NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.minY + bottomMargin
        )
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
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
