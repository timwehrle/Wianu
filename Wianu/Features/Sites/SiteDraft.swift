import Foundation

struct SiteDraft {
    var name: String
    var address: String

    init(name: String = "", address: String = "") {
        self.name = name
        self.address = address
    }

    init(site: SavedSite) {
        name = site.name
        address = site.urlString
    }

    var validatedValues: (name: String, url: URL)? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty, !trimmedAddress.isEmpty else { return nil }

        let normalizedAddress = trimmedAddress.hasHTTPPrefix
            ? trimmedAddress
            : "https://\(trimmedAddress)"

        guard
            let url = URL(string: normalizedAddress),
            let scheme = url.scheme,
            ["http", "https"].contains(scheme.lowercased()),
            url.host() != nil
        else { return nil }

        return (trimmedName, url)
    }
}

private extension String {
    var hasHTTPPrefix: Bool {
        let value = lowercased()
        return value.hasPrefix("http://") || value.hasPrefix("https://")
    }
}
