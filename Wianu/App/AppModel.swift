import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    let siteStore: SiteStore
    let continueWatchingStore: ContinueWatchingStore
    let letterboxdWatchlistStore: LetterboxdWatchlistStore

    private(set) var selection: SidebarSelection?
    private(set) var destinationURL: URL?
    var searchQuery = ""

    @ObservationIgnored
    private let userDefaults: UserDefaults

    private static let lastSelectedSiteKey = "lastSelectedSiteID"

    init() {
        siteStore = SiteStore()
        continueWatchingStore = ContinueWatchingStore()
        letterboxdWatchlistStore = LetterboxdWatchlistStore()
        userDefaults = .standard
        restoreSelection()
    }

    init(
        siteStore: SiteStore,
        continueWatchingStore: ContinueWatchingStore,
        letterboxdWatchlistStore: LetterboxdWatchlistStore,
        userDefaults: UserDefaults
    ) {
        self.siteStore = siteStore
        self.continueWatchingStore = continueWatchingStore
        self.letterboxdWatchlistStore = letterboxdWatchlistStore
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

    func destination(for selection: SidebarSelection?) -> URL? {
        switch selection {
        case .search:
            nil
        case .site(let siteID):
            siteStore.sites.first { $0.id == siteID }?.url
        case .continueWatching(let itemID):
            continueWatchingStore.item(id: itemID)?.url
        case .letterboxdWatchlistItem(let itemID):
            letterboxdWatchlistStore.item(id: itemID)?.letterboxdURL
        case nil:
            nil
        }
    }

    func search(_ query: String, in site: SavedSite) {
        guard let searchURL = site.searchURL(for: query) else { return }

        select(.site(site.id))
        destinationURL = searchURL
    }

    func select(_ newSelection: SidebarSelection?) {
        selection = newSelection
        destinationURL = destination(for: newSelection)

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
            destinationURL = nil
        }

        continueWatchingStore.removeItems(forSiteID: site.id)
        siteStore.deleteSite(id: site.id)

        if userDefaults.string(forKey: Self.lastSelectedSiteKey)
            == site.id.uuidString
        {
            userDefaults.removeObject(forKey: Self.lastSelectedSiteKey)
        }
    }

    func removeContinueWatchingItem(_ item: ContinueWatchingItem) {
        if selection == .continueWatching(item.id) {
            if let siteID = item.siteID {
                select(.site(siteID))
            } else {
                select(nil)
            }
        }

        continueWatchingStore.remove(id: item.id)
    }

    func replaceLetterboxdWatchlist(
        with items: [LetterboxdWatchlistItem]
    ) {
        let selectedItemID: LetterboxdWatchlistItem.ID?
        if case .letterboxdWatchlistItem(let itemID) = selection {
            selectedItemID = itemID
        } else {
            selectedItemID = nil
        }

        letterboxdWatchlistStore.replace(with: items)

        if let selectedItemID,
            letterboxdWatchlistStore.item(id: selectedItemID) == nil
        {
            selection = nil
            destinationURL = nil
        }
    }

    func activateSite(matching url: URL?) {
        guard
            let url,
            let host = normalizedHost(for: url),
            let site = siteStore.sites.first(where: {
                normalizedHost(for: $0.url) == host
            }),
            selection != .site(site.id)
        else { return }

        selection = .site(site.id)
        userDefaults.set(
            site.id.uuidString,
            forKey: Self.lastSelectedSiteKey
        )
    }

    func toggleContinueWatching(title: String, url: URL) {
        if let item = continueWatchingStore.item(matching: url) {
            removeContinueWatchingItem(item)
        } else {
            let trimmedTitle = title.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            let savedTitle: String

            if let site = selectedSite {
                savedTitle = PageTitleCleaner.clean(
                    trimmedTitle,
                    siteName: site.name
                )
            } else {
                savedTitle =
                    trimmedTitle.isEmpty
                    ? url.host() ?? "Untitled Page"
                    : trimmedTitle
            }

            continueWatchingStore.save(
                siteID: selectedSite?.id,
                title: savedTitle,
                url: url
            )
        }
    }

    private var selectedSiteID: SavedSite.ID? {
        switch selection {
        case .search:
            nil
        case .site(let siteID):
            siteID
        case .continueWatching(let itemID):
            continueWatchingStore.item(id: itemID)?.siteID
        case .letterboxdWatchlistItem:
            nil
        case nil:
            nil
        }
    }

    private func restoreSelection() {
        let savedID =
            userDefaults
            .string(forKey: Self.lastSelectedSiteKey)
            .flatMap(UUID.init(uuidString:))

        if let savedID, siteStore.sites.contains(where: { $0.id == savedID }) {
            selection = .site(savedID)
        } else if let firstSite = siteStore.sites.first {
            selection = .site(firstSite.id)
        }

        destinationURL = destination(for: selection)
    }

    private func normalizedHost(for url: URL?) -> String? {
        guard var host = url?.host()?.lowercased() else { return nil }

        if host.hasPrefix("www.") {
            host.removeFirst(4)
        }

        return host
    }
}
