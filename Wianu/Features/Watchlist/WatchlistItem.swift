import Foundation

struct WatchlistItem: Identifiable, Codable, Hashable, Sendable {
    enum Source: String, Codable, Hashable, Sendable {
        case custom
        case letterboxd
    }

    let id: UUID
    let title: String
    let year: Int?
    let url: URL?
    let addedAt: Date?
    let sourceOrder: Int
    let source: Source

    init(
        id: UUID = UUID(),
        title: String,
        year: Int?,
        url: URL?,
        addedAt: Date?,
        sourceOrder: Int,
        source: Source
    ) {
        self.id = id
        self.title = title
        self.year = year
        self.url = url
        self.addedAt = addedAt
        self.sourceOrder = sourceOrder
        self.source = source
    }

    init(
        id: UUID = UUID(),
        title: String,
        year: Int?,
        letterboxdURL: URL,
        addedAt: Date?,
        sourceOrder: Int
    ) {
        self.init(
            id: id,
            title: title,
            year: year,
            url: letterboxdURL,
            addedAt: addedAt,
            sourceOrder: sourceOrder,
            source: .letterboxd
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, year, url, letterboxdURL, addedAt, sourceOrder, source
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        title = try values.decode(String.self, forKey: .title)
        year = try values.decodeIfPresent(Int.self, forKey: .year)
        url = try values.decodeIfPresent(URL.self, forKey: .url)
            ?? values.decodeIfPresent(URL.self, forKey: .letterboxdURL)
        addedAt = try values.decodeIfPresent(Date.self, forKey: .addedAt)
        sourceOrder = try values.decode(Int.self, forKey: .sourceOrder)
        source = try values.decodeIfPresent(Source.self, forKey: .source)
            ?? .letterboxd
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(title, forKey: .title)
        try values.encodeIfPresent(year, forKey: .year)
        try values.encodeIfPresent(url, forKey: .url)
        try values.encodeIfPresent(addedAt, forKey: .addedAt)
        try values.encode(sourceOrder, forKey: .sourceOrder)
        try values.encode(source, forKey: .source)
    }
}
