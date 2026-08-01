import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        TabView {
            TMDBSettingsView(model: model)
                .tabItem { Label("TMDB", systemImage: "key") }

            CreditsView()
                .tabItem { Label("Credits", systemImage: "info.circle") }
        }
        .frame(width: 560, height: 420)
    }
}

private struct TMDBSettingsView: View {
    @Bindable var model: AppModel
    @State private var token = ""
    @State private var isVerifying = false
    @State private var feedback: Feedback?
    @State private var isConfirmingRemoval = false

    private var trimmedToken: String {
        token.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    LabeledContent("Status") {
                        connectionStatus
                    }

                    LabeledContent("Read access token") {
                        SecureField(fieldPrompt, text: $token)
                            .textFieldStyle(.roundedBorder)
                            .frame(minWidth: 280)
                            .disabled(isVerifying)
                            .onSubmit(saveToken)
                    }
                } header: {
                    Text("Authentication")
                } footer: {
                    Text(
                        "Wianu verifies the token with TMDB before storing it "
                            + "securely in your Keychain."
                    )
                }

                Section {
                    LabeledContent("Get a token") {
                        Link(
                            "Open TMDB API settings",
                            destination: URL(
                                string: "https://www.themoviedb.org/settings/api"
                            )!
                        )
                    }
                } header: {
                    Text("TMDB Account")
                } footer: {
                    Text(
                        "Create a free TMDB account and copy its API Read "
                            + "Access Token—not the shorter API key."
                    )
                }
            }
            .formStyle(.grouped)

            Divider()

            controls
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
        }
        .confirmationDialog(
            "Remove TMDB Token?",
            isPresented: $isConfirmingRemoval
        ) {
            Button("Remove Token", role: .destructive, action: removeToken)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Movie and TV search will be unavailable until you add another token.")
        }
    }

    private var fieldPrompt: String {
        model.hasStoredTMDBToken
            ? "Enter a replacement token"
            : "TMDB Read Access Token"
    }

    private var connectionStatus: some View {
        Group {
            if let feedback {
                Label(feedback.message, systemImage: feedback.icon)
                    .foregroundStyle(feedback.color)
            } else if let error = model.tmdbCredentialError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            } else if model.hasStoredTMDBToken {
                Label("Configured", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Label("Not configured", systemImage: "circle.dashed")
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.trailing)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            if model.hasStoredTMDBToken {
                Button("Remove Token", role: .destructive) {
                    isConfirmingRemoval = true
                }
                .disabled(isVerifying)
            }

            Spacer()

            if isVerifying {
                ProgressView()
                    .controlSize(.small)
            }

            Button(
                model.hasStoredTMDBToken
                    ? "Verify and Replace"
                    : "Verify and Save",
                action: saveToken
            )
            .buttonStyle(.borderedProminent)
            .disabled(trimmedToken.isEmpty || isVerifying)
        }
    }

    private func saveToken() {
        guard !trimmedToken.isEmpty, !isVerifying else { return }
        isVerifying = true
        feedback = nil

        Task {
            defer { isVerifying = false }
            do {
                try await model.saveTMDBToken(trimmedToken)
                token = ""
                feedback = .success(
                    "Token verified and stored securely in Keychain."
                )
            } catch {
                feedback = .failure(error.localizedDescription)
            }
        }
    }

    private func removeToken() {
        feedback = nil
        do {
            try model.removeStoredTMDBToken()
            token = ""
            feedback = .success("The stored token was removed.")
        } catch {
            feedback = .failure(error.localizedDescription)
        }
    }

    private struct Feedback {
        let message: String
        let icon: String
        let color: Color

        static func success(_ message: String) -> Self {
            Self(
                message: message,
                icon: "checkmark.circle.fill",
                color: .green
            )
        }

        static func failure(_ message: String) -> Self {
            Self(
                message: message,
                icon: "exclamationmark.triangle.fill",
                color: .red
            )
        }
    }
}

private struct CreditsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Wianu").font(.largeTitle.weight(.semibold))
            Text("Credits")
                .font(.headline)
            Text("Movie and TV discovery")
                .foregroundStyle(.secondary)

            Image("TMDBLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 42)
            Text(
                "This product uses the TMDB API but is not endorsed or "
                    + "certified by TMDB."
            )
            .multilineTextAlignment(.center)

            Text("Watch-provider availability data by JustWatch.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(32)
    }
}
