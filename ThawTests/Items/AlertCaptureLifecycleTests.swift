//
//  AlertCaptureLifecycleTests.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

import CoreGraphics
import MenuBarModel
import Testing
@testable import Thaw

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct AlertCaptureLifecycleTests {
    @Test func backgroundAlertDemandKeepsCaptureActiveWithoutVisibleConsumer() async {
        let captured = AsyncStream.makeStream(of: [String].self)
        let scheduler = AlertRevealCaptureScheduler<String>(
            inventory: { ["opted", "other"] }, identifier: { $0 },
            capture: { captured.continuation.yield($0) }
        )
        scheduler.update(identifiers: ["opted"])
        for await items in captured.stream {
            #expect(items == ["opted"])
            break
        }
        #expect(scheduler.isRunning)
        scheduler.update(identifiers: [])
    }

    @Test func backgroundAlertPlanIncludesOnlyOptedInConcealedItems() {
        struct Item { let id: String; let concealed: Bool }
        let inventory = [Item(id: "alert", concealed: true), Item(id: "other", concealed: true), Item(id: "visible", concealed: false)]
        let plan = AlertRevealCaptureScheduler<Item>.plan(items: inventory, optedIn: ["alert"], identifier: \.id)
        #expect(plan.map(\.id) == ["alert"])
        #expect(plan.allSatisfy { $0.concealed })
    }

    @Test func removingLastAlertIdentifierStopsBackgroundCapture() {
        let scheduler = AlertRevealCaptureScheduler<String>(inventory: { ["alert"] }, identifier: { $0 }, capture: { _ in })
        scheduler.update(identifiers: ["alert"])
        #expect(scheduler.isRunning)
        scheduler.update(identifiers: [])
        #expect(!scheduler.isRunning)
    }

    @Test func releasingSchedulerStopsBackgroundLifetime() async {
        let captured = AsyncStream.makeStream(of: Void.self)
        var scheduler: AlertRevealCaptureScheduler<String>? = AlertRevealCaptureScheduler(
            inventory: { ["alert"] },
            identifier: { $0 },
            capture: { _ in captured.continuation.yield(()) }
        )
        weak var released = scheduler
        scheduler?.update(identifiers: ["alert"])
        for await _ in captured.stream {
            break
        }
        scheduler = nil
        #expect(released == nil)
    }

    @Test func concealedAlertIconChangeIsObservedAndRevealed() async throws {
        let tag = MenuBarItemTag(namespace: .string("test.alert"), title: "Alert", instanceIndex: 0)
        let initial = try glyph(gray: 0)
        let changed = try glyph(gray: 1)
        var baselines = AlertRevealBaselines()
        #expect(baselines.changedIdentifiers(in: [tag: initial], enabled: [tag.tagIdentifier]).isEmpty)
        let observed = AsyncStream.makeStream(of: String.self)
        let reveals = TemporaryRevealCoordinator(reveal: { observed.continuation.yield($0) }, conceal: { _ in })
        var lease: TemporaryRevealCoordinator.Lease?
        let scheduler = AlertRevealCaptureScheduler<String>(
            inventory: { [tag.tagIdentifier] }, identifier: { $0 },
            capture: { _ in
                for identifier in baselines.changedIdentifiers(in: [tag: changed], enabled: [tag.tagIdentifier]) {
                    lease = reveals.acquire(identifier)
                }
            }
        )
        scheduler.update(identifiers: [tag.tagIdentifier])
        for await identifier in observed.stream {
            #expect(identifier == tag.tagIdentifier)
            break
        }
        scheduler.update(identifiers: [])
        if let lease {
            reveals.release(lease)
        }
    }

    @Test func concurrentTemporaryRevealSurvivesCaptureCleanup() {
        var concealed = [String]()
        let reveals = TemporaryRevealCoordinator(reveal: { _ in }, conceal: { concealed.append($0) })
        let capture = reveals.acquire("item")
        let user = reveals.acquire("item")
        reveals.release(capture)
        #expect(concealed.isEmpty)
        reveals.release(user)
        #expect(concealed == ["item"])
    }

    @Test func captureCleanupReleasesOnlyItsOwnRevealLease() {
        var concealed = [String]()
        let reveals = TemporaryRevealCoordinator(reveal: { _ in }, conceal: { concealed.append($0) })
        let user = reveals.acquire("item")
        let capture = reveals.acquire("item")
        reveals.release(capture)
        reveals.release(capture)
        #expect(concealed.isEmpty)
        reveals.release(user)
        #expect(concealed == ["item"])
    }

    @Test func lastRevealLeaseReleaseConcealsItem() {
        var revealed = [String]()
        var concealed = [String]()
        let reveals = TemporaryRevealCoordinator(reveal: { revealed.append($0) }, conceal: { concealed.append($0) })
        let one = reveals.acquire("item")
        let two = reveals.acquire("item")
        #expect(revealed == ["item"])
        reveals.release(two)
        #expect(concealed.isEmpty)
        reveals.release(one)
        #expect(concealed == ["item"])
    }

    @Test func cancelledCaptureStillReleasesItsRevealLease() async {
        var concealed = [String]()
        let reveals = TemporaryRevealCoordinator(reveal: { _ in }, conceal: { concealed.append($0) })
        let started = AsyncStream.makeStream(of: Void.self)
        let task = Task {
            let lease = reveals.acquire("item")
            defer { reveals.release(lease) }
            started.continuation.yield(())
            try? await Task.sleep(for: .seconds(60))
        }
        for await _ in started.stream {
            break
        }
        task.cancel()
        await task.value
        #expect(concealed == ["item"])
    }

    @Test func postSourceOverflowValidationDoesNotReusePreCaptureMemo() async {
        let counter = Counter()
        let gate = OverflowWalkGate<Int> { _, _ in await counter.next() }
        #expect(await gate.observation(on: 1) == 1)
        let pixelsCompletedAt = ContinuousClock.now
        #expect(await gate.observation(on: 1, newerThan: pixelsCompletedAt) == 2)
    }

    @Test func postSourceOverflowValidationDoesNotJoinPreCaptureWalk() async {
        let started = AsyncStream.makeStream(of: Void.self)
        let release = AsyncStream.makeStream(of: Void.self)
        let counter = Counter()
        let gate = OverflowWalkGate<Int> { _, _ in
            let number = await counter.next()
            if number == 1 {
                started.continuation.yield(())
                for await _ in release.stream {
                    break
                }
            }
            return number
        }
        let original = Task { await gate.observation(on: 1) }
        for await _ in started.stream {
            break
        }
        let pixelsCompletedAt = ContinuousClock.now
        #expect(await gate.observation(on: 1, newerThan: pixelsCompletedAt) == 2)
        release.continuation.finish()
        #expect(await original.value == 1)
        #expect(await gate.observation(on: 1) == 2)
    }

    private actor Counter {
        private var count = 0
        func next() -> Int {
            count += 1; return count
        }
    }

    private func glyph(gray: CGFloat) throws -> MenuBarItemGlyphCapture {
        let context = try #require(CGContext(
            data: nil, width: 20, height: 20, bitsPerComponent: 8, bytesPerRow: 80,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(gray: gray, alpha: 1)
        context.fill(CGRect(x: 2, y: 2, width: 16, height: 16))
        return try MenuBarItemGlyphCapture(cgImage: #require(context.makeImage()), scale: 1)
    }
}
