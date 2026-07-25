//
//  SavedSite.swift
//  Wianu
//
//  Created by Tim on 24.07.26.
//

import Foundation

struct SavedSite: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var urlString: String
    var createdAt: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        urlString: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.urlString = urlString
        self.createdAt = createdAt
    }

    var url: URL? {
        URL(string: urlString)
    }
}
