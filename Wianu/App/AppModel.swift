import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    let siteStore: SiteStore
    let continueWatchingStore: ContinueWatchingStore

    private(set) var selection: SidebarSelection?

    @ObservationIgnored
    private let userDefaults: UserDefaults

    private static let lastSelectedSiteKey = "lastSelectedSiteID"

    init() {
        siteStore = SiteStore()
        continueWatchingStore = ContinueWatchingStore()
        userDefaults = .standard
        restoreSelection()
    }

    init(
        siteStore: SiteStore,
        continueWatchingStore: ContinueWatchingStore,
        userDefaults: UserDefaults
    ) {
        self.siteStore = siteStore
        self.continueWatchingStore = continueWatchingStore
        self.userDefaults = userDefaults
        restoreSelection()
    }

    var selectedSite: SavedSite? {
        guard let selectedSiteID else { return nil }
        return siteStore.sites.first { $0.id == selectedSiteID }
    }

    var selectedContinueWatchingItem: ContinueWatchingItem? {
        guard case .continueWatching(let itemID) = selection else { return nil }
        return continueWatchingStore.item(id: itemID)
    }

    var destinationURL: URL? {
        switch selection {
        case .site(let siteID):
            siteStore.sites.first { $0.id == siteID }?.url
        case .continueWatching(let itemID):
            continueWatchingStore.item(id: itemID)?.url
        case nil:
            nil
        }
    }

    func select(_ newSelection: SidebarSelection?) {
        selection = newSelection

        if case .continueWatching(let itemID) = newSelection {
            continueWatchingStore.markOpened(id: itemID)
        }

        if let selectedSiteID {
            userDefaults.set(
                selectedSiteID.uuidString,
                forKey: Self.lastSelectedSiteKey
            )
        }
    }

    func deleteSite(_ site: SavedSite) {
        if selectedSiteID == site.id {
            selection = nil
        }

        continueWatchingStore.removeItems(forSiteID: site.id)
        siteStore.deleteSite(id: site.id)

        if userDefaults.string(forKey: Self.lastSelectedSiteKey) == site.id.uuidString {
            userDefaults.removeObject(forKey: Self.lastSelectedSiteKey)
        }
    }

    func removeContinueWatchingItem(_ item: ContinueWatchingItem) {
        if selection == .continueWatching(item.id) {
            selection = .site(item.siteID)
        }

        continueWatchingStore.remove(id: item.id)
    }

    func toggleContinueWatching(title: String, url: URL) {
        guard let site = selectedSite else { return }

        if let item = continueWatchingStore.item(matching: url) {
            removeContinueWatchingItem(item)
        } else {
            continueWatchingStore.save(
                siteID: site.id,
                title: PageTitleCleaner.clean(title, siteName: site.name),
                url: url
            )
        }
    }

    private var selectedSiteID: SavedSite.ID? {
        switch selection {
        case .site(let siteID):
            siteID
        case .continueWatching(let itemID):
            continueWatchingStore.item(id: itemID)?.siteID
        case nil:
            nil
        }
    }

    private func restoreSelection() {
        let savedID = userDefaults
            .string(forKey: Self.lastSelectedSiteKey)
            .flatMap(UUID.init(uuidString:))

        if let savedID, siteStore.sites.contains(where: { $0.id == savedID }) {
            selection = .site(savedID)
        } else if let firstSite = siteStore.sites.first {
            selection = .site(firstSite.id)
        }
    }
}
