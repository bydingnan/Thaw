//
//  ExitReclamationTests.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

import Foundation
import Testing
@testable import Thaw

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct ExitReclamationTests {
    @Test func successfulTerminationWaitsForControlItemReclaimBeforeReply() async throws {
        let sleeper = ExitReclamationSleeper()
        defer { sleeper.resume() }
        var events: [String] = []
        let coordinator = TerminationCoordinator(sleep: { delay in
            events.append("wait")
            await sleeper.sleep(for: delay)
        })
        let token = try #require(coordinator.begin())
        let completion = Task {
            await coordinator.finish(
                token,
                timedOut: false,
                teardown: { events.append("teardown") },
                reply: { events.append("reply") }
            )
        }

        await sleeper.waitUntilEntered()
        #expect(events == ["teardown", "wait"])
        #expect(sleeper.delays == [.milliseconds(150)])
        #expect(coordinator.isCurrent(token))
        #expect(coordinator.begin() == nil)

        sleeper.resume()
        await completion.value
        #expect(events == ["teardown", "wait", "reply"])
        #expect(!coordinator.isCurrent(token))
    }

    @Test func terminationTimeoutDoesNotWaitForControlItemReclaim() async throws {
        let sleeper = ExitReclamationSleeper()
        sleeper.resume()
        var events: [String] = []
        let coordinator = TerminationCoordinator(sleep: { delay in
            events.append("wait")
            await sleeper.sleep(for: delay)
        })
        let token = try #require(coordinator.begin())

        await coordinator.finish(
            token,
            timedOut: true,
            teardown: { events.append("teardown") },
            reply: { events.append("reply") }
        )

        #expect(events == ["teardown", "reply"])
        #expect(sleeper.delays.isEmpty)
        #expect(!coordinator.isCurrent(token))
    }

    @Test func restartWaitsForControlItemReclaimBeforeWatcherAndExit() async throws {
        let sleeper = ExitReclamationSleeper()
        defer { sleeper.resume() }
        var events: [String] = []
        let coordinator = RestartCoordinator(
            requestSave: { events.append("save") },
            flush: { events.append("flush") },
            prepareWatcher: {
                events.append("prepare")
                return { events.append("watcher") }
            },
            restore: { events.append("restore") },
            teardown: { events.append("teardown") },
            exit: { events.append("exit") },
            sleep: { delay in
                events.append("wait")
                await sleeper.sleep(for: delay)
            }
        )
        let completion = Task { try await coordinator.run() }

        await sleeper.waitUntilEntered()
        #expect(events == ["prepare", "save", "flush", "restore", "teardown", "wait"])
        #expect(sleeper.delays == [.milliseconds(650)])

        sleeper.resume()
        try await completion.value
        #expect(events == ["prepare", "save", "flush", "restore", "teardown", "wait", "watcher", "exit"])
    }

    @Test func lateRestoreCompletionDuringReclaimDelayCannotReplyTwice() async throws {
        let sleeper = ExitReclamationSleeper()
        defer { sleeper.resume() }
        var events: [String] = []
        let coordinator = TerminationCoordinator(sleep: { delay in
            events.append("wait")
            await sleeper.sleep(for: delay)
        })
        let token = try #require(coordinator.begin())
        let completion = Task {
            await coordinator.finish(
                token,
                timedOut: false,
                teardown: { events.append("teardown") },
                reply: { events.append("restoreReply") }
            )
        }
        await sleeper.waitUntilEntered()

        await coordinator.finish(
            token,
            timedOut: false,
            teardown: { events.append("duplicateTeardown") },
            reply: { events.append("duplicateReply") }
        )
        #expect(events == ["teardown", "wait"])
        #expect(sleeper.delays == [.milliseconds(150)])
        #expect(coordinator.begin() == nil)

        await coordinator.finish(
            token,
            timedOut: true,
            teardown: { events.append("timeoutTeardown") },
            reply: { events.append("timeoutReply") }
        )
        await coordinator.finish(
            token,
            timedOut: false,
            teardown: { events.append("lateTeardown") },
            reply: { events.append("lateReply") }
        )
        #expect(events == ["teardown", "wait", "timeoutReply"])
        #expect(!coordinator.isCurrent(token))

        let nextToken = try #require(coordinator.begin())
        sleeper.resume()
        await completion.value
        #expect(coordinator.isCurrent(nextToken))
        #expect(events == ["teardown", "wait", "timeoutReply"])
        #expect(sleeper.delays == [.milliseconds(150)])

        await coordinator.finish(
            nextToken,
            timedOut: true,
            teardown: { events.append("secondTeardown") },
            reply: { events.append("nextReply") }
        )
        #expect(events == ["teardown", "wait", "timeoutReply", "nextReply"])
    }
}

@MainActor
private final class ExitReclamationSleeper {
    private(set) var delays: [Duration] = []
    private var isReleased = false
    private var entry: CheckedContinuation<Void, Never>?
    private var sleepers: [CheckedContinuation<Void, Never>] = []

    func sleep(for delay: Duration) async {
        delays.append(delay)
        guard !isReleased else { return }
        await withCheckedContinuation { continuation in
            sleepers.append(continuation)
            entry?.resume()
            entry = nil
        }
    }

    func waitUntilEntered() async {
        guard delays.isEmpty else { return }
        await withCheckedContinuation { entry = $0 }
    }

    func resume() {
        isReleased = true
        for continuation in sleepers {
            continuation.resume()
        }
        sleepers.removeAll()
    }
}
