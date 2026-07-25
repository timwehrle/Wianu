//
//  BrowserPaneView.swift
//  Wianu
//
//  Created by Tim on 24.07.26.
//

import SwiftUI
import WebKit

struct BrowserPaneView: View {
    let destinationURL: URL
    let page: WebPage

    var body: some View {
        WebView(page)
            .webViewElementFullscreenBehavior(.enabled)
            .task(id: destinationURL) {
                configurePage()
                await load(destinationURL)
            }
    }

    private func configurePage() {
        page.customUserAgent = """
            Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) \
            AppleWebKit/605.1.15 (KHTML, like Gecko) \
            Version/18.0 Safari/605.1.15
            """
    }

    private func load(_ url: URL) async {
        do {
            for try await _ in page.load(URLRequest(url: url)) {
                try Task.checkCancellation()
            }
        } catch is CancellationError {
            return
        } catch {
        }
    }
}
