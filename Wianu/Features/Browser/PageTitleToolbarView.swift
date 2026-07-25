//
//  PageTitleToolbarView.swift
//  Wianu
//
//  Created by Tim on 25.07.26.
//

import SwiftUI

struct PageTitleToolbarView: View {
    let title: String
    let isSaved: Bool
    let canSave: Bool
    let toggleSaved: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.tail)
                .help(title)

            Divider().frame(height: 14)

            Button(action: toggleSaved) {
                Image(
                    systemName: isSaved
                        ? "bookmark.fill"
                        : "bookmark"
                )
                .imageScale(.medium)
            }
            .buttonStyle(.plain)
            .foregroundStyle(isSaved ? .primary : .secondary)
            .disabled(!canSave)
            .help(
                isSaved
                    ? "Remove from Continue Watching"
                    : "Save to Continue Watching"
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .fixedSize(horizontal: true, vertical: false)
    }
}
