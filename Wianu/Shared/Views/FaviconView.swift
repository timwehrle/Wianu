import AppKit
import SwiftUI

struct FaviconView: View {
    let url: URL?

    @State private var image: NSImage?

    private var faviconURL: URL? {
        guard
            let url,
            BrowserURLPolicy.allowsExternalNavigation(to: url),
            var components = URLComponents(
                url: url,
                resolvingAgainstBaseURL: false
            )
        else { return nil }

        components.user = nil
        components.password = nil
        components.path = "/favicon.ico"
        components.query = nil
        components.fragment = nil
        return components.url
    }

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                placeholder
            }
        }
        .frame(width: 16, height: 16)
        .clipShape(.rect(cornerRadius: 4))
        .task(id: faviconURL) {
            await loadFavicon()
        }
    }

    private var placeholder: some View {
        Image(systemName: "globe")
            .foregroundStyle(.secondary)
            .frame(width: 16, height: 16)
    }

    private func loadFavicon() async {
        image = nil
        guard let faviconURL else { return }

        do {
            let data = try await FaviconLoader.shared.data(for: faviconURL)
            try Task.checkCancellation()
            image = NSImage(data: data)
        } catch {}
    }
}

private actor FaviconLoader {
    static let shared = FaviconLoader()

    private var cache: [URL: Data] = [:]
    private var cacheOrder: [URL] = []
    private var requests: [URL: Task<Data, Error>] = [:]

    private static let maximumResponseBytes = 1_048_576
    private static let maximumCacheEntries = 128

    func data(for url: URL) async throws -> Data {
        if let data = cache[url] {
            return data
        }

        if let request = requests[url] {
            return try await request.value
        }

        let request = Task {
            try await Self.download(url)
        }
        requests[url] = request

        do {
            let data = try await request.value
            cache[url] = data
            cacheOrder.removeAll { $0 == url }
            cacheOrder.append(url)
            if cacheOrder.count > Self.maximumCacheEntries {
                let evictedURL = cacheOrder.removeFirst()
                cache[evictedURL] = nil
            }
            requests[url] = nil
            return data
        } catch {
            requests[url] = nil
            throw error
        }
    }

    private static func download(_ url: URL) async throws -> Data {
        var lastError: Error?

        for attempt in 0 ..< 3 {
            do {
                let (bytes, response) = try await URLSession.shared.bytes(
                    from: url
                )
                guard
                    let response = response as? HTTPURLResponse,
                    (200 ..< 300).contains(response.statusCode),
                    response.mimeType?.lowercased().hasPrefix("image/") == true,
                    response.expectedContentLength <= maximumResponseBytes
                else {
                    throw FaviconError.invalidResponse
                }

                var data = Data()
                data.reserveCapacity(
                    min(
                        max(Int(response.expectedContentLength), 0),
                        maximumResponseBytes
                    )
                )
                for try await byte in bytes {
                    guard data.count < maximumResponseBytes else {
                        throw FaviconError.responseTooLarge
                    }
                    data.append(byte)
                }
                guard NSImage(data: data) != nil else {
                    throw FaviconError.invalidResponse
                }
                return data
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
                if attempt < 2 {
                    try await Task.sleep(
                        for: .milliseconds(250 * (attempt + 1))
                    )
                }
            }
        }

        throw lastError ?? FaviconError.invalidResponse
    }

    private enum FaviconError: Error {
        case invalidResponse
        case responseTooLarge
    }
}
