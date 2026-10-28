//
//  ExitAndBackgroundWorkRegressionTests.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

import Foundation
import os.lock
import Testing
@testable import Thaw

@MainActor
struct ExitAndBackgroundWorkRegressionTests {
    @Test func terminationTimeoutStillTearsDownControlItems() throws {
        let coordinator = TerminationCoordinator()
        let token = try #require(coordinator.begin())
        var events: [String] = []
        coordinator.finish(token, teardown: { events.append("teardown") }, reply: { events.append("reply") })
        #expect(events == ["teardown", "reply"])
        #expect(!coordinator.isCurrent(token))
    }

    @Test func successAndTimeoutShareSingleTeardown() throws {
        let coordinator = TerminationCoordinator()
        let token = try #require(coordinator.begin())
        var count = 0
        coordinator.finish(token, teardown: { count += 1 }, reply: {})
        coordinator.finish(token, teardown: { count += 1 }, reply: {})
        coordinator.tearDownOnce { count += 1 }
        #expect(count == 1)
    }

    @Test func lateRestoreCompletionCannotReplyTwice() throws {
        let coordinator = TerminationCoordinator()
        let token = try #require(coordinator.begin())
        #expect(coordinator.begin() == nil)
        var replies = 0
        coordinator.finish(token, teardown: {}, reply: { replies += 1 })
        coordinator.finish(token, teardown: {}, reply: { replies += 1 })
        #expect(replies == 1)
    }

    @Test func flushPendingSaveWaitsForQueuedWrite() async throws {
        let store = MenuBarItemImageCacheDiskStore()
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        store.enqueueDiskOperation { try? Data("queued".utf8).write(to: file) }
        await store.flush()
        #expect(try String(contentsOf: file, encoding: .utf8) == "queued")
    }

    @Test func replacementCannotLaunchBeforeRestoreAndTeardown() async throws {
        var events: [String] = []
        let coordinator = RestartCoordinator(
            requestSave: { events.append("save") },
            flush: { events.append("flush") },
            prepareWatcher: { { events.append("watcher") } },
            restore: { events.append("restore") },
            teardown: { events.append("teardown") },
            exit: { events.append("exit") }
        )
        try await coordinator.run()
        #expect(events == ["save", "flush", "restore", "teardown", "watcher", "exit"])
    }

    @Test func restartExitsOnlyAfterRelaunchWatcherStarts() async throws {
        var started = false
        var exited = false
        let coordinator = RestartCoordinator(
            requestSave: {}, flush: {}, prepareWatcher: { { started = true } }, restore: {}, teardown: {},
            exit: { #expect(started); exited = true }
        )
        try await coordinator.run()
        #expect(exited)
    }

    @Test func relaunchPreparationFailureLeavesRunningInstanceUntouched() async {
        enum Failure: Error { case preparation }
        var touched = false
        let coordinator = RestartCoordinator(
            requestSave: { touched = true }, flush: { touched = true },
            prepareWatcher: { throw Failure.preparation }, restore: { touched = true },
            teardown: { touched = true }, exit: { touched = true }
        )
        do {
            try await coordinator.run()
            Issue.record("Preparation should fail")
        } catch {
            #expect(!touched)
        }
    }

    @Test func probeDoesNotPerformFileIOOnMainThread() async {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        let result = await PermissionFileProbe.read {
            guard !Thread.isMainThread else { return false }
            do {
                try Data("probe".utf8).write(to: file)
                return try Data(contentsOf: file) == Data("probe".utf8)
            } catch { return false }
        }
        #expect(result)
    }

    @Test func permissionRefreshPublishesOnMainActor() async {
        let gate = PermissionRefreshGate()
        var published = false
        await gate.refresh(probe: { await PermissionFileProbe.read { true } }) { value in
            MainActor.assertIsolated()
            #expect(Thread.isMainThread)
            published = value
        }
        #expect(published)
    }

    @Test func staleProbeCannotOverwriteNewerAccessState() async {
        let gate = PermissionRefreshGate()
        let (started, signal) = AsyncStream<Void>.makeStream()
        let (finish, release) = AsyncStream<Void>.makeStream()
        var published: [Bool] = []
        let old = Task {
            await gate.refresh(probe: {
                signal.yield(())
                for await _ in finish {
                    break
                }
                return false
            }, publish: { published.append($0) })
        }
        for await _ in started {
            break
        }
        await gate.refresh(probe: { true }, publish: { published.append($0) })
        release.yield(())
        await old.value
        #expect(published == [true])
    }

    @Test func protectedPermissionPollingUsesBackgroundProbe() async {
        let permission = Permission(
            title: "Injected", iconName: "checkmark", iconColor: .clear, details: [],
            isRequired: false, settingsURL: nil,
            check: { Issue.record("File permissions must not use the synchronous check"); return false },
            backgroundCheck: { await PermissionFileProbe.read { !Thread.isMainThread } },
            request: { _ in }
        )
        await permission.refreshStatus()
        #expect(permission.hasPermission)
        permission.stopCheck()
    }
}

@MainActor
struct DumpBackgroundWorkRegressionTests {
    @Test func dumpDoesNotRunAXOrFileIOOnMainThread() async {
        let offMain = OSAllocatedUnfairLock(initialState: false)
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        let service = ItemEnumerationDumpService(operation: {
            {
                offMain.withLock { $0 = !Thread.isMainThread }
                try? Data("dump".utf8).write(to: file)
                return file
            }
        }, callbackURL: { _, _ in nil }, open: { _ in Issue.record("No callback expected") })
        await service.request(callback: nil)
        #expect(offMain.withLock { $0 })
        #expect(FileManager.default.fileExists(atPath: file.path))
    }

    @Test func duplicateRequestsShareOneSnapshot() async {
        let count = OSAllocatedUnfairLock(initialState: 0)
        let semaphore = DispatchSemaphore(value: 0)
        let (started, signal) = AsyncStream<Void>.makeStream()
        let service = ItemEnumerationDumpService(operation: {
            {
                count.withLock { $0 += 1 }
                signal.yield(())
                semaphore.wait()
                return URL(fileURLWithPath: "/tmp/injected-dump")
            }
        }, callbackURL: { _, _ in nil }, open: { _ in })
        let first = Task { await service.request(callback: nil) }
        for await _ in started {
            break
        }
        let (joining, joined) = AsyncStream<Void>.makeStream()
        let second = Task {
            joined.yield(())
            await service.request(callback: nil)
        }
        for await _ in joining {
            break
        }
        semaphore.signal()
        await first.value
        await second.value
        #expect(count.withLock { $0 } == 1)
    }

    @Test func callbackOpensOnMainActor() async {
        var opened = false
        let callbackOffMain = OSAllocatedUnfairLock(initialState: false)
        let service = ItemEnumerationDumpService(operation: {
            { URL(fileURLWithPath: "/tmp/injected-dump") }
        }, callbackURL: { _, _ in
            callbackOffMain.withLock { $0 = !Thread.isMainThread }
            return URL(string: "foldy-test://callback")
        }, open: { _ in
            MainActor.assertIsolated()
            #expect(Thread.isMainThread)
            opened = true
        })
        await service.request(callback: "foldy-test://callback")
        #expect(opened)
        #expect(callbackOffMain.withLock { $0 })
    }
}
