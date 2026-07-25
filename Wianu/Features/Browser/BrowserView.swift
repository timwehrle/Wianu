import SwiftUI
import WebKit

struct BrowserView: View {
    @Bindable var model: AppModel
    @State private var router: BrowserNavigationRouter
    @State private var page: WebPage

    init(model: AppModel) {
        self.model = model

        let router = BrowserNavigationRouter()
        _router = State(initialValue: router)
        _page = State(
            initialValue: WebPage(
                navigationDecider: BrowserNavigationDecider(router: router)
            )
        )
    }

    var body: some View {
        Group {
            if let destinationURL = model.destinationURL {
                BrowserPaneView(destinationURL: destinationURL, page: page)
            } else {
                ContentUnavailableView(
                    "No Site Selected",
                    systemImage: "globe",
                    description: Text("Select a site or a Continue Watching item.")
                )
            }
        }
        .task(id: router.request?.id) {
            guard let url = router.request?.url else { return }
            await load(url)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                if model.destinationURL != nil {
                    PageTitleToolbarView(
                        title: displayedTitle,
                        isSaved: currentPageIsSaved,
                        canSave: canSaveCurrentPage,
                        toggleSaved: toggleContinueWatching
                    )
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Button(action: reload) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Reload")
                .disabled(page.url == nil)
            }
        }
    }

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
            && !page.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var currentPageIsSaved: Bool {
        guard let url = page.url else { return false }
        return model.continueWatchingStore.contains(url: url)
    }

    private func toggleContinueWatching() {
        guard let url = page.url else { return }
        model.toggleContinueWatching(title: page.title, url: url)
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

    private func load(_ url: URL) async {
        do {
            for try await _ in page.load(URLRequest(url: url)) {
                try Task.checkCancellation()
            }
        } catch is CancellationError {
            return
        } catch {
            assertionFailure("Navigation failed: \(error)")
        }
    }
}
