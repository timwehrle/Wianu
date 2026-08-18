import Foundation
import OSLog

enum AnalyticsEvent: String, Sendable {
    case appLaunched = "app-launched"
    case searchOpened = "search-opened"
    case letterboxdImportSucceeded = "letterboxd-import-succeeded"
    case watchlistItemAdded = "watchlist-item-added"
    case watchlistItemRemoved = "watchlist-item-removed"
    case continueWatchingItemAdded = "continue-watching-item-added"
    case continueWatchingItemRemoved = "continue-watching-item-removed"
    case siteAdded = "site-added"
    case siteEdited = "site-edited"
    case siteDeleted = "site-deleted"
    case settingsOpened = "settings-opened"
    case updateCheckStarted = "update-check-started"
}

@MainActor
protocol AnalyticsTracking {
    var isEnabled: Bool { get }
    func setEnabled(_ enabled: Bool)
    func track(_ event: AnalyticsEvent)
}

protocol AnalyticsSession: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: AnalyticsSession {}

@MainActor
final class AnalyticsClient: AnalyticsTracking {
    private let session: any AnalyticsSession
    private let endpoint: URL?
    private let websiteID: String
    private let userDefaults: UserDefaults
    private let appVersion: String
    private let build: String

    private static let enabledKey = "anonymousUsageAnalyticsEnabled"
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Wianu",
        category: "Analytics"
    )

    var isEnabled: Bool {
        if userDefaults.object(forKey: Self.enabledKey) == nil {
            return true
        }
        return userDefaults.bool(forKey: Self.enabledKey)
    }

    convenience init(
        bundle: Bundle = .main,
        userDefaults: UserDefaults = .standard
    ) {
        let baseURL = (bundle.object(
            forInfoDictionaryKey: "UmamiBaseURL"
        ) as? String).flatMap(Self.validConfigurationValue)
            .flatMap(URL.init(string:))
        let websiteID = (bundle.object(
            forInfoDictionaryKey: "UmamiWebsiteID"
        ) as? String).flatMap(Self.validConfigurationValue) ?? ""
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 10

        self.init(
            session: URLSession(configuration: configuration),
            endpoint: baseURL?.appending(path: "api/send"),
            websiteID: websiteID,
            userDefaults: userDefaults,
            appVersion: bundle.object(
                forInfoDictionaryKey: "CFBundleShortVersionString"
            ) as? String ?? "unknown",
            build: bundle.object(
                forInfoDictionaryKey: "CFBundleVersion"
            ) as? String ?? "unknown"
        )
    }

    init(
        session: any AnalyticsSession,
        endpoint: URL?,
        websiteID: String,
        userDefaults: UserDefaults,
        appVersion: String,
        build: String
    ) {
        self.session = session
        self.endpoint = endpoint
        self.websiteID = websiteID
        self.userDefaults = userDefaults
        self.appVersion = appVersion
        self.build = build
    }

    func setEnabled(_ enabled: Bool) {
        userDefaults.set(enabled, forKey: Self.enabledKey)
    }

    func track(_ event: AnalyticsEvent) {
        guard isEnabled, let endpoint, !websiteID.isEmpty else { return }
        let payload = RequestBody(
            payload: Payload(
                hostname: endpoint.host() ?? "app.wianu.com",
                url: "/app",
                website: websiteID,
                name: event.rawValue,
                data: [
                    "app_version": appVersion,
                    "build": build
                ]
            )
        )
        guard let data = try? JSONEncoder().encode(payload) else { return }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = data
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(
            "Wianu/\(appVersion) (macOS)",
            forHTTPHeaderField: "User-Agent"
        )

        let session = session
        Task {
            do {
                let (_, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse,
                      (200 ..< 300).contains(http.statusCode)
                else {
                    Self.logger.debug("Analytics request was not accepted")
                    return
                }
            } catch {
                Self.logger.debug(
                    "Analytics request failed: \(String(describing: error), privacy: .private)"
                )
            }
        }
    }

    private static func validConfigurationValue(_ value: String) -> String? {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !value.contains("$(") else { return nil }
        return value
    }

    private struct RequestBody: Encodable {
        let type = "event"
        let payload: Payload
    }

    private struct Payload: Encodable {
        let hostname: String
        let url: String
        let website: String
        let name: String
        let data: [String: String]
    }
}

@MainActor
struct DisabledAnalyticsTracker: AnalyticsTracking {
    let isEnabled = false
    func setEnabled(_ enabled: Bool) {}
    func track(_ event: AnalyticsEvent) {}
}
