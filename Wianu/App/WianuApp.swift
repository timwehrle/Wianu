import SwiftUI

@main
struct WianuApp: App {
    @StateObject private var updateService = UpdateService()
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
        }
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(after: .appInfo) {
                Button {
                    updateService.checkForUpdates()
                } label: {
                    Label(
                        "Check for Updates…",
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                }
                .disabled(!updateService.canCheckForUpdates)
            }
        }
        Settings {
            SettingsView(model: model)
        }
    }
}
