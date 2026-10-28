//
//  ParkedOffMenuBarBandTests.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

import Foundation
@testable import MenuBarModel
import Testing

/// MenuBarItem.isParkedOffMenuBarBand(among:): the host parks an item it
/// cannot seat at origin.x == -1, in the bar's own Y band, which the Y-only
/// checks used to miss (a notched, overflowed bar parks the control item there).
@Suite("Parked off the menu bar band")
struct ParkedOffMenuBarBandTests {
    private func item(
        _ bounds: CGRect,
        tag: MenuBarItemTag = MenuBarItemTag(namespace: .string("com.example.app"), title: "Item-0")
    ) -> MenuBarItem {
        MenuBarItem(
            tag: tag,
            windowID: 1,
            ownerPID: 700,
            sourcePID: 700,
            bounds: bounds,
            title: tag.title,
            isOnScreen: true
        )
    }

    private func isParked(_ item: MenuBarItem) -> Bool {
        MenuBarBandClassifier.isParked(
            item.bounds,
            displays: [CGRect(x: 0, y: 0, width: 1920, height: 1080)]
        )
    }

    @Test("The leading-edge sentinel is parked")
    func sentinelIsParked() {
        let parked = item(CGRect(x: -1, y: 4, width: 31, height: 24))
        #expect(isParked(parked))
    }

    @Test("A real seat beside the bar is not parked")
    func realSeatIsNotParked() {
        let live = item(CGRect(x: 1200, y: 4, width: 24, height: 22))
        #expect(!isParked(live))
    }

    @Test("A zero-size frame is parked")
    func zeroSizeIsParked() {
        let empty = item(CGRect(x: 1400, y: 0, width: 0, height: 0))
        #expect(isParked(empty))
    }

    @Test("The Y-band collateral park is still detected")
    func yBandIsParked() {
        let collateral = item(CGRect(x: 1200, y: 1400, width: 24, height: 22))
        #expect(isParked(collateral))
    }
}
