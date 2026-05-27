import SwiftUI
import AppKit

struct AccountSection: View {
    @Bindable var settings: AppSettings
    @Bindable var appState: AppState
    let client: MyMindClient
    let onConfigured: () -> Void

    @State private var keyIDInput: String = ""
    @State private var secretInput: String = ""
    @State private var replacingSecret = false
    @State private var isLoading = false
    @State private var statusMessage: String?
    @State private var statusIsError = false

    var body: some View {
        GroupBox("MyMind account") {
            VStack(alignment: .leading, spacing: 12) {
                // Key ID field
                VStack(alignment: .leading, spacing: 6) {
                    Text("Key ID")
                        .font(.callout)
                    TextField("Enter your MyMind key ID", text: $keyIDInput)
                        .textFieldStyle(.roundedBorder)
                }

                // Secret field — show placeholder when stored, SecureField to (re)enter
                VStack(alignment: .leading, spacing: 6) {
                    Text("Secret")
                        .font(.callout)
                    if settings.secret != nil && !replacingSecret {
                        HStack {
                            Text("\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Replace") {
                                replacingSecret = true
                                secretInput = ""
                            }
                            .controlSize(.small)
                        }
                    } else {
                        SecureField("Enter your MyMind secret", text: $secretInput)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                // Action buttons row
                HStack(spacing: 10) {
                    Button {
                        Task { await testConnection() }
                    } label: {
                        if isLoading {
                            HStack(spacing: 6) {
                                ProgressView().controlSize(.small)
                                Text("Testing\u{2026}")
                            }
                        } else {
                            Text("Test connection")
                        }
                    }
                    .disabled(keyIDInput.isEmpty || isLoading ||
                              (settings.secret == nil && secretInput.isEmpty))

                    Button("Save") {
                        saveCredentials()
                    }
                    .disabled(keyIDInput.isEmpty ||
                              (settings.secret == nil && secretInput.isEmpty && !replacingSecret))

                    if let statusMessage {
                        Label(
                            statusMessage,
                            systemImage: statusIsError
                                ? "exclamationmark.triangle.fill"
                                : "checkmark.circle.fill"
                        )
                        .labelStyle(.titleAndIcon)
                        .font(.callout)
                        .foregroundStyle(statusIsError ? .red : .green)
                        .lineLimit(2)
                    }
                }

                // Manage keys link
                Button("Manage access keys in MyMind\u{2026}") {
                    NSWorkspace.shared.open(AppConstants.manageKeysURL)
                }
                .buttonStyle(.link)
                .font(.callout)
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            keyIDInput = settings.keyID
        }
    }

    // MARK: - Actions

    private func saveCredentials() {
        settings.keyID = keyIDInput
        if !secretInput.isEmpty {
            settings.setSecret(secretInput)
            replacingSecret = false
            secretInput = ""
        }
        if settings.isConfigured {
            appState.isConfigured = true
            onConfigured()
        }
        statusMessage = "Saved."
        statusIsError = false
    }

    private func testConnection() async {
        // Persist inputs first so the client picks them up via settings.currentCredentials()
        settings.keyID = keyIDInput
        if !secretInput.isEmpty {
            settings.setSecret(secretInput)
        }

        statusMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            try await client.testConnection()
            statusMessage = "Connected"
            statusIsError = false
            appState.isConfigured = true
            replacingSecret = false
            secretInput = ""
            onConfigured()
        } catch let error as MyMindError {
            statusMessage = error.userMessage
            statusIsError = true
        } catch {
            statusMessage = error.localizedDescription
            statusIsError = true
        }
    }
}
