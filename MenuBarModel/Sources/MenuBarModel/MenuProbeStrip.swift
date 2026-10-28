//
//  MenuProbeStrip.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

import CoreGraphics

public enum MenuProbeStrip {
    public static func derive(display: CGRect, reservedHeight: CGFloat, revealedHeight: CGFloat) -> CGRect {
        CGRect(
            x: display.minX,
            y: display.minY,
            width: display.width,
            height: max(reservedHeight, revealedHeight)
        )
    }
}
