//
//  DisplayTopologyChange.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

/// Accumulates identity changes across a debounced burst, even if the final set returns to its starting value.
struct DisplayTopologyChange {
    private var identities: Set<UInt32>
    private(set) var added = Set<UInt32>()
    private(set) var removed = Set<UInt32>()

    init(identities: Set<UInt32>) {
        self.identities = identities
    }

    var requiresInventoryRefresh: Bool {
        !added.isEmpty || !removed.isEmpty
    }

    var requiresCaptureCleanup: Bool {
        !removed.isEmpty
    }

    mutating func observe(_ current: Set<UInt32>) {
        added.formUnion(current.subtracting(identities))
        removed.formUnion(identities.subtracting(current))
        identities = current
    }

    mutating func consume() -> Self {
        let change = self
        added.removeAll()
        removed.removeAll()
        return change
    }
}
