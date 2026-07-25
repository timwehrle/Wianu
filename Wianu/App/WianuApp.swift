//
//  WianuApp.swift
//  Wianu
//
//  Created by Tim on 24.07.26.
//

import SwiftUI

@main
struct WianuApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1200, height: 800)
    }
}
