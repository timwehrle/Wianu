import Foundation

struct SiteDraft {
    var name: String
    var address: String
    var searchURLTemplate: String

    init(
        name: String = "",
        address: String = "",
        searchURLTemplate: String = ""
    ) {
        self.name = name
        self.address = address
        self.searchURLTemplate = searchURLTemplate
    }

    init(site: SavedSite) {
        name = site.name
        address = site.urlString
        searchURLTemplate = site.resolvedSearchURLTemplate ?? ""
    }

    var validatedValues: (
        name: String,
        url: URL,
        searchURLTemplate: String
    )? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSearchTemplate = searchURLTemplate.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !trimmedName.isEmpty, !trimmedAddress.isEmpty else { return nil }

        guard let url = validatedSiteURL else { return nil }

        guard
            trimmedSearchTemplate.isEmpty
                || StreamingSearchURL.isValidTemplate(trimmedSearchTemplate)
        else { return nil }

        return (trimmedName, url, trimmedSearchTemplate)
    }

    var suggestedSearchURLTemplate: String? {
        StreamingSearchPreset.template(for: validatedSiteURL)
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
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
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

private extension String {
    var hasHTTPPrefix: Bool {
        let value = lowercased()
        return value.hasPrefix("http://") || value.hasPrefix("https://")
    }
}
