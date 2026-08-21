import SwiftUI

struct WatchlistRow: View {
    let item: WatchlistItem

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .lineLimit(1)

                if let year = item.year {
                    Text(year.formatted(.number.grouping(.never)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } icon: {
            Image(systemName: "film")
                .foregroundStyle(.secondary)
        }
        .help(item.title)
    }
}

struct WatchlistItemEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let item: WatchlistItem?
    let onSave: (String, Int?, URL?) -> Void

    @State private var title: String
    @State private var year: String
    @State private var address: String

    init(
        item: WatchlistItem? = nil,
        onSave: @escaping (String, Int?, URL?) -> Void
    ) {
        self.item = item
        self.onSave = onSave
        _title = State(initialValue: item?.title ?? "")
        _year = State(initialValue: item?.year.map(String.init) ?? "")
        _address = State(initialValue: item?.url?.absoluteString ?? "")
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item == nil ? "Add Movie" : "Edit Movie")
                        .font(.title2.weight(.semibold))
                    Text("Only the title is required. Add a link to open the movie directly.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 16) {
                    field("Title") {
                        TextField("Movie title", text: $title)
                    }
                    field("Year (Optional)") {
                        TextField("2026", text: $year)
                    }
                    field("Link (Optional)") {
                        TextField("https://example.com/movie", text: $address)
                            .autocorrectionDisabled()
                    }

                    if !yearIsValid {
                        validationMessage("Enter a four-digit year.")
                    }
                    if !addressIsValid {
                        validationMessage("Enter a valid HTTP or HTTPS link.")
                    }
                }

                Spacer()
            }
            .padding(20)
            .frame(minWidth: 500, minHeight: 330, alignment: .topLeading)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .keyboardShortcut(.defaultAction)
                        .disabled(!isValid)
                }
            }
        }
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedYear: String {
        year.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var parsedYear: Int? {
        trimmedYear.isEmpty ? nil : Int(trimmedYear)
    }

    private var yearIsValid: Bool {
        trimmedYear.isEmpty
            || (trimmedYear.count == 4
                && parsedYear.map { (1888 ... 2100).contains($0) } == true)
    }

    private var trimmedAddress: String {
        address.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var parsedURL: URL? {
        guard !trimmedAddress.isEmpty else { return nil }
        let addressWithScheme =
            trimmedAddress.contains("://")
                ? trimmedAddress
                : "https://\(trimmedAddress)"
        let candidate = URL(string: addressWithScheme)
        guard let candidate,
              let scheme = candidate.scheme?.lowercased(),
              scheme == "https",
              candidate.host() != nil
        else { return nil }
        return candidate
    }

    private var addressIsValid: Bool {
        trimmedAddress.isEmpty || parsedURL != nil
    }

    private var isValid: Bool {
        !trimmedTitle.isEmpty && yearIsValid && addressIsValid
    }

    private func field(
        _ label: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline.weight(.medium))
            content()
                .textFieldStyle(.roundedBorder)
        }
    }

    private func validationMessage(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.red)
    }

    private func save() {
        guard isValid else { return }
        onSave(trimmedTitle, parsedYear, parsedURL)
        dismiss()
    }
}
