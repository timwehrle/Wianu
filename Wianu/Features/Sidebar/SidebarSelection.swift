import Foundation

enum SidebarSelection: Hashable {
    case site(SavedSite.ID)
    case continueWatching(ContinueWatchingItem.ID)
}
