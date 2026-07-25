import SwiftUI

struct SiteRow: View {
    let site: SavedSite

    var body: some View {
        Label {
            Text(site.name)
                .lineLimit(1)
        } icon: {
            FaviconView(url: site.url)
        }
    }
}
