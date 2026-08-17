import OSLog
import SwiftUI
import WebKit

struct BrowserView: View {
    @Bindable var model: AppModel
    @State private var router: BrowserNavigationRouter
    @State private var page: WebPage
    @State private var videoDiagnostics: VideoDiagnosticsController
    @State private var isVideoInformationPresented = false
    @State private var showsLoadingIndicator = false
    @State private var historyRootID: WebPage.BackForwardList.Item.ID?

    init(model: AppModel) {
        self.model = model

        let router = BrowserNavigationRouter()
        let videoDiagnostics = VideoDiagnosticsController()
        let configuration = WebPage.Configuration()
        videoDiagnostics.install(in: configuration.userContentController)
        let page = WebPage(
            configuration: configuration,
            navigationDecider: BrowserNavigationDecider(router: router)
        )
        page.customUserAgent = Self.customUserAgent

        _router = State(initialValue: router)
        _page = State(initialValue: page)
        _videoDiagnostics = State(initialValue: videoDiagnostics)
    }

    // TODO: Extract toolbar items for more clarity
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
            router.openDestination(url)
        }
        .task(id: router.request?.id) {
            guard let request = router.request else { return }
            await perform(request)
        }
        .onChange(of: page.url) { _, url in
            videoDiagnostics.clear()
            model.activateSite(matching: url)
        }
        .focusedSceneValue(\.showVideoInformation) {
            isVideoInformationPresented = true
        }
        .sheet(isPresented: $isVideoInformationPresented) {
            VideoInformationView(diagnostics: videoDiagnostics)
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
            if !model.isCommandPalettePresented {
                ToolbarItemGroup(placement: .navigation) {
                    Button(action: goBack) {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(backItem == nil)
                    .help("Go Back")
                    .keyboardShortcut("[", modifiers: .command)

                    Button(action: goForward) {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(forwardItem == nil)
                    .help("Go Forward")
                    .keyboardShortcut("]", modifiers: .command)

                    Button(action: reloadOrStop) {
                        Image(
                            systemName: showsLoadingIndicator
                                ? "xmark"
                                : "arrow.clockwise"
                        )
                    }
                    .help(showsLoadingIndicator ? "Stop Loading" : "Reload")
                    .accessibilityLabel(
                        showsLoadingIndicator ? "Stop Loading" : "Reload"
                    )
                    .disabled(page.url == nil && !showsLoadingIndicator)
                    .keyboardShortcut("r", modifiers: .command)

                    Button(action: goHome) {
                        Image(systemName: "house")
                    }
                    .disabled(homeURL == nil)
                    .help("Go to Site Home")
                }

                ToolbarItem(placement: .principal) {
                    if model.destinationURL != nil {
                        PageTitleToolbarView(
                            title: displayedTitle,
                            url: page.url
                        )
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
                    Button {
                        model.showCommandPalette()
                    } label: {
                        Label("Command Palette", systemImage: "magnifyingglass")
                    }
                    .keyboardShortcut("k", modifiers: .command)
                    .help("Search Actions, Movies, and TV Shows")
                }
            }
        }
        .alert(
            "Navigation Blocked",
            isPresented: Binding(
                get: { router.blockedNavigationMessage != nil },
                set: { presented in
                    if !presented {
                        router.clearBlockedNavigationMessage()
                    }
                }
            )
        ) {
            Button("OK") {
                router.clearBlockedNavigationMessage()
            }
        } message: {
            Text(router.blockedNavigationMessage ?? "")
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
        router.openHistoryItem(backItem)
    }

    private func goForward() {
        guard let forwardItem else { return }
        router.openHistoryItem(forwardItem)
    }

    private func goHome() {
        guard let homeURL else { return }
        router.openInCurrentPage(URLRequest(url: homeURL))
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
        router.reload()
    }

    private func reloadOrStop() {
        if showsLoadingIndicator {
            page.stopLoading()
        } else {
            reload()
        }
    }

    private func perform(_ request: BrowserNavigationRouter.Request) async {
        switch request.action {
        case let .load(urlRequest, establishesHistoryRoot):
            BrowserNavigationLog.logger.notice("Executing queued load")
            router.loadDidBegin(request.id)

            if establishesHistoryRoot {
                historyRootID = nil
            }

            defer {
                router.loadDidEnd(request.id)
                if establishesHistoryRoot {
                    router.destinationDidEnd(request.id)
                }
            }

            if await load(
                urlRequest,
                navigationRequestID: request.id,
                destinationRequestID: establishesHistoryRoot
                    ? request.id
                    : nil
            ), establishesHistoryRoot {
                await Task.yield()
                establishHistoryRoot()
            }

        case let .history(item):
            await load(item)

        case .reload:
            await reloadPage()
        }
    }

    private func load(
        _ request: URLRequest,
        navigationRequestID: BrowserNavigationRouter.Request.ID,
        destinationRequestID: BrowserNavigationRouter.Request.ID?
    ) async -> Bool {
        do {
            for try await event in page.load(request) {
                try Task.checkCancellation()
                if event == .committed {
                    BrowserNavigationLog.logger.notice("Navigation committed")
                    router.loadDidEnd(navigationRequestID)
                    if let destinationRequestID {
                        router.destinationDidCommit(destinationRequestID)
                        await Task.yield()
                        establishHistoryRoot()
                    }
                }
            }
            return true
        } catch where isCancelledNavigation(error) {
            BrowserNavigationLog.logger.debug("Navigation cancelled")
            return false
        } catch {
            BrowserNavigationLog.logger.error(
                "Navigation failed: \(String(describing: error), privacy: .private)"
            )
            return false
        }
    }

    private func load(_ item: WebPage.BackForwardList.Item) async {
        do {
            for try await _ in page.load(item) {
                try Task.checkCancellation()
            }
        } catch where isCancelledNavigation(error) {
            BrowserNavigationLog.logger.debug("History navigation cancelled")
            return
        } catch {
            BrowserNavigationLog.logger.error(
                "History navigation failed: \(String(describing: error), privacy: .private)"
            )
        }
    }

    private func reloadPage() async {
        do {
            for try await _ in page.reload(fromOrigin: false) {
                try Task.checkCancellation()
            }
        } catch where isCancelledNavigation(error) {
            BrowserNavigationLog.logger.debug("Reload cancelled")
            return
        } catch {
            BrowserNavigationLog.logger.error(
                "Reload failed: \(String(describing: error), privacy: .private)"
            )
        }
    }

    private func establishHistoryRoot() {
        guard historyRootID == nil else { return }
        historyRootID = page.backForwardList.currentItem?.id
    }

    private func isCancelledNavigation(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }

        if let navigationError = error as? WebPage.NavigationError,
           case let .failedProvisionalNavigation(underlyingError) =
           navigationError
        {
            return isCancelledNavigation(underlyingError)
        }

        let error = error as NSError
        return error.domain == NSURLErrorDomain
            && error.code == NSURLErrorCancelled
    }
}
