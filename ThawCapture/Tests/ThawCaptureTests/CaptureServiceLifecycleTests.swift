//
//  CaptureServiceLifecycleTests.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

import Testing
@testable import ThawCapture

@Suite("Capture service lifecycle")
struct CaptureServiceLifecycleTests {
    @Test
    func idleExitClaimIsRejectedWhenSessionHasReopened() {
        let lifecycle = CaptureServiceLifecycleState()
        lifecycle.sessionOpened()
        #expect(lifecycle.sessionClosed())
        let generation = lifecycle.idleGeneration
        lifecycle.sessionOpened()
        #expect(!lifecycle.claimIdleExit(since: generation))
        #expect(lifecycle.sessionClosed())
        #expect(!lifecycle.claimIdleExit(since: generation))
        #expect(lifecycle.claimIdleExit(since: lifecycle.idleGeneration))
    }

    @Test
    func idleExitClaimIsRejectedWhileRequestIsInFlight() {
        let lifecycle = CaptureServiceLifecycleState()
        lifecycle.sessionOpened()
        let request = lifecycle.requestStarted()
        #expect(!lifecycle.sessionClosed())
        let generation = lifecycle.idleGeneration
        #expect(!lifecycle.claimIdleExit(since: generation))
        #expect(lifecycle.requestFinished(request))
        #expect(lifecycle.claimIdleExit(since: generation))
    }

    @Test
    func idleExitClaimSucceedsOnlyOnceForCurrentIdleGeneration() {
        let lifecycle = CaptureServiceLifecycleState()
        lifecycle.sessionOpened()
        #expect(lifecycle.sessionClosed())
        let generation = lifecycle.idleGeneration
        #expect(lifecycle.claimIdleExit(since: generation))
        #expect(!lifecycle.claimIdleExit(since: generation))
        #expect(!lifecycle.claimExit())
    }
}
