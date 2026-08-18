import Foundation
import Testing
@testable import Wianu

private actor AnalyticsFixtureSession: AnalyticsSession {
    private(set) var requests: [URLRequest] = []

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 204,
            httpVersion: nil,
            headerFields: nil
        )!
        return (Data(), response)
    }

    func capturedRequests() -> [URLRequest] {
        requests
    }
}

@Suite("Analytics client")
struct AnalyticsClientTests {
    @Test func `sends privacy minimal Umami event`() async throws {
        let defaults = try #require(UserDefaults(
            suiteName: "AnalyticsClientTests.send.\(UUID().uuidString)"
        ))
        let session = AnalyticsFixtureSession()
        let client = AnalyticsClient(
            session: session,
            endpoint: URL(string: "https://analytics.example/api/send"),
            websiteID: "website-id",
            userDefaults: defaults,
            appVersion: "1.5.0",
            build: "16"
        )

        client.track(.searchOpened)
        try await waitForRequest(in: session)

        let request = try #require(await session.capturedRequests().first)
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.value(forHTTPHeaderField: "User-Agent") == "Wianu/1.5.0 (macOS)")
        let body = try #require(request.httpBody)
        let json = try #require(
            JSONSerialization.jsonObject(with: body) as? [String: Any]
        )
        let payload = try #require(json["payload"] as? [String: Any])
        let data = try #require(payload["data"] as? [String: String])
        #expect(json["type"] as? String == "event")
        #expect(payload["website"] as? String == "website-id")
        #expect(payload["name"] as? String == "search-opened")
        #expect(payload["url"] as? String == "/app")
        #expect(data == ["app_version": "1.5.0", "build": "16"])
        #expect(!String(decoding: body, as: UTF8.self).contains("query"))
    }

    @Test func `opt out and missing configuration send nothing`() async throws {
        let defaults = try #require(UserDefaults(
            suiteName: "AnalyticsClientTests.disabled.\(UUID().uuidString)"
        ))
        let session = AnalyticsFixtureSession()
        let client = AnalyticsClient(
            session: session,
            endpoint: URL(string: "https://analytics.example/api/send"),
            websiteID: "website-id",
            userDefaults: defaults,
            appVersion: "1",
            build: "1"
        )

        #expect(client.isEnabled)
        client.setEnabled(false)
        client.track(.appLaunched)
        try await Task.sleep(for: .milliseconds(50))
        #expect(await session.capturedRequests().isEmpty)

        client.setEnabled(true)
        let unconfigured = AnalyticsClient(
            session: session,
            endpoint: nil,
            websiteID: "",
            userDefaults: defaults,
            appVersion: "1",
            build: "1"
        )
        unconfigured.track(.appLaunched)
        try await Task.sleep(for: .milliseconds(50))
        #expect(await session.capturedRequests().isEmpty)
    }

    private func waitForRequest(
        in session: AnalyticsFixtureSession
    ) async throws {
        for _ in 0 ..< 20 {
            if await !session.capturedRequests().isEmpty {
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        Issue.record("Expected an analytics request")
    }
}
