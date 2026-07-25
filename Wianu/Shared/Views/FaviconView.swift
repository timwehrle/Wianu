//
//  FaviconView.swift
//  Wianu
//
//  Created by Tim on 25.07.26.
//

import SwiftUI

struct FaviconView: View {
    let url: URL?

    private var faviconURL: URL? {
        guard let host = url?.host() else {
            return nil
        }

        var components = URLComponents(
            string: "https://www.google.com/s2/favicons"
        )

        components?.queryItems = [
            URLQueryItem(name: "domain", value: host),
            URLQueryItem(name: "sz", value: "64"),
        ]

        return components?.url
    }

    var body: some View {
        AsyncImage(url: faviconURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()

            case .empty, .failure:
                placeholder

            @unknown default:
                placeholder
            }
        }
        .frame(width: 16, height: 16)
        .clipShape(.rect(cornerRadius: 4))
    }

    private var placeholder: some View {
        Image(systemName: "globe")
            .foregroundStyle(.secondary)
            .frame(width: 16, height: 16)
    }
}
