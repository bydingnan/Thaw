//
//  ParkedItems.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import CoreGraphics
import MenuBarModel

/// Which live items macOS has parked off the menu bar, read from their frames.
nonisolated enum ParkedItems {
    /// The bar's vertical centre, read from a seated control item, and the windows of the
    /// items that sit off it: empty frames, frames below the bar band, and frames too far
    /// from that centre. Without a seated control only the first two can be told.
    static func parkedSetAndBarMidY(
        in items: [MenuBarItem],
        displays: [CGRect] = MenuBarBandClassifier.displayFrames
    ) -> (barMidY: CGFloat?, parkedIDs: Set<CGWindowID>) {
        let barMidY = items.first(where: {
            $0.isControlItem && !MenuBarBandClassifier.isParked($0.bounds, displays: displays)
        })?.bounds.midY
        let parkedIDs = Set(items.filter {
            MenuBarBandClassifier.isParked($0.bounds, displays: displays)
        }.map(\.windowID))

        return (barMidY, parkedIDs)
    }
}
