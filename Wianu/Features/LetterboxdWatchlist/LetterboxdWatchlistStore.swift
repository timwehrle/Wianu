import Foundation
import Observation

@MainActor
@Observable
final class LetterboxdWatchlistStore {
    private(set) var items: [LetterboxdWatchlistItem] = []
    private(set) var persistenceError: String?

    @ObservationIgnored
    private let fileStore: JSONFileStore<[LetterboxdWatchlistItem]>

    init(
        fileStore: JSONFileStore<[LetterboxdWatchlistItem]> = JSONFileStore(
            fileName: "letterboxd-watchlist.json",
            folderName: "Wianu"
        )
    ) {
        self.fileStore = fileStore
        load()
    }

    func item(id: LetterboxdWatchlistItem.ID) -> LetterboxdWatchlistItem? {
        items.first { $0.id == id }
    }

    func replace(with newItems: [LetterboxdWatchlistItem]) {
        let existingIDs = Dictionary(
            uniqueKeysWithValues: items.map {
                (urlKey($0.letterboxdURL), $0.id)
            }
        )

        items = newItems.map { item in
            LetterboxdWatchlistItem(
                id: existingIDs[urlKey(item.letterboxdURL)] ?? item.id,
                title: item.title,
                year: item.year,
                letterboxdURL: item.letterboxdURL,
                addedAt: item.addedAt,
                sourceOrder: item.sourceOrder
            )
        }
        persist()
    }

    private func load() {
        do {
            items = try fileStore.load(defaultValue: [])
                .sorted { $0.sourceOrder < $1.sourceOrder }
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

    private func urlKey(_ url: URL) -> String {
        url.absoluteString.lowercased()
    }
}
