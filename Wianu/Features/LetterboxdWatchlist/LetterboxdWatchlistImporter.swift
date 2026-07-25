import Foundation

struct LetterboxdWatchlistImportResult {
    let items: [LetterboxdWatchlistItem]
    let skippedRowCount: Int
}

enum LetterboxdWatchlistImportError: LocalizedError {
    case invalidEncoding
    case malformedCSV
    case missingRequiredColumns
    case noValidItems

    var errorDescription: String? {
        switch self {
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

enum LetterboxdWatchlistImporter {
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
        var items: [LetterboxdWatchlistItem] = []
        var skippedRowCount = 0

        for row in rows.dropFirst() where row.contains(where: { !$0.isEmpty }) {
            let title = value(at: nameColumn, in: row)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let urlString = value(at: urlColumn, in: row)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard
                !title.isEmpty,
                let url = URL(string: urlString),
                isLetterboxdURL(url)
            else {
                skippedRowCount += 1
                continue
            }

            let comparisonKey = normalizedURLKey(url)
            guard seenURLs.insert(comparisonKey).inserted else {
                skippedRowCount += 1
                continue
            }

            let year = yearColumn
                .map { value(at: $0, in: row) }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .flatMap(Int.init)
            let addedAt: Date?
            if let dateColumn {
                addedAt = parseDate(
                    value(at: dateColumn, in: row)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                )
            } else {
                addedAt = nil
            }

            items.append(
                LetterboxdWatchlistItem(
                    title: title,
                    year: year,
                    letterboxdURL: url,
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
            } else if (
                character == "\n"
                    || character == "\r"
                    || character == "\r\n"
            ), !isInsideQuotes {
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

    private static func isLetterboxdURL(_ url: URL) -> Bool {
        guard
            let scheme = url.scheme?.lowercased(),
            ["http", "https"].contains(scheme),
            let host = url.host()?.lowercased()
        else { return false }

        return host == "letterboxd.com"
            || host.hasSuffix(".letterboxd.com")
            || host == "boxd.it"
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
