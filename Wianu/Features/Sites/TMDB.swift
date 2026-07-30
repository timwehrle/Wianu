import Foundation
import Observation

enum TMDBMediaType: String, Codable, Sendable {
    case movie
    case tv
}

struct TMDBMediaResult: Identifiable, Codable, Hashable, Sendable {
    let id: Int
    let mediaType: TMDBMediaType
    let title: String
    let overview: String
    let posterPath: String?
    let releaseDate: String?

    var year: String? {
        releaseDate?.split(separator: "-").first.map(String.init)
    }

    init(
        id: Int,
        mediaType: TMDBMediaType,
        title: String,
        overview: String,
        posterPath: String?,
        releaseDate: String?
    ) {
        self.id = id
        self.mediaType = mediaType
        self.title = title
        self.overview = overview
        self.posterPath = posterPath
        self.releaseDate = releaseDate
    }

    private enum CodingKeys: String, CodingKey {
        case id, overview
        case mediaType = "media_type"
        case movieTitle = "title"
        case tvTitle = "name"
        case posterPath = "poster_path"
        case movieDate = "release_date"
        case tvDate = "first_air_date"
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(Int.self, forKey: .id)
        mediaType = try values.decode(TMDBMediaType.self, forKey: .mediaType)
        title =
            try values.decodeIfPresent(String.self, forKey: .movieTitle)
                ?? values.decode(String.self, forKey: .tvTitle)
        overview =
            try values.decodeIfPresent(String.self, forKey: .overview) ?? ""
        posterPath = try values.decodeIfPresent(
            String.self,
            forKey: .posterPath
        )
        releaseDate =
            try values.decodeIfPresent(String.self, forKey: .movieDate)
                ?? values.decodeIfPresent(String.self, forKey: .tvDate)
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(mediaType, forKey: .mediaType)
        try values.encode(overview, forKey: .overview)
        try values.encodeIfPresent(posterPath, forKey: .posterPath)
        if mediaType == .movie {
            try values.encode(title, forKey: .movieTitle)
            try values.encodeIfPresent(releaseDate, forKey: .movieDate)
        } else {
            try values.encode(title, forKey: .tvTitle)
            try values.encodeIfPresent(releaseDate, forKey: .tvDate)
        }
    }
}

struct TMDBProvider: Identifiable, Codable, Hashable, Sendable {
    let id: Int
    let name: String
    let logoPath: String?

    private enum CodingKeys: String, CodingKey {
        case id = "provider_id"
        case name = "provider_name"
        case logoPath = "logo_path"
    }
}

struct TMDBRegion: Identifiable, Codable, Hashable, Sendable {
    let isoCode: String
    let englishName: String
    let nativeName: String

    var id: String {
        isoCode
    }

    var displayName: String {
        nativeName.isEmpty ? englishName : nativeName
    }

    private enum CodingKeys: String, CodingKey {
        case isoCode = "iso_3166_1"
        case englishName = "english_name"
        case nativeName = "native_name"
    }
}

enum TMDBOfferType: String, CaseIterable, Identifiable, Sendable {
    case flatrate = "Subscription"
    case free = "Free"
    case ads = "Ads"
    case rent = "Rent"
    case buy = "Buy"
    var id: String {
        rawValue
    }
}

struct TMDBWatchAvailability: Sendable {
    let link: URL?
    let groups: [TMDBOfferType: [TMDBProvider]]

    subscript(_ type: TMDBOfferType) -> [TMDBProvider] {
        groups[type] ?? []
    }
}

struct TMDBSearchPage: Sendable {
    let page: Int
    let totalPages: Int
    let results: [TMDBMediaResult]
}

struct TMDBImageConfiguration: Sendable {
    let secureBaseURL: URL
    let posterSize: String
    let logoSize: String

    func posterURL(path: String?) -> URL? {
        imageURL(path: path, size: posterSize)
    }

    func logoURL(path: String?) -> URL? {
        imageURL(path: path, size: logoSize)
    }

    private func imageURL(path: String?, size: String) -> URL? {
        guard let path else { return nil }
        return secureBaseURL.appending(path: size).appending(path: path)
    }
}

enum TMDBError: LocalizedError, Equatable {
    case notConfigured
    case invalidResponse
    case unauthorized
    case rateLimited(retryAfter: TimeInterval?)
    case server(statusCode: Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "TMDB is not configured. Add a Read Access Token in Settings."
        case .invalidResponse:
            "TMDB returned an unreadable response."
        case .unauthorized:
            "The TMDB read access token is invalid."
        case let .rateLimited(retryAfter):
            if let retryAfter {
                "TMDB is busy. Try again in \(Int(retryAfter)) seconds."
            } else {
                "TMDB is busy. Please try again shortly."
            }
        case let .server(_, message):
            message ?? "TMDB could not complete the request."
        }
    }
}

