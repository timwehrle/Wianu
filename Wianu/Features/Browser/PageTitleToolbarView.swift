import SwiftUI

struct PageTitleToolbarView: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .lineLimit(1)
            .truncationMode(.tail)
            .help(title)
            .padding(.leading, 4)
            .padding(.trailing, 12)
    }
}
