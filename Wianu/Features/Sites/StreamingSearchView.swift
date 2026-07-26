import SwiftUI

struct StreamingSearchView: View {
    @Bindable var model: AppModel
    @FocusState private var searchFieldIsFocused: Bool

    private var searchableSites: [SavedSite] {
        model.siteStore.sites.filter {
            $0.resolvedSearchURLTemplate != nil
        }
    }

    private var trimmedQuery: String {
        model.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(.secondary)

                Text("Search Streaming Services")
                    .font(.title2.weight(.semibold))

                Text("Enter a movie or show, then choose where to search.")
                    .foregroundStyle(.secondary)
            }

            TextField("Movie or show title", text: $model.searchQuery)
                .textFieldStyle(.roundedBorder)
                .font(.title3)
                .focused($searchFieldIsFocused)

            if searchableSites.isEmpty {
                ContentUnavailableView(
                    "No Searchable Sites",
                    systemImage: "globe.badge.chevron.backward",
                    description: Text(
                        "Add or edit a site in the sidebar and configure "
                            + "its Search URL."
                    )
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(searchableSites) { site in
                        Button {
                            model.search(trimmedQuery, in: site)
                        } label: {
                            HStack(spacing: 10) {
                                FaviconView(url: site.url)

                                Text("Search in \(site.name)")

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .disabled(trimmedQuery.isEmpty)
                    }
                }
            }

            Spacer()
        }
        .padding(32)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .onAppear {
            searchFieldIsFocused = true
        }
    }
}