protocol TMDBSession: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: TMDBSession {}

struct TMDBClient: Sendable {
    private let token: String
    private let session: any TMDBSession
    private let baseURL: URL
    private let language: String

    var isConfigured: Bool {
        !token.isEmpty && !token.contains("$(")
    }

    init(
        token: String = "",
        session: any TMDBSession = URLSession.shared,
        baseURL: URL = URL(string: "https://api.themoviedb.org/3")!,
        language: String = Locale.current.identifier
    ) {
        self.token = token.trimmingCharacters(in: .whitespacesAndNewlines)
        self.session = session
        self.baseURL = baseURL
        self.language = language.replacingOccurrences(of: "_", with: "-")
    }

    func search(query: String, page: Int = 1) async throws -> TMDBSearchPage {
        let response: SearchResponse = try await request(
            path: "search/multi",
            query: [
                URLQueryItem(name: "query", value: query),
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "include_adult", value: "false"),
                URLQueryItem(name: "language", value: language)
            ]
        )
        return TMDBSearchPage(
            page: response.page,
            totalPages: response.totalPages,
            results: response.results.compactMap(\.media)
        )
    }

    func watchProviders(
        for media: TMDBMediaResult,
        region: String
    ) async throws -> TMDBWatchAvailability? {
        let response: WatchResponse = try await request(
            path: "\(media.mediaType.rawValue)/\(media.id)/watch/providers"
        )
        guard let value = response.results[region.uppercased()] else {
            return nil
        }
        return TMDBWatchAvailability(
            link: value.link.flatMap(URL.init(string:)),
            groups: [
                .flatrate: value.flatrate ?? [],
                .free: value.free ?? [],
                .ads: value.ads ?? [],
                .rent: value.rent ?? [],
                .buy: value.buy ?? []
            ]
        )
    }

    func regions() async throws -> [TMDBRegion] {
        let response: RegionResponse = try await request(
            path: "watch/providers/regions"
        )
        return response.results.sorted {
            $0.displayName.localizedStandardCompare($1.displayName)
                == .orderedAscending
        }
    }

    func providers() async throws -> [TMDBProvider] {
        let movies: ProviderResponse = try await request(
            path: "watch/providers/movie",
            query: [URLQueryItem(name: "language", value: language)]
        )
        let shows: ProviderResponse = try await request(
            path: "watch/providers/tv",
            query: [URLQueryItem(name: "language", value: language)]
        )
        let combined = movies.results + shows.results
        return Dictionary(grouping: combined, by: \.id)
            .compactMap(\.value.first)
            .sorted {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
    }

    func imageConfiguration() async throws -> TMDBImageConfiguration {
        let response: ConfigurationResponse = try await request(
            path: "configuration"
        )
        guard
            let url = URL(string: response.images.secureBaseURL),
            let posterSize = preferredSize(
                response.images.posterSizes,
                target: "w342"
            ),
            let logoSize = preferredSize(
                response.images.logoSizes,
                target: "w92"
            )
        else { throw TMDBError.invalidResponse }
        return TMDBImageConfiguration(
            secureBaseURL: url,
            posterSize: posterSize,
            logoSize: logoSize
        )
    }

    private func preferredSize(_ sizes: [String], target: String) -> String? {
        sizes.contains(target) ? target : sizes.last
    }

    private func request<Response: Decodable>(
        path: String,
        query: [URLQueryItem] = []
    ) async throws -> Response {
        guard isConfigured else { throw TMDBError.notConfigured }
        var components = URLComponents(
            url: baseURL.appending(path: path),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = query.isEmpty ? nil : query
        guard let url = components.url else { throw TMDBError.invalidResponse }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw TMDBError.invalidResponse
        }
        guard (200 ..< 300).contains(http.statusCode) else {
            let message = try? JSONDecoder().decode(
                ErrorResponse.self,
                from: data
            ).statusMessage
            switch http.statusCode {
            case 401: throw TMDBError.unauthorized
            case 429:
                throw TMDBError.rateLimited(
                    retryAfter: http.value(forHTTPHeaderField: "Retry-After")
                        .flatMap(TimeInterval.init)
                )
            default:
                throw TMDBError.server(
                    statusCode: http.statusCode,
                    message: message
                )
            }
        }
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw TMDBError.invalidResponse
        }
    }
}

private struct SearchResponse: Decodable {
    let page: Int
    let totalPages: Int
    let results: [SearchItem]

    enum CodingKeys: String, CodingKey {
        case page, results
        case totalPages = "total_pages"
    }
}

private struct SearchItem: Decodable {
    let media: TMDBMediaResult?

    init(from decoder: Decoder) throws {
        media = try? TMDBMediaResult(from: decoder)
    }
}

