import SwiftUI

struct ContentView: View {
    @Bindable var model: AppModel
    @Environment(\.openSettings) private var openSettings
    @State private var showingAddSite = false

    var body: some View {
        NavigationSplitView {
            SidebarView(
                model: model,
                showingAddSite: $showingAddSite
            )
        } detail: {
            ZStack {
                BrowserView(model: model)
                    .allowsHitTesting(!model.isCommandPalettePresented)
                    .accessibilityHidden(model.isCommandPalettePresented)

                if model.isCommandPalettePresented {
                    Color.black.opacity(0.22)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            model.dismissCommandPalette()
                        }

                    CommandPaletteView(
                        model: model,
                        onAction: perform,
                        onDismiss: model.dismissCommandPalette
                    )
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
        .sheet(isPresented: $showingAddSite) {
            SiteEditorView(
                store: model.siteStore,
                tmdbClient: model.tmdbClient,
                mode: .add
            )
        }
        .toolbar {
            if model.isCommandPalettePresented {
            ToolbarItem(placement: .primaryAction) {
                    Button {
                        model.dismissCommandPalette()
                    } label: {
                        Label("Close Command Palette", systemImage: "xmark")
                    }
                    .help("Return to Stream")
                }
            }
        }
    }

    private func perform(_ action: CommandPaletteAction) {
        switch action {
        case let .openSite(siteID):
            model.select(.site(siteID))
        case let .continueWatching(itemID):
            model.select(.continueWatching(itemID))
        case .addSite:
            model.dismissCommandPalette()
            showingAddSite = true
        case .openSettings:
            model.dismissCommandPalette()
            openSettings()
        }
    }
}
