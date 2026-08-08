import SwiftUI

struct PageTitleToolbarView: View {
    let title: String
    let url: URL?

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.tail)

            HStack(spacing: 3) {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                Text(url?.host() ?? "Unknown origin")
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .help(url?.absoluteString ?? title)
        .padding(.leading, 4)
        .padding(.trailing, 12)
    }
}
