import SwiftUI
import WebKit

struct BrowserView: View {
    @Bindable var model: AppModel
    @State private var page = WebPage()

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
        .toolbar {
            ToolbarItem(placement: .principal) {
                if model.selectedSite != nil {
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
        model.selectedSite != nil
            && page.url != nil
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
}
