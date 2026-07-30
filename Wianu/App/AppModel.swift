import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    let siteStore: SiteStore
    let continueWatchingStore: ContinueWatchingStore
    let watchlistStore: WatchlistStore
    private(set) var tmdbClient: TMDBClient
    private(set) var tmdbSearch: TMDBSearchModel
    private(set) var hasStoredTMDBToken: Bool
    private(set) var tmdbCredentialError: String?

    private(set) var selection: SidebarSelection?
    private(set) var destinationURL: URL?
    @ObservationIgnored
    private let userDefaults: UserDefaults
    @ObservationIgnored
    private let tmdbCredentialStore: any TMDBCredentialStoring

    private static let lastSelectedSiteKey = "lastSelectedSiteID"

    init(
        tmdbCredentialStore: any TMDBCredentialStoring =
            KeychainTMDBCredentialStore()
    ) {
        siteStore = SiteStore()
        continueWatchingStore = ContinueWatchingStore()
        watchlistStore = WatchlistStore()
        userDefaults = .standard
        self.tmdbCredentialStore = tmdbCredentialStore

        let storedToken: String?
        do {
            storedToken = try tmdbCredentialStore.loadToken()
            tmdbCredentialError = nil
        } catch {
            storedToken = nil
            tmdbCredentialError = error.localizedDescription
        }
        hasStoredTMDBToken = storedToken != nil
        let client = storedToken.map { TMDBClient(token: $0) } ?? TMDBClient()
        tmdbClient = client
        tmdbSearch = TMDBSearchModel(
            client: client,
            userDefaults: userDefaults
        )
        restoreSelection()
    }

    init(
        siteStore: SiteStore,
        continueWatchingStore: ContinueWatchingStore,
        watchlistStore: WatchlistStore,
        userDefaults: UserDefaults,
        tmdbClient: TMDBClient,
        tmdbCredentialStore: any TMDBCredentialStoring =
            KeychainTMDBCredentialStore()
    ) {
        self.siteStore = siteStore
        self.continueWatchingStore = continueWatchingStore
        self.watchlistStore = watchlistStore
        self.userDefaults = userDefaults
        self.tmdbCredentialStore = tmdbCredentialStore
        hasStoredTMDBToken = false
        tmdbCredentialError = nil
        self.tmdbClient = tmdbClient
        tmdbSearch = TMDBSearchModel(
            client: tmdbClient,
            userDefaults: userDefaults
        )
        restoreSelection()
    }

    func saveTMDBToken(_ token: String) async throws {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TMDBCredentialError.emptyToken }

        do {
            let client = TMDBClient(token: trimmed)
            _ = try await client.imageConfiguration()
            try tmdbCredentialStore.saveToken(trimmed)
            hasStoredTMDBToken = true
            tmdbCredentialError = nil
            configureTMDB(client)
        } catch {
            tmdbCredentialError = error.localizedDescription
            throw error
        }
    }

    func removeStoredTMDBToken() throws {
        do {
            try tmdbCredentialStore.removeToken()
            hasStoredTMDBToken = false
            tmdbCredentialError = nil
            configureTMDB(TMDBClient())
        } catch {
            tmdbCredentialError = error.localizedDescription
            throw error
        }
    }

    private func configureTMDB(_ client: TMDBClient) {
        let query = tmdbSearch.query
        tmdbClient = client
        tmdbSearch = TMDBSearchModel(
            client: client,
            userDefaults: userDefaults
        )
        if !query.isEmpty, client.isConfigured {
            tmdbSearch.query = query
            tmdbSearch.queryChanged()
        }
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
        case .search:
            nil
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

        select(.site(site.id))
        destinationURL = searchURL
    }

    func showSearch(query: String? = nil) {
        if let query {
            tmdbSearch.query = query
            tmdbSearch.queryChanged()
        }
        select(.search)
        tmdbSearch.requestFocus()
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
        selection = newSelection
        destinationURL = destination(for: newSelection)

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

    func replaceImportedWatchlistItems(
        with items: [WatchlistItem]
    ) {
        let selectedItemID: WatchlistItem.ID? = if case let .watchlistItem(itemID) = selection {
            itemID
        } else {
            nil
        }

        watchlistStore.replace(with: items)

        if let selectedItemID,
           watchlistStore.item(id: selectedItemID) == nil
        {
            selection = nil
            destinationURL = nil
        }
    }

    func removeWatchlistItem(_ item: WatchlistItem) {
        if selection == .watchlistItem(item.id) {
            select(nil)
        }
        watchlistStore.remove(id: item.id)
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
            let savedTitle: String = if let site = selectedSite {
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
        let savedTitle: String = if let site = selectedSite {
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
    }

    private var selectedSiteID: SavedSite.ID? {
        switch selection {
        case .search:
            nil
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
