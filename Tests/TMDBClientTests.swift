import Foundation
import Testing
@testable import Wianu

private actor FixtureSession: TMDBSession {
    let status: Int
    let headers: [String: String]
    let data: Data
    private(set) var request: URLRequest?

    init(_ json: String, status: Int = 200, headers: [String: String] = [:]) {
        self.status = status
        self.headers = headers
        data = Data(json.utf8)
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        self.request = request
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: status,
            httpVersion: nil,
            headerFields: headers
        )!
        return (data, response)
    }

    func capturedRequest() -> URLRequest? {
        request
    }
}

private actor CancelledSession: TMDBSession {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        throw URLError(.cancelled)
    }
}

@Suite("TMDB client")
struct TMDBClientTests {
    @Test func `cancelled URL requests are not shown as search errors`() async {
        let defaults = UserDefaults(
            suiteName: "TMDBClientTests.cancelled.\(UUID().uuidString)"
        )!
        let model = TMDBSearchModel(
            client: TMDBClient(token: "token", session: CancelledSession()),
            userDefaults: defaults
        )

        model.query = "Dune"
        model.queryChanged()
        try? await Task.sleep(for: .milliseconds(500))

        #expect(model.errorMessage == nil)
        #expect(!model.isSearching)
    }

    @Test func `Letterboxd links are available only for movies`() throws {
        let movie = TMDBMediaResult(
            id: 550,
            mediaType: .movie,
            title: "Fight Club",
            overview: "",
            posterPath: nil,
            releaseDate: "1999-10-15"
        )
        let show = TMDBMediaResult(
            id: 1396,
            mediaType: .tv,
            title: "Breaking Bad",
            overview: "",
            posterPath: nil,
            releaseDate: "2008-01-20"
        )

        #expect(
            movie.letterboxdURL
                == URL(string: "https://letterboxd.com/tmdb/550")
        )
        #expect(show.letterboxdURL == nil)
    }

    @Test func `search authenticates encodes and filters people`() async throws {
        let session = FixtureSession("""
        {"page":1,"total_pages":2,"results":[
          {"id":1,"media_type":"movie","title":"Dune","overview":"x",
           "poster_path":"/p.jpg","release_date":"2021-10-22"},
          {"id":2,"media_type":"tv","name":"Dark","overview":"y",
           "first_air_date":"2017-12-01"},
          {"id":3,"media_type":"person","name":"Someone"}
        ]}
        """)
        let client = try TMDBClient(
            token: "secret",
            session: session,
            baseURL: #require(URL(string: "https://example.test/3")),
            language: "de-DE"
        )

        let page = try await client.search(query: "A & B")

        #expect(page.results.map(\.title) == ["Dune", "Dark"])
        #expect(page.totalPages == 2)
        let request = await session.capturedRequest()
        #expect(request?.value(forHTTPHeaderField: "Authorization") == "Bearer secret")
        let components = try URLComponents(url: #require(request?.url), resolvingAgainstBaseURL: false)
        #expect(components?.queryItems?.contains(URLQueryItem(name: "query", value: "A & B")) == true)
        #expect(components?.queryItems?.contains(URLQueryItem(name: "include_adult", value: "false")) == true)
    }

    @Test func `groups provider offers and handles missing region`() async throws {
        let session = FixtureSession("""
        {"results":{"DE":{"link":"https://tmdb.test/title",
          "flatrate":[{"provider_id":8,"provider_name":"Netflix","logo_path":"/n.png"}],
          "rent":[{"provider_id":2,"provider_name":"Store","logo_path":null}]}}}
        """)
        let client = try TMDBClient(
            token: "secret",
            session: session,
            baseURL: #require(URL(string: "https://example.test/3"))
        )
        let media = TMDBMediaResult(
            id: 10, mediaType: .movie, title: "Title",
            overview: "", posterPath: nil, releaseDate: nil
        )

        let de = try await client.watchProviders(for: media, region: "DE")
        let us = try await client.watchProviders(for: media, region: "US")
        #expect(de?[.flatrate].map(\.name) == ["Netflix"])
        #expect(de?[.rent].map(\.name) == ["Store"])
        #expect(us == nil)
    }

    @Test func `maps credentials rate limits and malformed responses`() async throws {
        let unauthorized = try TMDBClient(
            token: "x",
            session: FixtureSession("{}", status: 401),
            baseURL: #require(URL(string: "https://example.test/3"))
        )
        await #expect(throws: TMDBError.unauthorized) {
            try await unauthorized.search(query: "x")
        }

        let limited = try TMDBClient(
            token: "x",
            session: FixtureSession("{}", status: 429, headers: ["Retry-After": "12"]),
            baseURL: #require(URL(string: "https://example.test/3"))
        )
        await #expect(throws: TMDBError.rateLimited(retryAfter: 12)) {
            try await limited.search(query: "x")
        }

        let malformed = try TMDBClient(
            token: "x",
            session: FixtureSession("{"),
            baseURL: #require(URL(string: "https://example.test/3"))
        )
        await #expect(throws: TMDBError.invalidResponse) {
            try await malformed.search(query: "x")
        }
    }

    @Test func `legacy sites decode and provider references round trip`() throws {
        let legacy = """
        [{"id":"C1A4E17B-9B32-443F-BEA8-AC1C70B31A22","name":"Netflix",
          "urlString":"https://netflix.com","createdAt":0}]
        """
        let decoded = try JSONDecoder().decode([SavedSite].self, from: Data(legacy.utf8))
        #expect(decoded.first?.tmdbProvider == nil)

        let site = SavedSite(
            name: "Netflix",
            urlString: "https://netflix.com",
            searchURLTemplate: "https://netflix.com/search?q={query}",
            tmdbProvider: .init(id: 8, name: "Netflix")
        )
        let roundTrip = try JSONDecoder().decode(
            SavedSite.self,
            from: JSONEncoder().encode(site)
        )
        #expect(roundTrip.tmdbProvider == site.tmdbProvider)
        #expect(site.searchURL(for: "A & B")?.absoluteString.contains("A%20%26%20B") == true)
    }

    @Test func `prime video provider tiers match the configured site`() {
        let primeVideo = TMDBProviderReference(
            id: 9,
            name: "Amazon Prime Video"
        )

        #expect(
            primeVideo.matches(
                TMDBProvider(
                    id: 2100,
                    name: "Amazon Prime Video with Ads",
                    logoPath: nil
                )
            )
        )
        #expect(
            primeVideo.matches(
                TMDBProvider(
                    id: 9,
                    name: "Prime Video",
                    logoPath: nil
                )
            )
        )
        #expect(
            primeVideo.matches(
                TMDBProvider(
                    id: 10,
                    name: "Amazon Video",
                    logoPath: nil
                )
            )
        )
        #expect(
            !primeVideo.matches(
                TMDBProvider(
                    id: 15,
                    name: "Hulu",
                    logoPath: nil
                )
            )
        )
    }
}
