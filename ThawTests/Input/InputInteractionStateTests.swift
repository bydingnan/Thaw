//
//  InputInteractionStateTests.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

import AppKit
import Testing
@testable import Thaw

struct InputInteractionStateTests {
    @Test func nestedPausesRemainPausedAfterHealthCheck() {
        var pauses = InputPauseCoordinator()
        let first = pauses.acquire()
        let second = pauses.acquire()
        #expect(pauses.isPaused)
        pauses.release(first)
        #expect(pauses.isPaused)
        pauses.release(second)
        #expect(!pauses.isPaused)
    }

    @Test func completingOneOfTwoLongPausesDoesNotEnableInput() {
        var pauses = InputPauseCoordinator()
        let first = pauses.acquire()
        let second = pauses.acquire()
        pauses.release(second)
        #expect(pauses.isPaused)
        pauses.release(first)
        #expect(!pauses.isPaused)
    }

    @Test func cancelledOwnerReleasesOnlyItsOwnPause() {
        var pauses = InputPauseCoordinator()
        let cancelled = pauses.acquire()
        let live = pauses.acquire()
        pauses.release(cancelled)
        pauses.release(cancelled)
        #expect(pauses.isPaused)
        pauses.release(live)
        #expect(!pauses.isPaused)
    }

    @Test func hoverUsesActiveMenuBarRatherThanInactivePointerDisplay() {
        let routing = PointerInteractionRouting(pointerDisplay: 1, activeMenuBarDisplay: 2, fallbackDisplay: 3)
        #expect(routing.revealDisplay == 2)
    }

    @Test func pointerDisplayStillDrivesControlItemUpdates() {
        let routing = PointerInteractionRouting(pointerDisplay: 1, activeMenuBarDisplay: 2, fallbackDisplay: 3)
        #expect(routing.bookkeepingDisplay == 1)
    }

    @Test func hoverAndScrollChooseSameDisplay() {
        let hover = PointerInteractionRouting(pointerDisplay: 1, activeMenuBarDisplay: 2, fallbackDisplay: 3)
        let scroll = PointerInteractionRouting<Int>(pointerDisplay: nil, activeMenuBarDisplay: 2, fallbackDisplay: 3)
        #expect(hover.revealDisplay == scroll.revealDisplay)
        #expect(scroll.revealDisplay == 2)
    }

    @Test func screenParameterChangeRebuildsFromUnchangedItemCache() {
        let cache = PointerBoundsCache()
        let original = CGRect(x: 100, y: 0, width: 24, height: 24)
        cache.refresh(live: [], onScreen: [], managed: [(7, original)])
        let moved = original.offsetBy(dx: 500, dy: 1000)
        cache.refresh(live: [(7, moved)], onScreen: [], managed: [(7, original)])
        #expect(cache.entries.first?.bounds == moved)
    }

    @Test func resolutionChangeDoesNotLeaveTooltipLookupEmpty() {
        let cache = PointerBoundsCache()
        let rect = CGRect(x: 100, y: 0, width: 24, height: 24)
        cache.refresh(live: [], onScreen: [], managed: [(7, rect)])
        cache.refresh(live: [], onScreen: [], managed: [(7, rect)])
        #expect(cache.entries.first(where: { $0.bounds.contains(CGPoint(x: 110, y: 10)) })?.windowID == 7)
    }

    @Test func refreshKeepsOnScreenOnlyItems() {
        let cache = PointerBoundsCache()
        let rect = CGRect(x: 100, y: 0, width: 24, height: 24)
        cache.refresh(live: [], onScreen: [(8, rect)], managed: [])
        #expect(cache.entries.map(\.windowID) == [8])
        cache.refresh(live: [], onScreen: [], managed: [])
        #expect(cache.entries.isEmpty)
    }

    @MainActor @Test func disablingInputEndsActiveDrag() {
        let drag = MenuBarDragSession()
        drag.begin()
        #expect(drag.cancel())
        #expect(!drag.isActive)
    }

    @MainActor @Test func lostMouseUpDoesNotLeaveCachingSuspended() {
        let drag = MenuBarDragSession()
        drag.begin()
        drag.reconcile(isButtonDown: false)
        #expect(!drag.end())
        #expect(!drag.isActive)
    }

    @MainActor @Test func nextCommandDragCanStartAfterCancellation() {
        let drag = MenuBarDragSession()
        drag.begin()
        drag.cancel()
        drag.begin()
        #expect(drag.isActive)
        #expect(drag.end())
    }

    @Test func diagonalGestureUsesDominantAxis() {
        #expect(ScrollRevealIntent.action(deltaX: 3, deltaY: 8, isMomentum: false) == .show)
    }

    @Test func opposingAxesDoNotCancelIntentionalScroll() {
        #expect(ScrollRevealIntent.action(deltaX: -9, deltaY: 8, isMomentum: false) == .hide)
    }

    @Test func smallMomentumNoiseDoesNotReveal() {
        #expect(ScrollRevealIntent.action(deltaX: 1, deltaY: 2, isMomentum: true) == nil)
        #expect(ScrollRevealIntent.action(deltaX: 1, deltaY: 20, isMomentum: true) == nil)
    }

    @Test func horizontalAndVerticalThresholdsRemainConsistent() {
        for delta: CGFloat in [-6, -5, 0, 5, 6] {
            #expect(ScrollRevealIntent.action(deltaX: delta, deltaY: 0, isMomentum: false)
                == ScrollRevealIntent.action(deltaX: 0, deltaY: delta, isMomentum: false))
        }
        #expect(ScrollRevealIntent.action(deltaX: 5, deltaY: 0, isMomentum: false) == nil)
    }
}

struct EventTapResourceFailureTests {
    private final class Port {
        var enabled = true
        var invalidated = false
    }

    @Test func runLoopSourceFailureDisablesAndInvalidatesMachPort() {
        let port = Port()
        var released = false
        let result: (port: Port, source: Int)? = EventTapResourceCreation.create(
            makePort: { port }, makeSource: { _ in nil },
            disable: { $0.enabled = false }, invalidate: { $0.invalidated = true },
            releaseContext: { released = true }
        )
        #expect(result == nil)
        #expect(!port.enabled)
        #expect(port.invalidated)
        #expect(released)
    }

    @Test func failedPartialCreationDoesNotRegisterOrLeakTap() {
        var releases = 0
        var registered = false
        let result: (port: Port, source: Int)? = EventTapResourceCreation.create(
            makePort: { Port() }, makeSource: { _ in nil },
            disable: { $0.enabled = false }, invalidate: { $0.invalidated = true },
            releaseContext: { releases += 1 }
        )
        if result != nil {
            registered = true
        }
        #expect(!registered)
        #expect(releases == 1)
    }

    @Test func recreationAfterPartialFailureStartsDisabled() {
        for succeeds in [false, true] {
            let port = Port()
            let result: (port: Port, source: Int)? = EventTapResourceCreation.create(
                makePort: { port }, makeSource: { _ in succeeds ? 1 : nil },
                disable: { $0.enabled = false }, invalidate: { $0.invalidated = true },
                releaseContext: {}
            )
            #expect(!port.enabled)
            #expect(port.invalidated == !succeeds)
            #expect((result != nil) == succeeds)
        }
    }
}
