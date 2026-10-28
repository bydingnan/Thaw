//
//  ExitCoordinators.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

import Foundation

@MainActor
final class TerminationCoordinator {
    private var attempt: UUID?
    private var tornDown = false

    func begin() -> UUID? {
        guard attempt == nil else { return nil }
        let token = UUID()
        attempt = token
        return token
    }

    func isCurrent(_ token: UUID) -> Bool {
        attempt == token
    }

    func tearDownOnce(_ teardown: () -> Void) {
        guard !tornDown else { return }
        tornDown = true
        teardown()
    }

    func finish(_ token: UUID, teardown: () -> Void, reply: () -> Void) {
        guard isCurrent(token) else { return }
        attempt = nil
        tearDownOnce(teardown)
        reply()
    }
}

@MainActor
struct RestartCoordinator {
    let requestSave: () -> Void
    let flush: () async -> Void
    let prepareWatcher: () throws -> (() -> Void)
    let restore: () async -> Void
    let teardown: () -> Void
    let exit: () -> Void

    func run() async throws {
        // Preparation can fail without touching layout or control ownership.
        let startWatcher = try prepareWatcher()
        requestSave()
        await flush()
        await restore()
        teardown()
        startWatcher()
        exit()
    }
}
