//
//  CaptureServiceLifecycleState.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

import os.lock

/// Locked lifecycle accounting shared by the helper's independent XPC sessions.
public final class CaptureServiceLifecycleState: Sendable {
    private struct State {
        var successfulCaptures = 0
        var activeSessions = 0
        var inFlightRequests = 0
        var exitWhenIdle = false
        var exitScheduled = false
        var inFlightCaptureIDs: Set<Int> = []
        var captureCounter = 0
        var idleGeneration = 0
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    public init() {}

    public var captureCount: Int {
        state.withLock(\.successfulCaptures)
    }

    public var idleGeneration: Int {
        state.withLock(\.idleGeneration)
    }

    public func sessionOpened() {
        state.withLock {
            $0.activeSessions += 1
            $0.idleGeneration += 1
            $0.exitWhenIdle = false
        }
    }

    public func sessionClosed() -> Bool {
        state.withLock {
            $0.activeSessions = max(0, $0.activeSessions - 1)
            guard $0.activeSessions == 0 else { return false }
            guard $0.inFlightRequests == 0 else {
                $0.exitWhenIdle = true
                return false
            }
            return true
        }
    }

    public func requestStarted() -> Int {
        state.withLock {
            $0.inFlightRequests += 1
            $0.captureCounter += 1
            $0.inFlightCaptureIDs.insert($0.captureCounter)
            return $0.captureCounter
        }
    }

    public func requestFinished(_ captureID: Int) -> Bool {
        state.withLock {
            $0.inFlightCaptureIDs.remove(captureID)
            $0.inFlightRequests = max(0, $0.inFlightRequests - 1)
            return $0.exitWhenIdle && $0.inFlightRequests == 0
        }
    }

    public func isCaptureInFlight(_ id: Int) -> Bool {
        state.withLock { $0.inFlightCaptureIDs.contains(id) }
    }

    public func recordSuccess() -> Int {
        state.withLock {
            $0.successfulCaptures += 1
            return $0.successfulCaptures
        }
    }

    /// Validates the idle generation and claims retirement in one transaction.
    public func claimIdleExit(since generation: Int) -> Bool {
        state.withLock {
            guard $0.idleGeneration == generation, $0.activeSessions == 0, $0.inFlightRequests == 0, !$0.exitScheduled
            else { return false }
            $0.exitScheduled = true
            return true
        }
    }

    public func claimExit() -> Bool {
        state.withLock {
            guard !$0.exitScheduled else { return false }
            $0.exitScheduled = true
            return true
        }
    }
}
