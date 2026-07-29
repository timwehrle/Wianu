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
    let tmdbClient: TMDBClient

    let mode: Mode
    @State private var draft: SiteDraft
    @State private var providers: [TMDBProvider] = []
    @State private var providerLoadError: String?
    @State private var providerWasManuallySelected = false

    init(store: SiteStore, tmdbClient: TMDBClient, mode: Mode) {
        self.store = store
        self.tmdbClient = tmdbClient
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

                    if !draft.address.isEmpty, !draft.siteURLIsValid {
                        Text("Enter a valid HTTP or HTTPS website address.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    field("Search URL (Optional)") {
                        TextField(
                            "https://example.com/search?q={query}",
                            text: $draft.searchURLTemplate
                        )
                        .autocorrectionDisabled()
                    }

                    Text(
                        "Use {query} where the movie or show title belongs. "
                            + "Leave this empty to hide the site from Search."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    if !draft.searchURLTemplateIsValid {
                        Text(
                            "Enter a valid HTTP or HTTPS URL containing "
                                + "exactly one {query} placeholder."
                        )
                        .font(.caption)
                        .foregroundStyle(.red)
                    }

                    field("TMDB Provider (Optional)") {
                        Picker("TMDB Provider", selection: providerSelection) {
                            Text("Not associated").tag(nil as Int?)
                            ForEach(providers) { provider in
                                Text(provider.name).tag(provider.id as Int?)
                            }
                        }
                        .labelsHidden()
                    }

                    Text(
                        providerLoadError
                            ?? "Associate this site so TMDB availability can open its configured Search URL."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(20)
            .frame(minWidth: 520, minHeight: 360, alignment: .topLeading)
            .onChange(of: draft.address) {
                applySuggestedSearchTemplate()
                applySuggestedProvider()
            }
            .task { await loadProviders() }
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

    private func applySuggestedSearchTemplate() {
        guard
            draft.searchURLTemplate.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty,
            let suggestion = draft.suggestedSearchURLTemplate
        else { return }

        draft.searchURLTemplate = suggestion
    }

    private var providerSelection: Binding<Int?> {
        Binding(
            get: { draft.tmdbProvider?.id },
            set: { id in
                providerWasManuallySelected = true
                draft.tmdbProvider = providers.first(where: { $0.id == id }).map
                {
                    TMDBProviderReference(id: $0.id, name: $0.name)
                }
            }
        )
    }

    private func applySuggestedProvider() {
        guard !providerWasManuallySelected else { return }
        draft.tmdbProvider = draft.suggestedTMDBProvider
    }

    private func loadProviders() async {
        guard tmdbClient.isConfigured else {
            providerLoadError =
                "Configure TMDB to load its catalog. Known sites are associated automatically."
            applySuggestedProvider()
            return
        }
        do {
            providers = try await tmdbClient.providers()
            if let current = draft.tmdbProvider,
                !providers.contains(where: { $0.id == current.id })
            {
                providers.insert(
                    TMDBProvider(
                        id: current.id,
                        name: current.name,
                        logoPath: nil
                    ),
                    at: 0
                )
            }
            applySuggestedProvider()
        } catch {
            providerLoadError = error.localizedDescription
            applySuggestedProvider()
        }
    }
}
