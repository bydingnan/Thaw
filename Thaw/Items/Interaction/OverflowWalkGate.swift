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
    }

    private struct Flight {
        let generation: UInt64
        let startedAt: ContinuousClock.Instant
        let task: Task<Value, Never>
    }

    private let read: @Sendable (CGDirectDisplayID) async -> Value
    private let lifetime: Duration
    private var memo: [CGDirectDisplayID: Observation] = [:]
    private var flights: [CGDirectDisplayID: Flight] = [:]
    private var generation: UInt64 = 0

    init(lifetime: Duration = .milliseconds(250), read: @escaping @Sendable (CGDirectDisplayID) async -> Value) {
        self.lifetime = lifetime
        self.read = read
    }

    func observation(on display: CGDirectDisplayID, newerThan: ContinuousClock.Instant? = nil) async -> Value {
        if let previous = memo[display], ContinuousClock.now - previous.startedAt < lifetime, newerThan.map({ previous.startedAt > $0 }) ?? true {
            return previous.value
        }
        if let flight = flights[display], newerThan.map({ flight.startedAt > $0 }) ?? true {
            return await flight.task.value
        }
        generation &+= 1
        let current = generation
        let startedAt = ContinuousClock.now
        let read = self.read
        let task = Task.detached(priority: Task.currentPriority) { await read(display) }
        flights[display] = Flight(generation: current, startedAt: startedAt, task: task)
        let value = await task.value
        if flights[display]?.generation == current {
            flights[display] = nil
            memo[display] = Observation(startedAt: startedAt, value: value)
        }
        return value
    }
}
