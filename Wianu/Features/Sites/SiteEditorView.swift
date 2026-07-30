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

    init(store: SiteStore, tmdbClient: TMDBClient, mode: Mode) {
        self.store = store
        self.tmdbClient = tmdbClient
        self.mode = mode

        switch mode {
        case .add:
            _draft = State(initialValue: SiteDraft())
        case let .edit(site):
            _draft = State(initialValue: SiteDraft(site: site))
            _providers = State(
                initialValue: site.tmdbProvider.map {
                    [
                        TMDBProvider(
                            id: $0.id,
                            name: $0.name,
                            logoPath: nil
                        )
                    ]
                } ?? []
            )
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
                        TMDBProviderPicker(
                            providers: providers,
                            selection: providerSelection
                        )
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

    private func field(
        _ title: String,
        @ViewBuilder content: () -> some View
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
        case let .edit(site):
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
                draft.tmdbProvider = providers.first(where: { $0.id == id }).map {
                    TMDBProviderReference(id: $0.id, name: $0.name)
                }
            }
        )
    }

    private func loadProviders() async {
        guard tmdbClient.isConfigured else {
            providerLoadError =
                "Configure TMDB to load its provider catalog."
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
        } catch {
            providerLoadError = error.localizedDescription
        }
    }
}

private struct TMDBProviderPicker: View {
    let providers: [TMDBProvider]
    @Binding var selection: Int?
    @State private var isPresented = false
    @State private var query = ""

    private var selectedProvider: TMDBProvider? {
        providers.first { $0.id == selection }
    }

    private var filteredProviders: [TMDBProvider] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return providers }
        return providers.filter {
            $0.name.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            HStack {
                Text(selectedProvider?.name ?? "Not associated")
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.bordered)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            VStack(spacing: 8) {
                TextField("Search providers", text: $query)
                    .textFieldStyle(.roundedBorder)

                List {
                    providerButton(name: "Not associated", id: nil)

                    ForEach(filteredProviders) { provider in
                        providerButton(name: provider.name, id: provider.id)
                    }
                }
                .listStyle(.plain)
            }
            .padding(12)
            .frame(width: 320, height: 360)
        }
    }

    private func providerButton(name: String, id: Int?) -> some View {
        Button {
            selection = id
            isPresented = false
            query = ""
        } label: {
            HStack {
                Text(name)
                Spacer()
                if selection == id {
                    Image(systemName: "checkmark")
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
