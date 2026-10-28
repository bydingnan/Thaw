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
    private struct Attempt {
        let token: UUID
        var isReclaiming = false
    }

    private let sleep: (Duration) async -> Void
    private var attempt: Attempt?
    private var tornDown = false

    init(sleep: @escaping (Duration) async -> Void = { try? await Task.sleep(for: $0) }) {
        self.sleep = sleep
    }

    func begin() -> UUID? {
        guard attempt == nil else { return nil }
        let token = UUID()
        attempt = Attempt(token: token)
        return token
    }

    func isCurrent(_ token: UUID) -> Bool {
        attempt?.token == token
    }

    func tearDownOnce(_ teardown: () -> Void) {
        guard !tornDown else { return }
        tornDown = true
        teardown()
    }

    func finish(
        _ token: UUID,
        timedOut: Bool,
        teardown: () -> Void,
        reply: () -> Void
    ) async {
        guard isCurrent(token) else { return }
        if !timedOut {
            guard attempt?.isReclaiming == false else { return }
            attempt?.isReclaiming = true
        }
        tearDownOnce(teardown)
        if !timedOut {
            await sleep(.milliseconds(150))
            guard isCurrent(token) else { return }
        }
        attempt = nil
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
    private let sleep: (Duration) async -> Void

    init(
        requestSave: @escaping () -> Void,
        flush: @escaping () async -> Void,
        prepareWatcher: @escaping () throws -> (() -> Void),
        restore: @escaping () async -> Void,
        teardown: @escaping () -> Void,
        exit: @escaping () -> Void,
        sleep: @escaping (Duration) async -> Void = { try? await Task.sleep(for: $0) }
    ) {
        self.requestSave = requestSave
        self.flush = flush
        self.prepareWatcher = prepareWatcher
        self.restore = restore
        self.teardown = teardown
        self.exit = exit
        self.sleep = sleep
    }

    func run() async throws {
        // Preparation can fail without touching layout or control ownership.
        let startWatcher = try prepareWatcher()
        requestSave()
        await flush()
        await restore()
        teardown()
        await sleep(.milliseconds(650))
        startWatcher()
        exit()
    }
}
