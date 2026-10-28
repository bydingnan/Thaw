//
//  SpaceAppearanceResolverTests.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

import CoreGraphics
import MenuBarModel
import Testing
@testable import Thaw

@MainActor
struct SpaceAppearanceResolverTests {
    private let shared = MenuBarAppearanceConfigurationV2.defaultConfiguration

    @Test func twoDisplaysResolveIndependentOverrides() {
        var first = shared
        first.shapeKind = .full
        var second = shared
        second.staticConfiguration.tintOpacity = 0.23
        let spaces: [CGDirectDisplayID: CGSSpaceID] = [1: 10, 2: 20]
        let overrides = ["10": first, "20": second]
        #expect(SpaceAppearanceResolver.configuration(for: 1, spaces: spaces, shared: shared, overrides: overrides) == first)
        #expect(SpaceAppearanceResolver.configuration(for: 2, spaces: spaces, shared: shared, overrides: overrides) == second)
    }

    @Test func spaceSwitchUpdatesOnlyOwningDisplay() {
        var override = shared
        override.staticConfiguration.tintOpacity = 0.23
        let before: [CGDirectDisplayID: CGSSpaceID] = [1: 10, 2: 20]
        let after: [CGDirectDisplayID: CGSSpaceID] = [1: 11, 2: 20]
        let overrides = ["11": override]
        let changed = [CGDirectDisplayID(1), 2].filter { display in
            SpaceAppearanceResolver.configuration(for: display, spaces: before, shared: shared, overrides: overrides)
                != SpaceAppearanceResolver.configuration(for: display, spaces: after, shared: shared, overrides: overrides)
        }
        #expect(changed == [1])
    }

    @Test func displayWithoutOverrideUsesSharedConfiguration() {
        var override = shared
        override.staticConfiguration.tintOpacity = 0.23
        let spaces: [CGDirectDisplayID: CGSSpaceID] = [1: 10, 2: 20]
        #expect(SpaceAppearanceResolver.configuration(for: 2, spaces: spaces, shared: shared, overrides: ["10": override]) == shared)
        #expect(SpaceAppearanceResolver.configuration(for: 3, spaces: spaces, shared: shared, overrides: ["10": override]) == shared)
    }

    @Test func displaySpaceSnapshotTracksSwitchesAndRemoval() {
        var current: [CGDirectDisplayID: CGSSpaceID] = [1: 10, 2: 20]
        let snapshot = DisplaySpaceSnapshot(read: { current })
        snapshot.refresh()
        #expect(snapshot.spaces == [1: 10, 2: 20])
        current = [1: 11, 2: 20]
        snapshot.refresh()
        #expect(snapshot.spaces == [1: 11, 2: 20])
        current = [2: 20]
        snapshot.refresh()
        #expect(snapshot.spaces == [2: 20])
        snapshot.refresh()
        #expect(snapshot.spaces == [2: 20])
    }
}
