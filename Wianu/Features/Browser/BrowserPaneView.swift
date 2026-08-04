import SwiftUI
import WebKit

struct BrowserPaneView: View {
    let page: WebPage

    var body: some View {
        WebView(page)
            .webViewElementFullscreenBehavior(.enabled)
    }
}
