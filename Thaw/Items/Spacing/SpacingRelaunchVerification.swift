//
//  SpacingRelaunchVerification.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

import Foundation

nonisolated enum SpacingRelaunchVerification {
    static func hasFreshProcess(currentPIDs: [pid_t], replacing originalPIDs: Set<pid_t>) -> Bool {
        currentPIDs.contains { !originalPIDs.contains($0) }
    }
}
