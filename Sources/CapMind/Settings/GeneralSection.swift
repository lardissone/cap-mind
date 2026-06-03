import SwiftUI

struct GeneralSection: View {
    @Bindable var settings: AppSettings

    @State private var launchAtLoginEnabled: Bool = LaunchAtLogin.isEnabled
    @State private var launchAtLoginError: String?

    var body: some View {
        GroupBox("General") {
            VStack(alignment: .leading, spacing: 14) {
                Picker("Panel position", selection: $settings.panelPosition) {
                    Text("Last used").tag(PanelPosition.lastUsed)
                    Text("Centered").tag(PanelPosition.centered)
                    Text("At cursor").tag(PanelPosition.atCursor)
                }
                .pickerStyle(.menu)

                Toggle("Always on top", isOn: $settings.alwaysOnTop)

                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Launch at login", isOn: $launchAtLoginEnabled)
                        .onChange(of: launchAtLoginEnabled) { _, newValue in
                            applyLaunchAtLogin(newValue)
                        }
                    if let launchAtLoginError {
                        Text(launchAtLoginError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .groupBoxStyle(PlainGroupBoxStyle())
        .onAppear {
            launchAtLoginEnabled = LaunchAtLogin.isEnabled
        }
    }

    private func applyLaunchAtLogin(_ newValue: Bool) {
        do {
            try LaunchAtLogin.set(newValue)
            launchAtLoginError = nil
            launchAtLoginEnabled = LaunchAtLogin.isEnabled
        } catch {
            launchAtLoginError = error.localizedDescription
            launchAtLoginEnabled = LaunchAtLogin.isEnabled
        }
    }
}
