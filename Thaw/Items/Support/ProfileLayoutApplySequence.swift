//
//  ProfileLayoutApplySequence.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

nonisolated enum ProfileLayoutApplySequence {
    static func mayContinue(isCancelled: Bool = Task.isCancelled) -> Bool {
        !isCancelled
    }
}
