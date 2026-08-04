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
    private var activeLoadRequestID: Request.ID?

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
        guard protectedDestinationRequestID == nil else {
            BrowserNavigationLog.logger.debug(
                "Blocked website navigation while app destination is protected"
            )
            return false
        }

        BrowserNavigationLog.logger.debug("Queued website navigation")
        self.request = Request(
            action: .load(request, establishesHistoryRoot: false)
        )
        return true
    }

    func openHistoryItem(_ item: WebPage.BackForwardList.Item) {
        request = Request(action: .history(item))
    }

    func reload() {
        request = Request(action: .reload)
    }

    func loadDidBegin(_ requestID: Request.ID) {
        BrowserNavigationLog.logger.notice("Programmatic load started")
        activeLoadRequestID = requestID
    }

    func loadDidEnd(_ requestID: Request.ID) {
        guard activeLoadRequestID == requestID else { return }
        BrowserNavigationLog.logger.notice("Programmatic load policy phase ended")
        activeLoadRequestID = nil
    }

    var isPerformingLoad: Bool {
        activeLoadRequestID != nil
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

        guard !router.isPerformingLoad else {
            BrowserNavigationLog.logger.debug(
                "Allowed policy action for active programmatic load"
            )
            return .allow
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
}
