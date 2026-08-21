import SwiftUI
import UniformTypeIdentifiers

struct SidebarView: View {
    @Bindable var model: AppModel
    @Binding var showingAddSite: Bool

    @State private var editingSite: SavedSite?
    @State private var renamingItem: ContinueWatchingItem?
    @State private var deletingSite: SavedSite?
    @State private var deletingItem: ContinueWatchingItem?
    @State private var showingWatchlistImporter = false
    @State private var showingAddWatchlistItem = false
    @State private var editingWatchlistItem: WatchlistItem?
    @State private var deletingWatchlistItem: WatchlistItem?
    @State private var importMessage: String?
    @State private var sitesExpanded = true
    @State private var continueWatchingExpanded = true
    @State private var watchlistExpanded = true

    var body: some View {
        List(selection: selectionBinding) {
            searchButton
            sitesSection
            continueWatchingSection
            watchlistSection
        }
        .listStyle(.sidebar)
        .frame(minWidth: 240)
        .sheet(item: $editingSite) { site in
            SiteEditorView(
                model: model,
                mode: .edit(site)
            )
        }
        .sheet(item: $renamingItem) { item in
            RenameContinueWatchingView(item: item) { title in
                model.continueWatchingStore.rename(id: item.id, to: title)
            }
        }
        .sheet(isPresented: $showingAddWatchlistItem) {
            WatchlistItemEditorView { title, year, url in
                model.addWatchlistItem(
                    title: title,
                    year: year,
                    url: url
                )
            }
        }
        .sheet(item: $editingWatchlistItem) { item in
            WatchlistItemEditorView(item: item) { title, year, url in
                model.updateWatchlistItem(
                    item,
                    title: title,
                    year: year,
                    url: url
                )
            }
        }
        .fileImporter(
            isPresented: $showingWatchlistImporter,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false,
            onCompletion: importWatchlist
        )
        .alert(
            "Delete Site?",
            isPresented: presenting($deletingSite),
            presenting: deletingSite
        ) { site in
            Button("Delete", role: .destructive) {
                model.deleteSite(site)
                deletingSite = nil
            }
            Button("Cancel", role: .cancel) {
                deletingSite = nil
            }
        } message: { _ in
            Text("This removes the site and its Continue Watching entries from Wianu.")
        }
        .alert(
            "Remove from Continue Watching?",
            isPresented: presenting($deletingItem),
            presenting: deletingItem
        ) { item in
            Button("Remove", role: .destructive) {
                model.removeContinueWatchingItem(item)
                deletingItem = nil
            }
            Button("Cancel", role: .cancel) {
                deletingItem = nil
            }
        } message: { item in
            Text("“\(item.title)” will be removed.")
        }
        .alert(
            "Letterboxd Import",
            isPresented: presenting($importMessage),
            presenting: importMessage
        ) { _ in
            Button("OK") {
                importMessage = nil
            }
        } message: { message in
            Text(message)
        }
        .alert(
            "Remove from Watchlist?",
            isPresented: presenting($deletingWatchlistItem),
            presenting: deletingWatchlistItem
        ) { item in
            Button("Remove", role: .destructive) {
                model.removeWatchlistItem(item)
                deletingWatchlistItem = nil
            }
            Button("Cancel", role: .cancel) {
                deletingWatchlistItem = nil
            }
        } message: { item in
            Text("“\(item.title)” will be removed.")
        }
    }

    private var searchButton: some View {
        Button {
            model.showCommandPalette()
        } label: {
            Label("Search", systemImage: "magnifyingglass")
        }
        .buttonStyle(.plain)
    }

    private var sitesSection: some View {
        Section("Sites", isExpanded: $sitesExpanded) {
            ForEach(model.siteStore.sites) { site in
                SiteRow(site: site)
                    .tag(SidebarSelection.site(site.id))
                    .contextMenu {
                        Button("Edit") { editingSite = site }
                        Divider()
                        Button("Delete", role: .destructive) {
                            deletingSite = site
                        }
                    }
            }
            Button {
                showingAddSite = true
            } label: {
                Label("Add Site", systemImage: "plus")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var continueWatchingSection: some View {
        if !model.continueWatchingStore.sortedItems.isEmpty {
            Section(
                "Continue Watching",
                isExpanded: $continueWatchingExpanded
            ) {
                ForEach(model.continueWatchingStore.sortedItems) { item in
                    ContinueWatchingRow(item: item, site: site(for: item))
                        .tag(SidebarSelection.continueWatching(item.id))
                        .contextMenu {
                            Button("Rename") { renamingItem = item }
                            Divider()
                            Button("Remove", role: .destructive) {
                                deletingItem = item
                            }
                        }
                }
            }
        }
    }

    private var watchlistSection: some View {
        Section("Watchlist", isExpanded: $watchlistExpanded) {
            ForEach(model.watchlistStore.items) { item in
                WatchlistRow(item: item)
                    .tag(SidebarSelection.watchlistItem(item.id))
                    .contextMenu { watchlistContextMenu(for: item) }
            }
            Button {
                showingAddWatchlistItem = true
            } label: {
                Label("Add Movie", systemImage: "plus")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            Button {
                showingWatchlistImporter = true
            } label: {
                Label(
                    "Import Letterboxd CSV…",
                    systemImage: "square.and.arrow.down"
                )
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func watchlistContextMenu(for item: WatchlistItem) -> some View {
        Button("Find Providers") {
            model.showCommandPalette(query: item.title)
        }
        Divider()
        if item.source == .custom {
            Button("Edit") { editingWatchlistItem = item }
            Divider()
        }
        Button("Remove", role: .destructive) {
            deletingWatchlistItem = item
        }
    }

    private var selectionBinding: Binding<SidebarSelection?> {
        Binding(
            get: { model.selection },
            set: model.select
        )
    }

    private func site(for item: ContinueWatchingItem) -> SavedSite? {
        model.siteStore.sites.first { $0.id == item.siteID }
    }

    private func importWatchlist(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            guard let url = urls.first else { return }
            Task {
                await importWatchlist(from: url)
            }

        case let .failure(error):
            if (error as? CocoaError)?.code != .userCancelled {
                importMessage = error.localizedDescription
            }
        }
    }

    private static let maximumImportBytes = 10 * 1_048_576

    private func importWatchlist(from url: URL) async {
        let hasSecurityAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let maximumBytes = Self.maximumImportBytes
            let result = try await Task.detached {
                try LetterboxdWatchlistImporter.importItems(
                    contentsOf: url,
                    maximumBytes: maximumBytes
                )
            }.value
            model.replaceImportedWatchlistItems(with: result.items)

            if let error = model.watchlistStore.persistenceError {
                importMessage = """
                Imported \(result.items.count) items for this session, \
                but they could not be saved: \(error)
                """
            } else if result.skippedRowCount > 0 {
                model.letterboxdImportSucceeded()
                importMessage = """
                Imported \(result.items.count) items. \
                Skipped \(result.skippedRowCount) invalid or duplicate rows.
                """
            } else {
                model.letterboxdImportSucceeded()
                importMessage = "Imported \(result.items.count) watchlist items."
            }
        } catch {
            importMessage = error.localizedDescription
        }
    }

    private func presenting(_ item: Binding<(some Any)?>) -> Binding<Bool> {
        Binding(
            get: { item.wrappedValue != nil },
            set: { isPresented in
                if !isPresented {
                    item.wrappedValue = nil
                }
            }
        )
    }
}
