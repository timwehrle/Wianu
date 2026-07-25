import SwiftUI

struct SiteEditorView: View {
    enum Mode {
        case add
        case edit(SavedSite)

        var title: String {
            switch self {
            case .add: "Add Site"
            case .edit: "Edit Site"
            }
        }

        var message: String {
            switch self {
            case .add: "Save a website to access it quickly from the sidebar."
            case .edit: "Update the name or website address."
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Bindable var store: SiteStore

    let mode: Mode
    @State private var draft: SiteDraft

    init(store: SiteStore, mode: Mode) {
        self.store = store
        self.mode = mode

        switch mode {
        case .add:
            _draft = State(initialValue: SiteDraft())
        case .edit(let site):
            _draft = State(initialValue: SiteDraft(site: site))
        }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(mode.title)
                        .font(.title2.weight(.semibold))

                    Text(mode.message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 16) {
                    field("Name") {
                        TextField("Example: OpenAI", text: $draft.name)
                    }

                    field("URL") {
                        TextField("example.com", text: $draft.address)
                            .autocorrectionDisabled()
                    }

                    if !draft.address.isEmpty, draft.validatedValues == nil {
                        Text("Enter a valid HTTP or HTTPS website address.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Spacer()
            }
            .padding(20)
            .frame(minWidth: 460, minHeight: 240, alignment: .topLeading)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .keyboardShortcut(.defaultAction)
                        .disabled(draft.validatedValues == nil)
                }
            }
        }
    }

    private func field<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.medium))
            content()
                .textFieldStyle(.roundedBorder)
        }
    }

    private func save() {
        switch mode {
        case .add:
            store.addSite(draft)
        case .edit(let site):
            store.updateSite(id: site.id, with: draft)
        }

        dismiss()
    }
}
