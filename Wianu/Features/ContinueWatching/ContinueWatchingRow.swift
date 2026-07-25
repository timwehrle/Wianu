//
//  ContinueWatchingRow.swift
//  Wianu
//
//  Created by Tim on 25.07.26.
//

import SwiftUI

struct ContinueWatchingRow: View {
    let item: ContinueWatchingItem
    let site: SavedSite?

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .lineLimit(1)

                if let site {
                    Text(site.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        } icon: {
            FaviconView(url: site?.url ?? item.url)
        }
        .help(item.title)
    }
}
