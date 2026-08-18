import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    struct NavigationRequest: Identifiable, Sendable {
        let id = UUID()
        let url: URL
    }

    let siteStore: SiteStore
    let continueWatchingStore: ContinueWatchingStore
    let watchlistStore: WatchlistStore
    private(set) var tmdbClient: TMDBClient
    private(set) var tmdbSearch: TMDBSearchModel
    private(set) var isCommandPalettePresented = false
    private(set) var analyticsEnabled: Bool

    private(set) var selection: SidebarSelection?
    private(set) var navigationRequest: NavigationRequest?
    @ObservationIgnored
    private let userDefaults: UserDefaults
    @ObservationIgnored
    private let analytics: any AnalyticsTracking

    private static let lastSelectedSiteKey = "lastSelectedSiteID"

    var destinationURL: URL? {
        navigationRequest?.url
    }

    init() {
        siteStore = SiteStore()
        continueWatchingStore = ContinueWatchingStore()
        watchlistStore = WatchlistStore()
        userDefaults = .standard
        let analytics = AnalyticsClient(userDefaults: userDefaults)
        self.analytics = analytics
        analyticsEnabled = analytics.isEnabled
        let client = TMDBClient()
        tmdbClient = client
        tmdbSearch = TMDBSearchModel(
            client: client,
            userDefaults: userDefaults
        )
        restoreSelection()
        analytics.track(.appLaunched)
    }

    init(
        siteStore: SiteStore,
        continueWatchingStore: ContinueWatchingStore,
        watchlistStore: WatchlistStore,
        userDefaults: UserDefaults,
        tmdbClient: TMDBClient,
        analytics: (any AnalyticsTracking)? = nil
    ) {
        self.siteStore = siteStore
        self.continueWatchingStore = continueWatchingStore
        self.watchlistStore = watchlistStore
        self.userDefaults = userDefaults
        let analytics = analytics ?? DisabledAnalyticsTracker()
        self.analytics = analytics
        analyticsEnabled = analytics.isEnabled
        self.tmdbClient = tmdbClient
        tmdbSearch = TMDBSearchModel(
            client: tmdbClient,
            userDefaults: userDefaults
        )
        restoreSelection()
        analytics.track(.appLaunched)
    }

    var selectedSite: SavedSite? {
        guard let selectedSiteID else { return nil }
        return siteStore.sites.first { $0.id == selectedSiteID }
    }

    var selectedContinueWatchingItem: ContinueWatchingItem? {
        guard case let .continueWatching(itemID) = selection else { return nil }
        return continueWatchingStore.item(id: itemID)
    }

    func destination(for selection: SidebarSelection?) -> URL? {
        switch selection {
        case let .site(siteID):
            siteStore.sites.first { $0.id == siteID }?.url
        case let .continueWatching(itemID):
            continueWatchingStore.item(id: itemID)?.url
        case let .watchlistItem(itemID):
            watchlistStore.item(id: itemID)?.url
        case nil:
            nil
        }
    }

    func search(_ query: String, in site: SavedSite) {
        guard let searchURL = site.searchURL(for: query) else { return }

        dismissCommandPalette()
        select(.site(site.id))
        navigate(to: searchURL)
    }

    func showCommandPalette(query: String? = nil) {
        tmdbSearch.clearSelection()
        if let query {
            tmdbSearch.query = query
        } else {
            tmdbSearch.query = ""
        }
        tmdbSearch.queryChanged()
        isCommandPalettePresented = true
        tmdbSearch.requestFocus()
        analytics.track(.searchOpened)
    }

    func setAnalyticsEnabled(_ enabled: Bool) {
        analytics.setEnabled(enabled)
        analyticsEnabled = enabled
    }

    func settingsOpened() {
        analytics.track(.settingsOpened)
    }

    func updateCheckStarted() {
        analytics.track(.updateCheckStarted)
    }

    func addSite(_ draft: SiteDraft) {
        guard draft.validatedValues != nil else { return }
        siteStore.addSite(draft)
        analytics.track(.siteAdded)
    }

    func updateSite(_ site: SavedSite, with draft: SiteDraft) {
        guard draft.validatedValues != nil else { return }
        siteStore.updateSite(id: site.id, with: draft)
        analytics.track(.siteEdited)
    }

    func dismissCommandPalette() {
        isCommandPalettePresented = false
    }

    func openProvider(_ provider: TMDBProvider, for media: TMDBMediaResult) {
        guard
            let site = siteStore.sites.first(where: {
                $0.tmdbProvider?.matches(provider) == true
                    && $0.isTMDBProviderActionable
            })
        else { return }
        search(media.title, in: site)
    }

    func site(for provider: TMDBProvider) -> SavedSite? {
        siteStore.sites.first {
            $0.tmdbProvider?.matches(provider) == true
        }
    }

    func select(_ newSelection: SidebarSelection?) {
        isCommandPalettePresented = false
        selection = newSelection
        navigate(to: destination(for: newSelection))

        if case let .continueWatching(itemID) = newSelection {
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
            navigate(to: nil)
        }

        continueWatchingStore.removeItems(forSiteID: site.id)
        siteStore.deleteSite(id: site.id)
        analytics.track(.siteDeleted)

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
        analytics.track(.continueWatchingItemRemoved)
    }

    func replaceImportedWatchlistItems(
        with items: [WatchlistItem]
    ) {
        let selectedItemID: WatchlistItem.ID? =
            if case let .watchlistItem(itemID) = selection {
                itemID
            } else {
                nil
            }

        watchlistStore.replace(with: items)

        if let selectedItemID,
           watchlistStore.item(id: selectedItemID) == nil
        {
            selection = nil
            navigate(to: nil)
        }
    }

    func letterboxdImportSucceeded() {
        analytics.track(.letterboxdImportSucceeded)
    }

    func addWatchlistItem(title: String, year: Int?, url: URL?) {
        watchlistStore.add(title: title, year: year, url: url)
        analytics.track(.watchlistItemAdded)
    }

    func updateWatchlistItem(
        _ item: WatchlistItem,
        title: String,
        year: Int?,
        url: URL?
    ) {
        watchlistStore.update(
            id: item.id,
            title: title,
            year: year,
            url: url
        )
    }

    func removeWatchlistItem(_ item: WatchlistItem) {
        if selection == .watchlistItem(item.id) {
            select(nil)
        }
        watchlistStore.remove(id: item.id)
        analytics.track(.watchlistItemRemoved)
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
            let savedTitle: String =
                if let site = selectedSite {
                    PageTitleCleaner.clean(
                        trimmedTitle,
                        siteName: site.name
                    )
                } else {
                    trimmedTitle.isEmpty
                        ? url.host() ?? "Untitled Page"
                        : trimmedTitle
                }

            continueWatchingStore.save(
                siteID: selectedSite?.id,
                title: savedTitle,
                url: url
            )
            analytics.track(.continueWatchingItemAdded)
        }
    }

    func toggleWatchlist(title: String, url: URL) {
        if let item = watchlistStore.item(matching: url) {
            removeWatchlistItem(item)
            return
        }

        let trimmedTitle = title.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let savedTitle: String =
            if let site = selectedSite {
                PageTitleCleaner.clean(
                    trimmedTitle,
                    siteName: site.name
                )
            } else {
                trimmedTitle.isEmpty
                    ? url.host() ?? "Untitled Movie"
                    : trimmedTitle
            }

        watchlistStore.add(
            title: savedTitle,
            year: nil,
            url: url
        )
        analytics.track(.watchlistItemAdded)
    }

    private var selectedSiteID: SavedSite.ID? {
        switch selection {
        case let .site(siteID):
            siteID
        case let .continueWatching(itemID):
            continueWatchingStore.item(id: itemID)?.siteID
        case .watchlistItem:
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

        navigate(to: destination(for: selection))
    }

    private func navigate(to url: URL?) {
        navigationRequest = url.map(NavigationRequest.init(url:))
    }

    private func normalizedHost(for url: URL?) -> String? {
        guard var host = url?.host()?.lowercased() else { return nil }

        if host.hasPrefix("www.") {
            host.removeFirst(4)
        }

        return host
    }
}
