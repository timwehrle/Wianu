import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }

            CreditsView()
                .tabItem { Label("Credits", systemImage: "info.circle") }
        }
        .frame(width: 560, height: 420)
        .onAppear {
            model.settingsOpened()
        }
    }
}

private struct GeneralSettingsView: View {
    @AppStorage(AnalyticsPreference.enabledKey)
    private var analyticsEnabled = true

    var body: some View {
        Form {
            Toggle(
                "Send Anonymous Usage Analytics",
                isOn: $analyticsEnabled
            )

            Text(
                "Share basic feature usage and the Wianu version. "
                    + "Searches, titles, URLs, providers, and personal "
                    + "identifiers are never included."
            )
            .font(.callout)
            .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .padding()
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
