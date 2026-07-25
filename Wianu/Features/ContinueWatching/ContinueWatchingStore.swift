//
//  ContinueWatchingStore.swift
//  Wianu
//
//  Created by Tim on 25.07.26.
//

import Foundation
import Observation

@MainActor
@Observable
final class ContinueWatchingStore {
    private(set) var items: [ContinueWatchingItem] = []
    private(set) var persistenceError: String?

    private let maximumItemCount: Int

    @ObservationIgnored
    private let fileStore: JSONFileStore<[ContinueWatchingItem]>

    init(
        maximumItemCount: Int = 50,
        fileStore: JSONFileStore<[ContinueWatchingItem]> = JSONFileStore(
            fileName: "continue-watching.json",
            folderName: "Wianu"
        )
    ) {
        self.maximumItemCount = maximumItemCount
        self.fileStore = fileStore
        load()
    }

    var sortedItems: [ContinueWatchingItem] {
        items.sorted {
            $0.lastOpenedAt > $1.lastOpenedAt
        }
    }

    func item(id: ContinueWatchingItem.ID) -> ContinueWatchingItem? {
        items.first { $0.id == id }
    }

    func contains(url: URL) -> Bool {
        item(matching: url) != nil
    }

    func item(matching url: URL) -> ContinueWatchingItem? {
        let key = URLNormalizer.comparisonKey(for: url)

        return items.first {
            URLNormalizer.comparisonKey(for: $0.url) == key
        }
    }

    @discardableResult
    func save(
        siteID: SavedSite.ID,
        title: String,
        url: URL
    ) -> ContinueWatchingItem {
        let normalizedURL = URLNormalizer.continueWatchingURL(url)
        let comparisonKey = URLNormalizer.comparisonKey(for: normalizedURL)
        let now = Date()

        if let index = items.firstIndex(where: {
            URLNormalizer.comparisonKey(for: $0.url) == comparisonKey
        }) {
            items[index].siteID = siteID
            items[index].title = title
            items[index].url = normalizedURL
            items[index].lastOpenedAt = now

            trimItemsIfNeeded()
            persist()

            return items[index]
        }

        let item = ContinueWatchingItem(
            siteID: siteID,
            title: title,
            url: normalizedURL,
            dateAdded: now,
            lastOpenedAt: now
        )

        items.append(item)

        trimItemsIfNeeded()
        persist()

        return item
    }

    func markOpened(id: ContinueWatchingItem.ID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            return
        }

        items[index].lastOpenedAt = .now
        persist()
    }

    func remove(id: ContinueWatchingItem.ID) {
        items.removeAll { $0.id == id }
        persist()
    }

    func removeItems(forSiteID siteID: SavedSite.ID) {
        let originalCount = items.count

        items.removeAll {
            $0.siteID == siteID
        }

        guard items.count != originalCount else {
            return
        }

        persist()
    }

    func removeAll() {
        guard !items.isEmpty else {
            return
        }

        items.removeAll()
        persist()
    }

    private func load() {
        do {
            items = try fileStore.load(defaultValue: [])
            trimItemsIfNeeded()
            persistenceError = nil
        } catch {
            items = []
            persistenceError = error.localizedDescription
        }
    }

    private func persist() {
        do {
            try fileStore.save(items)
            persistenceError = nil
        } catch {
            persistenceError = error.localizedDescription
        }
    }

    private func trimItemsIfNeeded() {
        guard items.count > maximumItemCount else {
            return
        }

        items = Array(
            items
                .sorted { $0.lastOpenedAt > $1.lastOpenedAt }
                .prefix(maximumItemCount)
        )
    }
}
