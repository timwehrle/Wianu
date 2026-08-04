import SwiftUI
import WebKit

struct BrowserPaneView: View {
    let page: WebPage
    let onReady: () -> Void

    var body: some View {
        WebView(page)
            .webViewElementFullscreenBehavior(.enabled)
            .task {
                page.customUserAgent = Self.streamingUserAgent
                onReady()
            }
    }

    private static let streamingUserAgent = """
    Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) \
    AppleWebKit/605.1.15 (KHTML, like Gecko) \
    Version/18.0 Safari/605.1.15
    """
}
