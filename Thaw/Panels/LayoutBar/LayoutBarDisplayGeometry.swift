//
//  LayoutBarDisplayGeometry.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

import AppKit

struct LayoutBarDisplayGeometry {
    let notchWidth: CGFloat
    let trailingOffset: CGFloat
    let minimumWidth: CGFloat

    init(screenFrame: CGRect, notchFrame: CGRect, notchGap: CGFloat) {
        notchWidth = notchFrame.width + notchGap
        trailingOffset = max(0, screenFrame.maxX - notchFrame.maxX - notchGap) + 7.5
        minimumWidth = max(0, screenFrame.maxX - notchFrame.minX) + 7.5
    }

    @MainActor
    static func screen(for view: NSView) -> NSScreen? {
        view.window?.screen
    }
}
