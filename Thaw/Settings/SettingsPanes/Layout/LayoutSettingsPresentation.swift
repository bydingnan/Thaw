//
//  LayoutSettingsPresentation.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

/// Arrangement depends on the system menu bar, but replacement settings remain independently editable.
struct LayoutSettingsPresentation {
    let isMenuBarAutoHidden: Bool

    var canArrangeLayout: Bool {
        !isMenuBarAutoHidden
    }

    var canConfigureReplacements: Bool {
        true
    }
}
