import Foundation

enum SidebarSelection: Hashable {
    case search
    case site(SavedSite.ID)
    case continueWatching(ContinueWatchingItem.ID)
    case watchlistItem(WatchlistItem.ID)
}
