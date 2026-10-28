//
//  MenuBarBandClassifier.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

import CoreGraphics

public enum MenuBarBandClassifier {
    public static var displayFrames: [CGRect] {
        Bridging.activeDisplayIDs().map { CGDisplayBounds($0) }
    }

    public static func isParked(_ bounds: CGRect, displays: [CGRect]) -> Bool {
        guard !bounds.isEmpty, bounds.minX != -1 else { return true }
        let point = CGPoint(x: bounds.midX, y: bounds.midY)
        // No live display list (test hosts / early boot): fall back to the
        // absolute on-bar midY cap so seated y≈0 frames are not all parked.
        guard !displays.isEmpty else { return bounds.midY > 80 }
        guard let display = displays.first(where: { $0.contains(point) }) else { return true }
        return bounds.midY - display.minY > 80
    }

    public static func isParked(_ bounds: CGRect) -> Bool {
        isParked(bounds, displays: displayFrames)
    }
}
