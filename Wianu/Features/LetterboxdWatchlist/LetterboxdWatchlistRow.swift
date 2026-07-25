import SwiftUI

struct LetterboxdWatchlistRow: View {
    let item: LetterboxdWatchlistItem

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .lineLimit(1)

                if let year = item.year {
                    Text(year.formatted(.number.grouping(.never)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } icon: {
            Image(systemName: "film")
                .foregroundStyle(.secondary)
        }
        .help(item.title)
    }
}
