import Foundation

struct LetterboxdWatchlistItem: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let title: String
    let year: Int?
    let letterboxdURL: URL
    let addedAt: Date?
    let sourceOrder: Int

    init(
        id: UUID = UUID(),
        title: String,
        year: Int?,
        letterboxdURL: URL,
        addedAt: Date?,
        sourceOrder: Int
    ) {
        self.id = id
        self.title = title
        self.year = year
        self.letterboxdURL = letterboxdURL
        self.addedAt = addedAt
        self.sourceOrder = sourceOrder
    }
}
