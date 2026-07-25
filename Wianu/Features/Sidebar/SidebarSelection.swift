//
//  SidebarSelection.swift
//  Wianu
//
//  Created by Tim on 25.07.26.
//

import Foundation

enum SidebarSelection: Hashable {
    case site(SavedSite.ID)
    case continueWatching(ContinueWatchingItem.ID)
}
