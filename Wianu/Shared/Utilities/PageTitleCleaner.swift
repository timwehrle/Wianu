//
//  PageTitleCleaner.swift
//  Wianu
//
//  Created by Tim on 25.07.26.
//

import Foundation

enum PageTitleCleaner {
    static func clean(_ title: String, siteName: String) -> String {
        var result = title.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !result.isEmpty else {
            return siteName
        }

        let separators = [" | ", " — ", " – ", " - "]

        for separator in separators {
            result = removeProviderSuffix(
                from: result,
                providerName: siteName,
                separator: separator
            )
        }

        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        return result.isEmpty ? siteName : result
    }

    private static func removeProviderSuffix(
        from title: String,
        providerName: String,
        separator: String
    ) -> String {
        let suffix = separator + providerName

        guard title.localizedCaseInsensitiveContains(suffix) else {
            return title
        }

        return String(title.dropLast(suffix.count))
    }
}
