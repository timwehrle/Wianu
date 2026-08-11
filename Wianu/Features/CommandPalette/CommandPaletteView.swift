import SwiftUI

struct CommandPaletteView: View {
    @Bindable var model: AppModel
    let onAction: (CommandPaletteAction) -> Void
    let onDismiss: () -> Void

    @FocusState private var searchFieldIsFocused: Bool
    @State private var selectedResult: ResultID?

    private enum ResultID: Hashable {
        case command(CommandPaletteAction)
        case media(TMDBMediaResult.ID)
    }

    private var search: TMDBSearchModel {
        model.tmdbSearch
    }

    private var commands: [CommandPaletteCommand] {
        CommandCatalog.commands(
            matching: search.query,
            sites: model.siteStore.sites,
            continueWatchingItems: model.continueWatchingStore.sortedItems
        )
    }

    private var visibleResultIDs: [ResultID] {
        commands.map { .command($0.action) }
            + (canSelectMediaResults
                ? search.results.map { .media($0.id) }
                : [])
    }

    private var canSelectMediaResults: Bool {
        search.isConfigured
            && !trimmedQuery.isEmpty
            && !search.isSearching
            && search.errorMessage == nil
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()

            if let selected = search.selectedMedia {
                TMDBAvailabilityView(model: model, media: selected) {
                    search.clearSelection()
                    searchFieldIsFocused = true
                }
            } else {
                resultsView
            }
        }
        .onAppear {
            searchFieldIsFocused = true
            selectedResult = visibleResultIDs.first
        }
        .onChange(of: search.focusRequest) {
            searchFieldIsFocused = true
        }
        .onChange(of: visibleResultIDs) { _, ids in
            guard let selectedResult, ids.contains(selectedResult) else {
                self.selectedResult = ids.first
                return
            }
        }
        .onKeyPress(.downArrow) {
            moveSelection(by: 1)
            return .handled
        }
        .onKeyPress(.upArrow) {
            moveSelection(by: -1)
            return .handled
        }
        .onKeyPress(.return) {
            activateSelection()
            return selectedResult == nil ? .ignored : .handled
        }
        .onKeyPress(.escape) {
            if search.selectedMedia != nil {
                search.clearSelection()
                searchFieldIsFocused = true
            } else {
                onDismiss()
            }
            return .handled
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(
                "Search actions, sites, movies, and TV shows",
                text: Bindable(search).query
            )
            .textFieldStyle(.plain)
            .font(.title3)
            .focused($searchFieldIsFocused)
            .onChange(of: search.query) { search.queryChanged() }
            if !search.query.isEmpty {
                Button {
                    search.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding(16)
    }

    private var resultsView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if !commands.isEmpty {
                    sectionHeader("Actions")
                    ForEach(commands) { command in
                        commandRow(command)
                    }
                }

                if !trimmedQuery.isEmpty {
                    sectionHeader("Movies & TV")

                    if !search.isConfigured {
                        compactMessage(
                            "TMDB is not configured",
                            systemImage: "key.slash",
                            description:
                                "Open Settings to add a TMDB Read Access Token."
                        )
                    } else if search.isSearching {
                        HStack {
                            Spacer()
                            ProgressView("Searching TMDB…").padding(24)
                            Spacer()
                        }
                    } else if let error = search.errorMessage {
                        TMDBErrorView(search: search, error: error)
                            .frame(minHeight: 180)
                    } else if search.results.isEmpty {
                        compactMessage(
                            "No TMDB results",
                            systemImage: "magnifyingglass",
                            description:
                                "Try another title or check the spelling."
                        )
                    } else {
                        ForEach(search.results) { item in
                            Button {
                                search.select(item)
                            } label: {
                                MediaResultRow(
                                    item: item,
                                    posterURL: search.imageConfiguration?
                                        .posterURL(
                                            path: item.posterPath
                                        )
                                )
                                .padding(.horizontal, 12)
                                .background(
                                    selectedResult == .media(item.id)
                                        ? Color.accentColor.opacity(0.16)
                                        : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 8)
                                )
                            }
                            .buttonStyle(.plain)
                            .onHover { hovering in
                                if hovering {
                                    selectedResult = .media(item.id)
                                }
                            }
                            .onAppear { search.loadMoreIfNeeded(after: item) }
                        }
                        if search.isLoadingMore {
                            ProgressView().padding()
                        }
                    }
                } else if commands.isEmpty {
                    compactMessage(
                        "No actions available",
                        systemImage: "command",
                        description: "Add a site to get started."
                    )
                }
            }
            .frame(maxWidth: 760)
            .padding(12)
            .frame(maxWidth: .infinity)
        }
    }

    private var trimmedQuery: String {
        search.query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 6)
    }

    private func commandRow(_ command: CommandPaletteCommand) -> some View {
        Button {
            onAction(command.action)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: command.systemImage)
                    .frame(width: 24)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(command.title)
                    if let subtitle = command.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
            .background(
                selectedResult == .command(command.action)
                    ? Color.accentColor.opacity(0.16)
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: 8)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering {
                selectedResult = .command(command.action)
            }
        }
    }

    private func compactMessage(
        _ title: String,
        systemImage: String,
        description: String
    ) -> some View {
        ContentUnavailableView(
            title,
            systemImage: systemImage,
            description: Text(description)
        )
        .frame(maxWidth: .infinity, minHeight: 180)
    }

    private func moveSelection(by offset: Int) {
        let ids = visibleResultIDs
        guard !ids.isEmpty else {
            selectedResult = nil
            return
        }
        guard let selectedResult,
            let index = ids.firstIndex(of: selectedResult)
        else {
            selectedResult = ids.first
            return
        }
        self.selectedResult = ids[(index + offset + ids.count) % ids.count]
    }

    private func activateSelection() {
        switch selectedResult {
        case .command(let action):
            onAction(action)
        case .media(let id):
            guard let media = search.results.first(where: { $0.id == id })
            else {
                return
            }
            search.select(media)
        case nil:
            break
        }
    }
}
