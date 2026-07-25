import Foundation
import Observation
import WebKit

@MainActor
@Observable
final class BrowserNavigationRouter {
    struct Request: Identifiable {
        let id = UUID()
        let url: URL
    }

    private(set) var request: Request?

    func openInCurrentPage(_ url: URL) {
        request = Request(url: url)
    }
}

struct BrowserNavigationDecider: WebPage.NavigationDeciding {
    let router: BrowserNavigationRouter

    func decidePolicy(
        for action: WebPage.NavigationAction,
        preferences: inout WebPage.NavigationPreferences
    ) async -> WKNavigationActionPolicy {
        guard let url = action.request.url else {
            return .cancel
        }

        guard action.target == nil else {
            return .allow
        }

        guard ["http", "https"].contains(url.scheme?.lowercased()) else {
            return .cancel
        }

        router.openInCurrentPage(url)
        return .cancel
    }
}
