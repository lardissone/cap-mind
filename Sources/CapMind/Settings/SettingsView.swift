import SwiftUI

/// A `GroupBox` style that drops the default filled container, leaving only the section
/// label and its content. The surrounding grouped `Form` still provides the outer card.
struct PlainGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            configuration.label
                .font(.headline)
            configuration.content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SettingsView: View {
    @Bindable var settings: AppSettings
    @Bindable var appState: AppState
    let client: MyMindClient
    let onConfigured: () -> Void

    var body: some View {
        TabView {
            Tab("General", systemImage: "gear") {
                Form {
                    GeneralSection(settings: settings)
                    ShortcutsSection()
                }
                .formStyle(.grouped)
            }

            Tab("Account", systemImage: "key") {
                Form {
                    AccountSection(
                        settings: settings,
                        appState: appState,
                        client: client,
                        onConfigured: onConfigured
                    )
                }
                .formStyle(.grouped)
            }

            Tab("Updates", systemImage: "arrow.down.circle") {
                Form {
                    UpdatesSection()
                }
                .formStyle(.grouped)
            }
        }
        .frame(width: 480, height: 400)
    }
}
