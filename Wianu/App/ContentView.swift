import SwiftUI

struct ContentView: View {
    @Bindable var model: AppModel

    var body: some View {
        NavigationSplitView {
            SidebarView(model: model)
        } detail: {
            ZStack {
                BrowserView(model: model)
                    .opacity(model.selection == .search ? 0 : 1)
                    .allowsHitTesting(model.selection != .search)
                    .accessibilityHidden(model.selection == .search)

                if model.selection == .search {
                    StreamingSearchView(model: model)
                        .background(.background)
                }
            }
        }
        .navigationTitle("Wianu")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if model.selection == .search {
                    Button {
                        model.dismissSearch()
                    } label: {
                        Label("Close Search", systemImage: "xmark")
                    }
                    .keyboardShortcut(.cancelAction)
                    .help("Return to Stream")
                } else {
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
}
