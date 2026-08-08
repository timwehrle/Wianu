import Foundation
import Testing
@testable import Wianu

@MainActor
@Suite("Browser navigation router")
struct BrowserNavigationRouterTests {
    @Test func `tracks a programmatic load through its policy phase`() throws {
        let router = BrowserNavigationRouter()
        try router.openDestination(#require(URL(string: "https://example.com")))
        let request = try #require(router.request)

        #expect(!router.isPerformingLoad)

        router.loadDidBegin(request.id)
        #expect(router.isPerformingLoad)

        router.loadDidEnd(request.id)
        #expect(!router.isPerformingLoad)
    }

    @Test func `stale completion cannot clear a replacement load`() throws {
        let router = BrowserNavigationRouter()
        try router.openDestination(#require(URL(string: "https://example.com")))
        let firstRequest = try #require(router.request)
        router.loadDidBegin(firstRequest.id)

        try router.openDestination(#require(URL(string: "https://example.org")))
        let replacementRequest = try #require(router.request)
        router.loadDidBegin(replacementRequest.id)

        router.loadDidEnd(firstRequest.id)
        #expect(router.isPerformingLoad)

        router.loadDidEnd(replacementRequest.id)
        #expect(!router.isPerformingLoad)
    }

    @Test func `only secure credential-free web URLs are accepted`() {
        #expect(
            BrowserURLPolicy.allowsExternalNavigation(
                to: URL(string: "https://example.com/watch?id=1")
            )
        )
        #expect(
            !BrowserURLPolicy.allowsExternalNavigation(
                to: URL(string: "http://example.com")
            )
        )
        #expect(
            !BrowserURLPolicy.allowsExternalNavigation(
                to: URL(string: "file:///tmp/movie")
            )
        )
        #expect(
            !BrowserURLPolicy.allowsExternalNavigation(
                to: URL(string: "https://user:secret@example.com")
            )
        )
    }

    @Test func `router preserves but blocks insecure legacy destinations`() throws {
        let router = BrowserNavigationRouter()
        let accepted = try router.openDestination(
            #require(URL(string: "http://example.com"))
        )

        #expect(!accepted)
        #expect(router.request == nil)
        #expect(router.blockedNavigationMessage != nil)
    }

    @Test func `site and search inputs require HTTPS`() {
        #expect(
            SiteDraft(name: "Secure", address: "https://example.com")
                .siteURLIsValid
        )
        #expect(
            !SiteDraft(name: "Legacy", address: "http://example.com")
                .siteURLIsValid
        )
        #expect(
            StreamingSearchURL.isValidTemplate(
                "https://example.com/search?q={query}"
            )
        )
        #expect(
            !StreamingSearchURL.isValidTemplate(
                "http://example.com/search?q={query}"
            )
        )
    }

    @Test func `Letterboxd imports upgrade HTTP and enforce size limits`() throws {
        let csv = "Name,Letterboxd URI\nMovie,http://letterboxd.com/film/movie/\n"
        let result = try LetterboxdWatchlistImporter.importItems(
            from: Data(csv.utf8)
        )
        #expect(result.items.first?.url?.scheme == "https")

        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
        try Data(csv.utf8).write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        #expect(throws: LetterboxdWatchlistImportError.self) {
            try LetterboxdWatchlistImporter.importItems(
                contentsOf: fileURL,
                maximumBytes: 4
            )
        }
    }
}
