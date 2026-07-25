import SwiftUI

struct PageTitleToolbarView: View {
    let title: String
    let canGoHome: Bool
    let isSaved: Bool
    let canSave: Bool
    let goHome: () -> Void
    let toggleSaved: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: goHome) {
                Image(systemName: "house")
                    .imageScale(.large)
            }
            .buttonStyle(.plain)
            .disabled(!canGoHome)
            .help("Go to Site Home")

            Divider().frame(height: 14)

            Text(title)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.tail)
                .help(title)

            Divider().frame(height: 14)

            Button(action: toggleSaved) {
                Image(
                    systemName: isSaved
                        ? "bookmark.fill"
                        : "bookmark"
                )
                .imageScale(.large)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
            .disabled(!canSave)
            .help(
                isSaved
                    ? "Remove from Continue Watching"
                    : "Save to Continue Watching"
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .fixedSize(horizontal: true, vertical: false)
    }
}
