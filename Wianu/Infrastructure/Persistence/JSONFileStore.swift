//
//  JSONFileStore.swift
//  Wianu
//
//  Created by Tim on 25.07.26.
//

import Foundation

enum JSONFileStoreError: LocalizedError {
    case applicationSupportDirectoryUnavailable

    var errorDescription: String? {
        switch self {
        case .applicationSupportDirectoryUnavailable:
            return "The Application Support directory is unavailable."
        }
    }
}

struct JSONFileStore<Value: Codable> {
    let fileName: String
    let folderName: String
    var baseDirectory: URL?

    private var fileURL: URL {
        get throws {
            let applicationSupportURL: URL

            if let baseDirectory {
                applicationSupportURL = baseDirectory
            } else if let defaultDirectory = FileManager.default.urls(
                    for: .applicationSupportDirectory,
                    in: .userDomainMask
                ).first {
                applicationSupportURL = defaultDirectory
            } else {
                throw JSONFileStoreError.applicationSupportDirectoryUnavailable
            }

            let folderURL = applicationSupportURL.appending(
                path: folderName,
                directoryHint: .isDirectory
            )

            try FileManager.default.createDirectory(
                at: folderURL,
                withIntermediateDirectories: true
            )

            return folderURL.appending(
                path: fileName,
                directoryHint: .notDirectory
            )
        }
    }

    func load(defaultValue: @autoclosure () -> Value) throws -> Value {
        let url = try fileURL

        guard FileManager.default.fileExists(atPath: url.path) else {
            return defaultValue()
        }

        let data = try Data(contentsOf: url)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode(Value.self, from: data)
        } catch {
            // Site data created by early versions used Foundation's default
            // numeric date representation. Keep that data readable.
            return try JSONDecoder().decode(Value.self, from: data)
        }
    }

    func save(_ value: Value) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(value)
        try data.write(to: fileURL, options: [.atomic])
    }
}
