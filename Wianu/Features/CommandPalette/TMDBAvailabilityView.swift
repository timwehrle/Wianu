import SwiftUI

struct TMDBAvailabilityView: View {
    @Bindable var model: AppModel
    let media: TMDBMediaResult
    let onBack: () -> Void

    private var search: TMDBSearchModel {
        model.tmdbSearch
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
    }

    private var header: some View {
        HStack {
            Button(action: onBack) {
                Label("Results", systemImage: "chevron.left")
            }

            Spacer()

            if let letterboxdURL = media.letterboxdURL {
                Link(destination: letterboxdURL) {
                    HStack(spacing: 6) {
                        Image("LetterboxdMark")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                        Text("Letterboxd")
                        Image(systemName: "arrow.up.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .accessibilityLabel("Open on Letterboxd")
                .help("Open \(media.title) on Letterboxd")
            }

            Picker(
                "Country",
                selection: Binding(
                    get: { search.selectedRegion },
                    set: { search.selectRegion($0) }
                )
            ) {
                if search.regions.isEmpty {
                    Text(search.selectedRegion).tag(search.selectedRegion)
                }
                ForEach(search.regions) { region in
                    Text(region.displayName).tag(region.isoCode)
                }
            }
            .labelsHidden()
            .frame(maxWidth: 220)
        }
        .padding()
    }

    @ViewBuilder
    private var content: some View {
        if search.isLoadingProviders {
            ProgressView("Loading availability…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = search.errorMessage {
            TMDBErrorView(search: search, error: error)
        } else if let availability = search.availability {
            availabilityContent(availability)
        } else {
            ContentUnavailableView(
                "Not available in this country",
                systemImage: "globe",
                description: Text(
                    "TMDB has no provider information for \(media.title) in the selected country."
                )
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func availabilityContent(
        _ availability: TMDBWatchAvailability
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                MediaHeader(
                    item: media,
                    posterURL: search.imageConfiguration?.posterURL(
                        path: media.posterPath
                    )
                )

                Text("Availability data by JustWatch")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(TMDBOfferType.allCases) { type in
                    if !availability[type].isEmpty {
                        providerGroup(
                            type,
                            providers: availability[type]
                        )
                    }
                }

                if TMDBOfferType.allCases.allSatisfy({
                    availability[$0].isEmpty
                }) {
                    Text("No offers are currently listed for this country.")
                        .foregroundStyle(.secondary)
                }

                if let link = availability.link {
                    Link("View on TMDB", destination: link)
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
    }

    private func providerGroup(
        _ type: TMDBOfferType,
        providers: [TMDBProvider]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(type.rawValue).font(.headline)
            ForEach(providers) { provider in
                providerButton(provider)
            }
        }
    }

    private func providerButton(_ provider: TMDBProvider) -> some View {
        let site = model.site(for: provider)
        return Button {
            model.openProvider(provider, for: media)
        } label: {
            HStack(spacing: 12) {
                ProviderLogo(
                    url: search.imageConfiguration?.logoURL(
                        path: provider.logoPath
                    )
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.name)
                    Text(providerDescription(for: site))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if site?.isTMDBProviderActionable == true {
                    Image(systemName: "arrow.up.forward.app")
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(site?.isTMDBProviderActionable != true)
    }

    private func providerDescription(for site: SavedSite?) -> String {
        guard let site, site.resolvedSearchURLTemplate != nil else {
            return "Not configured"
        }
        return "Search in \(site.name)"
    }
}
