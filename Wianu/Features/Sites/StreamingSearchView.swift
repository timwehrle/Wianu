import SwiftUI

struct StreamingSearchView: View {
    @Bindable var model: AppModel
    @FocusState private var searchFieldIsFocused: Bool

    private var search: TMDBSearchModel {
        model.tmdbSearch
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()

            if !search.isConfigured {
                ContentUnavailableView {
                    Label("TMDB is not configured", systemImage: "key.slash")
                } description: {
                    Text(
                        "Add your personal TMDB Read Access Token in Settings "
                            + "to enable movie and TV search."
                    )
                } actions: {
                    SettingsLink {
                        Text("Open Settings")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let selected = search.selectedMedia {
                availabilityView(selected)
            } else {
                resultsView
            }
        }
        .onAppear { searchFieldIsFocused = true }
        .onChange(of: search.focusRequest) {
            searchFieldIsFocused = true
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(
                "Search movies and TV shows",
                text: Bindable(search).query
            )
            .textFieldStyle(.plain)
            .font(.title3)
            .focused($searchFieldIsFocused)
            .onChange(of: search.query) { search.queryChanged() }
            if !search.query.isEmpty {
                Button {
                    search.query = ""
                    search.queryChanged()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding(16)
    }

    @ViewBuilder
    private var resultsView: some View {
        if search.isSearching {
            ProgressView("Searching TMDB…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = search.errorMessage {
            retryView(error)
        } else if search.query.trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
        {
            unavailable(
                title: "Find where to watch",
                icon: "film.stack",
                description:
                "Search TMDB for a movie or TV show, then choose a provider available in your country."
            )
        } else if search.results.isEmpty {
            unavailable(
                title: "No results",
                icon: "magnifyingglass",
                description: "Try another title or check the spelling."
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(search.results) { item in
                        Button {
                            search.select(item)
                        } label: {
                            MediaResultRow(
                                item: item,
                                posterURL: search.imageConfiguration?.posterURL(
                                    path: item.posterPath
                                )
                            )
                        }
                        .buttonStyle(.plain)
                        .onAppear { search.loadMoreIfNeeded(after: item) }
                        Divider().padding(.leading, 92)
                    }
                    if search.isLoadingMore {
                        ProgressView().padding()
                    }
                }
                .frame(maxWidth: 760)
                .padding()
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func availabilityView(_ media: TMDBMediaResult) -> some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    search.clearSelection()
                    searchFieldIsFocused = true
                } label: {
                    Label("Results", systemImage: "chevron.left")
                }

                Spacer()

                Picker("Country", selection: Bindable(search).selectedRegion) {
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

            Divider()

            if search.isLoadingProviders {
                ProgressView("Loading availability…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = search.errorMessage {
                retryView(error)
            } else if let availability = search.availability {
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
                                    providers: availability[type],
                                    media: media
                                )
                            }
                        }

                        if TMDBOfferType.allCases.allSatisfy({
                            availability[$0].isEmpty
                        }) {
                            Text(
                                "No offers are currently listed for this country."
                            )
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
            } else {
                unavailable(
                    title: "Not available in this country",
                    icon: "globe",
                    description:
                    "TMDB has no provider information for \(media.title) in the selected country."
                )
            }
        }
    }

    private func providerGroup(
        _ type: TMDBOfferType,
        providers: [TMDBProvider],
        media: TMDBMediaResult
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(type.rawValue).font(.headline)
            ForEach(providers) { provider in
                let site = model.site(for: provider)
                Button {
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
                            if site == nil
                                || site?.resolvedSearchURLTemplate == nil
                            {
                                Text("Not configured")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Search in \(site!.name)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
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
        }
    }

    private func retryView(_ error: String) -> some View {
        ContentUnavailableView {
            Label("Couldn’t load TMDB", systemImage: "exclamationmark.triangle")
        } description: {
            Text(error)
        } actions: {
            Button("Retry") { search.retry() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func unavailable(title: String, icon: String, description: String)
        -> some View
    {
        ContentUnavailableView(
            title,
            systemImage: icon,
            description: Text(description)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct MediaResultRow: View {
    let item: TMDBMediaResult
    let posterURL: URL?

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Poster(url: posterURL, width: 64, height: 96)
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(item.title).font(.headline)
                    if let year = item.year {
                        Text(year).foregroundStyle(.secondary)
                    }
                    Text(item.mediaType == .movie ? "Movie" : "TV")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }
                if !item.overview.isEmpty {
                    Text(item.overview)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

private struct MediaHeader: View {
    let item: TMDBMediaResult
    let posterURL: URL?

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            Poster(url: posterURL, width: 100, height: 150)
            VStack(alignment: .leading, spacing: 8) {
                Text(item.title).font(.title2.weight(.semibold))
                Text(
                    [item.mediaType == .movie ? "Movie" : "TV", item.year]
                        .compactMap(\.self).joined(separator: " · ")
                )
                .foregroundStyle(.secondary)
                if !item.overview.isEmpty {
                    Text(item.overview)
                }
            }
        }
    }
}

private struct Poster: View {
    let url: URL?
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        AsyncImage(url: url) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            Image(systemName: "film").foregroundStyle(.secondary)
        }
        .frame(width: width, height: height)
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}

private struct ProviderLogo: View {
    let url: URL?

    var body: some View {
        AsyncImage(url: url) { image in
            image.resizable().scaledToFit()
        } placeholder: {
            Image(systemName: "play.tv").foregroundStyle(.secondary)
        }
        .frame(width: 42, height: 42)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
