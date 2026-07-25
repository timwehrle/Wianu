import Foundation
import Observation

@MainActor
@Observable
final class SiteStore {
    private(set) var sites: [SavedSite] = []
    private(set) var persistenceError: String?

    @ObservationIgnored
    private let fileStore: JSONFileStore<[SavedSite]>

    init(
        fileStore: JSONFileStore<[SavedSite]> = JSONFileStore(
            fileName: "sites.json",
            folderName: "Wianu"
        )
    ) {
        self.fileStore = fileStore
        load()
    }

    func addSite(_ draft: SiteDraft) {
        guard let values = draft.validatedValues else { return }
        sites.append(SavedSite(name: values.name, urlString: values.url.absoluteString))
        persist()
    }

    func updateSite(id: SavedSite.ID, with draft: SiteDraft) {
        guard
            let index = sites.firstIndex(where: { $0.id == id }),
            let values = draft.validatedValues
        else { return }

        sites[index].name = values.name
        sites[index].urlString = values.url.absoluteString
        persist()
    }

    func deleteSite(id: SavedSite.ID) {
        sites.removeAll { $0.id == id }
        persist()
    }

    private func load() {
        do {
            sites = try fileStore.load(defaultValue: [])
            persistenceError = nil
        } catch {
            sites = []
            persistenceError = error.localizedDescription
        }
    }

    private func persist() {
        do {
            try fileStore.save(sites)
            persistenceError = nil
        } catch {
            persistenceError = error.localizedDescription
        }
    }
}
