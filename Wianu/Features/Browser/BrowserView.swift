import SwiftUI
import WebKit

struct BrowserView: View {
    @Bindable var model: AppModel
    @State private var router: BrowserNavigationRouter
    @State private var page: WebPage
    @State private var showsLoadingIndicator = false
    @State private var historyRootID: WebPage.BackForwardList.Item.ID?

    init(model: AppModel) {
        self.model = model

        let router = BrowserNavigationRouter()
        let page = WebPage(
            navigationDecider: BrowserNavigationDecider(router: router)
        )
        page.customUserAgent = Self.customUserAgent

        _router = State(initialValue: router)
        _page = State(initialValue: page)
    }

    var body: some View {
        Group {
            if model.navigationRequest != nil {
                BrowserPaneView(
                    page: page
                )
            } else {
                ContentUnavailableView(
                    "No Site Selected",
                    systemImage: "globe",
                    description: Text(
                        "Select a site or a Continue Watching item."
                    )
                )
            }
        }
        .task(id: model.navigationRequest?.id) {
            guard let url = model.navigationRequest?.url else { return }
            if await load(url) {
                await Task.yield()
                establishHistoryRoot()
            }
        }
        .task(id: router.request?.id) {
            guard let url = router.request?.url else { return }
            _ = await load(url)
        }
        .onChange(of: page.url) { _, url in
            model.activateSite(matching: url)
        }
        .task(id: page.isLoading) {
            if page.isLoading {
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled, page.isLoading else { return }
                showsLoadingIndicator = true
            } else {
                showsLoadingIndicator = false
            }
        }
        .toolbar {
            if model.selection != .search {
                ToolbarItem(placement: .navigation) {
                    Button(action: goBack) {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(backItem == nil)
                    .help("Go Back")
                    .keyboardShortcut("[", modifiers: .command)
                }

                ToolbarItem(placement: .navigation) {
                    Button(action: goForward) {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(forwardItem == nil)
                    .help("Go Forward")
                    .keyboardShortcut("]", modifiers: .command)
                }

                ToolbarItem(placement: .navigation) {
                    Button(action: goHome) {
                        Image(systemName: "house")
                    }
                    .disabled(homeURL == nil)
                    .help("Go to Site Home")
                }

                ToolbarItem(placement: .principal) {
                    if model.destinationURL != nil {
                        PageTitleToolbarView(title: displayedTitle)
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button(action: toggleWatchlist) {
                        Image(
                            systemName: currentPageIsOnWatchlist
                                ? "bookmark.fill"
                                : "bookmark"
                        )
                    }
                    .disabled(!canSaveCurrentPage)
                    .help(
                        currentPageIsOnWatchlist
                            ? "Remove from Watchlist"
                            : "Add to Watchlist"
                    )
                }

                ToolbarItem(placement: .primaryAction) {
                    Button(action: toggleContinueWatching) {
                        Image(
                            systemName: currentPageIsSaved
                                ? "play.rectangle.fill"
                                : "play.rectangle"
                        )
                    }
                    .disabled(!canSaveCurrentPage)
                    .help(
                        currentPageIsSaved
                            ? "Remove from Continue Watching"
                            : "Save to Continue Watching"
                    )
                }

                ToolbarItem(placement: .primaryAction) {
                    if showsLoadingIndicator {
                        Button(action: page.stopLoading) {
                            ProgressView()
                                .controlSize(.small)
                        }
                        .help("Stop Loading")
                        .accessibilityLabel("Stop Loading")
                    } else {
                        Button(action: reload) {
                            Image(systemName: "arrow.clockwise")
                        }
                        .help("Reload")
                        .disabled(page.url == nil)
                        .keyboardShortcut("r", modifiers: .command)
                    }
                }
            }
        }
    }

    private static let customUserAgent = """
    Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) \
    AppleWebKit/605.1.15 (KHTML, like Gecko) \
    Version/18.0 Safari/605.1.15
    """

    private var displayedTitle: String {
        let title = page.title.trimmingCharacters(in: .whitespacesAndNewlines)

        if !title.isEmpty {
            return title
        }

        return model.selectedContinueWatchingItem?.title
            ?? model.selectedSite?.name
            ?? "Wianu"
    }

    private var canSaveCurrentPage: Bool {
        page.url != nil
            && !page.title.trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
    }

    private var currentPageIsSaved: Bool {
        guard let url = page.url else { return false }
        return model.continueWatchingStore.contains(url: url)
    }

    private var currentPageIsOnWatchlist: Bool {
        guard let url = page.url else { return false }
        return model.watchlistStore.contains(url: url)
    }

    private var backItem: WebPage.BackForwardList.Item? {
        guard
            let historyRootID,
            page.backForwardList.currentItem?.id != historyRootID
        else { return nil }

        return page.backForwardList.backList.last
    }

    private var forwardItem: WebPage.BackForwardList.Item? {
        page.backForwardList.forwardList.first
    }

    private var homeURL: URL? {
        if let siteURL = model.selectedSite?.url {
            return siteURL
        }

        guard
            let currentURL = page.url,
            var components = URLComponents(
                url: currentURL,
                resolvingAgainstBaseURL: false
            )
        else { return nil }

        components.path = "/"
        components.query = nil
        components.fragment = nil
        return components.url
    }

    private func goBack() {
        guard let backItem else { return }

        Task {
            await load(backItem)
        }
    }

    private func goForward() {
        guard let forwardItem else { return }

        Task {
            await load(forwardItem)
        }
    }

    private func goHome() {
        guard let homeURL else { return }

        Task {
            await load(homeURL)
        }
    }

    private func toggleContinueWatching() {
        guard let url = page.url else { return }
        model.toggleContinueWatching(title: page.title, url: url)
    }

    private func toggleWatchlist() {
        guard let url = page.url else { return }
        model.toggleWatchlist(title: page.title, url: url)
    }

    private func reload() {
        Task {
            do {
                for try await _ in page.reload(fromOrigin: false) {
                    try Task.checkCancellation()
                }
            } catch is CancellationError {
                return
            } catch {
                assertionFailure("Reload failed: \(error)")
            }
        }
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
            assertionFailure("Navigation failed: \(error)")
            return false
        }
    }

    private func load(_ item: WebPage.BackForwardList.Item) async {
        do {
            for try await _ in page.load(item) {
                try Task.checkCancellation()
            }
        } catch is CancellationError {
            return
        } catch where isCancelledNavigation(error) {
            return
        } catch {
            assertionFailure("History navigation failed: \(error)")
        }
    }

    private func establishHistoryRoot() {
        guard historyRootID == nil else { return }
        historyRootID = page.backForwardList.currentItem?.id
    }

    private func isCancelledNavigation(_ error: Error) -> Bool {
        let error = error as NSError
        return error.domain == NSURLErrorDomain
            && error.code == NSURLErrorCancelled
    }
}
