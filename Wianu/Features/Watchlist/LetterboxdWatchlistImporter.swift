import Foundation

struct LetterboxdWatchlistImportResult: Sendable {
    let items: [WatchlistItem]
    let skippedRowCount: Int
}

enum LetterboxdWatchlistImportError: LocalizedError, Sendable {
    case fileTooLarge(maximumBytes: Int)
    case invalidEncoding
    case malformedCSV
    case missingRequiredColumns
    case noValidItems

    var errorDescription: String? {
        switch self {
        case let .fileTooLarge(maximumBytes):
            "The CSV exceeds the \(maximumBytes / 1_048_576) MB import limit."
        case .invalidEncoding:
            "The file is not valid UTF-8 text."
        case .malformedCSV:
            "The CSV file contains an unterminated quoted field."
        case .missingRequiredColumns:
            "The CSV must contain Name and Letterboxd URI columns."
        case .noValidItems:
            "No valid Letterboxd watchlist items were found."
        }
    }
}

nonisolated enum LetterboxdWatchlistImporter {
    static func importItems(
        contentsOf url: URL,
        maximumBytes: Int
    ) throws -> LetterboxdWatchlistImportResult {
        let resourceValues = try url.resourceValues(
            forKeys: [.fileSizeKey, .isRegularFileKey]
        )
        guard resourceValues.isRegularFile == true else {
            throw CocoaError(.fileReadUnsupportedScheme)
        }
        if let fileSize = resourceValues.fileSize,
           fileSize > maximumBytes
        {
            throw LetterboxdWatchlistImportError.fileTooLarge(
                maximumBytes: maximumBytes
            )
        }

        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        guard data.count <= maximumBytes else {
            throw LetterboxdWatchlistImportError.fileTooLarge(
                maximumBytes: maximumBytes
            )
        }
        return try importItems(from: data)
    }

    static func importItems(from data: Data) throws -> LetterboxdWatchlistImportResult {
        guard var text = String(data: data, encoding: .utf8) else {
            throw LetterboxdWatchlistImportError.invalidEncoding
        }

        if text.first == "\u{feff}" {
            text.removeFirst()
        }

        let rows = try parseCSV(text)
        guard let header = rows.first else {
            throw LetterboxdWatchlistImportError.missingRequiredColumns
        }

        var columns: [String: Int] = [:]
        for (index, name) in header.enumerated() {
            let key = normalizedHeader(name)
            if columns[key] == nil {
                columns[key] = index
            }
        }

        guard
            let nameColumn = columns["name"],
            let urlColumn = columns["letterboxduri"]
        else {
            throw LetterboxdWatchlistImportError.missingRequiredColumns
        }

        let yearColumn = columns["year"]
        let dateColumn = columns["date"]
        var seenURLs = Set<String>()
        var items: [WatchlistItem] = []
        var skippedRowCount = 0

        for row in rows.dropFirst() where row.contains(where: { !$0.isEmpty }) {
            let title = value(at: nameColumn, in: row)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let urlString = value(at: urlColumn, in: row)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard
                !title.isEmpty,
                let url = URL(string: urlString),
                let secureURL = secureLetterboxdURL(url)
            else {
                skippedRowCount += 1
                continue
            }

            let comparisonKey = normalizedURLKey(secureURL)
            guard seenURLs.insert(comparisonKey).inserted else {
                skippedRowCount += 1
                continue
            }

            let year = yearColumn
                .map { value(at: $0, in: row) }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .flatMap(Int.init)
            let addedAt: Date? = if let dateColumn {
                parseDate(
                    value(at: dateColumn, in: row)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                )
            } else {
                nil
            }

            items.append(
                WatchlistItem(
                    title: title,
                    year: year,
                    letterboxdURL: secureURL,
                    addedAt: addedAt,
                    sourceOrder: items.count
                )
            )
        }

        guard !items.isEmpty else {
            throw LetterboxdWatchlistImportError.noValidItems
        }

        return LetterboxdWatchlistImportResult(
            items: items,
            skippedRowCount: skippedRowCount
        )
    }

    private static func parseCSV(_ text: String) throws -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var isInsideQuotes = false
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]

            if character == "\"" {
                let nextIndex = text.index(after: index)

                if isInsideQuotes,
                   nextIndex < text.endIndex,
                   text[nextIndex] == "\""
                {
                    field.append("\"")
                    index = nextIndex
                } else {
                    isInsideQuotes.toggle()
                }
            } else if character == ",", !isInsideQuotes {
                row.append(field)
                field = ""
            } else if
                character == "\n"
                || character == "\r"
                || character == "\r\n",
                !isInsideQuotes
            {
                row.append(field)
                field = ""

                if row.contains(where: { !$0.isEmpty }) {
                    rows.append(row)
                }
                row = []

                if character == "\r" {
                    let nextIndex = text.index(after: index)
                    if nextIndex < text.endIndex, text[nextIndex] == "\n" {
                        index = nextIndex
                    }
                }
            } else {
                field.append(character)
            }

            index = text.index(after: index)
        }

        guard !isInsideQuotes else {
            throw LetterboxdWatchlistImportError.malformedCSV
        }

        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }

        return rows
    }

    private static func value(at index: Int, in row: [String]) -> String {
        row.indices.contains(index) ? row[index] : ""
    }

    private static func normalizedHeader(_ header: String) -> String {
        header
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .filter { !$0.isWhitespace }
    }

    private static func secureLetterboxdURL(_ url: URL) -> URL? {
        guard
            let scheme = url.scheme?.lowercased(),
            ["http", "https"].contains(scheme),
            let host = url.host()?.lowercased()
        else { return nil }

        guard host == "letterboxd.com"
            || host.hasSuffix(".letterboxd.com")
            || host == "boxd.it"
        else { return nil }

        guard var components = URLComponents(
            url: url,
            resolvingAgainstBaseURL: false
        ) else { return nil }
        components.scheme = "https"
        components.user = nil
        components.password = nil
        return components.url
    }

    private static func normalizedURLKey(_ url: URL) -> String {
        guard var components = URLComponents(
            url: url,
            resolvingAgainstBaseURL: false
        ) else {
            return url.absoluteString
        }

        let scheme = components.scheme?.lowercased()
        let host = components.host?.lowercased()
        components.scheme = scheme
        components.host = host

        if components.path.count > 1, components.path.hasSuffix("/") {
            components.path.removeLast()
        }

        return components.string ?? url.absoluteString
    }

    private static func parseDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }
}
