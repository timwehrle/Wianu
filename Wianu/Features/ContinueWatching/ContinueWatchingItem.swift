import Foundation

struct ContinueWatchingItem: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var siteID: SavedSite.ID

    var title: String
    var url: URL
    var dateAdded: Date
    var lastOpenedAt: Date

    init(
        id: UUID = UUID(),
        siteID: SavedSite.ID,
        title: String,
        url: URL,
        dateAdded: Date = .now,
        lastOpenedAt: Date = .now
    ) {
        self.id = id
        self.siteID = siteID
        self.title = title
        self.url = url
        self.dateAdded = dateAdded
        self.lastOpenedAt = lastOpenedAt
    }
}
