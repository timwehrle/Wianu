import SwiftUI

struct ContentView: View {
    @Bindable var model: AppModel

    var body: some View {
        NavigationSplitView {
            SidebarView(model: model)
        } detail: {
            if model.selection == .search {
                StreamingSearchView(model: model)
            } else {
                BrowserView(model: model)
            }
        }
        .navigationTitle("Wianu")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    model.showSearch()
                } label: {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .keyboardShortcut("k", modifiers: .command)
                .help("Search Movies and TV Shows")
            }
        }
    }
}
