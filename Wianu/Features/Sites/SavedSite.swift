import Foundation

struct SavedSite: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var urlString: String
    var searchURLTemplate: String?
    var createdAt: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        urlString: String,
        searchURLTemplate: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.urlString = urlString
        self.searchURLTemplate = searchURLTemplate
        self.createdAt = createdAt
    }

    var url: URL? {
        URL(string: urlString)
    }

    var resolvedSearchURLTemplate: String? {
        if let searchURLTemplate {
            let trimmed = searchURLTemplate.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            return trimmed.isEmpty ? nil : trimmed
        }

        return StreamingSearchPreset.template(for: url)
    }

    func searchURL(for query: String) -> URL? {
        guard let resolvedSearchURLTemplate else { return nil }
        return StreamingSearchURL.makeURL(
            template: resolvedSearchURLTemplate,
            query: query
        )
    }
}
