import SwiftUI

struct TMDBErrorView: View {
    let search: TMDBSearchModel
    let error: String

    var body: some View {
        ContentUnavailableView {
            Label("Couldn’t load TMDB", systemImage: "exclamationmark.triangle")
        } description: {
            Text(error)
        } actions: {
            Button("Retry") { search.retry() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct MediaResultRow: View {
    let item: TMDBMediaResult
    let posterURL: URL?

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Poster(url: posterURL, width: 64, height: 96)
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(item.title).font(.headline)
                    if let year = item.year {
                        Text(year).foregroundStyle(.secondary)
                    }
                    Text(item.mediaType == .movie ? "Movie" : "TV")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }
                if !item.overview.isEmpty {
                    Text(item.overview)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

struct MediaHeader: View {
    let item: TMDBMediaResult
    let posterURL: URL?

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            Poster(url: posterURL, width: 100, height: 150)
            VStack(alignment: .leading, spacing: 8) {
                Text(item.title).font(.title2.weight(.semibold))
                Text(
                    [item.mediaType == .movie ? "Movie" : "TV", item.year]
                        .compactMap(\.self).joined(separator: " · ")
                )
                .foregroundStyle(.secondary)
                if !item.overview.isEmpty {
                    Text(item.overview)
                }
            }
        }
    }
}

private struct Poster: View {
    let url: URL?
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        AsyncImage(url: url) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            Image(systemName: "film").foregroundStyle(.secondary)
        }
        .frame(width: width, height: height)
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}

struct ProviderLogo: View {
    let url: URL?

    var body: some View {
        AsyncImage(url: url) { image in
            image.resizable().scaledToFit()
        } placeholder: {
            Image(systemName: "play.tv").foregroundStyle(.secondary)
        }
        .frame(width: 42, height: 42)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
