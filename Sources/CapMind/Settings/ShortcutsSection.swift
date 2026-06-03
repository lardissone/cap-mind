import SwiftUI
import KeyboardShortcuts

struct ShortcutsSection: View {
    var body: some View {
        GroupBox("Keyboard Shortcuts") {
            VStack(alignment: .leading, spacing: 14) {
                LabeledContent("New note") {
                    KeyboardShortcuts.Recorder(for: .openNote)
                }

                LabeledContent("Capture region") {
                    KeyboardShortcuts.Recorder(for: .captureRegion)
                }

                Button("Reset to defaults") {
                    KeyboardShortcuts.reset(.openNote, .captureRegion)
                }
                .controlSize(.small)
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .groupBoxStyle(PlainGroupBoxStyle())
    }
}
