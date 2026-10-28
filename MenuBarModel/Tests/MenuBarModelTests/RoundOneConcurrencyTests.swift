//
//  RoundOneConcurrencyTests.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

import MenuBarModel
import Testing

@Suite(.timeLimit(.minutes(1)))
struct RoundOneConcurrencyTests {
    @Test func cancellingOwningRequestReturnsWithoutCancellingSharedWalk() async {
        let started = AsyncStream.makeStream(of: Void.self)
        let release = AsyncStream.makeStream(of: Void.self)
        let finished = AsyncStream.makeStream(of: Bool.self)
        let gate = MenuBarInventoryScanGate<String, Bool> { state, _, _ in
            started.continuation.yield(())
            for await _ in release.stream {
                break
            }
            finished.continuation.yield(!Task.isCancelled)
            return (!Task.isCancelled, state)
        }
        let request = Task { await gate.snapshot(freshOnly: false) }
        for await _ in started.stream {
            break
        }
        request.cancel()
        #expect(await request.value == nil)
        release.continuation.finish()
        for await uncancelled in finished.stream {
            #expect(uncancelled)
            break
        }
    }

    @Test func cancellingJoinedRequestReturnsBeforeSharedWalkFinishes() async {
        let started = AsyncStream.makeStream(of: Void.self)
        let release = AsyncStream.makeStream(of: Void.self)
        let gate = MenuBarInventoryScanGate<String, Bool> { state, _, _ in
            started.continuation.yield(())
            for await _ in release.stream {
                break
            }
            return (!Task.isCancelled, state)
        }
        let owner = Task { await gate.snapshot(freshOnly: false) }
        for await _ in started.stream {
            break
        }
        let joined = Task { await gate.snapshot(freshOnly: false) }
        // Let the joined request enter the shared wait, while the walk is held.
        try? await Task.sleep(for: .milliseconds(20))
        joined.cancel()
        #expect(await joined.value == nil)
        release.continuation.finish()
        #expect(await owner.value == true)
    }

    @Test func sharedWalkStillPublishesStateAfterAllRequestersCancel() async {
        let started = AsyncStream.makeStream(of: Void.self)
        let release = AsyncStream.makeStream(of: Void.self)
        let finished = AsyncStream.makeStream(of: Void.self)
        let gate = MenuBarInventoryScanGate<String, [String]> { previous, _, _ in
            var state = previous
            let pass = state.begin(owners: [1], priorityOwners: [])
            if pass.generation == 1 {
                started.continuation.yield(())
                for await _ in release.stream {
                    break
                }
                state.didAttempt(owner: 1, generation: pass.generation)
                state.record(["retained"], owner: 1, generation: pass.generation)
                finished.continuation.yield(())
            }
            return (state.observations, state)
        }
        let owner = Task { await gate.snapshot(freshOnly: false) }
        for await _ in started.stream {
            break
        }
        owner.cancel()
        #expect(await owner.value == nil)
        release.continuation.finish()
        for await _ in finished.stream {
            break
        }
        #expect(await gate.snapshot(freshOnly: true) == ["retained"])
    }

    @Test func cancellingTimedWaitReleasesConcurrentlyAcquiredPermit() async throws {
        try await exerciseCancellationRace()
    }

    @Test func subsequentTimedWaitStillAcquiresAfterCancellationRace() async throws {
        try await exerciseCancellationRace()
    }

    @Test func timeoutCompensationStillReleasesPermit() async throws {
        let semaphore = SimpleSemaphore(value: 0)
        do {
            try await semaphore.wait(timeout: .milliseconds(1))
            Issue.record("Expected timeout")
        } catch is SimpleSemaphore.TimeoutError {} catch {
            Issue.record("Unexpected error: \(error)")
        }
        await semaphore.signal()
        try await semaphore.wait(timeout: .seconds(1))
        await semaphore.signal()
    }

    private func exerciseCancellationRace() async throws {
        for _ in 0 ..< 100 {
            let semaphore = SimpleSemaphore(value: 0)
            let waiter = Task {
                do {
                    try await semaphore.wait(timeout: .seconds(1))
                    await semaphore.signal()
                } catch is CancellationError {} catch {
                    Issue.record("Unexpected wait failure: \(error)")
                }
            }
            await Task.yield()
            waiter.cancel()
            await semaphore.signal()
            await waiter.value
            try await semaphore.wait(timeout: .seconds(1))
            await semaphore.signal()
        }
    }
}
