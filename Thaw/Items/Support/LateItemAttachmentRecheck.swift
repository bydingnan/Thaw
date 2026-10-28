//
//  LateItemAttachmentRecheck.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

import Foundation

nonisolated struct LateItemAttachmentRecheck {
    private let initial: Set<String>
    private(set) var finished = false
    init(initialIdentifiers: [String]) {
        initial = Set(initialIdentifiers)
    }

    mutating func observed(_ identifiers: [String]) {
        if !Set(identifiers).subtracting(initial).isEmpty {
            finished = true
        }
    }

    var shouldForceAXRead: Bool {
        !finished
    }
}
