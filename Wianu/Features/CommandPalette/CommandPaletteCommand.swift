import Foundation

enum CommandPaletteAction: Hashable, Sendable {
    case openSite(SavedSite.ID)
    case continueWatching(ContinueWatchingItem.ID)
    case addSite
    case openSettings
}

struct CommandPaletteCommand: Identifiable, Hashable, Sendable {
    let action: CommandPaletteAction
    let title: String
    let subtitle: String?
    let systemImage: String
    let keywords: [String]

    var id: CommandPaletteAction {
        action
    }
}

enum CommandCatalog {
    static func commands(
        matching query: String,
        sites: [SavedSite],
        continueWatchingItems: [ContinueWatchingItem]
    ) -> [CommandPaletteCommand] {
        let trimmedQuery = query.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let general = generalCommands
        let siteCommands = sites.map { openSiteCommand($0) }
        let continueCommands = continueWatchingItems
            .sorted { $0.lastOpenedAt > $1.lastOpenedAt }
            .map { continueWatchingCommand($0) }

        guard !trimmedQuery.isEmpty else {
            return general + siteCommands
                + Array(continueCommands.prefix(5))
        }

        return (general + siteCommands + continueCommands)
            .compactMap { command -> (CommandPaletteCommand, Int)? in
                score(command, for: trimmedQuery).map {
                    (
                        command,
                        $0 + rankingAdjustment(for: command)
                    )
                }
            }
            .sorted {
                if $0.1 != $1.1 {
                    return $0.1 > $1.1
                }
                return $0.0.title.localizedStandardCompare($1.0.title)
                    == .orderedAscending
            }
            .map(\.0)
    }

    private static let generalCommands = [
        CommandPaletteCommand(
            action: .addSite,
            title: "Add Site",
            subtitle: "Add a streaming website",
            systemImage: "plus.rectangle.on.rectangle",
            keywords: ["new", "streaming", "website"]
        ),
        CommandPaletteCommand(
            action: .openSettings,
            title: "Settings",
            subtitle: "Open Wianu settings",
            systemImage: "gearshape",
            keywords: ["preferences", "tmdb", "configuration"]
        )
    ]

    private static func openSiteCommand(
        _ site: SavedSite
    ) -> CommandPaletteCommand {
        CommandPaletteCommand(
            action: .openSite(site.id),
            title: "Open \(site.name)",
            subtitle: site.url?.host(),
            systemImage: "play.tv",
            keywords: [site.name, "site", "stream", "open"]
        )
    }

    private static func continueWatchingCommand(
        _ item: ContinueWatchingItem
    ) -> CommandPaletteCommand {
        CommandPaletteCommand(
            action: .continueWatching(item.id),
            title: "Continue \(item.title)",
            subtitle: item.url.host(),
            systemImage: "play.rectangle",
            keywords: [item.title, "continue", "watch", "resume"]
        )
    }

    private static func score(
        _ command: CommandPaletteCommand,
        for query: String
    ) -> Int? {
        let normalizedQuery = normalize(query)
        guard !normalizedQuery.isEmpty else { return 0 }

        let title = normalize(command.title)
        if title == normalizedQuery {
            return 400
        }
        if title.hasPrefix(normalizedQuery) {
            return 300
        }
        if title.split(separator: " ").contains(where: {
            $0.hasPrefix(normalizedQuery)
        }) {
            return 250
        }
        if title.contains(normalizedQuery) {
            return 200
        }

        let keywordScore = command.keywords
            .map { normalize($0) }
            .compactMap { keyword -> Int? in
                if keyword == normalizedQuery {
                    return 180
                }
                if keyword.hasPrefix(normalizedQuery) {
                    return 150
                }
                if keyword.contains(normalizedQuery) {
                    return 100
                }
                return nil
            }
            .max()
        if let keywordScore {
            return keywordScore
        }

        let searchableText = normalize(
            ([command.title] + command.keywords).joined(separator: " ")
        )
        let tokens = normalizedQuery.split(whereSeparator: \.isWhitespace)
        if !tokens.isEmpty,
           tokens.allSatisfy({ searchableText.contains($0) })
        {
            return 80
        }
        return nil
    }

    private static func rankingAdjustment(
        for command: CommandPaletteCommand
    ) -> Int {
        switch command.action {
        case .openSite:
            20
        default:
            0
        }
    }

    private static func normalize(_ value: String) -> String {
        value
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: .current
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
