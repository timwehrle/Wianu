import SwiftUI
import UniformTypeIdentifiers

struct SidebarView: View {
    @Bindable var model: AppModel

    @State private var showingAddSite = false
    @State private var editingSite: SavedSite?
    @State private var renamingItem: ContinueWatchingItem?
    @State private var deletingSite: SavedSite?
    @State private var deletingItem: ContinueWatchingItem?
    @State private var showingWatchlistImporter = false
    @State private var importMessage: String?
    @State private var sitesExpanded = true
    @State private var continueWatchingExpanded = true
    @State private var letterboxdWatchlistExpanded = true

    var body: some View {
        List(selection: selectionBinding) {
            Section("Sites", isExpanded: $sitesExpanded) {
                ForEach(model.siteStore.sites) { site in
                    SiteRow(site: site)
                        .tag(SidebarSelection.site(site.id))
                        .contextMenu {
                            Button("Edit") {
                                editingSite = site
                            }

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

            if !model.continueWatchingStore.sortedItems.isEmpty {
                Section("Continue Watching", isExpanded: $continueWatchingExpanded) {
                    ForEach(model.continueWatchingStore.sortedItems) { item in
                        ContinueWatchingRow(
                            item: item,
                            site: site(for: item)
                        )
                        .tag(SidebarSelection.continueWatching(item.id))
                        .contextMenu {
                            Button("Rename") {
                                renamingItem = item
                            }

                            Divider()

                            Button("Remove", role: .destructive) {
                                deletingItem = item
                            }
                        }
                    }
                }
            }

            Section("Letterboxd Watchlist", isExpanded: $letterboxdWatchlistExpanded) {
                ForEach(model.letterboxdWatchlistStore.items) { item in
                    LetterboxdWatchlistRow(item: item)
                        .tag(
                            SidebarSelection.letterboxdWatchlistItem(item.id)
                        )
                }

                Button {
                    showingWatchlistImporter = true
                } label: {
                    Label("Import Watchlist…", systemImage: "square.and.arrow.down")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 240)
        .sheet(isPresented: $showingAddSite) {
            SiteEditorView(store: model.siteStore, mode: .add)
        }
        .sheet(item: $editingSite) { site in
            SiteEditorView(store: model.siteStore, mode: .edit(site))
        }
        .sheet(item: $renamingItem) { item in
            RenameContinueWatchingView(item: item) { title in
                model.continueWatchingStore.rename(id: item.id, to: title)
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
        case .success(let urls):
            guard let url = urls.first else { return }
            importWatchlist(from: url)

        case .failure(let error):
            if (error as? CocoaError)?.code != .userCancelled {
                importMessage = error.localizedDescription
            }
        }
    }

    private func importWatchlist(from url: URL) {
        let hasSecurityAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let result = try LetterboxdWatchlistImporter.importItems(
                from: Data(contentsOf: url)
            )
            model.replaceLetterboxdWatchlist(with: result.items)

            if let error = model.letterboxdWatchlistStore.persistenceError {
                importMessage = """
                    Imported \(result.items.count) items for this session, \
                    but they could not be saved: \(error)
                    """
            } else if result.skippedRowCount > 0 {
                importMessage = """
                    Imported \(result.items.count) items. \
                    Skipped \(result.skippedRowCount) invalid or duplicate rows.
                    """
            } else {
                importMessage = "Imported \(result.items.count) watchlist items."
            }
        } catch {
            importMessage = error.localizedDescription
        }
    }

    private func presenting<Item>(_ item: Binding<Item?>) -> Binding<Bool> {
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
