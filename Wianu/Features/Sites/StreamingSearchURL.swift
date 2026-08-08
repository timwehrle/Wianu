import Foundation

enum StreamingSearchURL {
    static let queryPlaceholder = "{query}"

    static func isValidTemplate(_ template: String) -> Bool {
        let parts = template.components(separatedBy: queryPlaceholder)
        guard parts.count == 2 else { return false }

        let testURLString = parts[0] + "Wianu" + parts[1]
        guard
            let url = URL(string: testURLString),
            let scheme = url.scheme?.lowercased(),
            scheme == "https",
            url.host() != nil
        else { return false }

        return true
    }

    static func makeURL(template: String, query: String) -> URL? {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty, isValidTemplate(template) else {
            return nil
        }

        let allowedCharacters = CharacterSet(
            charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
        )
        guard
            let encodedQuery = trimmedQuery.addingPercentEncoding(
                withAllowedCharacters: allowedCharacters
            )
        else { return nil }

        return URL(
            string: template.replacingOccurrences(
                of: queryPlaceholder,
                with: encodedQuery
            )
        )
    }
}

enum StreamingSearchPreset {
    private struct Preset {
        let domain: String
        let template: String
    }

    private static let presets = [
        Preset(
            domain: "netflix.com",
            template: "https://www.netflix.com/search?q={query}"
        ),
        Preset(
            domain: "primevideo.com",
            template:
            "https://www.primevideo.com/search/ref=atv_nb_sr?phrase={query}"
        ),
        Preset(
            domain: "amazon.de",
            template: "https://www.amazon.de/s?i=instant-video&k={query}"
        ),
        Preset(
            domain: "tv.apple.com",
            template: "https://tv.apple.com/search?term={query}"
        )
    ]

    static func template(for url: URL?) -> String? {
        guard let host = url?.host()?.lowercased() else { return nil }

        return presets.first { preset in
            host == preset.domain || host.hasSuffix(".\(preset.domain)")
        }?.template
    }
}
