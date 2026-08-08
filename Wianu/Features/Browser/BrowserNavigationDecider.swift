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

enum BrowserURLPolicy {
    static func allowsExternalNavigation(to url: URL?) -> Bool {
        guard
            let url,
            url.scheme?.lowercased() == "https",
            url.host() != nil,
            url.user == nil,
            url.password == nil
        else { return false }

        return true
    }

    static func rejectionMessage(for url: URL?) -> String {
        guard let url else { return "Wianu blocked an invalid link." }
        if url.scheme?.lowercased() == "http" {
            return "Wianu only opens secure HTTPS pages. Update this address before opening it."
        }
        return "Wianu blocked an unsupported or unsafe link."
    }
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
    private(set) var blockedNavigationMessage: String?
    private var protectedDestinationRequestID: Request.ID?
    private var activeLoadRequestID: Request.ID?

    @discardableResult
    func openDestination(_ url: URL) -> Bool {
        guard BrowserURLPolicy.allowsExternalNavigation(to: url) else {
            blockedNavigationMessage = BrowserURLPolicy.rejectionMessage(for: url)
            return false
        }
        BrowserNavigationLog.logger.notice("Queued app destination")
        let request = Request(
            action: .load(
                URLRequest(url: url),
                establishesHistoryRoot: true
            )
        )
        protectedDestinationRequestID = request.id
        self.request = request
        return true
    }

    @discardableResult
    func openInCurrentPage(_ request: URLRequest) -> Bool {
        guard BrowserURLPolicy.allowsExternalNavigation(to: request.url) else {
            blockedNavigationMessage = BrowserURLPolicy.rejectionMessage(
                for: request.url
            )
            return false
        }
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

    func clearBlockedNavigationMessage() {
        blockedNavigationMessage = nil
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

        // Streaming providers use non-HTTPS internal URLs in sandboxed
        // subframes for playback and authentication. They do not replace the
        // user-visible origin, so leave their handling to WebKit.
        if let target = action.target, !target.isMainFrame {
            return .allow
        }

        guard BrowserURLPolicy.allowsExternalNavigation(to: url) else {
            BrowserNavigationLog.logger.error("Cancelled unsafe navigation")
            _ = router.openInCurrentPage(action.request)
            return .cancel
        }

        guard !router.isPerformingLoad else {
            BrowserNavigationLog.logger.notice(
                "Allowed navigation for active programmatic load"
            )
            return .allow
        }

        guard action.target == nil else {
            return .allow
        }

        if router.openInCurrentPage(action.request) {
            BrowserNavigationLog.logger.notice(
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
        // NavigationResponse does not expose its target frame. The action
        // policy above validates every user-visible navigation, while WebKit
        // remains responsible for provider subresource responses.
        return .allow
    }
}
