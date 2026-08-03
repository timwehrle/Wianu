import SwiftUI
import WebKit

struct BrowserPaneView: View {
    let page: WebPage

    var body: some View {
        WebView(page)
            .webViewElementFullscreenBehavior(.enabled)
            .task {
                configurePage()
            }
    }

    private func configurePage() {
        page.customUserAgent = """
        Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) \
        AppleWebKit/605.1.15 (KHTML, like Gecko) \
        Version/18.0 Safari/605.1.15
        """
    }
}
