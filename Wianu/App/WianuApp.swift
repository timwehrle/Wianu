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
            VideoInformationCommands()

            CommandGroup(after: .appInfo) {
                Button {
                    model.updateCheckStarted()
                    updateService.checkForUpdates()
                } label: {
                    Label(
                        "Check for Updates…",
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                }
                .disabled(!updateService.canCheckForUpdates)
            }

            CommandGroup(after: .help) {
                Link(
                    "Send Feedback…",
                    destination: URL(
                        string: "https://github.com/timwehrle/Wianu/issues/new/choose"
                    )!
                )
            }
        }
        Settings {
            SettingsView(model: model)
        }
    }
}

struct ShowVideoInformationKey: FocusedValueKey {
    typealias Value = @MainActor () -> Void
}

extension FocusedValues {
    var showVideoInformation: ShowVideoInformationKey.Value? {
        get { self[ShowVideoInformationKey.self] }
        set { self[ShowVideoInformationKey.self] = newValue }
    }
}

private struct VideoInformationCommands: Commands {
    @FocusedValue(\.showVideoInformation) private var showVideoInformation

    var body: some Commands {
        CommandMenu("Debug") {
            Button("Video Information…") {
                showVideoInformation?()
            }
            .disabled(showVideoInformation == nil)
        }
    }
}
