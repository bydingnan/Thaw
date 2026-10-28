//
//  OverflowWalkGate.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

import CoreGraphics

actor OverflowWalkGate<Value: Sendable> {
    private struct Observation {
        let startedAt: ContinuousClock.Instant
        let value: Value
        let cutoff: ContinuousClock.Instant?
    }

    private struct Flight {
        let generation: UInt64
        let startedAt: ContinuousClock.Instant
        let task: Task<Value, Never>
        let cutoff: ContinuousClock.Instant?
    }

    private let read: @Sendable (CGDirectDisplayID, ContinuousClock.Instant?) async -> Value
    private let lifetime: Duration
    private var memo: [CGDirectDisplayID: Observation] = [:]
    private var flights: [CGDirectDisplayID: Flight] = [:]
    private var generation: UInt64 = 0

    init(lifetime: Duration = .milliseconds(250), read: @escaping @Sendable (CGDirectDisplayID, ContinuousClock.Instant?) async -> Value) {
        self.lifetime = lifetime
        self.read = read
    }

    func observation(on display: CGDirectDisplayID, newerThan: ContinuousClock.Instant? = nil) async -> Value {
        if let previous = memo[display], ContinuousClock.now - previous.startedAt < lifetime, isFresh(startedAt: previous.startedAt, cutoff: previous.cutoff, for: newerThan) {
            return previous.value
        }
        if let flight = flights[display], isFresh(startedAt: flight.startedAt, cutoff: flight.cutoff, for: newerThan) {
            return await flight.task.value
        }
        generation &+= 1
        let current = generation
        let startedAt = ContinuousClock.now
        let read = self.read
        let task = Task.detached(priority: Task.currentPriority) { await read(display, newerThan) }
        flights[display] = Flight(generation: current, startedAt: startedAt, task: task, cutoff: newerThan)
        let value = await task.value
        if flights[display]?.generation == current {
            flights[display] = nil
            memo[display] = Observation(startedAt: startedAt, value: value, cutoff: newerThan)
        }
        return value
    }

    private func isFresh(
        startedAt: ContinuousClock.Instant,
        cutoff: ContinuousClock.Instant?,
        for requested: ContinuousClock.Instant?
    ) -> Bool {
        guard let requested else { return true }
        // A newer outer walk can still contain an older inner absence memo.
        return startedAt > requested && cutoff.map { $0 >= requested } == true
    }
}
