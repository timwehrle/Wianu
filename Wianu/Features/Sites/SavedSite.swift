import Foundation

struct TMDBProviderReference: Codable, Hashable, Sendable {
    let id: Int
    let name: String

    func matches(_ provider: TMDBProvider) -> Bool {
        id == provider.id
            || (providerFamily != nil
                && providerFamily == Self.family(for: provider.name))
    }

    private var providerFamily: ProviderFamily? {
        Self.family(for: name)
    }

    private static func family(for name: String) -> ProviderFamily? {
        let words =
            name
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: nil
            )
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }

        // TMDB separates Prime subscription tiers from Amazon's rent/buy
        // store. We can open all of them through the same Amazon site.
        let isPrimeVideo = words.contains("prime") && words.contains("video")
        let isAmazonVideo = words == ["amazon", "video"]
        if isPrimeVideo || isAmazonVideo {
            return .primeVideo
        }

        return nil
    }

    private enum ProviderFamily {
        case primeVideo
    }
}

struct SavedSite: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var urlString: String
    var searchURLTemplate: String?
    var tmdbProvider: TMDBProviderReference?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        urlString: String,
        searchURLTemplate: String? = nil,
        tmdbProvider: TMDBProviderReference? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.urlString = urlString
        self.searchURLTemplate = searchURLTemplate
        self.tmdbProvider = tmdbProvider
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

    var isTMDBProviderActionable: Bool {
        tmdbProvider != nil && resolvedSearchURLTemplate != nil
    }
}
