//
//  MenuBarBandClassifierTests.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

import CoreGraphics
@testable import MenuBarModel
import Testing

struct MenuBarBandClassifierTests {
    let displays = [CGRect(x: 0, y: 0, width: 1920, height: 1080), CGRect(x: 0, y: 1080, width: 1920, height: 1080)]

    @Test func lowerDisplayMenuBarItemsAreNotParked() {
        #expect(!MenuBarBandClassifier.isParked(CGRect(x: 100, y: 1080, width: 24, height: 24), displays: displays))
    }

    @Test func genuinelyParkedItemBelowLowerDisplayIsStillParked() {
        #expect(MenuBarBandClassifier.isParked(CGRect(x: 100, y: 1400, width: 24, height: 24), displays: displays))
    }

    @Test func sentinelAndCollapsedFramesRemainParked() {
        #expect(MenuBarBandClassifier.isParked(CGRect(x: -1, y: 1080, width: 24, height: 24), displays: displays))
        #expect(MenuBarBandClassifier.isParked(.zero, displays: displays))
    }

    @Test func emptyDisplaysFallBackToAbsoluteMidY() {
        #expect(!MenuBarBandClassifier.isParked(CGRect(x: 100, y: 12, width: 24, height: 24), displays: []))
        #expect(MenuBarBandClassifier.isParked(CGRect(x: 100, y: 200, width: 24, height: 24), displays: []))
    }
}
