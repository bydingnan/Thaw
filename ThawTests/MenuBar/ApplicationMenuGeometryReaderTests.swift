//
//  ApplicationMenuGeometryReaderTests.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

import AppKit
import Testing
@testable import Thaw

@MainActor
struct ApplicationMenuGeometryReaderTests {
    private actor Reads {
        private var count = 0
        private var pending: [Int: CheckedContinuation<ApplicationMenuGeometryReader.Snapshot?, Never>] = [:]
        private var waiters: [(Int, CheckedContinuation<Void, Never>)] = []

        func read(_: ApplicationMenuGeometryReader.Request) async -> ApplicationMenuGeometryReader.Snapshot? {
            count += 1
            let index = count
            return await withCheckedContinuation { continuation in
                pending[index] = continuation
                let ready = waiters.filter { $0.0 <= count }
                waiters.removeAll { $0.0 <= count }
                for (_, waiter) in ready {
                    waiter.resume()
                }
            }
        }

        func waitForRead(_ index: Int) async {
            if count >= index {
                return
            }
            await withCheckedContinuation { waiters.append((index, $0)) }
        }

        func finish(_ index: Int, with snapshot: ApplicationMenuGeometryReader.Snapshot) {
            pending.removeValue(forKey: index)?.resume(returning: snapshot)
        }

        var readCount: Int {
            count
        }
    }

    private func request(pid: pid_t = 123) -> ApplicationMenuGeometryReader.Request {
        .init(displayID: 1, pid: pid, bundleIdentifier: "example.app", displayBounds: CGRect(x: 0, y: 0, width: 1200, height: 800))
    }

    private func snapshot(pid: pid_t = 123, width: CGFloat = 200) -> ApplicationMenuGeometryReader.Snapshot {
        let frame = CGRect(x: 0, y: 0, width: width, height: 24)
        return .init(pid: pid, titles: [.init(role: "AXMenuBarItem", frame: frame)], frame: frame, focus: .notFinder)
    }

    @Test func applicationMenuSnapshotUsesOneConsistentRead() async {
        let reads = Reads()
        let reader = ApplicationMenuGeometryReader { await reads.read($0) }
        let request = request()
        #expect(reader.cached(request) == nil)
        #expect(reader.cached(request) == nil)
        await reads.waitForRead(1)
        #expect(await reads.readCount == 1)
        let expected = snapshot()
        await reads.finish(1, with: expected)
        let result = await reader.snapshot(request)
        #expect(result == expected)
        #expect(result?.frame == result?.titles.first?.frame)
    }

    @Test func staleApplicationMenuReadDoesNotReplaceNewAppGeometry() async {
        let reads = Reads()
        let reader = ApplicationMenuGeometryReader { await reads.read($0) }
        let old = request(pid: 123)
        let new = request(pid: 456)
        let oldRead = Task { await reader.snapshot(old) }
        await reads.waitForRead(1)
        let newRead = Task { await reader.snapshot(new) }
        await reads.waitForRead(2)
        let expected = snapshot(pid: 456, width: 300)
        await reads.finish(2, with: expected)
        #expect(await newRead.value == expected)
        await reads.finish(1, with: snapshot())
        #expect(await oldRead.value == nil)
        #expect(reader.cached(new) == expected)
    }

    @Test func applicationMenuRefreshKeepsLastGoodGeometryWhileReadIsPending() async {
        let reads = Reads()
        let reader = ApplicationMenuGeometryReader { await reads.read($0) }
        let request = request()
        let initialRead = Task { await reader.snapshot(request) }
        await reads.waitForRead(1)
        let initial = snapshot()
        await reads.finish(1, with: initial)
        #expect(await initialRead.value == initial)
        #expect(reader.cached(request, refresh: true) == initial)
        await reads.waitForRead(2)
        #expect(reader.cached(request) == initial)
        let updated = snapshot(width: 300)
        await reads.finish(2, with: updated)
        #expect(await reader.snapshot(request) == updated)
    }

    @Test func readsAXOffMainActor() async {
        let isMain = await ApplicationMenuGeometryExecution.read(pid: getpid() + 1) { Thread.isMainThread }
        #expect(!isMain)
    }

    @Test func ownProcessApplicationMenuReadUsesMainActor() async {
        let isMain = await ApplicationMenuGeometryExecution.read(pid: getpid()) {
            MainActor.assertIsolated()
            return Thread.isMainThread
        }
        #expect(isMain)
    }

    @Test func foreignProcessApplicationMenuReadStaysConcurrent() async {
        #expect(await ApplicationMenuGeometryExecution.read(pid: getpid() + 1) { !Thread.isMainThread })
    }
}
