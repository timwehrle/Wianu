import SwiftUI

struct SidebarView: View {
    @Bindable var model: AppModel

    @State private var showingAddSite = false
    @State private var editingSite: SavedSite?
    @State private var deletingSite: SavedSite?
    @State private var deletingItem: ContinueWatchingItem?
    @State private var sitesExpanded = true
    @State private var continueWatchingExpanded = true

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
                            Button("Remove", role: .destructive) {
                                deletingItem = item
                            }
                        }
                    }
                }
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
