//
//  PendingPhysicalSeatLedger.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

nonisolated struct PendingPhysicalSeatLedger {
    private var identifiers = Set<String>()
    mutating func insert(_ identifier: String) {
        identifiers.insert(identifier)
    }

    func contains(_ identifier: String) -> Bool {
        identifiers.contains(identifier)
    }

    mutating func remove(_ identifier: String) {
        identifiers.remove(identifier)
    }

    mutating func removeAll() {
        identifiers.removeAll()
    }

    var isEmpty: Bool {
        identifiers.isEmpty
    }
}
