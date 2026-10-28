//
//  LayoutApplyOutcome.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

nonisolated enum LayoutApplyOutcome: Equatable {
    case applied
    case restored(originalOrder: [String], requestedOrder: [String])
    case rollbackIncomplete(originalOrder: [String], requestedOrder: [String])
}
