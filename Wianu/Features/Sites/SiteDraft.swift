import Foundation

struct SiteDraft {
    var name: String
    var address: String
    var searchURLTemplate: String
    var tmdbProvider: TMDBProviderReference?

    init(
        name: String = "",
        address: String = "",
        searchURLTemplate: String = "",
        tmdbProvider: TMDBProviderReference? = nil
    ) {
        self.name = name
        self.address = address
        self.searchURLTemplate = searchURLTemplate
        self.tmdbProvider = tmdbProvider
    }

    init(site: SavedSite) {
        name = site.name
        address = site.urlString
        searchURLTemplate = site.resolvedSearchURLTemplate ?? ""
        tmdbProvider = site.tmdbProvider
    }

    var validatedValues:
        (
            name: String,
            url: URL,
            searchURLTemplate: String,
            tmdbProvider: TMDBProviderReference?
        )?
    {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAddress = address.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let trimmedSearchTemplate = searchURLTemplate.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !trimmedName.isEmpty, !trimmedAddress.isEmpty else { return nil }

        guard let url = validatedSiteURL else { return nil }

        guard
            trimmedSearchTemplate.isEmpty
                || StreamingSearchURL.isValidTemplate(trimmedSearchTemplate)
        else { return nil }

        return (trimmedName, url, trimmedSearchTemplate, tmdbProvider)
    }

    var suggestedSearchURLTemplate: String? {
        StreamingSearchPreset.template(for: validatedSiteURL)
    }

    var suggestedTMDBProvider: TMDBProviderReference? {
        guard let host = validatedSiteURL?.host()?.lowercased() else {
            return nil
        }
        let suggestions: [(String, TMDBProviderReference)] = [
            ("netflix.com", .init(id: 8, name: "Netflix")),
            ("primevideo.com", .init(id: 9, name: "Amazon Prime Video")),
            ("amazon.", .init(id: 9, name: "Amazon Prime Video")),
            ("tv.apple.com", .init(id: 2, name: "Apple TV")),
        ]
        return suggestions.first {
            host == $0.0 || host.hasSuffix(".\($0.0)") || host.contains($0.0)
        }?.1
    }

    var siteURLIsValid: Bool {
        validatedSiteURL != nil
    }

    var searchURLTemplateIsValid: Bool {
        let trimmed = searchURLTemplate.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        return trimmed.isEmpty || StreamingSearchURL.isValidTemplate(trimmed)
    }

    private var normalizedAddress: String? {
        let trimmedAddress = address.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmedAddress.isEmpty else { return nil }
        return trimmedAddress.hasHTTPPrefix
            ? trimmedAddress
            : "https://\(trimmedAddress)"
    }

    private var validatedSiteURL: URL? {
        guard
            let normalizedAddress,
            let url = URL(string: normalizedAddress),
            let scheme = url.scheme,
            ["http", "https"].contains(scheme.lowercased()),
            url.host() != nil
        else { return nil }

        return url
    }
}

extension String {
    fileprivate var hasHTTPPrefix: Bool {
        let value = lowercased()
        return value.hasPrefix("http://") || value.hasPrefix("https://")
    }
}
