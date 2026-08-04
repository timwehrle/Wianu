import Foundation
import Observation
import OSLog
import WebKit

enum BrowserNavigationLog {
    static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Wianu",
        category: "BrowserNavigation"
    )
}

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
        BrowserNavigationLog.logger.notice("Queued app destination")
        let request = Request(
            action: .load(
                URLRequest(url: url),
                establishesHistoryRoot: true
            )
        )
        protectedDestinationRequestID = request.id
        self.request = request
    }

    @discardableResult
    func openInCurrentPage(_ request: URLRequest) -> Bool {
        BrowserNavigationLog.logger.debug("Queued website navigation")
        let establishesHistoryRoot = protectedDestinationRequestID != nil
        let replacement = Request(
            action: .load(
                request,
                establishesHistoryRoot: establishesHistoryRoot
            )
        )
        if establishesHistoryRoot {
            protectedDestinationRequestID = replacement.id
        }
        self.request = replacement
        return true
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
            BrowserNavigationLog.logger.error(
                "Cancelled navigation without a URL"
            )
            return .cancel
        }

        guard action.target == nil else {
            return .allow
        }

        guard ["http", "https"].contains(url.scheme?.lowercased()) else {
            BrowserNavigationLog.logger.debug(
                "Cancelled unsupported targetless navigation"
            )
            return .cancel
        }

        if router.openInCurrentPage(action.request) {
            BrowserNavigationLog.logger.debug(
                "Rerouted targetless navigation into current page"
            )
            return .cancel
        }

        BrowserNavigationLog.logger.notice(
            "Allowed targetless navigation because rerouting was unavailable"
        )
        return .allow
    }

    func decidePolicy(
        for response: WebPage.NavigationResponse
    ) async -> WKNavigationResponsePolicy {
        BrowserNavigationLog.logger.notice("Received navigation response")
        return .allow
    }
}
