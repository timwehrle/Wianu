import SwiftUI

struct ContentView: View {
    @State private var model = AppModel()

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
    }
}
