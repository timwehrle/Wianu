import Combine
import Sparkle

@MainActor
final class UpdateService: ObservableObject {
    @Published private(set) var canCheckForUpdates = false

    private let controller: SPUStandardUpdaterController

    init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        controller.updater.publisher(for: \.canCheckForUpdates).assign(
            to: &$canCheckForUpdates
        )
    }

    func checkForUpdates() {
        controller.updater.checkForUpdates()
    }
}
