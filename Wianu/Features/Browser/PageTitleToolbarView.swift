import SwiftUI

struct PageTitleToolbarView: View {
    let title: String
    let url: URL?
    @Environment(\.controlActiveState) private var controlActiveState

    var body: some View {
        HStack(spacing: 5) {
            Text(title)
                .fontWeight(.semibold)
                .lineLimit(1)
                .truncationMode(.tail)
                .layoutPriority(0)

            Text("·")
                .foregroundStyle(.tertiary)

            Text(url?.host() ?? "Unknown origin")
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(1)
        }
        .font(.headline)
        .foregroundStyle(
            controlActiveState == .key ? .primary : .secondary
        )
        .help(url?.absoluteString ?? title)
        .padding(.horizontal, 16)
    }
}
