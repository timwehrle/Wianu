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
        .frame(width: 520, height: 360)
    }
}

private struct TMDBSettingsView: View {
    @Bindable var model: AppModel
    @State private var token = ""
    @State private var isVerifying = false
    @State private var feedback: Feedback?

    private var trimmedToken: String {
        token.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Form {
            Section("TMDB API") {
                SecureField(fieldPrompt, text: $token)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isVerifying)
                    .onSubmit(saveToken)

                Text(
                    "Create a free TMDB account, request an API key, "
                        + "then paste the API Read Access Token here."
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Link(
                    "Open TMDB API settings",
                    destination: URL(
                        string: "https://www.themoviedb.org/settings/api"
                    )!
                )

                controls

                if let feedback {
                    Label(feedback.message, systemImage: feedback.icon)
                        .foregroundStyle(feedback.color)
                } else if let error = model.tmdbCredentialError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(20)
    }

    private var fieldPrompt: String {
        model.hasStoredTMDBToken
            ? "Enter a replacement token"
            : "TMDB Read Access Token"
    }

    private var controls: some View {
        HStack {
            Button(
                model.hasStoredTMDBToken
                    ? "Verify and Replace"
                    : "Verify and Save",
                action: saveToken
            )
            .disabled(trimmedToken.isEmpty || isVerifying)

            if model.hasStoredTMDBToken {
                Button("Remove Token", role: .destructive, action: removeToken)
                    .disabled(isVerifying)
            }

            if isVerifying {
                ProgressView()
                    .controlSize(.small)
            }
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