private struct WatchResponse: Decodable {
    let results: [String: WatchRegion]
}

private struct WatchRegion: Decodable {
    let link: String?
    let flatrate: [TMDBProvider]?
    let free: [TMDBProvider]?
    let ads: [TMDBProvider]?
    let rent: [TMDBProvider]?
    let buy: [TMDBProvider]?
}

private struct RegionResponse: Decodable {
    let results: [TMDBRegion]
}

private struct ProviderResponse: Decodable {
    let results: [TMDBProvider]
}

private struct ConfigurationResponse: Decodable {
    let images: Images

    struct Images: Decodable {
        let secureBaseURL: String
        let posterSizes: [String]
        let logoSizes: [String]

        enum CodingKeys: String, CodingKey {
            case secureBaseURL = "secure_base_url"
            case posterSizes = "poster_sizes"
            case logoSizes = "logo_sizes"
        }
    }
}

private struct ErrorResponse: Decodable {
    let statusMessage: String
    enum CodingKeys: String, CodingKey {
        case statusMessage = "status_message"
    }
}

@MainActor
@Observable
final class TMDBSearchModel {
    var query = ""
    private(set) var results: [TMDBMediaResult] = []
    private(set) var selectedMedia: TMDBMediaResult?
    private(set) var availability: TMDBWatchAvailability?
    private(set) var regions: [TMDBRegion] = []
    private(set) var imageConfiguration: TMDBImageConfiguration?
    private(set) var isSearching = false
    private(set) var isLoadingMore = false
    private(set) var isLoadingProviders = false
    private(set) var errorMessage: String?
    private(set) var focusRequest = 0
    var selectedRegion: String {
        didSet {
            userDefaults.set(selectedRegion, forKey: Self.regionKey)
            if selectedMedia != nil {
                loadAvailability()
            }
        }
    }

    @ObservationIgnored private let client: TMDBClient
    @ObservationIgnored private let userDefaults: UserDefaults
    @ObservationIgnored private var searchTask: Task<Void, Never>?
    @ObservationIgnored private var providerTask: Task<Void, Never>?
    private var currentPage = 0
    private var totalPages = 0

    private static let regionKey = "tmdbRegion"

    init(client: TMDBClient, userDefaults: UserDefaults) {
        self.client = client
        self.userDefaults = userDefaults
        let systemRegion = Locale.current.region?.identifier ?? "US"
        selectedRegion =
            userDefaults.string(forKey: Self.regionKey) ?? systemRegion
        Task { await loadMetadata() }
    }

    var isConfigured: Bool {
        client.isConfigured
    }

    var canLoadMore: Bool {
        currentPage < totalPages && !isLoadingMore
    }

    func requestFocus() {
        focusRequest += 1
    }

    func queryChanged() {
        searchTask?.cancel()
        selectedMedia = nil
        availability = nil
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            errorMessage = nil
            isSearching = false
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            await search(query: trimmed, page: 1)
        }
    }

    func retry() {
        if selectedMedia != nil {
            loadAvailability()
        } else {
            queryChanged()
        }
    }

    func loadMoreIfNeeded(after item: TMDBMediaResult) {
        guard item.id == results.last?.id, canLoadMore else { return }
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        searchTask = Task { await search(query: query, page: currentPage + 1) }
    }

    func select(_ media: TMDBMediaResult) {
        selectedMedia = media
        availability = nil
        loadAvailability()
    }

    func clearSelection() {
        providerTask?.cancel()
        selectedMedia = nil
        availability = nil
        errorMessage = nil
    }

    private func search(query: String, page: Int) async {
        if page == 1 {
            isSearching = true
        } else {
            isLoadingMore = true
        }
        errorMessage = nil
        do {
            let response = try await client.search(query: query, page: page)
            try Task.checkCancellation()
            if page == 1 {
                results = response.results
            } else {
                results.append(contentsOf: response.results)
            }
            currentPage = response.page
            totalPages = response.totalPages
        } catch is CancellationError {
        } catch {
            errorMessage = error.localizedDescription
        }
        isSearching = false
        isLoadingMore = false
    }

    private func loadAvailability() {
        providerTask?.cancel()
        guard let selectedMedia else { return }
        isLoadingProviders = true
        errorMessage = nil
        providerTask = Task {
            do {
                availability = try await client.watchProviders(
                    for: selectedMedia,
                    region: selectedRegion
                )
            } catch is CancellationError {
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoadingProviders = false
        }
    }

    private func loadMetadata() async {
        guard client.isConfigured else { return }
        async let loadedRegions = client.regions()
        async let loadedImages = client.imageConfiguration()
        regions = await (try? loadedRegions) ?? []
        imageConfiguration = try? await loadedImages
        if !regions.contains(where: { $0.isoCode == selectedRegion }) {
            selectedRegion = "US"
        }
    }
}
