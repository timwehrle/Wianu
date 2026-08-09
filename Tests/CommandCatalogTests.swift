import Foundation
import Testing
@testable import Wianu

@Suite("Command catalog")
struct CommandCatalogTests {
    @Test
    func `Empty query shows core commands and recent items`() {
        let site = SavedSite(name: "Netflix", urlString: "https://netflix.com")
        let items = (0 ..< 7).map { index in
            ContinueWatchingItem(
                siteID: site.id,
                title: "Show \(index)",
                url: URL(string: "https://netflix.com/show/\(index)")!,
                lastOpenedAt: Date(timeIntervalSince1970: TimeInterval(index))
            )
        }

        let commands = CommandCatalog.commands(
            matching: "",
            sites: [site],
            continueWatchingItems: items
        )

        #expect(commands.contains { $0.action == .addSite })
        #expect(commands.contains { $0.action == .openSettings })
        #expect(commands.contains { $0.action == .openSite(site.id) })
        #expect(commands.filter {
            if case .continueWatching = $0.action {
                return true
            }
            return false
        }.count == 5)
        #expect(commands.last?.title == "Continue Show 2")
    }

    @Test
    func `Matching ignores case and diacritics`() {
        let site = SavedSite(name: "Mubi Café", urlString: "https://mubi.com")
        let commands = CommandCatalog.commands(
            matching: "CAFE",
            sites: [site],
            continueWatchingItems: []
        )

        #expect(commands.first?.action == .openSite(site.id))
    }
}
