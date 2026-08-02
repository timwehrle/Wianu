import SwiftUI

struct ContentView: View {
    @Bindable var model: AppModel

    var body: some View {
        NavigationSplitView {
            SidebarView(model: model)
        } detail: {
            ZStack {
                BrowserView(model: model)
                    .allowsHitTesting(model.selection != .search)
                    .accessibilityHidden(model.selection == .search)

                if model.selection == .search {
                    Color.black.opacity(0.22)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            model.dismissSearch()
                        }

                    StreamingSearchView(model: model)
                        .frame(maxWidth: 760, maxHeight: 640)
                        .background(
                            .regularMaterial,
                            in: RoundedRectangle(
                                cornerRadius: 18,
                                style: .continuous
                            )
                        )
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 18,
                                style: .continuous
                            )
                        )
                        .overlay {
                            RoundedRectangle(
                                cornerRadius: 18,
                                style: .continuous
                            )
                            .stroke(.separator.opacity(0.7), lineWidth: 1)
                        }
                        .shadow(color: .black.opacity(0.28), radius: 30, y: 12)
                        .padding(32)
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
