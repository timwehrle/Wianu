//
//  URLNormalizer.swift
//  Wianu
//
//  Created by Tim on 25.07.26.
//

import Foundation

enum URLNormalizer {
    private static let removableQueryNames: Set<String> = [
        "utm_source",
        "utm_medium",
        "utm_campaign",
        "utm_term",
        "utm_content",
    ]

    static func continueWatchingURL(_ url: URL) -> URL {
        guard
            var components = URLComponents(
                url: url,
                resolvingAgainstBaseURL: false
            )
        else {
            return url
        }

        components.fragment = nil

        if let queryItems = components.queryItems {
            let filteredItems = queryItems.filter {
                !removableQueryNames.contains($0.name.lowercased())
            }

            components.queryItems = filteredItems.isEmpty ? nil : filteredItems
        }

        return components.url ?? url
    }

    static func comparisonKey(for url: URL) -> String {
        let normalizedURL = continueWatchingURL(url)

        guard
            var components = URLComponents(
                url: normalizedURL,
                resolvingAgainstBaseURL: false
            )
        else {
            return normalizedURL.absoluteString
        }

        components.scheme = components.scheme?.lowercased()
        components.host = components.host?.lowercased()

        if components.path.count > 1, components.path.hasSuffix("/") {
            components.path.removeLast()
        }

        return components.string ?? normalizedURL.absoluteString
    }
}
