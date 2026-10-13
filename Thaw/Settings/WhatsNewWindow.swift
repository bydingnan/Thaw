//
//  WhatsNewWindow.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import SwiftUI

/// The standalone, resizable What's New window. Kept separate from Settings so
/// release notes read as their own destination, reachable from the menu, the
/// About pane, and automatically on the first launch after an upgrade.
struct WhatsNewWindow: Scene {
    @Bindable var appState: AppState

    var body: some Scene {
        ThawWindow(id: .whatsNew, appState: appState) {
            WhatsNewView()
                .environment(appState)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 860, height: 780)
        .windowStyle(.titleBar)
    }
}
