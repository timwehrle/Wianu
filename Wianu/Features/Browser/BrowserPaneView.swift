import SwiftUI
import WebKit

struct BrowserPaneView: View {
    let destinationURL: URL
    let page: WebPage
    let onNavigationFinished: () -> Void

    var body: some View {
        WebView(page)
            .webViewElementFullscreenBehavior(.enabled)
            .task(id: destinationURL) {
                configurePage()
                if await load(destinationURL) {
                    await Task.yield()
                    onNavigationFinished()
                }
            }
    }

    private func configurePage() {
        page.customUserAgent = """
            Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) \
            AppleWebKit/605.1.15 (KHTML, like Gecko) \
            Version/18.0 Safari/605.1.15
            """
    }

    private func load(_ url: URL) async -> Bool {
        do {
            for try await _ in page.load(URLRequest(url: url)) {
                try Task.checkCancellation()
            }
            return true
        } catch is CancellationError {
            return false
        } catch {
            return false
        }
    }
}
