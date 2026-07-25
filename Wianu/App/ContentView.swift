import SwiftUI

struct ContentView: View {
    @State private var model = AppModel()

    var body: some View {
        NavigationSplitView {
            SidebarView(model: model)
        } detail: {
            BrowserView(model: model)
        }
        .navigationTitle("Wianu")
    }
}
