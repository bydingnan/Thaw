//
//  PeriodicCacheRefreshGate.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

import CoreGraphics

nonisolated struct PeriodicCacheRefreshGate {
    private(set) var signature: [CGWindowID]?
    func needsRefresh(_ candidate: [CGWindowID]) -> Bool {
        signature != candidate
    }

    mutating func complete(_ candidate: [CGWindowID]) {
        signature = candidate
    }

    mutating func deferRefresh() {
        signature = nil
    }
}
