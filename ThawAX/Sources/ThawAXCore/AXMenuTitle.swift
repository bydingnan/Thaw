//
//  AXMenuTitle.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

/// The shared eligibility rule for application-menu geometry.
public enum AXMenuTitle {
    public static func includes(role: String?, isEnabled: Bool?) -> Bool {
        isEnabled == true && (role == "AXMenuBarItem" || role == "AXMenuItem")
    }
}
