import SwiftUI

struct RenameContinueWatchingView: View {
    @Environment(\.dismiss) private var dismiss

    let item: ContinueWatchingItem
    let onSave: (String) -> Void

    @State private var title: String

    init(
        item: ContinueWatchingItem,
        onSave: @escaping (String) -> Void
    ) {
        self.item = item
        self.onSave = onSave
        _title = State(initialValue: item.title)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Rename Item")
                        .font(.title2.weight(.semibold))

                    Text("Choose a new title for this Continue Watching item.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Title")
                        .font(.subheadline.weight(.medium))

                    TextField("Continue Watching title", text: $title)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .padding(20)
            .frame(minWidth: 460, minHeight: 60, alignment: .topLeading)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .keyboardShortcut(.defaultAction)
                        .disabled(trimmedTitle.isEmpty)
                }
            }
        }
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        guard !trimmedTitle.isEmpty else { return }
        onSave(trimmedTitle)
        dismiss()
    }
}
