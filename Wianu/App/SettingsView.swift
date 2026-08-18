import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        TabView {
            CreditsView()
                .tabItem { Label("Credits", systemImage: "info.circle") }
        }
        .frame(width: 560, height: 420)
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
