//
//  SpaceAppearanceResolver.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

import AppKit
import MenuBarModel
import Observation

nonisolated enum SpaceAppearanceResolver {
    static func configuration(
        for displayID: CGDirectDisplayID,
        spaces: [CGDirectDisplayID: CGSSpaceID],
        shared: MenuBarAppearanceConfigurationV2,
        overrides: [String: MenuBarAppearanceConfigurationV2]
    ) -> MenuBarAppearanceConfigurationV2 {
        guard let space = spaces[displayID] else { return shared }
        return overrides[String(space)] ?? shared
    }
}

@MainActor
@Observable
final class DisplaySpaceSnapshot {
    private(set) var spaces: [CGDirectDisplayID: CGSSpaceID] = [:]
    private let read: () -> [CGDirectDisplayID: CGSSpaceID]

    init(read: @escaping () -> [CGDirectDisplayID: CGSSpaceID] = {
        Dictionary(uniqueKeysWithValues: NSScreen.managedScreens.compactMap { screen in
            Bridging.getCurrentSpaceID(for: screen.displayID).map { (screen.displayID, $0) }
        })
    }) {
        self.read = read
    }

    func refresh() {
        let latest = read()
        if latest != spaces {
            spaces = latest
        }
    }
}
