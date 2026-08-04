import Foundation
import Observation
import WebKit

@MainActor
@Observable
final class BrowserNavigationRouter {
    struct Request: Identifiable {
        let id = UUID()
        let action: Action
    }

    enum Action {
        case load(URLRequest, establishesHistoryRoot: Bool)
        case history(WebPage.BackForwardList.Item)
        case reload
    }

    private(set) var request: Request?
    private var protectedDestinationRequestID: Request.ID?

    func openDestination(_ url: URL) {
        let request = Request(
            action: .load(
                URLRequest(url: url),
                establishesHistoryRoot: true
            )
        )
        protectedDestinationRequestID = request.id
        self.request = request
    }

    func openInCurrentPage(_ request: URLRequest) {
        guard protectedDestinationRequestID == nil else { return }
        self.request = Request(
            action: .load(request, establishesHistoryRoot: false)
        )
    }

    func openHistoryItem(_ item: WebPage.BackForwardList.Item) {
        request = Request(action: .history(item))
    }

    func reload() {
        request = Request(action: .reload)
    }

    func destinationDidCommit(_ requestID: Request.ID) {
        guard protectedDestinationRequestID == requestID else { return }
        protectedDestinationRequestID = nil
    }

    func destinationDidEnd(_ requestID: Request.ID) {
        destinationDidCommit(requestID)
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

        router.openInCurrentPage(action.request)
        return .cancel
    }
}
