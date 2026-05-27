import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    @Bindable var appState: AppState
    let client: MyMindClient
    let onConfigured: () -> Void

    var body: some View {
        TabView {
            Tab("General", systemImage: "gear") {
                Form {
                    GeneralSection(settings: settings, onIconStyleChanged: onConfigured)
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
