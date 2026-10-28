//
//  MenuProbeStripTests.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

import CoreGraphics
@testable import MenuBarModel
import Testing

struct MenuProbeStripTests {
    @Test func fullscreenAutohideUsesRevealedMenuBarStrip() {
        let strip = MenuProbeStrip.derive(display: CGRect(x: 0, y: 0, width: 1440, height: 900), reservedHeight: 0, revealedHeight: 24)
        #expect(strip.height == 24)
        #expect(strip.minY == 0)
    }

    @Test func fullscreenMenuOnSecondDisplayRemainsEligible() {
        let strip = MenuProbeStrip.derive(display: CGRect(x: 0, y: 900, width: 1440, height: 900), reservedHeight: 0, revealedHeight: 24)
        #expect(strip.minY == 900)
        #expect(strip.maxY == 924)
    }

    @Test func desktopPopupStillDoesNotBorrowFullscreenStrip() {
        let strip = MenuProbeStrip.derive(display: CGRect(x: 0, y: 900, width: 1440, height: 900), reservedHeight: 0, revealedHeight: 24)
        #expect(!strip.intersects(CGRect(x: 20, y: 1200, width: 200, height: 100)))
    }
}
