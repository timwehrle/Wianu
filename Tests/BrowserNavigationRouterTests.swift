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
}
